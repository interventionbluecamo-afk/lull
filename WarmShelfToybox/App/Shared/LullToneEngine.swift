import AVFoundation

/// Lull's built-in *voice*.
///
/// Instead of shipping dozens of foley files, almost every interaction in the app is a
/// soft synthesized tone drawn from a single warm pentatonic scale. Because every sound
/// lives in the same key, the whole toybox rings like one gentle instrument — nothing
/// ever clashes, and nothing has a hard transient that could startle a 2-year-old.
///
/// Real recorded foley (bubble pops, chews, block knocks) still plays from files via
/// `AudioManager`; this engine fills everything that would otherwise be silent.
///
/// Robust by design: if the audio engine can't start (interruptions, odd routes), every
/// call is a graceful no-op — a toy must never crash or hang on sound.
final class LullToneEngine {
    static let shared = LullToneEngine()

    // MARK: - Sound description

    /// One synthesized timbre: a small additive stack of partials under a pluck envelope.
    struct Voice {
        /// Overtones relative to the fundamental: (frequency ratio, gain).
        var partials: [(ratio: Double, gain: Double)] = [(1, 1)]
        /// Fade-in, from silence. Keeps every onset soft — no clicks, no spikes.
        var attack: Double = 0.010
        /// Time from the end of attack until the note has fully decayed to silence.
        var body: Double = 0.42
        /// Decay shape. ~1 = linear, higher = quicker initial fall (more "plucked").
        var curve: Double = 2.2
        /// Peak loudness (kept low and calm).
        var amplitude: Double = 0.16
        var vibratoHz: Double = 0
        var vibratoDepthSemitones: Double = 0
        /// A small shaped-noise layer for felt, breath, clay scrape, and soft air.
        var noiseGain: Double = 0

        static let soft = Voice()                                   // pure, round
        static let warm = Voice(partials: [(1, 1), (2, 0.18), (3, 0.06)])
        static let voiceLike = Voice(partials: [(1, 1), (2, 0.30), (3, 0.12)], body: 0.36,
                                     amplitude: 0.17, vibratoHz: 5, vibratoDepthSemitones: 0.12)
        static let bell = Voice(partials: [(1, 1), (2.01, 0.5), (3.0, 0.22), (4.2, 0.10)],
                                body: 0.85, curve: 1.6, amplitude: 0.13)
        static let wood = Voice(partials: [(1, 1), (2, 0.22), (4, 0.05)], body: 0.40, amplitude: 0.15)
        static let air = Voice(partials: [(1, 1), (3, 0.05)], body: 0.20, amplitude: 0.10)
        static let felt = Voice(partials: [(1, 1), (2, 0.10)], body: 0.26, amplitude: 0.12, noiseGain: 0.09)
        static let clay = Voice(partials: [(1, 1), (2, 0.20), (4, 0.05)], body: 0.34, curve: 2.8,
                                amplitude: 0.13, noiseGain: 0.12)
        static let water = Voice(partials: [(1, 1), (2.01, 0.16), (3.02, 0.08)], body: 0.30,
                                 amplitude: 0.12, vibratoHz: 3.2, vibratoDepthSemitones: 0.06,
                                 noiseGain: 0.05)
        static let breath = Voice(partials: [(1, 0.35), (2, 0.04)], body: 0.58, curve: 1.4,
                                  amplitude: 0.08, vibratoHz: 2.0, vibratoDepthSemitones: 0.05,
                                  noiseGain: 0.55)

        // — Beautiful sustained-friendly voices for the Hum instrument —
        /// Music-box / celeste: bright shimmer over a long, soft bloom.
        static let celeste = Voice(partials: [(1, 1), (2, 0.36), (3, 0.14), (4.01, 0.07), (6.0, 0.03)],
                                   attack: 0.008, body: 1.25, curve: 1.5, amplitude: 0.12)
        /// Warm wordless choir "aah" — rich vowel harmonics with a little breath and lilt.
        static let choir = Voice(partials: [(1, 1), (2, 0.42), (3, 0.20), (4, 0.09), (5, 0.045)],
                                 attack: 0.04, body: 0.80, curve: 1.3, amplitude: 0.14,
                                 vibratoHz: 5.0, vibratoDepthSemitones: 0.10, noiseGain: 0.05)
        /// Glass harmonica: crystalline odd-harmonic shimmer, very long ring.
        static let glass = Voice(partials: [(1, 1), (3, 0.22), (5, 0.09), (7, 0.03)],
                                 attack: 0.02, body: 1.15, curve: 1.4, amplitude: 0.11,
                                 vibratoHz: 3.0, vibratoDepthSemitones: 0.05)
        /// Soft marimba: rounded wooden mallet with its characteristic 4th/10th overtones.
        static let marimba = Voice(partials: [(1, 1), (4, 0.5), (10, 0.08)],
                                   body: 0.58, curve: 2.1, amplitude: 0.14)

        /// A copy with a few fields nudged — keeps the spec table readable.
        func with(
            body: Double? = nil,
            amplitude: Double? = nil,
            curve: Double? = nil,
            noiseGain: Double? = nil
        ) -> Voice {
            var copy = self
            if let body { copy.body = body }
            if let amplitude { copy.amplitude = amplitude }
            if let curve { copy.curve = curve }
            if let noiseGain { copy.noiseGain = noiseGain }
            return copy
        }
    }

    /// A playable sound: one or more scale notes (degrees into the pentatonic scale),
    /// each with a start delay so chords and little arpeggios are possible.
    struct Spec {
        var notes: [(degree: Int, delay: Double)]
        var voice: Voice
        /// Multiplies all rendered frequencies — lets per-toy voice colour shift the whole
        /// pitch slightly without touching the pentatonic degree table.
        var pitchMultiplier: Double = 1.0

        static func single(_ degree: Int, _ voice: Voice, pitch: Double = 1.0) -> Spec {
            Spec(notes: [(degree, 0)], voice: voice, pitchMultiplier: pitch)
        }
        /// Notes struck together — a soft chord.
        static func chord(_ degrees: [Int], _ voice: Voice) -> Spec {
            Spec(notes: degrees.map { ($0, 0) }, voice: voice)
        }
        /// Notes struck in sequence — a gentle rising/falling figure.
        static func arp(_ degrees: [Int], step: Double = 0.075, _ voice: Voice) -> Spec {
            Spec(notes: degrees.enumerated().map { ($0.element, Double($0.offset) * step) }, voice: voice)
        }
    }

    // MARK: - Ambient tone descriptor

    /// Describes a continuous room-tone: a slow drone or shaped-noise texture that plays on
    /// loop at near-silence volume. The rendered buffer cross-fades at its endpoints so the
    /// AVAudioPlayerNode `.loops` option produces a seamless cycle.
    struct AmbientSpec {
        var frequency: Double = 60          // fundamental Hz of any sine partials
        var partials: [(ratio: Double, gain: Double)] = [(1, 1.0)]
        var noiseGain: Double = 0           // 0 = pure tone, 1 = pure shaped noise
        var lfoHz: Double = 0              // amplitude modulation rate (0 = none)
        var lfoDepth: Double = 0            // 0–1 LFO amplitude depth
        var amplitude: Double = 0.022       // peak output level (kept very low)
        var duration: Double = 8            // loop length in seconds
    }

    // MARK: - Engine

    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    private let format: AVAudioFormat
    private let sampleRate: Double = 44_100
    private let poolSize = 8
    private var pool: [AVAudioPlayerNode] = []
    private var nextNode = 0
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var started = false
    private var playbackGeneration = 0
    private var oneShotNodes: [ObjectIdentifier: AVAudioPlayerNode] = [:]

    /// Reserved for a future spatial pass. Disabled for now because shelf taps must be
    /// absolutely crash-proof across Simulator, iPhone, and iPad routes.
    var isSpatialEnabled: Bool = false

    // Ambient tone state — one looping player node per ambient id.
    private var ambientNodes: [String: AVAudioPlayerNode] = [:]
    // Generation counter per id: incrementing cancels any in-flight fade for that id.
    private var ambientFadeGen: [String: Int] = [:]

    /// Warm C-major pentatonic (C D E G A) across four octaves from C3.
    /// Degree 0 is the lowest C; mid-register voices sit around degrees 5–14.
    private let scale: [Double] = {
        let semitones = [0, 2, 4, 7, 9]
        var freqs: [Double] = []
        for octave in 0..<4 {
            for s in semitones {
                let midi = 48 + octave * 12 + s          // 48 = C3
                freqs.append(440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0))
            }
        }
        return freqs
    }()

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
            ?? AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        let mixer = engine.mainMixerNode

        // A gentle large-room reverb so every soft tone blooms with space — the toybox
        // sounds like one warm instrument heard from the next room, never dry or in-your-face.
        // Recorded foley plays through AudioManager (a separate player) and stays crisp.
        reverb.loadFactoryPreset(.largeChamber)
        reverb.wetDryMix = 22
        engine.attach(reverb)
        engine.connect(reverb, to: engine.outputNode, format: format)

        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: mixer, format: format)
            pool.append(node)
        }

        engine.connect(mixer, to: reverb, format: format)
    }

    private func startIfNeeded() {
        guard AudioManager.shared.prepareForPlayback() else {
            started = false
            return
        }
        if engine.isRunning { started = true; return }
        do {
            try engine.start()
            started = true
        } catch {
            started = false
            #if DEBUG
            print("LullToneEngine: audio engine could not be started: \(error)")
            #endif
        }
    }

    /// Sound Off and app interruptions cancel every voice, including delayed notes and
    /// temporary one-shot nodes. Cached buffers and the fixed voice pool stay ready to reuse.
    func stopAllPlayback() {
        playbackGeneration += 1
        for node in pool { node.stop() }
        for id in Array(ambientNodes.keys) { commitStopAmbient(id: id) }
        let transientNodes = Array(oneShotNodes.values)
        oneShotNodes.removeAll()
        for node in transientNodes {
            node.stop()
            engine.detach(node)
        }
        engine.pause()
        started = false
    }

    // MARK: - Playback

    /// Render (once, then cache) the given spec and play it on the next free voice.
    func play(_ spec: Spec, cacheKey: String) {
        startIfNeeded()
        guard started else { return }

        let buffer: AVAudioPCMBuffer
        if let cached = cache[cacheKey] {
            buffer = cached
        } else if let rendered = render(spec) {
            cache[cacheKey] = rendered
            buffer = rendered
        } else {
            return
        }

        let node = pool[nextNode]
        nextNode = (nextNode + 1) % pool.count
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !node.isPlaying { node.play() }
    }

    /// Render and cache a spec WITHOUT playing it — warms the cache so the first real strike
    /// (and fast glissandos) never synthesise on the calling thread.
    func prewarm(_ spec: Spec, cacheKey: String) {
        guard cache[cacheKey] == nil, let rendered = render(spec) else { return }
        cache[cacheKey] = rendered
    }

    /// Render and cache a looping ambient buffer without playing it — so the first held note
    /// never synthesises on the calling thread.
    func prewarmAmbient(id: String, spec: AmbientSpec) {
        let key = "~ambient~\(id)"
        guard cache[key] == nil, let rendered = renderAmbient(spec) else { return }
        cache[key] = rendered
    }

    // MARK: - Timed sequence playback

    /// Fires a list of specs with independent delays — each note is played through the normal
    /// pool so the existing cooldown / cache / voice logic applies.
    func playSequence(_ steps: [(spec: Spec, delay: Double, cacheKey: String)]) {
        startIfNeeded()
        guard started else { return }
        let generation = playbackGeneration
        for step in steps {
            if step.delay <= 0 {
                play(step.spec, cacheKey: step.cacheKey)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) { [weak self] in
                    guard let self, self.playbackGeneration == generation else { return }
                    self.play(step.spec, cacheKey: step.cacheKey)
                }
            }
        }
    }

    // MARK: - Ambient tone system

    /// Start (or restart) a looping ambient tone with a fade-in.
    /// `loopCount: nil` loops forever (true ambients). A finite `loopCount` schedules the buffer
    /// exactly that many times and then self-cleans — so a "held note" sustain can NEVER ring
    /// forever, even if every stop request is lost to a touch bug or a bookkeeping desync.
    func playAmbient(id: String, spec: AmbientSpec, volume: Float, fadeIn: TimeInterval, loopCount: Int? = nil) {
        startIfNeeded()
        guard started else { return }
        stopAmbient(id: id, fadeOut: 0)

        let bufferKey = "~ambient~\(id)"
        let buffer: AVAudioPCMBuffer
        if let cached = cache[bufferKey] {
            buffer = cached
        } else if let rendered = renderAmbient(spec) {
            cache[bufferKey] = rendered
            buffer = rendered
        } else { return }

        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        ambientNodes[id] = node
        node.volume = 0
        if let loops = loopCount {
            let total = max(1, loops)
            for index in 0..<total {
                let isLast = index == total - 1
                node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: !isLast ? nil : { [weak self] in
                    DispatchQueue.main.async {
                        guard let self, self.ambientNodes[id] === node else { return }
                        self.commitStopAmbient(id: id)
                    }
                })
            }
        } else {
            node.scheduleBuffer(buffer, at: nil, options: .loops)
        }
        node.play()
        animateAmbientVolume(id: id, to: volume, over: fadeIn)
    }

    /// Fade out and remove an ambient tone. Pass `fadeOut: 0` for an instant stop.
    func stopAmbient(id: String, fadeOut: TimeInterval) {
        guard ambientNodes[id] != nil else { return }
        if fadeOut <= 0 {
            commitStopAmbient(id: id)
        } else {
            animateAmbientVolume(id: id, to: 0, over: fadeOut) { [weak self] in
                self?.commitStopAmbient(id: id)
            }
        }
    }

    /// Smoothly ramp an ambient channel to a new volume level.
    func setAmbientVolume(_ volume: Float, for id: String, animated duration: TimeInterval) {
        guard ambientNodes[id] != nil else { return }
        animateAmbientVolume(id: id, to: volume, over: duration)
    }

    private func commitStopAmbient(id: String) {
        ambientFadeGen[id] = (ambientFadeGen[id] ?? 0) + 1   // invalidate any fade in flight
        if let node = ambientNodes.removeValue(forKey: id) {
            node.stop()
            engine.detach(node)
        }
    }

    private func animateAmbientVolume(
        id: String,
        to target: Float,
        over duration: TimeInterval,
        completion: (() -> Void)? = nil
    ) {
        let generation = (ambientFadeGen[id] ?? 0) + 1
        ambientFadeGen[id] = generation

        guard let node = ambientNodes[id] else { completion?(); return }
        guard duration > 0 else { node.volume = target; completion?(); return }

        let steps = max(1, Int(duration * 25))
        let interval = duration / Double(steps)
        let start = node.volume

        func scheduleStep(_ n: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(n + 1)) {
                [weak self, weak node] in
                guard let self, let node, self.ambientFadeGen[id] == generation else { return }
                let t = Float(n + 1) / Float(steps)
                let ease = t * t * (3 - 2 * t)   // smoothstep
                node.volume = start + (target - start) * ease
                if n + 1 < steps {
                    scheduleStep(n + 1)
                } else {
                    node.volume = target
                    completion?()
                }
            }
        }
        scheduleStep(0)
    }

    // MARK: - Wren's first breath

    /// Synthesize Wren's unique first-breath sound. The variant (0–11) subtly shifts pitch,
    /// attack, and the felt/breath harmonic blend so each device gets its own quiet moment.
    func synthesizeWrenBreath(variant: Int) -> AVAudioPCMBuffer? {
        let v = max(0, min(11, variant))
        let duration = 2.2
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData else { return nil }
        buffer.frameLength = frameCount

        let channelCount = Int(format.channelCount)
        let totalFrames = Int(frameCount)
        let left = channelData[0]
        for i in 0..<totalFrames { left[i] = 0 }

        let pitchHz = 110.0 + Double(v) * 1.8          // A2 ± variant shift
        let attackDur = 0.18 + Double(v) * 0.012
        let bodyDur = duration - attackDur - 0.05
        let feltRatio = 1.0 - Double(v) / 22.0          // felt voice 1.0→0.5
        let breathRatio = Double(v) / 22.0              // breath voice 0.0→0.5
        let noiseGain = breathRatio * 0.55
        let partials: [(ratio: Double, gain: Double)] = [
            (1.0, feltRatio * 1.0 + breathRatio * 0.35),
            (2.0, feltRatio * 0.10 + breathRatio * 0.04),
        ]
        let gainSum = max(partials.reduce(0) { $0 + $1.gain } + noiseGain, 0.0001)

        var noiseSeed: UInt64 = UInt64(v + 1) &* 0x9E3779B97F4A7C15
        var noiseState = 0.0

        for i in 0..<totalFrames {
            let t = Double(i) / sampleRate
            let env: Double
            if t < attackDur {
                env = t / max(attackDur, 1e-5)
            } else {
                let x = (t - attackDur) / max(bodyDur, 1e-5)
                env = x >= 1 ? 0 : pow(1 - x, 1.6)
            }
            guard env > 0 else { continue }

            var sample = 0.0
            for partial in partials {
                sample += sin(2 * .pi * pitchHz * partial.ratio * t) * partial.gain
            }
            if noiseGain > 0 {
                noiseSeed = noiseSeed &* 6364136223846793005 &+ 1442695040888963407
                let raw = Double((noiseSeed >> 33) & 0x7fffffff) / Double(0x3fffffff) - 1.0
                noiseState = noiseState * 0.93 + raw * 0.07
                sample += noiseState * noiseGain
            }
            left[i] = Float(tanh(sample / gainSum * env * 0.22))
        }

        if channelCount > 1 {
            for c in 1..<channelCount {
                let other = channelData[c]
                for i in 0..<totalFrames { other[i] = left[i] }
            }
        }
        return buffer
    }

    // MARK: - One-shot buffer playback

    /// Play a buffer exactly once at the given volume, then tear down the player node.
    func playOnceBuffer(_ buffer: AVAudioPCMBuffer, volume: Float) {
        startIfNeeded()
        guard started else { return }
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        node.volume = volume
        let identifier = ObjectIdentifier(node)
        oneShotNodes[identifier] = node
        node.scheduleBuffer(buffer, at: nil, options: []) { [weak self, weak node] in
            DispatchQueue.main.async {
                guard let self, let node, self.oneShotNodes.removeValue(forKey: identifier) === node else { return }
                node.stop()
                self.engine.detach(node)
            }
        }
        node.play()
    }

    private func renderAmbient(_ spec: AmbientSpec) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(spec.duration * sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData else { return nil }
        buffer.frameLength = frameCount

        let channelCount = Int(format.channelCount)
        let totalFrames = Int(frameCount)
        let left = channelData[0]
        for i in 0..<totalFrames { left[i] = 0 }

        let gainSum = max(spec.partials.reduce(0) { $0 + $1.gain } + spec.noiseGain, 0.0001)
        var noiseSeed: UInt64 = 0xDEADBEEFCAFEBABE
        var noiseState = 0.0

        // Trapezoidal cross-fade window — first/last 0.3 s taper to zero so the loop point
        // is seamless when AVAudioPlayerNode repeats the buffer.
        let fadeSamples = min(Int(0.3 * sampleRate), totalFrames / 4)

        for i in 0..<totalFrames {
            let t = Double(i) / sampleRate

            // LFO: slow amplitude modulation for breathing texture
            let lfoEnv = spec.lfoHz > 0
                ? 1.0 - spec.lfoDepth * 0.5 * (1 + sin(2 * .pi * spec.lfoHz * t))
                : 1.0

            // Loop cross-fade
            let loopEnv: Double
            if i < fadeSamples {
                loopEnv = Double(i) / Double(fadeSamples)
            } else if i >= totalFrames - fadeSamples {
                loopEnv = Double(totalFrames - i) / Double(fadeSamples)
            } else {
                loopEnv = 1.0
            }

            var sample = 0.0
            for partial in spec.partials {
                sample += sin(2 * .pi * spec.frequency * partial.ratio * t) * partial.gain
            }
            if spec.noiseGain > 0 {
                noiseSeed = noiseSeed &* 6364136223846793005 &+ 1442695040888963407
                let raw = Double((noiseSeed >> 33) & 0x7fffffff) / Double(0x3fffffff) - 1.0
                noiseState = noiseState * 0.93 + raw * 0.07
                sample += noiseState * spec.noiseGain
            }

            left[i] = Float(tanh(sample / gainSum * lfoEnv * loopEnv * spec.amplitude))
        }

        if channelCount > 1 {
            for c in 1..<channelCount {
                let other = channelData[c]
                for i in 0..<totalFrames { other[i] = left[i] }
            }
        }
        return buffer
    }

    // MARK: - Spatial audio

    /// Convert a 2D screen point to a 3D position on the ambient node for that ID.
    /// No-op if spatial hardware is not detected or the nodeID has no active ambient.
    func setSoundPosition(_ point: CGPoint, sceneSize: CGSize, nodeID: String) {
        return
    }

    /// Check current route outputs for spatial-capable headphones and update `isSpatialEnabled`.
    func detectSpatialCapability() {
        isSpatialEnabled = false
    }

    // MARK: - Bloom season ambient

    enum BloomSeason { case spring, summer, autumn, winter }

    /// Crossfade the bloom ambient to a new season character over `duration` seconds.
    /// First half fades current out; second half fades new season in.
    func transitionBloomAmbientToSeason(_ season: BloomSeason, duration: TimeInterval = 12.0) {
        startIfNeeded()
        guard started else { return }
        let id = "ambient.bloom"
        let half = duration / 2
        let targetVolume: Float = 0.022

        if ambientNodes[id] != nil {
            animateAmbientVolume(id: id, to: 0, over: half) { [weak self] in
                guard let self else { return }
                self.commitStopAmbient(id: id)
                self.cache.removeValue(forKey: "~ambient~\(id)")
                self.playAmbient(id: id, spec: self.bloomSeasonSpec(for: season),
                                 volume: targetVolume, fadeIn: half)
            }
        } else {
            cache.removeValue(forKey: "~ambient~\(id)")
            playAmbient(id: id, spec: bloomSeasonSpec(for: season),
                        volume: targetVolume, fadeIn: half)
        }
    }

    private func bloomSeasonSpec(for season: BloomSeason) -> AmbientSpec {
        switch season {
        case .spring:
            // E4 — 329.63 Hz, breath-heavy with lifted harmonics
            return AmbientSpec(frequency: 329.63,
                               partials: [(1, 0.25), (1.25, 0.20), (1.5, 0.18), (2.0, 0.12)],
                               noiseGain: 0.60, lfoHz: 0.18, lfoDepth: 0.28,
                               amplitude: 0.020, duration: 8)
        case .summer:
            // G4 — 392.00 Hz, warm felt with full harmonic stack
            return AmbientSpec(frequency: 392.00,
                               partials: [(1, 0.70), (1.25, 0.25), (1.5, 0.20), (1.75, 0.12), (2.0, 0.10)],
                               noiseGain: 0.08, lfoHz: 0.14, lfoDepth: 0.16,
                               amplitude: 0.024, duration: 8)
        case .autumn:
            // D4 — 293.66 Hz, clay-heavy with minor-flavoured intervals
            return AmbientSpec(frequency: 293.66,
                               partials: [(1, 0.80), (1.2, 0.40), (1.5, 0.22), (1.8, 0.14)],
                               noiseGain: 0.28, lfoHz: 0.09, lfoDepth: 0.20,
                               amplitude: 0.020, duration: 8)
        case .winter:
            // A3 — 220.00 Hz, sparse breath with very slow LFO
            return AmbientSpec(frequency: 220.00,
                               partials: [(1, 0.30), (1.25, 0.12), (1.5, 0.08)],
                               noiseGain: 0.78, lfoHz: 0.05, lfoDepth: 0.45,
                               amplitude: 0.016, duration: 8)
        }
    }

    private func frequency(forDegree degree: Int) -> Double {
        let clamped = max(0, min(scale.count - 1, degree))
        return scale[clamped]
    }

    /// Public pitch lookup so an instrument (Hum) can tune its sustained hold tone to the
    /// exact same pentatonic note its struck onset plays — onset and sustain never disagree.
    func pitchHz(forDegree degree: Int) -> Double {
        frequency(forDegree: degree)
    }

    /// Lowest playable degree's octave size, in scale steps (pentatonic = 5 per octave).
    var degreesPerOctave: Int { 5 }

    private func render(_ spec: Spec) -> AVAudioPCMBuffer? {
        let voice = spec.voice
        let noteLength = voice.attack + voice.body
        let maxDelay = spec.notes.map { $0.delay }.max() ?? 0
        let totalSeconds = maxDelay + noteLength + 0.02
        let frameCount = AVAudioFrameCount(totalSeconds * sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData else { return nil }
        buffer.frameLength = frameCount

        let channelCount = Int(format.channelCount)
        let totalFrames = Int(frameCount)
        let left = channelData[0]
        for i in 0..<totalFrames { left[i] = 0 }

        let gainSum = max(voice.partials.reduce(0) { $0 + $1.gain } + voice.noiseGain, 0.0001)

        for note in spec.notes {
            let f0 = frequency(forDegree: note.degree) * spec.pitchMultiplier
            let startFrame = Int(note.delay * sampleRate)
            let noteFrames = Int(noteLength * sampleRate)
            var noiseSeed = UInt64(note.degree + 97) &* 0x9E3779B97F4A7C15
            var noiseState = 0.0
            for n in 0..<noteFrames {
                let i = startFrame + n
                if i >= totalFrames { break }
                let t = Double(n) / sampleRate

                // Envelope: soft attack from 0, then a natural decay to exactly 0.
                let env: Double
                if t < voice.attack {
                    env = t / max(voice.attack, 1e-5)
                } else {
                    let x = (t - voice.attack) / max(voice.body, 1e-5)
                    env = x >= 1 ? 0 : pow(1 - x, voice.curve)
                }
                if env <= 0 { continue }

                var freq = f0
                if voice.vibratoHz > 0 {
                    let cents = (voice.vibratoDepthSemitones / 12.0) * sin(2 * .pi * voice.vibratoHz * t)
                    freq *= pow(2.0, cents)
                }

                var sample = 0.0
                for partial in voice.partials {
                    sample += sin(2 * .pi * freq * partial.ratio * t) * partial.gain
                }
                if voice.noiseGain > 0 {
                    noiseSeed = noiseSeed &* 6364136223846793005 &+ 1442695040888963407
                    let raw = Double((noiseSeed >> 33) & 0x7fffffff) / Double(0x3fffffff) - 1.0
                    noiseState = noiseState * 0.86 + raw * 0.14
                    sample += noiseState * voice.noiseGain
                }
                sample = sample / gainSum * env * voice.amplitude
                left[i] += Float(sample)
            }
        }

        // Gentle soft-limit, then mirror to any other channels.
        for i in 0..<totalFrames {
            left[i] = Float(tanh(Double(left[i])))
        }
        if channelCount > 1 {
            for c in 1..<channelCount {
                let other = channelData[c]
                for i in 0..<totalFrames { other[i] = left[i] }
            }
        }
        return buffer
    }
}
