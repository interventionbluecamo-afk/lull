import AVFoundation
import AudioToolbox
import UIKit

/// Lull's sound system: one engine, one room, one loudness standard.
///
/// Every sound is a cue from `LullSoundBook` (rendered once from physical models, then cached),
/// played on a small pool of voices that feed per-bus mixers, a shared small room, a gentle
/// speaker EQ and a peak limiter, so no combination of toys can ever get loud or harsh.
///
/// - Cues: `play(cue:)` with optional pan, volume and a sample-accurate delay.
/// - Variation: most cues render several variants that rotate without immediate repeats.
/// - Held notes (Hum): `startHeldNote` / `releaseHeldNote` with smooth fades.
/// - Room beds: quiet generative loops per toy, dimmed and put to sleep by idle time.
/// - Lifecycle: Sound Off, backgrounding and interruptions stop every voice, loop, held note and
///   queued note; returning resumes only the room bed. The parent's Sound control is the gate,
///   including on a phone in Silent Mode (category .playback, mixing with other audio).
final class AudioManager: LullTonePlayer {
    static let shared = AudioManager()

    // MARK: - Preferences and lifecycle state

    var isEnabled: Bool {
        get { LullDemoState.shared.isSoundEnabled }
        set {
            LullDemoState.shared.isSoundEnabled = newValue
            if newValue {
                resumeRoomAudio()
            } else {
                suspendPlayback()
                deactivateAudioSession()
            }
        }
    }

    var currentToyVoice: LullSoundVoice = .none

    private var sessionIsActive = false
    private var applicationIsActive = UIApplication.shared.applicationState == .active
    private var audioIsInterrupted = false
    private var audioObservers: [NSObjectProtocol] = []

    // MARK: - Engine graph

    private let engine = AVAudioEngine()
    private let monoFormat = AVAudioFormat(standardFormatWithSampleRate: LullSynth.sampleRate, channels: 1)!
    private let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: LullSynth.sampleRate, channels: 2)!
    private let submix = AVAudioMixerNode()
    private let room = AVAudioUnitReverb()
    private let speakerEQ = AVAudioUnitEQ(numberOfBands: 2)
    private let limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_PeakLimiter,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0))
    private var busMixers: [LullSoundBus: AVAudioMixerNode] = [:]
    private var graphBuilt = false

    private final class Voice {
        let node = AVAudioPlayerNode()
        let bus: LullSoundBus
        var startedAt: CFTimeInterval = 0
        var endsAt: CFTimeInterval = 0
        var heldToken: Int?
        init(bus: LullSoundBus) { self.bus = bus }
    }

    private final class LoopSlot {
        let node = AVAudioPlayerNode()
        var id: String?
        var level: Float = 0
    }

    private static let voicesPerBus: [LullSoundBus: Int] = [.ui: 4, .effects: 12, .music: 12, .voices: 6]
    private var voices: [LullSoundBus: [Voice]] = [:]
    private var loopSlots: [LoopSlot] = (0..<6).map { _ in LoopSlot() }

    // MARK: - Sound cache

    private var cache: [String: [AVAudioPCMBuffer]] = [:]
    private var cacheBus: [String: LullSoundBus] = [:]
    private var rendering: Set<String> = []
    private var lastVariant: [String: Int] = [:]
    private var lastPlayTime: [String: CFTimeInterval] = [:]
    private let renderQueue = DispatchQueue(label: "com.lull.sound.render", qos: .utility)

    // MARK: - Fades

    private struct Fade {
        let node: AVAudioPlayerNode
        let from: Float
        let to: Float
        let start: CFTimeInterval
        let duration: CFTimeInterval
        let stopAtEnd: Bool
        let onStop: (() -> Void)?
    }

    private var fades: [ObjectIdentifier: Fade] = [:]
    private var fadeTimer: Timer?
    private var heldTokens = 0
    private var sprinkleTimer: Timer?

    private init() {
        LullToneEngine.shared.player = self
        observeAudioLifecycle()
    }

    // MARK: - Cues

    /// Plays one cue. `pan` is -1 (left) ... 1 (right); it is kept subtle. `delay` schedules the
    /// cue sample-accurately; every queued cue is cancelled by Sound Off, backgrounding or an
    /// interruption. Returns false when sound is off or the cue does not exist.
    @discardableResult
    func play(cue id: String, pan: Float = 0, volume: Float = 1, delay: TimeInterval = 0) -> Bool {
        guard prepareForPlayback(), startEngineIfNeeded() else { return false }
        let now = CACurrentMediaTime()
        let cooldown = Self.cooldown(for: id)
        if let last = lastPlayTime[id], now - last < cooldown { return false }
        guard let buffer = nextBuffer(for: id) else { return false }
        lastPlayTime[id] = now
        schedule(buffer, bus: cacheBus[id] ?? .effects, pan: pan, volume: volume, delay: delay)
        return true
    }

    /// Subtle stereo position for a point in a scene (phones in landscape and headphones).
    static func pan(x: CGFloat, width: CGFloat) -> Float {
        guard width > 0 else { return 0 }
        return Float(max(-0.35, min(0.35, (x / width * 2 - 1) * 0.35)))
    }

    /// Renders a toy's cues ahead of time on a background queue, so the first touch is instant.
    func prewarm(prefixes: [String]) {
        let ids = LullSoundBook.cueIDs.filter { id in prefixes.contains { id.hasPrefix($0) } }
        for id in ids { prewarm(cue: id) }
    }

    func prewarm(cue id: String) {
        guard cache[id] == nil, !rendering.contains(id) else { return }
        rendering.insert(id)
        let count = LullSoundBook.variants(for: id)
        let format = monoFormat
        renderQueue.async {
            let rendered = (0..<count).compactMap { LullSoundBook.render(id, variant: $0) }
            let buffers = rendered.compactMap { AudioManager.makeBuffer($0.samples, format: format) }
            let bus = rendered.first?.bus ?? .effects
            DispatchQueue.main.async { AudioManager.shared.store(id, buffers: buffers, bus: bus, replace: false) }
        }
    }

    /// Main-thread landing for buffers rendered in the background.
    private func store(_ id: String, buffers: [AVAudioPCMBuffer], bus: LullSoundBus, replace: Bool) {
        rendering.remove(id)
        guard !buffers.isEmpty else { return }
        if cache[id] == nil || replace {
            cache[id] = buffers
            cacheBus[id] = bus
        } else {
            cache[id, default: []].append(contentsOf: buffers)
        }
    }

    // MARK: - Held notes (Hum)

    /// Starts a note that rings while a finger stays down. Returns a token for release, or nil.
    func startHeldNote(cue id: String, pan: Float = 0, volume: Float = 1) -> Int? {
        guard prepareForPlayback(), startEngineIfNeeded(), let buffer = nextBuffer(for: id) else { return nil }
        heldTokens += 1
        let token = heldTokens
        let voice = schedule(buffer, bus: .music, pan: pan, volume: volume, delay: 0)
        voice?.heldToken = token
        return voice == nil ? nil : token
    }

    /// Lets a held note go with a soft fade. Struck instruments simply keep ringing out when
    /// `fade` is nil.
    func releaseHeldNote(_ token: Int, fade: TimeInterval? = 0.35) {
        for pool in voices.values {
            for voice in pool where voice.heldToken == token {
                voice.heldToken = nil
                if let fade { fadeNode(voice.node, to: 0, duration: fade, stopAtEnd: true) }
            }
        }
    }

    func releaseAllHeldNotes(fade: TimeInterval = 0.3) {
        for pool in voices.values {
            for voice in pool where voice.heldToken != nil {
                voice.heldToken = nil
                fadeNode(voice.node, to: 0, duration: fade, stopAtEnd: true)
            }
        }
    }

    // MARK: - Named sounds (the toys' vocabulary)

    func playBubblePop(size: CGFloat, isRare: Bool = false) {
        if isRare {
            play(cue: "bubble.rare")
        } else if size < 50 {
            play(cue: "bubble.small")
        } else if size < 82 {
            play(cue: "bubble.medium")
        } else {
            play(cue: "bubble.large")
        }
    }

    func playSoftTap() {
        play(cue: "ui.tap")
        HapticsManager.shared.softTap()
    }

    func playEmptyTap() {
        play(cue: "ui.empty")
        HapticsManager.shared.emptyTap()
    }

    func playBlockPickup() { play(cue: "stack.lift") }
    func playBlockRelease() { play(cue: "stack.place") }
    func playBlockSettle() { play(cue: "stack.settle.medium") }
    func playMysteryShape() { play(cue: "stack.wake") }
    func playShelfTransition() { play(cue: "ui.transition") }
    func playToyNotice() { play(cue: "ui.notice") }
    func playToySettle() { play(cue: "ui.settle") }
    func playBubbleNotice() { play(cue: "bubble.notice") }
    func playBubbleBreath() { play(cue: "bubble.breath") }
    func playFoodPickup() { play(cue: "feed.pickup") }
    func playFoodRelease() { play(cue: "feed.release") }
    func playFoodPlop() { play(cue: "feed.plop") }
    func playFeedReceive() { play(cue: "feed.receive") }

    func playFeedHappy() {
        play(cue: "feed.happy")
        HapticsManager.shared.softTap()
    }

    func playFeedDecline() { play(cue: "feed.decline") }

    /// Three bites, timed to the friend's chewing frames.
    func playFeedChew(isCrunchy: Bool) {
        play(cue: isCrunchy ? "feed.chew.crunchy" : "feed.chew.soft")
    }

    func playFeedSuccess() {
        play(cue: "feed.success")
        HapticsManager.shared.celebration()
    }

    func playStackPlace() {
        play(cue: "stack.place")
        HapticsManager.shared.blockRelease()
    }

    func playStackLift() {
        play(cue: "stack.lift")
        HapticsManager.shared.blockPickup()
    }

    /// `hardness` 0...1 from the impact speed: softer landings are quieter and rounder.
    func playStackSettle(hardness: Float = 1.0) {
        let cue = hardness < 0.35 ? "stack.settle.soft" : (hardness < 0.7 ? "stack.settle.medium" : "stack.settle.hard")
        play(cue: cue, volume: 0.75 + 0.25 * max(0, min(1, hardness)))
        HapticsManager.shared.blockSettle()
    }

    func playStackWake() {
        play(cue: "stack.wake")
        HapticsManager.shared.mysteryShape()
    }

    func playStackKnockover() { play(cue: "stack.knockover") }

    // Parked Bloom toy (kept compiling; not on the shelf).
    func playBloomPlant() {
        play(cue: "meadow.bloom")
        HapticsManager.shared.softTap()
    }
    func playBloomStretch() { play(cue: "meadow.paint") }
    func playBloomFlourish() {
        play(cue: "meadow.spring")
        HapticsManager.shared.mysteryShape()
    }
    func playBloomSettle() { play(cue: "ui.settle") }
    func playBloomCritter() {
        play(cue: "bird")
        HapticsManager.shared.softTap()
    }
    func playBloomSeasonChime(for season: LullToneEngine.BloomSeason) { play(cue: "ui.notice") }

    func playMixFlip() {
        play(cue: "mix.flip")
        HapticsManager.shared.softTap()
    }

    func playMixCelebrate() {
        play(cue: "mix.celebrate")
        HapticsManager.shared.softTap()
    }

    func playMixSettle() { play(cue: "mix.settle") }

    func playMixCelebrationCombo() { play(cue: "mix.save") }

    /// A Mix-Up friend's own voice. `name` is the friend's cast name (bunny, bear, songbird,
    /// fox, mouse, frog, robot, officer, firefighter). `.arrive` plays when that friend's head
    /// lands; `.wholeFriend` when head, body and legs all belong to the same friend.
    enum MixFriendMoment { case arrive, wholeFriend }

    func playMixFriend(_ name: String, moment: MixFriendMoment) {
        let id = "friend.\(name)" + (moment == .wholeFriend ? ".whole" : "")
        guard LullSoundBook.cueIDs.contains(id) else {
            play(cue: moment == .wholeFriend ? "mix.celebrate" : "mix.settle")
            return
        }
        play(cue: id, delay: moment == .arrive ? 0.05 : 0)
    }

    func playBird() { play(cue: "bird") }
    func playBoxOpen() { play(cue: "box.open") }
    func playWindowCatHappy() { play(cue: "window.cat") }
    func playWindowToyboxOpen() { play(cue: "window.toybox.open") }

    func updateSoundPosition(nodeID: String, screenPoint: CGPoint, sceneSize: CGSize) {}

    // MARK: - Room beds

    enum LullSoundVoice: Equatable {
        case none
        case bubbles
        case bloom
        case hum
        case stack
        case mixUp
        case feed
        case glowboard   // Meadow
        case rollway

        var pitchMultiplier: Double { 1.0 }

        var ambientID: String? {
            switch self {
            case .none, .hum: return nil
            case .bubbles: return "bed.airy"
            case .glowboard, .bloom: return "bed.breeze"
            case .stack, .mixUp, .feed, .rollway: return "bed.room"
            }
        }

        /// Loop level for the room bed (the bed itself is mastered quiet).
        var baseAmbientVolume: Float {
            switch self {
            case .none, .hum: return 0
            case .bubbles: return 0.9
            case .glowboard, .bloom: return 1.0
            case .stack, .mixUp, .feed, .rollway: return 0.7
            }
        }

        /// Occasional creatures in the bed (outdoor rooms only).
        var hasBirds: Bool { self == .glowboard || self == .bloom }
    }

    func startToyAmbient(_ voice: LullSoundVoice) {
        guard let id = voice.ambientID, prepareForPlayback(), startEngineIfNeeded() else { return }
        guard let buffer = bedBuffer(id) else { return }
        playLoop(id: id, buffer: buffer, volume: voice.baseAmbientVolume, fadeIn: 1.8)
        if voice.hasBirds { startSprinkles() }
    }

    func stopToyAmbient(_ voice: LullSoundVoice) {
        if let id = voice.ambientID { stopLoop(id: id, fadeOut: 1.5) }
        stopLoop(id: "bed.sleep", fadeOut: 1.0)
        stopSprinkles()
    }

    func wakeAmbient(_ voice: LullSoundVoice) {
        if let id = voice.ambientID { setLoopVolume(id: id, voice.baseAmbientVolume, duration: 2.0) }
        stopLoop(id: "bed.sleep", fadeOut: 1.5)
    }

    func dimAmbient(_ voice: LullSoundVoice) {
        if let id = voice.ambientID { setLoopVolume(id: id, voice.baseAmbientVolume * 0.6, duration: 3.0) }
    }

    func sleepAmbient(_ voice: LullSoundVoice) {
        if let id = voice.ambientID { setLoopVolume(id: id, 0, duration: 4.0) }
        stopSprinkles()
        guard prepareForPlayback(), startEngineIfNeeded(), let buffer = bedBuffer("bed.sleep") else { return }
        playLoop(id: "bed.sleep", buffer: buffer, volume: 0.8, fadeIn: 3.0)
    }

    // MARK: Window day/night beds

    private var windowDayPhase: CGFloat?

    func setWindowAmbience(dayPhase: CGFloat, animated: Bool) {
        windowDayPhase = dayPhase
        guard prepareForPlayback(), startEngineIfNeeded(),
              let day = bedBuffer("bed.room"), let night = bedBuffer("bed.night") else { return }
        let n = smoothstep(0.58, 0.86, dayPhase)
        let wasActive = loopSlots.contains { $0.id == "window.day" || $0.id == "window.night" }
        let duration: TimeInterval = wasActive ? (animated ? 0.85 : 0.28) : 1.35
        playLoop(id: "window.day", buffer: day, volume: Float(1 - n) * 0.9, fadeIn: duration)
        playLoop(id: "window.night", buffer: night, volume: Float(n) * 0.9, fadeIn: duration)
    }

    func stopWindowAmbience(fadeOut: TimeInterval = 1.2) {
        windowDayPhase = nil
        stopLoop(id: "window.day", fadeOut: fadeOut)
        stopLoop(id: "window.night", fadeOut: fadeOut)
    }

    // MARK: - Session and lifecycle

    /// All playback shares this live gate. Failed activation is retried on the next interaction
    /// rather than leaving the toybox silent until relaunch.
    @discardableResult
    func prepareForPlayback() -> Bool {
        guard isEnabled, applicationIsActive, !audioIsInterrupted else { return false }
        guard !sessionIsActive else { return true }
        do {
            // Toy sound follows the parent's Sound control, including on a phone in Silent Mode.
            // Mixing lets a family's music continue; the app has no background-audio entitlement.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setPreferredSampleRate(LullSynth.sampleRate)
            try? AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.005)
            try AVAudioSession.sharedInstance().setActive(true)
            sessionIsActive = true
            return true
        } catch {
            sessionIsActive = false
            #if DEBUG
            print("AudioManager: audio session could not be activated: \(error)")
            #endif
            return false
        }
    }

    private func observeAudioLifecycle() {
        let center = NotificationCenter.default
        audioObservers.append(center.addObserver(forName: UIApplication.willResignActiveNotification,
                                                object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.applicationIsActive = false
            self.suspendPlayback()
            self.deactivateAudioSession()
        })
        audioObservers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.applicationIsActive = true
            self.resumeRoomAudio()
        })
        audioObservers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                                object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] note in
            guard let self,
                  let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
            self.sessionIsActive = false
            switch type {
            case .began:
                self.audioIsInterrupted = true
                self.suspendPlayback()
            case .ended:
                self.audioIsInterrupted = false
                let rawOptions = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                if AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume) {
                    self.resumeRoomAudio()
                }
            @unknown default:
                break
            }
        })
        // A route or sample-rate change (headphones, Bluetooth) stops the engine; rebuild the
        // connections at the new hardware format and carry on with the room bed.
        audioObservers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange,
                                                object: engine, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.stopAllVoicesAndLoops()
            self.resumeRoomAudio()
        })
        audioObservers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                                object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.sessionIsActive = false
            self.stopAllVoicesAndLoops()
            self.resumeRoomAudio()
        })
    }

    private func deactivateAudioSession() {
        sessionIsActive = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // The engine and players are already stopped; a phone interruption can own the session.
        }
    }

    /// Stops every voice, held note, queued note and loop, and pauses the engine.
    private func suspendPlayback() {
        stopAllVoicesAndLoops()
        lastPlayTime.removeAll()
        stopSprinkles()
        if engine.isRunning { engine.pause() }
    }

    private func resumeRoomAudio() {
        guard prepareForPlayback() else { return }
        // Resume only the room bed. Held Hum notes and old celebrations need a new gesture.
        startToyAmbient(currentToyVoice)
        if let phase = windowDayPhase {
            setWindowAmbience(dayPhase: phase, animated: false)
        }
    }

    private func stopAllVoicesAndLoops() {
        fades.removeAll()
        fadeTimer?.invalidate()
        fadeTimer = nil
        for pool in voices.values {
            for voice in pool {
                voice.node.stop()
                voice.heldToken = nil
                voice.endsAt = 0
            }
        }
        for slot in loopSlots {
            slot.node.stop()
            slot.id = nil
            slot.level = 0
        }
    }

    // MARK: - Engine

    private func buildGraphIfNeeded() {
        guard !graphBuilt else { return }
        graphBuilt = true

        engine.attach(submix)
        engine.attach(room)
        engine.attach(speakerEQ)
        engine.attach(limiter)

        room.loadFactoryPreset(.smallRoom)
        room.wetDryMix = 9

        // Phone speakers can't move air below ~110 Hz; removing it keeps headroom for what they can.
        let lowCut = speakerEQ.bands[0]
        lowCut.filterType = .highPass
        lowCut.frequency = 110
        lowCut.bypass = false
        let soften = speakerEQ.bands[1]
        soften.filterType = .highShelf
        soften.frequency = 9000
        soften.gain = -2
        soften.bypass = false

        for bus in LullSoundBus.allCases {
            let mixer = AVAudioMixerNode()
            engine.attach(mixer)
            engine.connect(mixer, to: submix, fromBus: 0, toBus: submix.nextAvailableInputBus, format: stereoFormat)
            busMixers[bus] = mixer
        }
        for (bus, count) in Self.voicesPerBus {
            guard let mixer = busMixers[bus] else { continue }
            voices[bus] = (0..<count).map { _ in
                let voice = Voice(bus: bus)
                engine.attach(voice.node)
                engine.connect(voice.node, to: mixer, fromBus: 0, toBus: mixer.nextAvailableInputBus, format: monoFormat)
                return voice
            }
        }
        if let ambience = busMixers[.ambience] {
            for slot in loopSlots {
                engine.attach(slot.node)
                engine.connect(slot.node, to: ambience, fromBus: 0, toBus: ambience.nextAvailableInputBus, format: monoFormat)
            }
        }

        engine.connect(submix, to: room, format: stereoFormat)
        engine.connect(room, to: speakerEQ, format: stereoFormat)
        engine.connect(speakerEQ, to: limiter, format: stereoFormat)
        engine.connect(limiter, to: engine.mainMixerNode, format: stereoFormat)

        let unit = limiter.audioUnit
        AudioUnitSetParameter(unit, AudioUnitParameterID(kLimiterParam_AttackTime), AudioUnitScope(kAudioUnitScope_Global), 0, 0.003, 0)
        AudioUnitSetParameter(unit, AudioUnitParameterID(kLimiterParam_DecayTime), AudioUnitScope(kAudioUnitScope_Global), 0, 0.08, 0)
        AudioUnitSetParameter(unit, AudioUnitParameterID(kLimiterParam_PreGain), AudioUnitScope(kAudioUnitScope_Global), 0, 0, 0)
        engine.prepare()
    }

    private func startEngineIfNeeded() -> Bool {
        buildGraphIfNeeded()
        if engine.isRunning { return true }
        do {
            try engine.start()
            return true
        } catch {
            #if DEBUG
            print("AudioManager: engine could not start: \(error)")
            #endif
            return false
        }
    }

    @discardableResult
    private func schedule(_ buffer: AVAudioPCMBuffer, bus: LullSoundBus, pan: Float, volume: Float,
                          delay: TimeInterval) -> Voice? {
        let poolBus: LullSoundBus = bus == .ambience ? .effects : bus
        guard let voice = takeVoice(poolBus) else { return nil }
        let node = voice.node
        fades.removeValue(forKey: ObjectIdentifier(node))
        if node.isPlaying { node.stop() }
        node.volume = max(0, min(1.5, volume))
        node.pan = max(-1, min(1, pan))
        var when: AVAudioTime?
        if delay > 0.001 {
            when = AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: delay))
        }
        node.scheduleBuffer(buffer, at: when, options: [], completionHandler: nil)
        node.play()
        let now = CACurrentMediaTime()
        voice.startedAt = now + delay
        voice.endsAt = now + delay + Double(buffer.frameLength) / LullSynth.sampleRate
        voice.heldToken = nil
        return voice
    }

    /// An idle voice, else the one that started longest ago (mostly decayed). Held notes are
    /// stolen only when every voice on the bus is held.
    private func takeVoice(_ bus: LullSoundBus) -> Voice? {
        guard let pool = voices[bus], !pool.isEmpty else { return nil }
        let now = CACurrentMediaTime()
        if let idle = pool.first(where: { $0.heldToken == nil && $0.endsAt <= now }) { return idle }
        let free = pool.filter { $0.heldToken == nil }
        return (free.isEmpty ? pool : free).min { $0.startedAt < $1.startedAt }
    }

    // MARK: Buffers

    private func nextBuffer(for id: String) -> AVAudioPCMBuffer? {
        if cache[id] == nil {
            // Not prewarmed: render one variant now (a few milliseconds) and the rest later.
            guard let first = LullSoundBook.render(id, variant: 0),
                  let buffer = Self.makeBuffer(first.samples, format: monoFormat) else { return nil }
            cache[id] = [buffer]
            cacheBus[id] = first.bus
            if LullSoundBook.variants(for: id) > 1 { refillVariants(id) }
            return buffer
        }
        guard let buffers = cache[id], !buffers.isEmpty else { return nil }
        var index = Int.random(in: 0..<buffers.count)
        if buffers.count > 1, index == lastVariant[id] { index = (index + 1) % buffers.count }
        lastVariant[id] = index
        return buffers[index]
    }

    private func refillVariants(_ id: String) {
        guard !rendering.contains(id) else { return }
        rendering.insert(id)
        let count = LullSoundBook.variants(for: id)
        let format = monoFormat
        let bus = cacheBus[id] ?? .effects
        renderQueue.async {
            let more = (1..<count).compactMap { LullSoundBook.render(id, variant: $0) }
                .compactMap { AudioManager.makeBuffer($0.samples, format: format) }
            DispatchQueue.main.async { AudioManager.shared.store(id, buffers: more, bus: bus, replace: false) }
        }
    }

    private func bedBuffer(_ id: String) -> AVAudioPCMBuffer? {
        if let cached = cache[id]?.first { return cached }
        let room = String(id.dropFirst("bed.".count))
        guard let samples = LullSoundBook.bed(room), let buffer = Self.makeBuffer(samples, format: monoFormat) else { return nil }
        cache[id] = [buffer]
        cacheBus[id] = .ambience
        return buffer
    }

    static func makeBuffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for i in 0..<samples.count { channel[i] = samples[i] }
        return buffer
    }

    /// Minimum seconds between two plays of the same cue (keeps rapid taps from stacking).
    private static func cooldown(for id: String) -> TimeInterval {
        if id.hasPrefix("bubble.") { return 0.035 }
        if id.hasPrefix("note.") { return 0.02 }
        switch id {
        case "meadow.paint": return 0.14
        case "dots.fall", "dots.hover", "sleepy.hover", "window.dial": return 0.06
        case "stack.settle.soft", "stack.settle.medium", "stack.settle.hard": return 0.08
        case "ui.tap", "ui.empty", "mix.flip": return 0.05
        case "feed.chew.soft", "feed.chew.crunchy": return 0.4
        default: return 0.03
        }
    }

    // MARK: Loops

    private func playLoop(id: String, buffer: AVAudioPCMBuffer, volume: Float, fadeIn: TimeInterval) {
        if let slot = loopSlots.first(where: { $0.id == id }), slot.node.isPlaying {
            slot.level = volume
            fadeNode(slot.node, to: volume, duration: fadeIn, stopAtEnd: false)
            return
        }
        guard volume > 0.001 else { return }
        guard let slot = loopSlots.first(where: { $0.id == nil || !$0.node.isPlaying }) else { return }
        slot.id = id
        slot.level = volume
        let node = slot.node
        fades.removeValue(forKey: ObjectIdentifier(node))
        if node.isPlaying { node.stop() }
        node.volume = 0
        node.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        node.play()
        fadeNode(node, to: volume, duration: fadeIn, stopAtEnd: false)
    }

    private func stopLoop(id: String, fadeOut: TimeInterval) {
        for slot in loopSlots where slot.id == id {
            slot.level = 0
            fadeNode(slot.node, to: 0, duration: fadeOut, stopAtEnd: true) { [weak slot] in slot?.id = nil }
        }
    }

    private func setLoopVolume(id: String, _ volume: Float, duration: TimeInterval) {
        for slot in loopSlots where slot.id == id {
            slot.level = volume
            fadeNode(slot.node, to: volume, duration: duration, stopAtEnd: false)
        }
    }

    // MARK: Fades

    private func fadeNode(_ node: AVAudioPlayerNode, to target: Float, duration: TimeInterval, stopAtEnd: Bool,
                          onStop: (() -> Void)? = nil) {
        guard duration > 0.01 else {
            node.volume = target
            if stopAtEnd { node.stop(); onStop?() }
            return
        }
        fades[ObjectIdentifier(node)] = Fade(node: node, from: node.volume, to: target, start: CACurrentMediaTime(),
                                             duration: duration, stopAtEnd: stopAtEnd, onStop: onStop)
        if fadeTimer == nil {
            let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.stepFades() }
            RunLoop.main.add(timer, forMode: .common)
            fadeTimer = timer
        }
    }

    private func stepFades() {
        let now = CACurrentMediaTime()
        for (key, fade) in fades {
            let p = Float(min(1, (now - fade.start) / fade.duration))
            let eased = p * p * (3 - 2 * p)
            fade.node.volume = fade.from + (fade.to - fade.from) * eased
            if p >= 1 {
                fades.removeValue(forKey: key)
                if fade.stopAtEnd {
                    fade.node.stop()
                    fade.onStop?()
                }
            }
        }
        if fades.isEmpty {
            fadeTimer?.invalidate()
            fadeTimer = nil
        }
    }

    // MARK: Outdoor sprinkles (a bird now and then)

    private func startSprinkles() {
        guard sprinkleTimer == nil else { return }
        scheduleNextSprinkle()
    }

    private func scheduleNextSprinkle() {
        sprinkleTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 9...20), repeats: false) { [weak self] _ in
            guard let self else { return }
            self.sprinkleTimer = nil
            guard self.currentToyVoice.hasBirds else { return }
            self.play(cue: "bird", pan: Float.random(in: -0.3...0.3), volume: 0.35)
            self.scheduleNextSprinkle()
        }
    }

    private func stopSprinkles() {
        sprinkleTimer?.invalidate()
        sprinkleTimer = nil
    }

    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    // MARK: - LullTonePlayer (the older note-and-preset interface)

    func playRendered(_ key: String, render: @escaping () -> LullRenderedSound) {
        guard prepareForPlayback(), startEngineIfNeeded() else { return }
        guard let buffer = legacyBuffer(key, render: render) else { return }
        schedule(buffer, bus: cacheBus[key] ?? .music, pan: 0, volume: 1, delay: 0)
    }

    func prewarmRendered(_ key: String, render: @escaping () -> LullRenderedSound) {
        guard cache[key] == nil, !rendering.contains(key) else { return }
        rendering.insert(key)
        let format = monoFormat
        renderQueue.async {
            let rendered = render()
            let buffers = AudioManager.makeBuffer(rendered.samples, format: format).map { [$0] } ?? []
            let bus = rendered.bus
            DispatchQueue.main.async { AudioManager.shared.store(key, buffers: buffers, bus: bus, replace: false) }
        }
    }

    func playLegacySequence(_ steps: [(key: String, delay: Double, render: () -> LullRenderedSound)]) {
        guard prepareForPlayback(), startEngineIfNeeded() else { return }
        for step in steps {
            guard let buffer = legacyBuffer(step.key, render: step.render) else { continue }
            schedule(buffer, bus: cacheBus[step.key] ?? .music, pan: 0, volume: 1, delay: step.delay)
        }
    }

    func playLegacyAmbient(id: String, volume: Float, fadeIn: TimeInterval, render: @escaping () -> LullRenderedSound) {
        guard prepareForPlayback(), startEngineIfNeeded(),
              let buffer = legacyBuffer("ambient." + id, render: render) else { return }
        playLoop(id: id, buffer: buffer, volume: min(1, volume * 12), fadeIn: fadeIn)
    }

    func stopLegacyAmbient(id: String, fadeOut: TimeInterval) { stopLoop(id: id, fadeOut: fadeOut) }

    func setLegacyAmbientVolume(_ volume: Float, for id: String, duration: TimeInterval) {
        setLoopVolume(id: id, min(1, volume * 12), duration: duration)
    }

    func stopEverything() { stopAllVoicesAndLoops() }

    private func legacyBuffer(_ key: String, render: () -> LullRenderedSound) -> AVAudioPCMBuffer? {
        if let cached = cache[key]?.first { return cached }
        let rendered = render()
        guard let buffer = Self.makeBuffer(rendered.samples, format: monoFormat) else { return nil }
        cache[key] = [buffer]
        cacheBus[key] = rendered.bus
        return buffer
    }
}
