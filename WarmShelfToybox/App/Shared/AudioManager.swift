import AVFoundation
import QuartzCore

final class AudioManager {
    static let shared = AudioManager()

    private enum SoundProfile: String {
        case bubbleSmall
        case bubbleMedium
        case bubbleLarge
        case bubbleRare
        case emptyTap
        case softTap
        case blockPickup
        case blockRelease
        case blockSettle
        case mysteryShape
        case shelfTransition
        case toyNotice
        case toySettle
        case bubbleNotice
        case bubbleBreath
        case foodPickup
        case foodRelease
        case foodPlop
        case feedReceive
        case feedHappy
        case feedDecline
        case feedChewSoft
        case feedChewCrunch
        case stackLift
        case stackPlace
        case stackSettle
        case stackWake
        case bloomPlant
        case bloomStretch
        case bloomFlourish
        case bloomSettle
        case bloomCritter
        case mixFlip
        case mixCelebrate
        case mixSettle
        case bird
        case boxOpen
        case windowCatHappy
        case windowToyboxOpen
    }

    private enum WindowAmbienceChannel: Hashable {
        case morning
        case night
    }

    private struct SoundTuning {
        let resourceNames: [String]
        let fallbackResourceName: String?
        let volume: Float
        let rate: Float
        let rateJitter: ClosedRange<Float>
        let volumeJitter: ClosedRange<Float>
        let cooldown: TimeInterval

        init(
            resourceNames: [String],
            fallbackResourceName: String?,
            volume: Float,
            rate: Float,
            rateJitter: ClosedRange<Float> = -0.025...0.025,
            volumeJitter: ClosedRange<Float> = 0.92...1.04,
            cooldown: TimeInterval = 0
        ) {
            self.resourceNames = resourceNames
            self.fallbackResourceName = fallbackResourceName
            self.volume = volume
            self.rate = rate
            self.rateJitter = rateJitter
            self.volumeJitter = volumeJitter
            self.cooldown = cooldown
        }
    }

    private var players: [SoundProfile: [AVAudioPlayer]] = [:]
    private var nextPlayerIndex: [SoundProfile: Int] = [:]
    private var lastPlayTime: [SoundProfile: TimeInterval] = [:]
    private var windowAmbiencePlayers: [WindowAmbienceChannel: AVAudioPlayer] = [:]
    private var windowAmbienceTargets: [WindowAmbienceChannel: Float] = [:]
    private var windowAmbienceFadeGen: [WindowAmbienceChannel: Int] = [:]
    private var windowAmbienceActive = false

    var isEnabled: Bool {
        get { LullDemoState.shared.isSoundEnabled }
        set {
            LullDemoState.shared.isSoundEnabled = newValue
            if !newValue {
                stopWindowAmbience(fadeOut: 0.45)
            }
        }
    }

    private init() {
        configureAudioSession()
        loadPlayers()
    }

    func playBubblePop(size: CGFloat, isRare: Bool = false) {
        let profile: SoundProfile
        if isRare {
            profile = .bubbleRare
        } else if size < 50 {
            profile = .bubbleSmall
        } else if size < 82 {
            profile = .bubbleMedium
        } else {
            profile = .bubbleLarge
        }

        play(profile)
    }

    func playSoftTap() {
        play(.softTap)
        HapticsManager.shared.softTap()
    }

    func playEmptyTap() {
        play(.emptyTap)
        HapticsManager.shared.emptyTap()
    }

    func playBlockPickup() {
        play(.blockPickup)
    }

    func playBlockRelease() {
        play(.blockRelease)
    }

    func playBlockSettle() {
        play(.blockSettle)
    }

    func playMysteryShape() {
        play(.mysteryShape)
    }

    func playShelfTransition() {
        play(.shelfTransition)
    }

    func playToyNotice() {
        play(.toyNotice)
    }

    func playToySettle() {
        play(.toySettle)
    }

    func playBubbleNotice() {
        play(.bubbleNotice)
    }

    func playBubbleBreath() {
        play(.bubbleBreath)
    }

    func playFoodPickup() {
        if !play(.foodPickup) {
            play(.softTap)
        }
    }

    func playFoodRelease() {
        if !play(.foodRelease) {
            play(.softTap)
        }
    }

    func playFoodPlop() {
        if !play(.foodPlop) {
            play(.foodRelease)
        }
    }

    func playFeedReceive() {
        if !play(.feedReceive) {
            play(.feedChewSoft)
        }
    }

    func playFeedHappy() {
        play(.feedHappy)
        HapticsManager.shared.softTap()
    }

    func playFeedDecline() {
        if !play(.feedDecline) {
            play(.emptyTap)
        }
    }

    func playFeedChew(isCrunchy: Bool) {
        play(isCrunchy ? .feedChewCrunch : .feedChewSoft)
    }

    func playStackPlace() {
        if !play(.stackPlace) { play(.blockRelease) }
        HapticsManager.shared.blockRelease()
    }

    func playStackLift() {
        if !play(.stackLift) { play(.blockPickup) }
        HapticsManager.shared.blockPickup()
    }

    /// A soft clay settle. `hardness` (0…1) scales how present it is, so gentle micro-landings
    /// stay almost silent and only a firmer landing has real weight — never a constant chime.
    func playStackSettle(hardness: Float = 1.0) {
        let h = hardness.clamped(to: 0...1)
        let volumeScale = 0.5 + 0.5 * h
        let rateOffset = Float.random(in: -0.07...0.05)   // each landing sits a little differently
        if !play(.stackSettle, rateOffset: rateOffset, volumeScale: volumeScale) {
            play(.blockSettle, rateOffset: rateOffset, volumeScale: volumeScale)
        }
        HapticsManager.shared.blockSettle()
    }

    func playStackWake() {
        if !play(.stackWake) { play(.feedHappy) }
        HapticsManager.shared.mysteryShape()
    }

    func playBloomPlant() {
        if !play(.bloomPlant) { play(.softTap) }
        HapticsManager.shared.softTap()
    }

    func playBloomStretch() {
        if !play(.bloomStretch) { play(.bloomPlant) }
    }

    func playBloomFlourish() {
        if !play(.bloomFlourish) { play(.feedHappy) }
        HapticsManager.shared.mysteryShape()
    }

    func playBloomSettle() {
        if !play(.bloomSettle) { play(.toySettle) }
    }

    func playBloomCritter() {
        if !play(.bloomCritter) { play(.toyNotice) }
        HapticsManager.shared.softTap()
    }

    func playMixFlip() {
        if !play(.mixFlip) { play(.stackPlace) }
        HapticsManager.shared.softTap()
    }

    func playMixCelebrate() {
        if !play(.mixCelebrate) { play(.bloomFlourish) }
        HapticsManager.shared.softTap()
    }

    func playMixSettle() {
        if !play(.mixSettle) { play(.toySettle) }
    }

    func playBird() {
        if !play(.bird) {
            play(.bubbleNotice)
        }
    }

    func playBoxOpen() {
        if !play(.boxOpen) {
            play(.blockSettle)
        }
    }

    func playWindowCatHappy() {
        if !play(.windowCatHappy) {
            play(.feedHappy)
        }
    }

    func playWindowToyboxOpen() {
        if !play(.windowToyboxOpen) {
            play(.toyNotice)
        }
    }

    /// Play a synthesized buffer exactly once at the given volume. Used for one-off sounds
    /// like Wren's first breath that are not cached or pooled.
    func playOnceBuffer(_ buffer: AVAudioPCMBuffer, volume: Float) {
        guard isEnabled else { return }
        LullToneEngine.shared.playOnceBuffer(buffer, volume: volume)
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio should never block toy play; haptics remain as fallback.
        }
    }

    private func loadPlayers() {
        soundTunings.forEach { profile, tuning in
            let hasSynthVoice = toneSpecs[profile]?.isEmpty == false
            players[profile] = makePlayers(for: tuning, allowsFallbackResource: !hasSynthVoice)
        }
    }

    private func makePlayers(for tuning: SoundTuning, allowsFallbackResource: Bool) -> [AVAudioPlayer] {
        guard let url = firstAvailableURL(named: tuning.resourceNames)
            ?? (allowsFallbackResource ? tuning.fallbackResourceName.flatMap { firstAvailableURL(named: [$0]) } : nil)
        else {
            return []
        }

        return (0..<3).compactMap { _ in
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.enableRate = true
                player.volume = tuning.volume
                player.rate = tuning.rate
                player.prepareToPlay()
                return player
            } catch {
                return nil
            }
        }
    }

    private func firstAvailableURL(named resourceNames: [String]) -> URL? {
        for name in resourceNames {
            if let mp3 = Bundle.main.url(forResource: name, withExtension: "mp3") {
                return mp3
            }

            if let wav = Bundle.main.url(forResource: name, withExtension: "wav") {
                return wav
            }

            if let m4a = Bundle.main.url(forResource: name, withExtension: "m4a") {
                return m4a
            }
        }

        return nil
    }

    @discardableResult
    private func play(_ profile: SoundProfile, rateOffset: Float = 0, volumeScale: Float = 1) -> Bool {
        guard isEnabled else { return false }
        let tuning = soundTunings[profile]
        let now = CACurrentMediaTime()
        if let tuning, tuning.cooldown > 0 {
            let last = lastPlayTime[profile] ?? -Double.greatestFiniteMagnitude
            if now - last < tuning.cooldown {
                return true
            }
            lastPlayTime[profile] = now
        }

        guard let profilePlayers = players[profile], !profilePlayers.isEmpty else {
            // No recorded foley for this one — sing it with the built-in voice instead.
            return playSynth(profile)
        }

        let index = nextPlayerIndex[profile, default: 0]
        let player = profilePlayers[index]
        nextPlayerIndex[profile] = (index + 1) % profilePlayers.count

        player.stop()
        player.currentTime = 0
        if let tuning {
            let rate = tuning.rate + rateOffset + Float.random(in: tuning.rateJitter)
            player.rate = rate.clamped(to: 0.62...1.42)
            let volume = tuning.volume * volumeScale * Float.random(in: tuning.volumeJitter)
            player.volume = volume.clamped(to: 0...0.55)
        }
        player.play()
        return true
    }

    // MARK: - Synthesized voice (used whenever no recorded file exists)

    private typealias ToneSpec = LullToneEngine.Spec
    private typealias ToneVoice = LullToneEngine.Voice
    private var toneRotation: [SoundProfile: Int] = [:]

    @discardableResult
    private func playSynth(_ profile: SoundProfile) -> Bool {
        guard let variants = toneSpecs[profile], !variants.isEmpty else {
            #if DEBUG
            print("AudioManager: no audio or tone for \(profile.rawValue)")
            #endif
            return false
        }
        let index = toneRotation[profile, default: 0]
        toneRotation[profile] = (index + 1) % variants.count
        LullToneEngine.shared.play(variants[index], cacheKey: "\(profile.rawValue)#\(index)")
        return true
    }

    /// Every interaction's voice, drawn from one warm pentatonic scale (degree 0 = low C,
    /// mid-register ≈ 5–14). Sounds that have recorded foley keep a tone here only as a
    /// safety net for a failed file load. `bloomPlant` rotates a gentle pentatonic noodle.
    private lazy var toneSpecs: [SoundProfile: [ToneSpec]] = [
        // Shared / UI
        .softTap: [.single(8, ToneVoice.felt.with(body: 0.18, amplitude: 0.10))],
        .emptyTap: [.single(6, ToneVoice.breath.with(body: 0.18, amplitude: 0.055, noiseGain: 0.40))],
        .shelfTransition: [ToneSpec.arp([6, 9], step: 0.06, ToneVoice.breath.with(body: 0.5, amplitude: 0.10))],
        .toyNotice: [ToneSpec.arp([8, 10], step: 0.045, ToneVoice.felt.with(body: 0.18, amplitude: 0.09))],
        .toySettle: [ToneSpec.arp([7, 5, 3], step: 0.08, ToneVoice.breath.with(body: 0.54, amplitude: 0.065))],

        // Bubbles (recorded — tones are a safety net)
        .bubbleSmall: [.single(13, ToneVoice.water.with(body: 0.13, amplitude: 0.10))],
        .bubbleMedium: [.single(10, ToneVoice.water.with(body: 0.18, amplitude: 0.12))],
        .bubbleLarge: [.single(5, ToneVoice.water.with(body: 0.24, amplitude: 0.13))],
        .bubbleRare: [ToneSpec.chord([7, 12], ToneVoice.bell.with(amplitude: 0.11))],
        .bubbleNotice: [.single(12, ToneVoice.water.with(body: 0.12, amplitude: 0.075))],
        .bubbleBreath: [ToneSpec.arp([7, 9, 12], step: 0.095, ToneVoice.breath.with(body: 0.46, amplitude: 0.07))],

        // Blocks / Clay
        .blockPickup: [.single(7, ToneVoice.clay.with(body: 0.16, amplitude: 0.12))],
        .blockRelease: [.single(5, ToneVoice.clay.with(body: 0.20))],
        .blockSettle: [.single(3, ToneVoice.clay.with(body: 0.25, amplitude: 0.12))],
        .mysteryShape: [.single(9, ToneVoice.warm.with(body: 0.4))],

        // Feed the People
        .foodPickup: [.single(10, ToneVoice.felt.with(body: 0.13, amplitude: 0.10))],
        .foodRelease: [.single(8, ToneVoice.felt.with(body: 0.15, amplitude: 0.10))],
        .foodPlop: [.single(6, ToneVoice.clay.with(body: 0.17, amplitude: 0.11))],
        .feedReceive: [ToneSpec.arp([7, 10], ToneVoice.voiceLike.with(amplitude: 0.13))],
        .feedHappy: [ToneSpec.arp([5, 7, 9, 10], step: 0.085, ToneVoice.warm.with(amplitude: 0.14))],
        .feedDecline: [ToneSpec.arp([9, 7], step: 0.09, ToneVoice.breath.with(body: 0.32, amplitude: 0.065))],

        // Stack
        .stackLift: [ToneSpec.arp([7, 10], step: 0.045, ToneVoice.clay.with(body: 0.10, amplitude: 0.085))],
        .stackPlace: [.single(8, ToneVoice.clay.with(body: 0.14, amplitude: 0.06))],
        .stackSettle: [.single(5, ToneVoice.clay.with(body: 0.17, amplitude: 0.045))],
        .stackWake: [ToneSpec.arp([8, 10, 13], step: 0.07, ToneVoice.bell.with(amplitude: 0.105))],

        // Bloom (plant rotates a gentle pentatonic noodle while drawing)
        .bloomPlant: [
            .single(7, ToneVoice.felt.with(body: 0.18, amplitude: 0.095)),
            .single(8, ToneVoice.felt.with(body: 0.18, amplitude: 0.095)),
            .single(9, ToneVoice.felt.with(body: 0.18, amplitude: 0.095)),
            .single(10, ToneVoice.felt.with(body: 0.18, amplitude: 0.095)),
            .single(8, ToneVoice.felt.with(body: 0.18, amplitude: 0.095)),
            .single(7, ToneVoice.felt.with(body: 0.18, amplitude: 0.095))
        ],
        .bloomStretch: [
            .single(8, ToneVoice.water.with(body: 0.16, amplitude: 0.080)),
            .single(9, ToneVoice.water.with(body: 0.16, amplitude: 0.080)),
            .single(10, ToneVoice.water.with(body: 0.16, amplitude: 0.080)),
            .single(12, ToneVoice.water.with(body: 0.16, amplitude: 0.080))
        ],
        .bloomFlourish: [ToneSpec.chord([5, 8, 12], ToneVoice.warm.with(amplitude: 0.13))],
        .bloomSettle: [ToneSpec.arp([10, 8, 7], step: 0.08, ToneVoice.breath.with(body: 0.48, amplitude: 0.06))],
        .bloomCritter: [ToneSpec.arp([12, 10, 12], step: 0.07, ToneVoice.voiceLike.with(amplitude: 0.10))],

        // Mix-Up
        .mixFlip: [ToneSpec.arp([7, 10], step: 0.045, ToneVoice.felt.with(body: 0.13, amplitude: 0.08))],
        .mixCelebrate: [ToneSpec.arp([8, 10, 13], step: 0.07, ToneVoice.warm.with(amplitude: 0.12))],
        .mixSettle: [.single(5, ToneVoice.breath.with(body: 0.44, amplitude: 0.055))],

        // Recorded shared/window foley
        .bird: [ToneSpec.arp([14, 17], step: 0.09, ToneVoice.celeste.with(body: 0.24, amplitude: 0.055))],
        .boxOpen: [.single(3, ToneVoice.wood.with(body: 0.42, amplitude: 0.070, noiseGain: 0.28))],
        .windowCatHappy: [ToneSpec.arp([8, 10], step: 0.08, ToneVoice.voiceLike.with(body: 0.38, amplitude: 0.080))],
        .windowToyboxOpen: [ToneSpec.arp([4, 7, 9, 12], step: 0.07, ToneVoice.celeste.with(body: 0.6, amplitude: 0.040))],

        // Feed chews (recorded — tones are a safety net)
        .feedChewSoft: [.single(4, ToneVoice.clay.with(body: 0.10, amplitude: 0.075))],
        .feedChewCrunch: [.single(11, ToneVoice.clay.with(body: 0.09, amplitude: 0.070))]
    ]

    // MARK: - Per-toy voice identity

    /// Each toy has a voice character: a slight pitch shift and amplitude flavour that colours
    /// every synthesised sound it plays. Scenes set `AudioManager.shared.currentToyVoice` in
    /// their `didMove(to:)` so the shift is applied transparently to all toneSpec playback.
    enum LullSoundVoice: Equatable {
        case none
        case bubbles   // wetter, higher
        case bloom     // breathier, slightly up
        case hum       // near-silence, just the clay breathing
        case stack     // lower, resonant
        case mixUp     // warm and round
        case feed      // bright outdoor air
        case glowboard // a hushed, warm bedroom at night
        case rollway   // a warm wooden playroom

        var pitchMultiplier: Double {
            switch self {
            case .none:      return 1.00
            case .bubbles:   return 1.06
            case .bloom:     return 1.02
            case .hum:       return 1.00
            case .stack:     return 0.94
            case .mixUp:     return 1.01
            case .feed:      return 1.03
            case .glowboard: return 0.99
            case .rollway:   return 0.97
            }
        }

        var ambientID: String? {
            switch self {
            case .none:      return nil
            case .bubbles:   return "ambient.bubbles"
            case .bloom:     return "ambient.bloom"
            case .hum:       return "ambient.hum"
            case .stack:     return "ambient.stack"
            case .mixUp:     return "ambient.mixup"
            case .feed:      return "ambient.feed"
            case .glowboard: return "ambient.glowboard"
            case .rollway:   return "ambient.rollway"
            }
        }

        var baseAmbientVolume: Float {
            switch self {
            case .none:      return 0
            case .bubbles:   return 0.030
            case .bloom:     return 0.022
            case .hum:       return 0.005
            case .stack:     return 0.024
            case .mixUp:     return 0.016
            case .feed:      return 0.018
            case .glowboard: return 0.012
            case .rollway:   return 0.016
            }
        }
    }

    var currentToyVoice: LullSoundVoice = .none

    // MARK: - Layered sound architecture

    /// One component of a multi-layer composite sound. Stack 2–3 of these and fire them
    /// simultaneously with `playLayered(_:baseCacheKey:)` for sounds with weight and texture.
    struct LullSoundLayer {
        let spec: LullToneEngine.Spec
        /// Multiplied into the voice's amplitude before rendering.
        let volumeScale: Double
        let cacheKeySuffix: String
    }

    /// Play two or three simultaneous tone layers at once. Each layer is rendered/cached
    /// independently, keeping the pool-based playback responsive.
    func playLayered(_ layers: [LullSoundLayer], baseCacheKey: String) {
        guard isEnabled else { return }
        let pitch = currentToyVoice.pitchMultiplier
        for layer in layers {
            let scaledVoice = layer.spec.voice.with(amplitude: layer.spec.voice.amplitude * layer.volumeScale)
            let scaledSpec = LullToneEngine.Spec(
                notes: layer.spec.notes,
                voice: scaledVoice,
                pitchMultiplier: layer.spec.pitchMultiplier * pitch
            )
            LullToneEngine.shared.play(scaledSpec, cacheKey: "\(baseCacheKey)_\(layer.cacheKeySuffix)")
        }
    }

    // MARK: - Ambient room tone

    /// Begin the ambient room tone for the given toy voice, fading in over 1.8 s.
    func startToyAmbient(_ voice: LullSoundVoice) {
        guard isEnabled, let id = voice.ambientID,
              let spec = AudioManager.ambientSpecs[voice] else { return }
        LullToneEngine.shared.playAmbient(id: id, spec: spec, volume: voice.baseAmbientVolume, fadeIn: 1.8)
    }

    /// Recorded daytime/nighttime Window room beds. Both players are kept prepared and only
    /// their volumes move, so a child scrubbing the day dial never restarts or clicks the bed.
    func setWindowAmbience(dayPhase: CGFloat, animated: Bool) {
        guard isEnabled else {
            stopWindowAmbience(fadeOut: 0.35)
            return
        }
        ensureWindowAmbiencePlayers()
        guard !windowAmbiencePlayers.isEmpty else { return }

        let night = smoothstep(0.58, 0.86, dayPhase)
        let morningTarget = Float((1 - night) * 0.078)
        let nightTarget = Float(night * 0.070)
        let duration: TimeInterval
        if windowAmbienceActive {
            duration = animated ? 0.85 : 0.28
        } else {
            duration = 1.35
        }
        windowAmbienceActive = true

        rampWindowAmbience(.morning, to: morningTarget, duration: duration, stopWhenSilent: morningTarget <= 0.001)
        rampWindowAmbience(.night, to: nightTarget, duration: duration, stopWhenSilent: nightTarget <= 0.001)
    }

    func stopWindowAmbience(fadeOut: TimeInterval = 1.2) {
        windowAmbienceActive = false
        rampWindowAmbience(.morning, to: 0, duration: fadeOut, stopWhenSilent: true)
        rampWindowAmbience(.night, to: 0, duration: fadeOut, stopWhenSilent: true)
    }

    /// Fade out and tear down the ambient for this voice over 1.5 s.
    func stopToyAmbient(_ voice: LullSoundVoice) {
        guard let id = voice.ambientID else { return }
        LullToneEngine.shared.stopAmbient(id: id, fadeOut: 1.5)
        LullToneEngine.shared.stopAmbient(id: AudioManager.sleepBreathID, fadeOut: 1.0)
    }

    /// The child is active again — restore ambient to its awake level over 2 s.
    func wakeAmbient(_ voice: LullSoundVoice) {
        guard let id = voice.ambientID else { return }
        LullToneEngine.shared.setAmbientVolume(voice.baseAmbientVolume, for: id, animated: 2.0)
        LullToneEngine.shared.stopAmbient(id: AudioManager.sleepBreathID, fadeOut: 1.5)
    }

    /// Update the 3D position of a sustained ambient node. No-op if spatial hardware is absent.
    func updateSoundPosition(nodeID: String, screenPoint: CGPoint, sceneSize: CGSize) {
        guard LullToneEngine.shared.isSpatialEnabled else { return }
        LullToneEngine.shared.setSoundPosition(screenPoint, sceneSize: sceneSize, nodeID: nodeID)
    }

    /// Single gentle chime announcing a Bloom season change — the only audible cue.
    func playBloomSeasonChime(for season: LullToneEngine.BloomSeason) {
        guard isEnabled else { return }
        let degree: Int
        let key: String
        switch season {
        case .spring: degree = 7;  key = "bloom.season_chime.spring"
        case .summer: degree = 8;  key = "bloom.season_chime.summer"
        case .autumn: degree = 6;  key = "bloom.season_chime.autumn"
        case .winter: degree = 4;  key = "bloom.season_chime.winter"
        }
        let voice = LullToneEngine.Voice.bell.with(body: 2.8, amplitude: 0.35)
        LullToneEngine.shared.play(.single(degree, voice), cacheKey: key)
    }

    /// Idle for 20 s — dim the ambient to 60 % of its normal level over 3 s.
    func dimAmbient(_ voice: LullSoundVoice) {
        guard let id = voice.ambientID else { return }
        LullToneEngine.shared.setAmbientVolume(voice.baseAmbientVolume * 0.6, for: id, animated: 3.0)
    }

    /// Idle for 60 s — fade toy ambient to silence and bring in the single slow breath tone.
    func sleepAmbient(_ voice: LullSoundVoice) {
        guard let id = voice.ambientID else { return }
        LullToneEngine.shared.setAmbientVolume(0, for: id, animated: 4.0)
        LullToneEngine.shared.playAmbient(
            id: AudioManager.sleepBreathID,
            spec: AudioManager.sleepBreathSpec,
            volume: 0.04,
            fadeIn: 3.0
        )
    }

    private static let sleepBreathID = "ambient.sleep_breath"

    private func ensureWindowAmbiencePlayers() {
        guard windowAmbiencePlayers.isEmpty else { return }
        if let morning = makeLoopingPlayer(named: "window-morning-ambience") {
            windowAmbiencePlayers[.morning] = morning
        }
        if let night = makeLoopingPlayer(named: "window-night-ambience") {
            windowAmbiencePlayers[.night] = night
        }
    }

    private func makeLoopingPlayer(named resourceName: String) -> AVAudioPlayer? {
        guard let url = firstAvailableURL(named: [resourceName]) else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }

    private func rampWindowAmbience(_ channel: WindowAmbienceChannel,
                                    to target: Float,
                                    duration: TimeInterval,
                                    stopWhenSilent: Bool) {
        guard let player = windowAmbiencePlayers[channel] else { return }
        let target = target.clamped(to: 0...0.14)
        let lastTarget = windowAmbienceTargets[channel] ?? player.volume
        if abs(lastTarget - target) < 0.004, (player.isPlaying || target <= 0.001) {
            if target <= 0.001, stopWhenSilent, player.isPlaying {
                player.stop()
            }
            return
        }
        windowAmbienceTargets[channel] = target
        windowAmbienceFadeGen[channel, default: 0] += 1
        let generation = windowAmbienceFadeGen[channel, default: 0]
        let start = player.volume
        let clampedDuration = max(0.05, duration)
        let steps = max(4, min(28, Int(clampedDuration * 24)))

        if target > 0.001, !player.isPlaying {
            player.play()
        }

        for step in 1...steps {
            let delay = clampedDuration * Double(step) / Double(steps)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak player] in
                guard let self, let player, self.windowAmbienceFadeGen[channel] == generation else { return }
                let t = Float(step) / Float(steps)
                let eased = t * t * (3 - 2 * t)
                player.volume = start + (target - start) * eased
                if step == steps, target <= 0.001, stopWhenSilent {
                    player.stop()
                    player.currentTime = 0
                }
            }
        }
    }

    private func smoothstep(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = ((x - a) / max(0.0001, b - a)).clamped(to: 0...1)
        return t * t * (3 - 2 * t)
    }

    // MARK: - Celebration sound sequences

    /// Mix-Up full outfit combo: a 3-note rising clay chime with slightly imperfect intervals
    /// (not a scale — warm, handmade-feeling). Haptic score (.mixUpCombo) is fired by MixUpScene.
    func playMixCelebrationCombo() {
        guard isEnabled else { return }
        LullToneEngine.shared.playSequence([
            (spec: ToneSpec(notes: [(degree: 7, delay: 0)],
                            voice: ToneVoice.clay.with(body: 0.44, amplitude: 0.13),
                            pitchMultiplier: 0.972),
             delay: 0.00, cacheKey: "mix_combo_0"),
            (spec: ToneSpec(notes: [(degree: 10, delay: 0)],
                            voice: ToneVoice.warm.with(body: 0.48, amplitude: 0.115),
                            pitchMultiplier: 1.008),
             delay: 0.11, cacheKey: "mix_combo_1"),
            (spec: ToneSpec(notes: [(degree: 14, delay: 0)],
                            voice: ToneVoice.bell.with(body: 0.64, amplitude: 0.10),
                            pitchMultiplier: 0.988),
             delay: 0.24, cacheKey: "mix_combo_2"),
        ])
    }

    /// Stack knockover: tumble rush → low felt thud → tiny stone-skip tail.
    /// Haptic score (.stackKnockover) is fired by StackScene so the timing is physics-driven.
    func playStackKnockover() {
        guard isEnabled else { return }
        LullToneEngine.shared.playSequence([
            (spec: ToneSpec(notes: [(degree: 8, delay: 0)],
                            voice: ToneVoice.breath.with(body: 0.24, amplitude: 0.11, noiseGain: 0.68)),
             delay: 0.00, cacheKey: "stack_knock_0"),
            (spec: ToneSpec(notes: [(degree: 3, delay: 0)],
                            voice: ToneVoice.clay.with(body: 0.30, amplitude: 0.14)),
             delay: 0.08, cacheKey: "stack_knock_1"),
            (spec: ToneSpec(notes: [(degree: 13, delay: 0)],
                            voice: ToneVoice.water.with(body: 0.16, amplitude: 0.065)),
             delay: 0.21, cacheKey: "stack_knock_2"),
        ])
    }

    /// Feed success: two-tone soft bell → warm breath exhale → character voice echo.
    func playFeedSuccess() {
        guard isEnabled else { return }
        LullToneEngine.shared.playSequence([
            (spec: ToneSpec(notes: [(degree: 8, delay: 0)],
                            voice: ToneVoice.bell.with(body: 0.58, amplitude: 0.115)),
             delay: 0.00, cacheKey: "feed_success_0"),
            (spec: ToneSpec(notes: [(degree: 11, delay: 0)],
                            voice: ToneVoice.bell.with(body: 0.62, amplitude: 0.10)),
             delay: 0.14, cacheKey: "feed_success_1"),
            (spec: ToneSpec(notes: [(degree: 6, delay: 0)],
                            voice: ToneVoice.breath.with(body: 0.56, amplitude: 0.072)),
             delay: 0.32, cacheKey: "feed_success_2"),
            (spec: ToneSpec(notes: [(degree: 4, delay: 0)],
                            voice: ToneVoice.voiceLike.with(body: 0.40, amplitude: 0.055)),
             delay: 0.50, cacheKey: "feed_success_3"),
        ])
        HapticsManager.shared.celebration()
    }

    // MARK: - Ambient specs (static — built once, shared across sessions)

    private static let ambientSpecs: [LullSoundVoice: LullToneEngine.AmbientSpec] = [
        .bubbles: .init(
            frequency: 62,
            partials: [(1, 1.0), (2.01, 0.18), (3.0, 0.06)],
            noiseGain: 0.08,
            lfoHz: 0.18, lfoDepth: 0.22,
            amplitude: 0.022, duration: 8
        ),
        .bloom: .init(
            frequency: 180,
            partials: [(1, 0.3)],
            noiseGain: 0.85,
            lfoHz: 0.12, lfoDepth: 0.35,
            amplitude: 0.016, duration: 8
        ),
        .hum: .init(
            frequency: 60,
            partials: [(1, 0.15)],
            noiseGain: 0.20,
            lfoHz: 0.06, lfoDepth: 0.12,
            amplitude: 0.005, duration: 8
        ),
        .stack: .init(
            frequency: 44,
            partials: [(1, 1.0), (2.0, 0.12), (4.0, 0.04)],
            noiseGain: 0.06,
            lfoHz: 0.10, lfoDepth: 0.18,
            amplitude: 0.018, duration: 8
        ),
        .mixUp: .init(
            frequency: 120,
            partials: [(1, 0.4)],
            noiseGain: 0.72,
            lfoHz: 0.22, lfoDepth: 0.28,
            amplitude: 0.012, duration: 6
        ),
        .feed: .init(
            frequency: 220,
            partials: [(1, 0.25)],
            noiseGain: 0.88,
            lfoHz: 0.14, lfoDepth: 0.20,
            amplitude: 0.014, duration: 8
        ),
        // A hushed bedroom: a low, warm pad that breathes very slowly, like a night light's hum.
        .glowboard: .init(
            frequency: 58,
            partials: [(1, 1.0), (2, 0.10), (3, 0.035)],
            noiseGain: 0.05,
            lfoHz: 0.06, lfoDepth: 0.20,
            amplitude: 0.011, duration: 8
        ),
        // A warm wooden playroom: a soft low room tone with a little woody body.
        .rollway: .init(
            frequency: 49,
            partials: [(1, 1.0), (2, 0.12), (4, 0.04)],
            noiseGain: 0.06,
            lfoHz: 0.09, lfoDepth: 0.16,
            amplitude: 0.014, duration: 8
        ),
    ]

    private static let sleepBreathSpec = LullToneEngine.AmbientSpec(
        frequency: 52,
        partials: [(1, 0.6), (2, 0.08)],
        noiseGain: 0.42,
        lfoHz: 0.08, lfoDepth: 0.45,
        amplitude: 0.04, duration: 8
    )

    private var soundTunings: [SoundProfile: SoundTuning] {
        [
            .bubbleSmall: SoundTuning(
                resourceNames: ["bubble-pop-small-1", "bubble-pop-small", "bubble-pop-medium-1"],
                fallbackResourceName: "bubble-pop",
                volume: 0.18,
                rate: 1.12,
                cooldown: 0.025
            ),
            .bubbleMedium: SoundTuning(
                resourceNames: ["bubble-pop-medium-1", "bubble-pop-medium"],
                fallbackResourceName: "bubble-pop",
                volume: 0.24,
                rate: 1.00,
                cooldown: 0.025
            ),
            .bubbleLarge: SoundTuning(
                resourceNames: ["bubble-pop-large-1", "bubble-pop-large", "bubble-pop-medium-1"],
                fallbackResourceName: "bubble-pop",
                volume: 0.29,
                rate: 0.84,
                cooldown: 0.035
            ),
            .bubbleRare: SoundTuning(
                resourceNames: ["bubble-pop-rare-1", "bubble-pop-rare", "bubble-pop-small-1"],
                fallbackResourceName: "bubble-pop-medium-1",
                volume: 0.20,
                rate: 0.78,
                cooldown: 0.18
            ),
            .emptyTap: SoundTuning(
                resourceNames: ["empty-tap", "soft-ripple"],
                fallbackResourceName: "bubble-pop-small-1",
                volume: 0.10,
                rate: 1.06,
                cooldown: 0.08
            ),
            .softTap: SoundTuning(
                resourceNames: ["soft-tap", "felt-tap"],
                fallbackResourceName: "bubble-pop-small-1",
                volume: 0.12,
                rate: 0.96,
                cooldown: 0.035
            ),
            .toyNotice: SoundTuning(
                resourceNames: ["toy-notice", "soft-perk"],
                fallbackResourceName: nil,
                volume: 0.08,
                rate: 1.0,
                cooldown: 0.16
            ),
            .toySettle: SoundTuning(
                resourceNames: ["toy-settle", "soft-exhale"],
                fallbackResourceName: nil,
                volume: 0.07,
                rate: 0.92,
                cooldown: 0.24
            ),
            .bubbleNotice: SoundTuning(
                resourceNames: ["bubble-notice", "soft-water-perk"],
                fallbackResourceName: nil,
                volume: 0.07,
                rate: 1.08,
                cooldown: 0.14
            ),
            .bubbleBreath: SoundTuning(
                resourceNames: ["bubble-breath", "soft-bubble-swell"],
                fallbackResourceName: nil,
                volume: 0.08,
                rate: 0.96,
                cooldown: 0.30
            ),
            .blockPickup: SoundTuning(
                resourceNames: ["block-pickup", "soft-block-pickup"],
                fallbackResourceName: "block-release-1",
                volume: 0.14,
                rate: 1.02
            ),
            .blockRelease: SoundTuning(
                resourceNames: ["block-release-1", "block-release", "soft-block-release"],
                fallbackResourceName: nil,
                volume: 0.13,
                rate: 0.98
            ),
            .blockSettle: SoundTuning(
                resourceNames: ["block-settle-1", "block-settle", "clay-block-settle"],
                fallbackResourceName: nil,
                volume: 0.11,
                rate: 0.90
            ),
            .mysteryShape: SoundTuning(
                resourceNames: ["mystery-shape", "shape-source"],
                fallbackResourceName: "block-release-1",
                volume: 0.14,
                rate: 1.0
            ),
            .shelfTransition: SoundTuning(
                resourceNames: ["shelf-transition", "soft-whoosh"],
                fallbackResourceName: "bubble-pop-small-1",
                volume: 0.12,
                rate: 0.94
            ),
            .foodPickup: SoundTuning(
                resourceNames: ["food-pickup", "fruit-pickup", "soft-food-pickup"],
                fallbackResourceName: "feed-chew-soft-1",
                volume: 0.12,
                rate: 1.04
            ),
            .foodRelease: SoundTuning(
                resourceNames: ["food-release", "fruit-release", "soft-food-release"],
                fallbackResourceName: "feed-chew-soft-1",
                volume: 0.12,
                rate: 0.98
            ),
            .foodPlop: SoundTuning(
                resourceNames: ["food-plop", "fruit-plop", "soft-food-plop"],
                fallbackResourceName: "feed-chew-soft-1",
                volume: 0.13,
                rate: 0.96
            ),
            .feedReceive: SoundTuning(
                resourceNames: ["feed-receive", "soft-mmm", "food-receive"],
                fallbackResourceName: "feed-chew-soft-1",
                volume: 0.18,
                rate: 1.0,
                cooldown: 0.14
            ),
            .feedHappy: SoundTuning(
                resourceNames: ["feed-happy", "soft-exhale", "happy-hum"],
                fallbackResourceName: "feed-chew-soft-1",
                volume: 0.16,
                rate: 0.96,
                cooldown: 0.30
            ),
            .feedDecline: SoundTuning(
                resourceNames: ["feed-decline", "soft-no-thanks", "decline-soft"],
                fallbackResourceName: "empty-tap",
                volume: 0.10,
                rate: 0.98
            ),
            .feedChewSoft: SoundTuning(
                resourceNames: ["feed-chew-soft-1", "feed-chew-soft"],
                fallbackResourceName: nil,
                volume: 0.11,
                rate: 1.03,
                cooldown: 0.055
            ),
            .feedChewCrunch: SoundTuning(
                resourceNames: ["feed-chew-crunch-1", "feed-chew-crunch"],
                fallbackResourceName: nil,
                volume: 0.09,
                rate: 1.08,
                cooldown: 0.055
            ),
            .stackLift: SoundTuning(
                resourceNames: ["stack-lift", "stack-pickup"],
                fallbackResourceName: "block-pickup-1",
                volume: 0.10,
                rate: 1.08
            ),
            .stackPlace: SoundTuning(
                resourceNames: ["stack-place", "stack-appear"],
                fallbackResourceName: "block-release-1",
                volume: 0.14,
                rate: 1.04
            ),
            .stackSettle: SoundTuning(
                resourceNames: ["stack-settle", "stack-land"],
                fallbackResourceName: "block-settle-1",
                volume: 0.085,
                rate: 0.92,
                rateJitter: -0.05...0.05,
                cooldown: 0.08
            ),
            .stackWake: SoundTuning(
                resourceNames: ["stack-wake", "stack-chime"],
                fallbackResourceName: "bubble-pop-medium-1",
                volume: 0.16,
                rate: 1.12,
                cooldown: 0.80
            ),
            .bloomPlant: SoundTuning(
                resourceNames: ["bloom-plant", "bloom-pop"],
                fallbackResourceName: "bubble-pop-small-1",
                volume: 0.13,
                rate: 1.10,
                cooldown: 0.08
            ),
            .bloomStretch: SoundTuning(
                resourceNames: ["bloom-stretch", "stem-stretch"],
                fallbackResourceName: nil,
                volume: 0.08,
                rate: 1.0,
                cooldown: 0.13
            ),
            .bloomFlourish: SoundTuning(
                resourceNames: ["bloom-flourish", "bloom-chime"],
                fallbackResourceName: "bubble-pop-medium-1",
                volume: 0.16,
                rate: 1.05,
                cooldown: 0.42
            ),
            .bloomSettle: SoundTuning(
                resourceNames: ["bloom-settle", "leaf-settle"],
                fallbackResourceName: nil,
                volume: 0.07,
                rate: 0.94,
                cooldown: 0.22
            ),
            .bloomCritter: SoundTuning(
                resourceNames: ["bloom-critter", "garden-critter"],
                fallbackResourceName: nil,
                volume: 0.08,
                rate: 1.02,
                cooldown: 0.16
            ),
            .mixFlip: SoundTuning(
                resourceNames: ["mix-flip", "soft-page-flip"],
                fallbackResourceName: nil,
                volume: 0.08,
                rate: 1.0,
                cooldown: 0.07
            ),
            .mixCelebrate: SoundTuning(
                resourceNames: ["mix-celebrate", "soft-ta-da"],
                fallbackResourceName: nil,
                volume: 0.12,
                rate: 1.02,
                cooldown: 0.34
            ),
            .mixSettle: SoundTuning(
                resourceNames: ["mix-settle", "soft-page-settle"],
                fallbackResourceName: nil,
                volume: 0.07,
                rate: 0.92,
                cooldown: 0.18
            ),
            .bird: SoundTuning(
                resourceNames: ["bird"],
                fallbackResourceName: nil,
                volume: 0.16,
                rate: 1.0,
                rateJitter: -0.012...0.012,
                volumeJitter: 0.92...1.0,
                cooldown: 0.45
            ),
            .boxOpen: SoundTuning(
                resourceNames: ["box-open"],
                fallbackResourceName: "block-settle-1",
                volume: 0.16,
                rate: 1.0,
                rateJitter: -0.010...0.010,
                volumeJitter: 0.94...1.0,
                cooldown: 0.34
            ),
            .windowCatHappy: SoundTuning(
                resourceNames: ["cat-happy"],
                fallbackResourceName: nil,
                volume: 0.15,
                rate: 1.0,
                rateJitter: -0.008...0.008,
                volumeJitter: 0.94...1.0,
                cooldown: 0.55
            ),
            .windowToyboxOpen: SoundTuning(
                resourceNames: ["window-toybox-open"],
                fallbackResourceName: "block-release-1",
                volume: 0.17,
                rate: 1.0,
                rateJitter: -0.010...0.010,
                volumeJitter: 0.94...1.0,
                cooldown: 0.45
            )
        ]
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
