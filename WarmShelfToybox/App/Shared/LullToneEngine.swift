import Foundation

// MARK: - Lull's sound palette
//
// Every sound in Lull is synthesized here, from small physical models: struck wooden bars,
// kalimba tines, felt landing on felt, bubbles closing, cloth, breath and soft hummed voices.
// Nothing is a recording, so the whole toybox shares one tuning, one material world and one
// loudness standard, and there is nothing to license.
//
// This file is pure Foundation (no AVFoundation), so every sound can be rendered and measured
// off-device: `Tools/verify_sound_kit.py` compiles it on any Swift toolchain, renders every cue
// and checks loudness, peaks, clicks and pitch. `AudioManager` turns the rendered samples into
// buffers and plays them.
//
// Rules every sound follows:
// - No clicks: raised-cosine attack (>= 1.5 ms) and release on every buffer.
// - No aliasing: tones are sums of sinusoids kept below 0.45 x sample rate.
// - Phone-speaker friendly: nothing important lives below ~200 Hz.
// - One tuning: C major pentatonic, so any two notes sound well together.
// - Loudness by bus (see `LullSoundBus.targetRMS`), peaks under -3 dBFS before the master limiter.
// - Variation: most cues have several variants (pitch, mallet and timing nudged) that rotate.

enum LullSoundBus: Int, CaseIterable {
    case ui, effects, music, voices, ambience

    /// Target RMS (dBFS) over the audible part of each sound. Calm and close together on
    /// purpose: a reward is never much louder than the touch that caused it.
    var targetRMS: Double {
        switch self {
        case .ui: return -31
        case .effects: return -26
        case .music: return -25.5
        case .voices: return -27
        case .ambience: return -47
        }
    }
}

struct LullRenderedSound {
    var samples: [Float]
    var bus: LullSoundBus
}

enum LullSynth {
    static let sampleRate: Double = 48_000
    static let peakCeiling: Float = 0.708   // -3 dBFS

    // MARK: Random (deterministic per cue + variant, so renders are reproducible)

    struct Random {
        private var state: UInt64
        init(seed: UInt64) { state = (seed &* 0x9E37_79B9_7F4A_7C15) | 1 }
        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
        mutating func unit() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
        mutating func signed() -> Double { unit() * 2 - 1 }
        mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * unit() }
        /// Roughly normal noise (sum of four uniforms), cheap and bounded.
        mutating func noise() -> Double { (unit() + unit() + unit() + unit() - 2) * 1.73 }
    }

    /// Stable FNV-1a hash (Swift's `hashValue` changes between launches).
    static func seed(_ text: String, _ variant: Int) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01B3 }
        return hash ^ UInt64(truncatingIfNeeded: variant &* 7919)
    }

    // MARK: Tuning

    static let pentatonic = [0, 2, 4, 7, 9]

    /// Degree 0 = C3. Degrees walk the C major pentatonic upward (5 = C4, 10 = C5, 15 = C6).
    static func hz(degree: Int) -> Double {
        let octave = Int(floor(Double(degree) / 5))
        let step = degree - octave * 5
        let midi = 48 + 12 * octave + pentatonic[step]
        return 440 * pow(2, Double(midi - 69) / 12)
    }

    /// Lifts a pitch by octaves until a phone speaker can carry it.
    static func speakerSafe(_ f: Double, floor minimum: Double = 196) -> Double {
        var f = f
        while f < minimum { f *= 2 }
        return f
    }

    static func frames(_ seconds: Double) -> Int { max(2, Int(seconds * sampleRate)) }

    // MARK: Shaping

    static func fade(_ x: inout [Float], attack: Double = 0.0015, release: Double = 0.012) {
        let n = x.count
        guard n > 4 else { return }
        let a = min(max(1, Int(attack * sampleRate)), n / 2)
        let r = min(max(1, Int(release * sampleRate)), n / 2)
        for i in 0..<a { x[i] *= Float(0.5 - 0.5 * cos(Double.pi * Double(i) / Double(a))) }
        for i in 0..<r { x[n - 1 - i] *= Float(0.5 - 0.5 * cos(Double.pi * Double(i) / Double(r))) }
    }

    /// Mixes `source` into `into` starting `at` seconds, growing `into` as needed.
    static func mix(_ source: [Float], into: inout [Float], at seconds: Double, gain: Float = 1) {
        let start = max(0, Int(seconds * sampleRate))
        if into.count < start + source.count {
            into.append(contentsOf: [Float](repeating: 0, count: start + source.count - into.count))
        }
        for i in 0..<source.count { into[start + i] += source[i] * gain }
    }

    static func peak(_ x: [Float]) -> Float { x.reduce(0) { max($0, abs($1)) } }

    /// RMS over the audible part of a sound (where a 10 ms envelope is within 20 dB of the
    /// peak), so a short pop and a long chord can be matched by ear.
    static func activeRMS(_ x: [Float]) -> Double {
        let p = Double(peak(x))
        guard p > 0 else { return 0 }
        let a = exp(-1 / (0.010 * sampleRate))
        var env = 0.0, sum = 0.0, count = 0
        for s in x {
            let v = Double(abs(s))
            env = max(v, a * env)
            if env > p * 0.1 { sum += Double(s) * Double(s); count += 1 }
        }
        return count > 0 ? sqrt(sum / Double(count)) : 0
    }

    /// Scales to the bus target RMS, then pulls down if the peak would pass the ceiling.
    static func normalize(_ x: inout [Float], rmsDB: Double, gainDB: Double = 0) {
        let rms = activeRMS(x)
        guard rms > 0 else { return }
        var g = Float(pow(10, (rmsDB + gainDB) / 20) / rms)
        let p = peak(x) * g
        if p > peakCeiling { g *= peakCeiling / p }
        for i in 0..<x.count { x[i] *= g }
    }

    /// Drops the silent tail (below -66 dB of the peak), keeping a short fade.
    static func trimTail(_ x: inout [Float]) {
        let threshold = peak(x) * 0.0005
        var last = x.count - 1
        while last > 0 && abs(x[last]) < threshold { last -= 1 }
        let keep = min(x.count, last + frames(0.012))
        if keep < x.count { x.removeLast(x.count - keep) }
        fade(&x, attack: 0.0005, release: 0.010)
    }

    // MARK: Filters

    struct Biquad {
        var b0: Double, b1: Double, b2: Double, a1: Double, a2: Double
        var z1 = 0.0, z2 = 0.0

        mutating func process(_ x: Double) -> Double {
            let y = b0 * x + z1
            z1 = b1 * x - a1 * y + z2
            z2 = b2 * x - a2 * y
            return y
        }

        static func lowpass(_ f: Double, q: Double = 0.707) -> Biquad {
            let w = 2 * Double.pi * min(f, sampleRate * 0.45) / sampleRate
            let alpha = sin(w) / (2 * q), c = cos(w), a0 = 1 + alpha
            return Biquad(b0: (1 - c) / 2 / a0, b1: (1 - c) / a0, b2: (1 - c) / 2 / a0,
                          a1: -2 * c / a0, a2: (1 - alpha) / a0)
        }

        static func highpass(_ f: Double, q: Double = 0.707) -> Biquad {
            let w = 2 * Double.pi * f / sampleRate
            let alpha = sin(w) / (2 * q), c = cos(w), a0 = 1 + alpha
            return Biquad(b0: (1 + c) / 2 / a0, b1: -(1 + c) / a0, b2: (1 + c) / 2 / a0,
                          a1: -2 * c / a0, a2: (1 - alpha) / a0)
        }

        /// Constant 0 dB peak gain band-pass.
        static func bandpass(_ f: Double, q: Double) -> Biquad {
            let w = 2 * Double.pi * min(f, sampleRate * 0.45) / sampleRate
            let alpha = sin(w) / (2 * q), c = cos(w), a0 = 1 + alpha
            return Biquad(b0: alpha / a0, b1: 0, b2: -alpha / a0, a1: -2 * c / a0, a2: (1 - alpha) / a0)
        }
    }

    // MARK: Sources

    /// A struck resonator: damped partials (ratio, decay seconds, gain) plus a mallet tick.
    /// `hardness` 0 = felt mallet (dark, round), 1 = wooden stick (bright, clicky).
    static func modal(_ f0: Double, _ partials: [(Double, Double, Double)], duration: Double,
                      hardness: Double, rng: inout Random) -> [Float] {
        let n = frames(duration)
        var out = [Float](repeating: 0, count: n)
        for (index, p) in partials.enumerated() {
            let f = f0 * p.0 * (1 + rng.signed() * 0.0015)
            guard f < sampleRate * 0.45 else { continue }
            let brightness = index == 0 ? 1.0 : (0.25 + 0.95 * hardness)
            let amp = p.2 * brightness
            let decay = p.1 * (index == 0 ? 1 : (1.15 - 0.3 * hardness))
            let w = 2 * Double.pi * f / sampleRate
            let k = exp(-1 / (decay * sampleRate))
            let phase = rng.range(0, 2 * Double.pi)
            var env = amp
            // Recursive sine and envelope keep this cheap: no sin() per sample.
            var s0 = sin(phase), s1 = sin(phase - w)
            let c2 = 2 * cos(w)
            for i in 0..<n {
                out[i] += Float(s0 * env)
                let s2 = c2 * s0 - s1
                s1 = s0
                s0 = s2
                env *= k
                if env < 1e-6 { break }
            }
        }
        // Mallet: a few milliseconds of filtered noise, brighter for harder mallets.
        let tickN = frames(0.005)
        var lp = Biquad.lowpass(900 + 7000 * hardness)
        for i in 0..<min(tickN, n) {
            let e = exp(-Double(i) / (0.0009 * sampleRate))
            out[i] += Float(lp.process(rng.noise()) * e * 0.10 * (0.3 + hardness))
        }
        fade(&out, attack: 0.0015, release: min(0.06, duration * 0.25))
        return out
    }

    static func marimba(_ f: Double, duration: Double = 1.3, hardness: Double = 0.3, rng: inout Random) -> [Float] {
        modal(f, [(1, 0.62, 1), (3.93, 0.13, 0.20), (9.2, 0.04, 0.05)], duration: duration, hardness: hardness, rng: &rng)
    }

    static func kalimba(_ f: Double, duration: Double = 1.6, hardness: Double = 0.35, rng: inout Random) -> [Float] {
        modal(f, [(1, 0.95, 1), (2.0, 0.22, 0.06), (5.93, 0.07, 0.12), (8.5, 0.03, 0.04)],
              duration: duration, hardness: hardness, rng: &rng)
    }

    static func glock(_ f: Double, duration: Double = 1.7, hardness: Double = 0.25, rng: inout Random) -> [Float] {
        modal(f, [(1, 1.1, 1), (2.76, 0.42, 0.26), (5.40, 0.16, 0.09), (8.93, 0.06, 0.03)],
              duration: duration, hardness: hardness, rng: &rng)
    }

    static func smallBell(_ f: Double, duration: Double = 1.9, rng: inout Random) -> [Float] {
        modal(f, [(1, 1.2, 1), (2.0, 0.7, 0.45), (2.4, 0.6, 0.38), (3.0, 0.35, 0.22), (4.07, 0.2, 0.10), (5.4, 0.12, 0.05)],
              duration: duration, hardness: 0.4, rng: &rng)
    }

    static func woodblock(_ f: Double, duration: Double = 0.24, hardness: Double = 0.5, rng: inout Random) -> [Float] {
        modal(f, [(1, 0.055, 1), (1.58, 0.032, 0.45), (2.43, 0.018, 0.22), (3.6, 0.010, 0.08)],
              duration: duration, hardness: hardness, rng: &rng)
    }

    /// A hollow wooden box answering a drop: low box modes plus a soft knock.
    static func hollowBox(_ f: Double, duration: Double = 0.5, rng: inout Random) -> [Float] {
        modal(f, [(1, 0.11, 1), (1.62, 0.08, 0.55), (2.55, 0.05, 0.32), (4.1, 0.025, 0.14)],
              duration: duration, hardness: 0.3, rng: &rng)
    }

    /// Felt-wrapped stone on felt: a short round tunk.
    static func tunk(_ f: Double, duration: Double = 0.32, hardness: Double = 0.25, rng: inout Random) -> [Float] {
        var x = modal(f, [(1, 0.075, 1), (2.32, 0.04, 0.32), (3.9, 0.02, 0.08)], duration: duration, hardness: hardness, rng: &rng)
        mix(feltPuff(duration: 0.08, bright: 700, rng: &rng), into: &x, at: 0, gain: 0.35)
        return x
    }

    /// Felt landing: a soft low body that sinks a little, plus a muffled puff.
    static func feltThump(_ f: Double = 230, duration: Double = 0.2, rng: inout Random) -> [Float] {
        let n = frames(duration)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let freq = f * (1 - 0.22 * min(1, t / duration))
            phase += 2 * Double.pi * freq / sampleRate
            let env = exp(-t / 0.045)
            out[i] = Float((sin(phase) + 0.28 * sin(2 * phase)) * env)
        }
        mix(feltPuff(duration: 0.07, bright: 900, rng: &rng), into: &out, at: 0, gain: 0.45)
        fade(&out, attack: 0.002, release: 0.03)
        return out
    }

    static func feltPuff(duration: Double, bright: Double, rng: inout Random) -> [Float] {
        let n = frames(duration)
        var out = [Float](repeating: 0, count: n)
        var lp = Biquad.lowpass(bright)
        for i in 0..<n {
            let e = exp(-Double(i) / (0.018 * sampleRate))
            out[i] = Float(lp.process(rng.noise()) * e)
        }
        fade(&out, attack: 0.001, release: 0.01)
        return out
    }

    /// A soft rustle: band-passed noise in a rounded swell with a little flutter.
    static func cloth(duration: Double = 0.35, center: Double = 1800, q: Double = 0.9,
                      flutter: Double = 18, rng: inout Random) -> [Float] {
        let n = frames(duration)
        var out = [Float](repeating: 0, count: n)
        var bp = Biquad.bandpass(center, q: q)
        let ph = rng.range(0, 6)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var env = pow(sin(Double.pi * min(1, t / duration)), 1.5)
            env *= 0.75 + 0.25 * sin(2 * Double.pi * flutter * t + ph)
            out[i] = Float(bp.process(rng.noise()) * env)
        }
        fade(&out, attack: 0.004, release: 0.04)
        return out
    }

    /// Minnaert bubble: a damped sine whose pitch rises as the bubble closes.
    static func bubble(_ f0: Double, duration: Double = 0.12, rise: Double = 1.4, rng: inout Random) -> [Float] {
        let n = frames(duration)
        var out = [Float](repeating: 0, count: n)
        let tau = duration / 4.5
        var phase = rng.range(0, 1)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let f = f0 * (1 + rise * t / duration)
            phase += 2 * Double.pi * f / sampleRate
            out[i] = Float(sin(phase) * exp(-t / tau))
        }
        var hp = Biquad.highpass(2500)
        for i in 0..<min(n, frames(0.0015)) { out[i] += Float(hp.process(rng.noise()) * 0.05) }
        fade(&out, attack: 0.0008, release: 0.012)
        return out
    }

    /// Air moving past: a resonant band sweeping between two frequencies.
    static func whoosh(duration: Double = 0.45, from: Double = 500, to: Double = 2000, q: Double = 1.1,
                       rng: inout Random) -> [Float] {
        let n = frames(duration)
        var out = [Float](repeating: 0, count: n)
        var bp = Biquad.bandpass(from, q: q)
        var lp = Biquad.lowpass(5000)
        for i in 0..<n {
            if i % 32 == 0 {
                let f = from * pow(to / from, Double(i) / Double(n))
                let fresh = Biquad.bandpass(f, q: q)
                bp.b0 = fresh.b0; bp.b1 = fresh.b1; bp.b2 = fresh.b2; bp.a1 = fresh.a1; bp.a2 = fresh.a2
            }
            let t = Double(i) / sampleRate
            let env = pow(sin(Double.pi * t / duration), 2)
            out[i] = Float(lp.process(bp.process(rng.noise())) * env)
        }
        fade(&out, attack: 0.01, release: 0.05)
        return out
    }

    enum Vowel { case oo, oh, ah, mm }

    /// A soft hummed vowel: harmonics shaped by two formants, gentle (correct) vibrato and breath.
    /// `glide` bends pitch from f0 to f0 * glide over the note.
    static func voice(_ f0: Double, duration: Double, vowel: Vowel = .oo, glide: Double = 1,
                      vibrato: Double = 5.0, depth: Double = 0.005, breath: Double = 0.05,
                      attack: Double = 0.05, release: Double = 0.2, rng: inout Random) -> [Float] {
        let formants: [(Double, Double)]
        switch vowel {
        case .oo: formants = [(330, 90), (820, 140)]
        case .oh: formants = [(470, 100), (880, 140)]
        case .ah: formants = [(720, 120), (1180, 160)]
        case .mm: formants = [(260, 70), (1150, 320)]
        }
        let n = frames(duration)
        var out = [Float](repeating: 0, count: n)
        let maxF = min(sampleRate * 0.45, 5200)
        let harmonics = max(1, Int(maxF / (f0 * max(1, glide))))
        var gains = [Double](repeating: 0, count: harmonics + 1)
        for k in 1...harmonics {
            let h = f0 * Double(k)
            var g = 0.04 / Double(k)
            for (fc, bw) in formants { g += exp(-pow((h - fc) / bw, 2) / 2) }
            gains[k] = g / pow(Double(k), 0.55)
        }
        let vibPhase = rng.range(0, 6)
        var phase = 0.0
        var lp = Biquad.lowpass(2400)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let bend = pow(glide, t / duration)
            let vib = 1 + depth * sin(2 * Double.pi * vibrato * t + vibPhase) * min(1, t / 0.25)
            phase += 2 * Double.pi * f0 * bend * vib / sampleRate
            var s = 0.0
            for k in 1...harmonics where f0 * bend * Double(k) < maxF { s += gains[k] * sin(Double(k) * phase) }
            let env = min(1, t / attack) * min(1, max(0, (duration - t) / release))
            out[i] = Float((s * 0.35 + breath * lp.process(rng.noise())) * env)
        }
        fade(&out, attack: 0.003, release: 0.02)
        return out
    }

    /// A soft additive tone following a pitch curve (Hz as a function of 0...1 progress).
    static func tone(duration: Double, harmonics: [Double] = [1, 0.18, 0.05], attack: Double = 0.01,
                     release: Double = 0.06, pitch: (Double) -> Double) -> [Float] {
        let n = frames(duration)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let f = pitch(t / duration)
            phase += 2 * Double.pi * f / sampleRate
            var s = 0.0
            for (k, a) in harmonics.enumerated() where f * Double(k + 1) < sampleRate * 0.45 {
                s += a * sin(Double(k + 1) * phase)
            }
            let env = min(1, t / attack) * min(1, max(0, (duration - t) / release))
            out[i] = Float(s * env)
        }
        fade(&out)
        return out
    }

    /// One crunchy bite: a cluster of tiny band-passed noise grains.
    static func crunch(rng: inout Random) -> [Float] {
        var out = [Float](repeating: 0, count: frames(0.11))
        for _ in 0..<Int(rng.range(4, 7)) {
            let len = frames(rng.range(0.006, 0.016))
            var bp = Biquad.bandpass(rng.range(1400, 3200), q: 1.2)
            var grain = [Float](repeating: 0, count: len)
            for i in 0..<len {
                let e = exp(-Double(i) / (Double(len) * 0.35))
                grain[i] = Float(bp.process(rng.noise()) * e)
            }
            mix(grain, into: &out, at: rng.range(0, 0.08))
        }
        var soften = Biquad.lowpass(4200)
        for i in 0..<out.count { out[i] = Float(soften.process(Double(out[i]))) }
        fade(&out)
        return out
    }

    /// One soft munch: a small closed-mouth "mnf".
    static func munch(rng: inout Random) -> [Float] {
        var out = voice(rng.range(190, 230), duration: 0.09, vowel: .mm, breath: 0.2, attack: 0.01, release: 0.05, rng: &rng)
        mix(feltPuff(duration: 0.06, bright: 1400, rng: &rng), into: &out, at: 0.005, gain: 0.5)
        return out
    }

    /// A small bird: two quick rising-and-falling chirps.
    static func chirp(rng: inout Random, count: Int = 2, base: Double = 2600) -> [Float] {
        var out = [Float]()
        for c in 0..<count {
            let f0 = base * rng.range(0.94, 1.08)
            let up = rng.range(1.25, 1.45)
            let note = tone(duration: rng.range(0.055, 0.08), harmonics: [1, 0.08], attack: 0.004, release: 0.02) { p in
                f0 * (1 + (up - 1) * sin(Double.pi * p))
            }
            mix(note, into: &out, at: Double(c) * rng.range(0.10, 0.13))
        }
        return out
    }

    /// A content cat: a low pulsing purr with a small "mrrp" at the start.
    static func purr(duration: Double = 1.1, rng: inout Random) -> [Float] {
        let n = frames(duration)
        var out = [Float](repeating: 0, count: n)
        var lp = Biquad.lowpass(900)
        var hp = Biquad.highpass(200)
        let rate = rng.range(24, 28)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let pulse = pow(max(0, sin(2 * Double.pi * rate * t)), 3)
            let body = sin(2 * Double.pi * 250 * t) * 0.5 + sin(2 * Double.pi * 500 * t) * 0.22
            let env = min(1, t / 0.12) * min(1, (duration - t) / 0.3)
            out[i] = Float(hp.process((lp.process(rng.noise()) * 0.9 + body) * pulse * env))
        }
        let mrrp = voice(420, duration: 0.16, vowel: .oo, glide: 1.25, breath: 0.03, attack: 0.02, release: 0.06, rng: &rng)
        mix(mrrp, into: &out, at: 0, gain: 0.8)
        fade(&out)
        return out
    }

    /// A tiny frog: two "rib-bit" syllables, a voice gated at ~30 Hz.
    static func ribbit(rng: inout Random) -> [Float] {
        var out = [Float]()
        for s in 0..<2 {
            var syllable = voice(rng.range(270, 300) * (s == 0 ? 1 : 0.92), duration: 0.12, vowel: .oh, breath: 0.08,
                                 attack: 0.01, release: 0.03, rng: &rng)
            for i in 0..<syllable.count {
                let t = Double(i) / sampleRate
                syllable[i] *= Float(0.35 + 0.65 * pow(max(0, sin(2 * Double.pi * 30 * t)), 2))
            }
            mix(syllable, into: &out, at: Double(s) * 0.15)
        }
        return out
    }

    /// A soft electronic "beep": odd harmonics only, gently rounded, never shrill.
    static func beep(_ f: Double, duration: Double = 0.12) -> [Float] {
        tone(duration: duration, harmonics: [1, 0, 0.18, 0, 0.06], attack: 0.008, release: 0.04) { _ in f }
    }
}

// MARK: - The sound book: every cue Lull plays

enum LullSoundBook {
    /// Every named cue (musical notes are parametric:
    /// "note.<kalimba|marimba|glock|glass|bell|wood|choir>.<degree>").
    static let cueIDs: [String] = [
        "ui.tap", "ui.empty",
        "ui.transition", "ui.settle", "ui.notice", "host.giggle", "bubble.small", "bubble.medium",
        "bubble.large", "bubble.rare", "bubble.notice", "bubble.breath", "bird", "feed.pickup",
        "feed.release", "feed.plop", "feed.receive", "feed.chew.soft", "feed.chew.crunchy", "feed.happy",
        "feed.success", "feed.decline", "stack.place", "stack.lift", "stack.settle.soft", "stack.settle.medium",
        "stack.settle.hard", "stack.knockover", "stack.wake", "sleepy.lift", "sleepy.bump", "sleepy.hover",
        "sleepy.drop.0", "sleepy.drop.1", "sleepy.drop.2", "sleepy.drop.3", "sleepy.hum.0", "sleepy.hum.1", "sleepy.hum.2", "sleepy.hum.3", "sleepy.lullaby", "sleepy.drawer",
        "sleepy.tumble", "box.open", "window.dial", "window.toybox.open", "window.toybox.close", "window.nudge",
        "window.squish", "window.drop", "window.curtain", "window.cat", "window.cat.gift", "window.water",
        "window.grow", "window.guest", "window.lamp.on", "window.lamp.off", "window.sky.day", "window.sky.night",
        "window.star", "window.comet", "window.plant", "window.morning", "window.night", "dots.tab",
        "dots.pickup", "dots.full", "dots.fall", "dots.land.0", "dots.land.1", "dots.land.2",
        "dots.land.3", "dots.golden", "dots.wave", "dots.pattern", "dots.full.board", "dots.pour",
        "dots.hover", "dots.home", "mix.flip", "mix.settle", "mix.celebrate", "mix.save",
        "friend.bunny", "friend.bear", "friend.songbird", "friend.fox", "friend.mouse", "friend.frog",
        "friend.robot", "friend.officer", "friend.firefighter", "friend.bunny.whole", "friend.bear.whole", "friend.songbird.whole",
        "friend.fox.whole", "friend.mouse.whole", "friend.frog.whole", "friend.robot.whole", "friend.officer.whole", "friend.firefighter.whole",
        "hum.knob", "hum.invite", "meadow.wake", "meadow.breeze", "meadow.invite", "meadow.paint",
        "meadow.bloom", "meadow.spring", "meadow.fullspring", "meadow.frost", "meadow.landmark.wake"
    ]

    /// How many variants each cue renders; plays rotate through them without repeating.
    static func variants(for id: String) -> Int {
        if id.hasPrefix("note.") || id.hasPrefix("bed.") { return 1 }
        switch id {
        case "bubble.small", "bubble.medium", "bubble.large", "stack.settle.soft", "stack.settle.medium",
             "stack.settle.hard", "ui.tap", "dots.land.0", "dots.land.1", "dots.land.2", "dots.land.3",
             "feed.chew.soft", "feed.chew.crunchy", "meadow.paint", "sleepy.tumble", "window.dial":
            return 5
        case "mix.flip", "ui.empty", "stack.lift", "feed.pickup", "sleepy.lift", "dots.pickup", "bubble.breath":
            return 4
        default:
            return 3
        }
    }

    static func render(_ id: String, variant: Int) -> LullRenderedSound? {
        var rng = LullSynth.Random(seed: LullSynth.seed(id, variant))
        guard let (raw, bus, gainDB) = recipe(id, variant: variant, rng: &rng) else { return nil }
        var x = raw
        LullSynth.trimTail(&x)
        LullSynth.normalize(&x, rmsDB: bus.targetRMS, gainDB: gainDB + rng.range(-0.6, 0.6))
        return LullRenderedSound(samples: x, bus: bus)
    }

    typealias S = LullSynth

    private static func note(_ degree: Int) -> Double { S.hz(degree: degree) }

    /// Renders one arpeggio of `instrument` notes `step` seconds apart.
    private static func arp(_ degrees: [Int], step: Double, rng: inout LullSynth.Random,
                            instrument: (Double, inout LullSynth.Random) -> [Float]) -> [Float] {
        var out = [Float]()
        for (i, d) in degrees.enumerated() {
            let gain = Float(1 - 0.06 * Double(i))
            S.mix(instrument(note(d), &rng), into: &out, at: Double(i) * step * rng.range(0.96, 1.04), gain: gain)
        }
        return out
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func recipe(_ id: String, variant: Int, rng: inout LullSynth.Random)
        -> ([Float], LullSoundBus, Double)? {
        let jitter = rng.range(0.97, 1.03)

        // Parametric musical notes: "note.<instrument>.<degree>" (Hum and the compatibility path).
        if id.hasPrefix("note.") {
            let parts = id.split(separator: ".")
            guard parts.count == 3, let degree = Int(parts[2]) else { return nil }
            let f = S.speakerSafe(note(degree))
            switch parts[1] {
            case "kalimba": return (S.kalimba(f, duration: 2.2, hardness: 0.32, rng: &rng), .music, 0)
            case "marimba": return (S.marimba(f, duration: 1.8, hardness: 0.22, rng: &rng), .music, 0)
            case "glock": return (S.glock(f, duration: 2.4, hardness: 0.2, rng: &rng), .music, -1)
            case "glass": return (S.glock(f, duration: 2.6, hardness: 0.5, rng: &rng), .music, -2)
            case "bell": return (S.smallBell(f, duration: 2.4, rng: &rng), .music, -2)
            case "wood": return (S.woodblock(f, duration: 0.5, hardness: 0.35, rng: &rng), .music, 0)
            case "choir":
                var v = S.voice(f, duration: 9.0, vowel: .oo, depth: 0.004, breath: 0.035, attack: 0.09, release: 1.4, rng: &rng)
                S.mix(S.voice(f * 2, duration: 9.0, vowel: .ah, depth: 0.003, breath: 0, attack: 0.2, release: 1.6, rng: &rng),
                      into: &v, at: 0, gain: 0.18)
                return (v, .music, -2)
            default: return nil
            }
        }

        switch id {
        // — Shared / UI ———————————————————————————————————————————————
        case "ui.tap":
            var x = S.woodblock(880 * jitter, duration: 0.16, hardness: 0.18, rng: &rng)
            S.mix(S.feltPuff(duration: 0.05, bright: 1100, rng: &rng), into: &x, at: 0, gain: 0.4)
            return (x, .ui, 0)
        case "ui.empty":
            return (S.cloth(duration: 0.13, center: 1300 * jitter, q: 1.1, flutter: 0, rng: &rng), .ui, -5)
        case "ui.transition":
            var x = S.whoosh(duration: 0.42, from: 420, to: 1300, q: 1.0, rng: &rng)
            S.mix(S.kalimba(note(8), duration: 1.0, hardness: 0.25, rng: &rng), into: &x, at: 0.16, gain: 0.5)
            return (x, .ui, 0)
        case "ui.settle":
            return (S.feltThump(240 * jitter, rng: &rng), .ui, 0)
        case "ui.notice":
            return (S.kalimba(note(12), duration: 1.0, hardness: 0.2, rng: &rng), .ui, -1)
        case "host.giggle":
            return (arp([12, 13, 15], step: 0.07, rng: &rng) { f, r in S.kalimba(f, duration: 0.9, hardness: 0.3, rng: &r) }, .voices, 0)

        // — Bubbles —————————————————————————————————————————————————
        case "bubble.small":
            return (S.bubble(rng.range(1500, 1900), duration: 0.09, rise: 1.2, rng: &rng), .effects, -2)
        case "bubble.medium":
            return (S.bubble(rng.range(950, 1250), duration: 0.12, rise: 1.3, rng: &rng), .effects, 0)
        case "bubble.large":
            var x = S.bubble(rng.range(560, 740), duration: 0.17, rise: 1.4, rng: &rng)
            S.mix(S.feltPuff(duration: 0.06, bright: 1600, rng: &rng), into: &x, at: 0, gain: 0.25)
            return (x, .effects, 1)
        case "bubble.rare":
            var x = S.bubble(rng.range(950, 1150), duration: 0.12, rise: 1.3, rng: &rng)
            S.mix(arp([15, 17], step: 0.08, rng: &rng) { f, r in S.glock(f, duration: 1.2, hardness: 0.18, rng: &r) },
                  into: &x, at: 0.05, gain: 0.55)
            return (x, .effects, 1)
        case "bubble.notice":
            return (S.glock(note(17) * jitter, duration: 0.5, hardness: 0.08, rng: &rng), .effects, -9)
        case "bubble.breath":
            return (S.whoosh(duration: 0.65, from: 700, to: 1700, q: 0.8, rng: &rng), .effects, -5)
        case "bird":
            return (S.chirp(rng: &rng, count: 2), .voices, -2)

        // — Feed ——————————————————————————————————————————————————
        case "feed.pickup":
            var x = S.cloth(duration: 0.16, center: 1900 * jitter, q: 1.0, flutter: 0, rng: &rng)
            S.mix(S.woodblock(1250, duration: 0.08, hardness: 0.1, rng: &rng), into: &x, at: 0, gain: 0.3)
            return (x, .effects, -4)
        case "feed.release":
            return (S.feltThump(260 * jitter, duration: 0.18, rng: &rng), .effects, -3)
        case "feed.plop":
            var x = S.woodblock(520 * jitter, duration: 0.2, hardness: 0.25, rng: &rng)
            S.mix(S.feltThump(250, duration: 0.15, rng: &rng), into: &x, at: 0.02, gain: 0.7)
            return (x, .effects, -2)
        case "feed.receive":
            return (S.voice(note(9) * jitter, duration: 0.24, vowel: .mm, glide: 1.12, breath: 0.06, attack: 0.03, release: 0.1, rng: &rng), .voices, -2)
        case "feed.chew.soft", "feed.chew.crunchy":
            // Three bites timed to the friend's chewing frames (0.18, 0.43, 0.68 s after the food lands;
            // this cue is started 0.10 s after landing).
            var x = [Float]()
            for (i, t) in [0.08, 0.33, 0.58].enumerated() {
                let bite = id.hasSuffix("crunchy") ? S.crunch(rng: &rng) : S.munch(rng: &rng)
                S.mix(bite, into: &x, at: t + rng.range(-0.01, 0.01), gain: Float(1 - 0.12 * Double(i)))
            }
            return (x, .effects, id.hasSuffix("crunchy") ? -2 : 0)
        case "feed.happy":
            var x = S.voice(note(7), duration: 0.22, vowel: .mm, breath: 0.04, attack: 0.02, release: 0.08, rng: &rng)
            S.mix(S.voice(note(9), duration: 0.32, vowel: .mm, glide: 1.03, breath: 0.04, attack: 0.02, release: 0.14, rng: &rng),
                  into: &x, at: 0.17)
            return (x, .voices, 0)
        case "feed.success":
            var x = arp([10, 12, 14], step: 0.11, rng: &rng) { f, r in S.kalimba(f, duration: 1.2, hardness: 0.3, rng: &r) }
            S.mix(S.glock(note(17), duration: 1.4, hardness: 0.15, rng: &rng), into: &x, at: 0.24, gain: 0.35)
            return (x, .music, 0)
        case "feed.decline":
            var x = S.voice(note(8), duration: 0.16, vowel: .mm, breath: 0.05, attack: 0.02, release: 0.06, rng: &rng)
            S.mix(S.voice(note(7), duration: 0.22, vowel: .mm, glide: 0.97, breath: 0.05, attack: 0.02, release: 0.1, rng: &rng),
                  into: &x, at: 0.2)
            return (x, .voices, -3)

        // — Stack ——————————————————————————————————————————————————
        case "stack.place":
            var x = S.woodblock(430 * jitter, duration: 0.2, hardness: 0.15, rng: &rng)
            S.mix(S.feltThump(240, duration: 0.14, rng: &rng), into: &x, at: 0, gain: 0.8)
            return (x, .effects, -3)
        case "stack.lift":
            return (S.cloth(duration: 0.14, center: 1500 * jitter, q: 1.0, flutter: 0, rng: &rng), .effects, -6)
        case "stack.settle.soft":
            return (S.tunk(rng.range(250, 330), hardness: 0.12, rng: &rng), .effects, -6)
        case "stack.settle.medium":
            return (S.tunk(rng.range(250, 330), hardness: 0.25, rng: &rng), .effects, -2)
        case "stack.settle.hard":
            return (S.tunk(rng.range(250, 330), hardness: 0.4, rng: &rng), .effects, 0)
        case "stack.knockover":
            var x = S.cloth(duration: 0.5, center: 1100, q: 0.8, flutter: 12, rng: &rng)
            var t = 0.05
            for i in 0..<5 {
                S.mix(S.tunk(rng.range(240, 340) * (1 - 0.04 * Double(i)), hardness: 0.3, rng: &rng), into: &x, at: t,
                      gain: Float(1 - 0.12 * Double(i)))
                t += rng.range(0.09, 0.16) * (1 - 0.1 * Double(i))
            }
            return (x, .effects, 1)
        case "stack.wake":
            var x = arp([9, 12], step: 0.13, rng: &rng) { f, r in S.kalimba(f, duration: 1.1, hardness: 0.25, rng: &r) }
            S.mix(S.voice(note(12), duration: 0.35, vowel: .oo, glide: 1.06, breath: 0.03, attack: 0.04, release: 0.15, rng: &rng),
                  into: &x, at: 0.12, gain: 0.4)
            return (x, .music, -1)

        // — Sleepy Box —————————————————————————————————————————————
        case "sleepy.lift":
            return (S.cloth(duration: 0.15, center: 1600 * jitter, q: 1.0, flutter: 0, rng: &rng), .effects, -6)
        case "sleepy.bump":
            return (S.woodblock(300 * jitter, duration: 0.18, hardness: 0.22, rng: &rng), .effects, -4)
        case "sleepy.hover":
            return (S.cloth(duration: 0.22, center: 900, q: 0.9, flutter: 8, rng: &rng), .effects, -12)
        case "sleepy.drop.0", "sleepy.drop.1", "sleepy.drop.2", "sleepy.drop.3":
            let shape = Int(id.split(separator: ".").last ?? "0") ?? 0
            var x = S.hollowBox(rng.range(225, 260), rng: &rng)
            S.mix(S.kalimba(note(10 + shape), duration: 1.3, hardness: 0.25, rng: &rng), into: &x, at: 0.06, gain: 0.55)
            return (x, .effects, 1)
        case "sleepy.hum.0", "sleepy.hum.1", "sleepy.hum.2", "sleepy.hum.3":
            let shape = Int(id.split(separator: ".").last ?? "0") ?? 0
            var x = S.voice(note(10 + shape), duration: 0.75, vowel: .oo, breath: 0.03, attack: 0.07, release: 0.4, rng: &rng)
            S.mix(S.kalimba(note(10 + shape), duration: 1.0, hardness: 0.15, rng: &rng), into: &x, at: 0, gain: 0.4)
            return (x, .music, -2)
        case "sleepy.lullaby":
            var x = [Float]()
            for (i, d) in [10, 12, 11, 13, 12, 10].enumerated() {
                let len = i == 5 ? 1.4 : 0.42
                S.mix(S.voice(note(d), duration: len, vowel: .oo, breath: 0.03, attack: 0.06, release: len * 0.5, rng: &rng),
                      into: &x, at: Double(i) * 0.36, gain: 0.8)
                S.mix(S.kalimba(note(d), duration: 0.9, hardness: 0.18, rng: &rng), into: &x, at: Double(i) * 0.36, gain: 0.35)
            }
            return (x, .music, -1)
        case "sleepy.drawer":
            var x = S.whoosh(duration: 0.32, from: 520, to: 820, q: 1.6, rng: &rng)
            S.mix(S.woodblock(380, duration: 0.18, hardness: 0.3, rng: &rng), into: &x, at: 0.28, gain: 0.9)
            return (x, .effects, -3)
        case "sleepy.tumble":
            return (S.woodblock(rng.range(500, 760), duration: 0.12, hardness: 0.3, rng: &rng), .effects, -8)
        case "box.open":
            var x = S.woodblock(330, duration: 0.2, hardness: 0.25, rng: &rng)
            for _ in 0..<5 {
                S.mix(S.woodblock(rng.range(520, 900), duration: 0.1, hardness: 0.3, rng: &rng), into: &x,
                      at: rng.range(0.08, 0.5), gain: Float(rng.range(0.3, 0.6)))
            }
            S.mix(S.cloth(duration: 0.4, center: 1200, q: 0.8, flutter: 10, rng: &rng), into: &x, at: 0.05, gain: 0.5)
            return (x, .effects, -1)

        // — Window ————————————————————————————————————————————————
        case "window.dial":
            return (S.woodblock(1500 * jitter, duration: 0.06, hardness: 0.3, rng: &rng), .ui, -9)
        case "window.toybox.open":
            var x = S.woodblock(300, duration: 0.25, hardness: 0.2, rng: &rng)
            S.mix(arp([14, 17], step: 0.1, rng: &rng) { f, r in S.glock(f, duration: 1.2, hardness: 0.15, rng: &r) }, into: &x, at: 0.12, gain: 0.5)
            return (x, .effects, 0)
        case "window.toybox.close":
            var x = S.feltThump(230, duration: 0.2, rng: &rng)
            S.mix(S.woodblock(280, duration: 0.15, hardness: 0.2, rng: &rng), into: &x, at: 0.01, gain: 0.6)
            return (x, .effects, -2)
        case "window.nudge":
            var x = S.tone(duration: 0.2, harmonics: [1, 0.25, 0.06], attack: 0.006, release: 0.08) { p in 560 - 140 * p }
            S.mix(S.feltPuff(duration: 0.05, bright: 1000, rng: &rng), into: &x, at: 0, gain: 0.4)
            return (x, .effects, -4)
        case "window.squish":
            var x = S.voice(330, duration: 0.2, vowel: .oo, glide: 0.75, breath: 0.15, attack: 0.02, release: 0.1, rng: &rng)
            S.mix(S.feltPuff(duration: 0.08, bright: 800, rng: &rng), into: &x, at: 0, gain: 0.5)
            return (x, .effects, -4)
        case "window.drop":
            return (S.feltThump(235 * jitter, duration: 0.18, rng: &rng), .effects, -3)
        case "window.curtain":
            return (S.cloth(duration: 0.5, center: 1500 * jitter, q: 0.8, flutter: 14, rng: &rng), .effects, -7)
        case "window.cat":
            return (S.purr(rng: &rng), .voices, -2)
        case "window.cat.gift":
            return (arp([12, 14, 17], step: 0.1, rng: &rng) { f, r in S.kalimba(f, duration: 1.1, hardness: 0.28, rng: &r) }, .music, -1)
        case "window.water":
            var x = [Float]()
            for (i, t) in [0.0, 0.17, 0.36].enumerated() {
                S.mix(S.bubble(rng.range(1300, 1700) * (1 - 0.06 * Double(i)), duration: 0.08, rise: 1.0, rng: &rng), into: &x, at: t)
            }
            return (x, .effects, -3)
        case "window.grow":
            return (arp([9, 12, 14], step: 0.13, rng: &rng) { f, r in S.glock(f, duration: 1.3, hardness: 0.15, rng: &r) }, .music, -1)
        case "window.guest":
            return (S.kalimba(note(13), duration: 1.2, hardness: 0.25, rng: &rng), .music, -2)
        case "window.lamp.on":
            var x = S.woodblock(1700, duration: 0.05, hardness: 0.35, rng: &rng)
            S.mix(S.voice(note(7), duration: 0.6, vowel: .mm, glide: 1.06, breath: 0.02, attack: 0.15, release: 0.3, rng: &rng),
                  into: &x, at: 0.03, gain: 0.7)
            return (x, .effects, -4)
        case "window.lamp.off":
            var x = S.woodblock(1500, duration: 0.05, hardness: 0.35, rng: &rng)
            S.mix(S.voice(note(7), duration: 0.5, vowel: .mm, glide: 0.94, breath: 0.02, attack: 0.05, release: 0.3, rng: &rng),
                  into: &x, at: 0.03, gain: 0.55)
            return (x, .effects, -5)
        case "window.sky.day":
            return (S.glock(note(15) * jitter, duration: 1.2, hardness: 0.15, rng: &rng), .music, -4)
        case "window.sky.night":
            return (S.glock(note(17) * jitter, duration: 1.4, hardness: 0.1, rng: &rng), .music, -5)
        case "window.star":
            return (arp([17, 15, 13], step: 0.08, rng: &rng) { f, r in S.glock(f, duration: 1.0, hardness: 0.12, rng: &r) }, .music, -4)
        case "window.comet":
            var x = S.whoosh(duration: 0.6, from: 2600, to: 1400, q: 1.4, rng: &rng)
            S.mix(S.glock(note(19), duration: 1.0, hardness: 0.1, rng: &rng), into: &x, at: 0.1, gain: 0.6)
            return (x, .music, -5)
        case "window.plant":
            return (S.cloth(duration: 0.28, center: 3200, q: 1.2, flutter: 30, rng: &rng), .effects, -9)
        case "window.morning":
            return (arp([10, 12, 14, 17], step: 0.12, rng: &rng) { f, r in S.kalimba(f, duration: 1.3, hardness: 0.25, rng: &r) }, .music, -1)
        case "window.night":
            var x = [Float]()
            for (i, d) in [5, 9, 12].enumerated() {
                S.mix(S.voice(note(d), duration: 1.6, vowel: .oo, breath: 0.03, attack: 0.25, release: 0.8, rng: &rng),
                      into: &x, at: Double(i) * 0.12, gain: 0.7)
            }
            return (x, .music, -3)

        // — Drop Dots ——————————————————————————————————————————————
        case "dots.tab":
            return (S.woodblock(1100 * jitter, duration: 0.09, hardness: 0.3, rng: &rng), .ui, -4)
        case "dots.pickup":
            var x = S.cloth(duration: 0.12, center: 1700 * jitter, q: 1.0, flutter: 0, rng: &rng)
            S.mix(S.woodblock(1300, duration: 0.07, hardness: 0.15, rng: &rng), into: &x, at: 0, gain: 0.35)
            return (x, .effects, -5)
        case "dots.full":
            var x = S.woodblock(260, duration: 0.14, hardness: 0.15, rng: &rng)
            S.mix(S.woodblock(245, duration: 0.14, hardness: 0.15, rng: &rng), into: &x, at: 0.13, gain: 0.8)
            return (x, .effects, -5)
        case "dots.fall":
            return (S.whoosh(duration: 0.24, from: 900, to: 1700, q: 1.2, rng: &rng), .effects, -9)
        case "dots.land.0", "dots.land.1", "dots.land.2", "dots.land.3":
            // Honest weight: each dot that lands on others sounds one pentatonic step deeper.
            let level = Int(id.split(separator: ".").last ?? "0") ?? 0
            var x = S.woodblock(note(13 - level) * jitter, duration: 0.2, hardness: 0.3, rng: &rng)
            S.mix(S.feltThump(250, duration: 0.12, rng: &rng), into: &x, at: 0, gain: 0.5)
            return (x, .effects, -1)
        case "dots.golden":
            return (arp([15, 17], step: 0.07, rng: &rng) { f, r in S.glock(f, duration: 1.1, hardness: 0.15, rng: &r) }, .music, -3)
        case "dots.wave":
            return (arp([9, 10, 12], step: 0.1, rng: &rng) { f, r in S.kalimba(f, duration: 1.1, hardness: 0.28, rng: &r) }, .music, -1)
        case "dots.pattern":
            return (arp([10, 12, 14], step: 0.1, rng: &rng) { f, r in S.kalimba(f, duration: 1.2, hardness: 0.28, rng: &r) }, .music, 0)
        case "dots.full.board":
            var x = arp([10, 12, 13, 15], step: 0.12, rng: &rng) { f, r in S.kalimba(f, duration: 1.3, hardness: 0.28, rng: &r) }
            S.mix(S.glock(note(20), duration: 1.5, hardness: 0.12, rng: &rng), into: &x, at: 0.42, gain: 0.4)
            return (x, .music, 0)
        case "dots.pour":
            var x = S.whoosh(duration: 0.55, from: 600, to: 1500, q: 1.0, rng: &rng)
            for i in 0..<8 {
                S.mix(S.woodblock(rng.range(700, 1150), duration: 0.09, hardness: 0.3, rng: &rng), into: &x,
                      at: 0.1 + Double(i) * rng.range(0.05, 0.08), gain: Float(rng.range(0.3, 0.55)))
            }
            return (x, .effects, -1)
        case "dots.hover":
            return (S.cloth(duration: 0.15, center: 1000, q: 0.9, flutter: 0, rng: &rng), .effects, -14)
        case "dots.home":
            return (S.woodblock(rng.range(600, 800), duration: 0.12, hardness: 0.25, rng: &rng), .effects, -6)

        // — Mix-Up ——————————————————————————————————————————————————
        case "mix.flip":
            var x = S.whoosh(duration: 0.09, from: 1800, to: 3200, q: 1.3, rng: &rng)
            S.mix(S.woodblock(1600 * jitter, duration: 0.05, hardness: 0.2, rng: &rng), into: &x, at: 0.06, gain: 0.5)
            return (x, .effects, -5)
        case "mix.settle":
            return (S.feltThump(245 * jitter, duration: 0.16, rng: &rng), .effects, -5)
        case "mix.celebrate":
            return (arp([12, 14], step: 0.1, rng: &rng) { f, r in S.kalimba(f, duration: 1.0, hardness: 0.28, rng: &r) }, .music, -2)
        case "mix.save":
            var x = S.smallBell(note(17), duration: 1.6, rng: &rng)
            S.mix(S.kalimba(note(12), duration: 1.1, hardness: 0.25, rng: &rng), into: &x, at: 0, gain: 0.6)
            return (x, .music, -2)
        case "friend.bunny":
            var x = S.tone(duration: 0.17, harmonics: [1, 0.12], attack: 0.006, release: 0.06) { p in 330 + 230 * p }
            S.mix(S.feltPuff(duration: 0.05, bright: 900, rng: &rng), into: &x, at: 0, gain: 0.3)
            return (x, .voices, -3)
        case "friend.bear":
            return (S.voice(220, duration: 0.38, vowel: .mm, glide: 0.94, breath: 0.06, attack: 0.04, release: 0.14, rng: &rng), .voices, -2)
        case "friend.songbird":
            return (S.chirp(rng: &rng, count: 2, base: 2900), .voices, -3)
        case "friend.fox":
            return (S.voice(520, duration: 0.13, vowel: .ah, glide: 1.3, breath: 0.05, attack: 0.012, release: 0.06, rng: &rng), .voices, -4)
        case "friend.mouse":
            return (S.tone(duration: 0.1, harmonics: [1, 0.06], attack: 0.005, release: 0.04) { p in 1750 + 500 * p }, .voices, -6)
        case "friend.frog":
            return (S.ribbit(rng: &rng), .voices, -2)
        case "friend.robot":
            var x = S.beep(note(12))
            S.mix(S.beep(note(8)), into: &x, at: 0.15)
            return (x, .voices, -4)
        case "friend.officer":
            return (S.tone(duration: 0.2, harmonics: [1, 0.05], attack: 0.015, release: 0.07) { p in 2050 * (1 + 0.02 * sin(2 * Double.pi * 16 * p * 0.2)) }, .voices, -6)
        case "friend.firefighter":
            return (S.smallBell(1320 * jitter, duration: 1.2, rng: &rng), .voices, -3)
        case "friend.bunny.whole":
            var x = [Float]()
            for i in 0..<2 {
                S.mix(S.tone(duration: 0.15, harmonics: [1, 0.12], attack: 0.006, release: 0.05) { p in 330 + 260 * p }, into: &x, at: Double(i) * 0.2)
            }
            S.mix(S.kalimba(note(14), duration: 1.0, hardness: 0.25, rng: &rng), into: &x, at: 0.42, gain: 0.6)
            return (x, .voices, -1)
        case "friend.bear.whole":
            var x = S.voice(220, duration: 0.3, vowel: .mm, breath: 0.05, attack: 0.04, release: 0.1, rng: &rng)
            S.mix(S.voice(247, duration: 0.42, vowel: .mm, glide: 1.04, breath: 0.05, attack: 0.04, release: 0.18, rng: &rng), into: &x, at: 0.3)
            S.mix(S.kalimba(note(9), duration: 1.1, hardness: 0.25, rng: &rng), into: &x, at: 0.55, gain: 0.55)
            return (x, .voices, -1)
        case "friend.songbird.whole":
            var x = S.chirp(rng: &rng, count: 4, base: 2800)
            S.mix(S.glock(note(17), duration: 1.0, hardness: 0.12, rng: &rng), into: &x, at: 0.5, gain: 0.5)
            return (x, .voices, -1)
        case "friend.fox.whole":
            var x = S.voice(520, duration: 0.12, vowel: .ah, glide: 1.3, breath: 0.05, attack: 0.012, release: 0.05, rng: &rng)
            S.mix(S.voice(580, duration: 0.14, vowel: .ah, glide: 1.3, breath: 0.05, attack: 0.012, release: 0.06, rng: &rng), into: &x, at: 0.18)
            S.mix(S.kalimba(note(13), duration: 1.0, hardness: 0.25, rng: &rng), into: &x, at: 0.4, gain: 0.6)
            return (x, .voices, -2)
        case "friend.mouse.whole":
            var x = [Float]()
            for i in 0..<3 {
                S.mix(S.tone(duration: 0.08, harmonics: [1, 0.06], attack: 0.005, release: 0.03) { p in 1800 + 450 * p }, into: &x, at: Double(i) * 0.12)
            }
            S.mix(S.glock(note(15), duration: 0.9, hardness: 0.12, rng: &rng), into: &x, at: 0.38, gain: 0.5)
            return (x, .voices, -4)
        case "friend.frog.whole":
            var x = S.ribbit(rng: &rng)
            S.mix(S.ribbit(rng: &rng), into: &x, at: 0.4, gain: 0.8)
            S.mix(S.kalimba(note(7), duration: 1.0, hardness: 0.3, rng: &rng), into: &x, at: 0.8, gain: 0.55)
            return (x, .voices, -1)
        case "friend.robot.whole":
            var x = [Float]()
            for (i, d) in [12, 8, 10, 13].enumerated() { S.mix(S.beep(note(d), duration: 0.11), into: &x, at: Double(i) * 0.14) }
            S.mix(S.glock(note(18), duration: 1.0, hardness: 0.15, rng: &rng), into: &x, at: 0.6, gain: 0.45)
            return (x, .voices, -3)
        case "friend.officer.whole":
            var x = [Float]()
            for i in 0..<2 {
                S.mix(S.tone(duration: 0.17, harmonics: [1, 0.05], attack: 0.015, release: 0.06) { _ in 2050 }, into: &x, at: Double(i) * 0.24)
            }
            S.mix(S.kalimba(note(12), duration: 1.0, hardness: 0.25, rng: &rng), into: &x, at: 0.52, gain: 0.7)
            return (x, .voices, -7)
        case "friend.firefighter.whole":
            var x = S.smallBell(1320, duration: 0.9, rng: &rng)
            S.mix(S.smallBell(1320, duration: 1.2, rng: &rng), into: &x, at: 0.28, gain: 0.85)
            // A tiny, slow "wee-woo": two gentle cycles, far quieter than the bell.
            let siren = S.tone(duration: 1.3, harmonics: [1, 0.12], attack: 0.12, release: 0.3) { p in 640 + 200 * (0.5 - 0.5 * cos(4 * Double.pi * p)) }
            S.mix(siren, into: &x, at: 0.55, gain: 0.22)
            return (x, .voices, -3)

        // — Hum ——————————————————————————————————————————————————
        case "hum.knob":
            var x = S.woodblock(640 * jitter, duration: 0.12, hardness: 0.22, rng: &rng)
            S.mix(S.woodblock(980, duration: 0.06, hardness: 0.2, rng: &rng), into: &x, at: 0.07, gain: 0.4)
            return (x, .ui, -2)
        case "hum.invite":
            return (arp([10, 12, 15], step: 0.2, rng: &rng) { f, r in S.kalimba(f, duration: 1.3, hardness: 0.2, rng: &r) }, .music, -4)

        // — Meadow ——————————————————————————————————————————————————
        case "meadow.wake":
            return (S.glock(note(12) * jitter, duration: 0.9, hardness: 0.12, rng: &rng), .music, -5)
        case "meadow.breeze":
            return (S.whoosh(duration: 0.8, from: 500, to: 1100, q: 0.7, rng: &rng), .effects, -7)
        case "meadow.invite":
            return (S.kalimba(note(9), duration: 1.1, hardness: 0.2, rng: &rng), .music, -4)
        case "meadow.paint":
            return (S.glock(note(Int(rng.range(10, 15))), duration: 0.7, hardness: 0.08, rng: &rng), .music, -11)
        case "meadow.bloom":
            var x = S.glock(note(Int(rng.range(11, 15))), duration: 1.0, hardness: 0.12, rng: &rng)
            S.mix(S.cloth(duration: 0.25, center: 3000, q: 1.2, flutter: 26, rng: &rng), into: &x, at: 0, gain: 0.3)
            return (x, .music, -5)
        case "meadow.spring":
            return (arp([5, 9, 12], step: 0.13, rng: &rng) { f, r in S.kalimba(f, duration: 1.2, hardness: 0.25, rng: &r) }, .music, -1)
        case "meadow.fullspring":
            var x = arp([9, 12, 14, 17], step: 0.13, rng: &rng) { f, r in S.kalimba(f, duration: 1.3, hardness: 0.25, rng: &r) }
            S.mix(S.glock(note(19), duration: 1.6, hardness: 0.12, rng: &rng), into: &x, at: 0.5, gain: 0.4)
            return (x, .music, 0)
        case "meadow.frost":
            var x = arp([17, 15, 12], step: 0.16, rng: &rng) { f, r in S.glock(f, duration: 1.4, hardness: 0.08, rng: &r) }
            S.mix(S.whoosh(duration: 0.9, from: 1800, to: 900, q: 0.9, rng: &rng), into: &x, at: 0, gain: 0.35)
            return (x, .music, -4)
        case "meadow.landmark.wake":
            return (S.voice(note(9), duration: 0.4, vowel: .oh, glide: 1.08, breath: 0.04, attack: 0.04, release: 0.16, rng: &rng), .voices, -4)

        default:
            return nil
        }
    }

    // MARK: Room beds (looping, generative, very quiet)

    /// A seamless loop for a room: shaped noise with slow movement, plus baked-in creatures
    /// where they belong. Rendered once per room, ~16 s, crossfaded end-to-start.
    static func bed(_ room: String) -> [Float]? {
        var rng = LullSynth.Random(seed: LullSynth.seed("bed." + room, 0))
        let seconds = 16.0
        let n = LullSynth.frames(seconds)
        let (lowCut, highCut, sway): (Double, Double, Double)
        switch room {
        case "room": (lowCut, highCut, sway) = (160, 900, 0.15)
        case "breeze": (lowCut, highCut, sway) = (220, 1600, 0.45)
        case "airy": (lowCut, highCut, sway) = (300, 2400, 0.35)
        case "night": (lowCut, highCut, sway) = (150, 700, 0.10)
        case "sleep": (lowCut, highCut, sway) = (200, 800, 0.9)
        default: return nil
        }
        var x = [Float](repeating: 0, count: n)
        var hp = LullSynth.Biquad.highpass(lowCut)
        var lp = LullSynth.Biquad.lowpass(highCut)
        var lp2 = LullSynth.Biquad.lowpass(highCut)
        let swayRate = room == "sleep" ? 1 / 4.0 : 1 / 8.0   // whole cycles per loop keep the seam clean
        for i in 0..<n {
            let t = Double(i) / LullSynth.sampleRate
            let move = 1 - sway * 0.5 * (1 - cos(2 * Double.pi * swayRate * t))
            x[i] = Float(lp2.process(lp.process(hp.process(rng.noise()))) * move)
        }
        if room == "night" {
            // Distant crickets: soft 4.4 kHz chirp trains.
            var t = 0.4
            while t < seconds - 0.6 {
                for k in 0..<3 {
                    let c = LullSynth.tone(duration: 0.035, harmonics: [1], attack: 0.006, release: 0.015) { _ in 4400 }
                    LullSynth.mix(c, into: &x, at: t + Double(k) * 0.06, gain: 0.05)
                }
                t += rng.range(0.9, 1.8)
            }
            if x.count > n { x.removeLast(x.count - n) }
        }
        // Crossfade the last second into the first so `.loops` is seamless.
        let cross = LullSynth.frames(1.0)
        for i in 0..<cross {
            let w = Float(i) / Float(cross)
            x[i] = x[i] * w + x[n - cross + i] * (1 - w)
        }
        x.removeLast(cross)
        LullSynth.normalize(&x, rmsDB: LullSoundBus.ambience.targetRMS, gainDB: room == "sleep" ? -4 : 0)
        return x
    }
}

// MARK: - Compatibility: the older note-and-preset interface
//
// Older toy code (and the parked toys still in the project) describe sounds as pentatonic
// degrees plus a preset voice. That interface stays so it keeps compiling, but every preset now
// renders through the physical models above, at the same tuning and loudness as everything else.

/// The playback side, provided by `AudioManager`.
protocol LullTonePlayer: AnyObject {
    func playRendered(_ key: String, render: @escaping () -> LullRenderedSound)
    func prewarmRendered(_ key: String, render: @escaping () -> LullRenderedSound)
    func playLegacySequence(_ steps: [(key: String, delay: Double, render: () -> LullRenderedSound)])
    func playLegacyAmbient(id: String, volume: Float, fadeIn: TimeInterval, render: @escaping () -> LullRenderedSound)
    func stopLegacyAmbient(id: String, fadeOut: TimeInterval)
    func setLegacyAmbientVolume(_ volume: Float, for id: String, duration: TimeInterval)
    func stopEverything()
}

final class LullToneEngine {
    static let shared = LullToneEngine()
    weak var player: LullTonePlayer?

    struct Voice {
        enum Kind { case soft, warm, voiceLike, bell, wood, air, felt, clay, water, breath, celeste, choir, glass, marimba }

        var kind: Kind = .soft
        var partials: [(ratio: Double, gain: Double)] = [(1, 1)]
        var attack: Double = 0.010
        var body: Double = 0.42
        var curve: Double = 2.2
        var amplitude: Double = 0.16
        var vibratoHz: Double = 0
        var vibratoDepthSemitones: Double = 0
        var noiseGain: Double = 0

        static let soft = Voice(kind: .soft)
        static let warm = Voice(kind: .warm)
        static let voiceLike = Voice(kind: .voiceLike, body: 0.36, amplitude: 0.17)
        static let bell = Voice(kind: .bell, body: 0.85, amplitude: 0.13)
        static let wood = Voice(kind: .wood, body: 0.40, amplitude: 0.15)
        static let air = Voice(kind: .air, body: 0.20, amplitude: 0.10)
        static let felt = Voice(kind: .felt, body: 0.26, amplitude: 0.12, noiseGain: 0.09)
        static let clay = Voice(kind: .clay, body: 0.34, amplitude: 0.13, noiseGain: 0.12)
        static let water = Voice(kind: .water, body: 0.30, amplitude: 0.12, noiseGain: 0.05)
        static let breath = Voice(kind: .breath, body: 0.58, amplitude: 0.08, noiseGain: 0.55)
        static let celeste = Voice(kind: .celeste, attack: 0.008, body: 1.25, amplitude: 0.12)
        static let choir = Voice(kind: .choir, attack: 0.04, body: 0.80, amplitude: 0.14)
        static let glass = Voice(kind: .glass, attack: 0.02, body: 1.15, amplitude: 0.11)
        static let marimba = Voice(kind: .marimba, body: 0.58, amplitude: 0.14)

        func with(body: Double? = nil, amplitude: Double? = nil, curve: Double? = nil, noiseGain: Double? = nil) -> Voice {
            var copy = self
            if let body { copy.body = body }
            if let amplitude { copy.amplitude = amplitude }
            if let curve { copy.curve = curve }
            if let noiseGain { copy.noiseGain = noiseGain }
            return copy
        }
    }

    struct Spec {
        var notes: [(degree: Int, delay: Double)]
        var voice: Voice
        var pitchMultiplier: Double = 1.0

        static func single(_ degree: Int, _ voice: Voice, pitch: Double = 1.0) -> Spec {
            Spec(notes: [(degree, 0)], voice: voice, pitchMultiplier: pitch)
        }
        static func chord(_ degrees: [Int], _ voice: Voice) -> Spec {
            Spec(notes: degrees.map { ($0, 0) }, voice: voice)
        }
        static func arp(_ degrees: [Int], step: Double = 0.075, _ voice: Voice) -> Spec {
            Spec(notes: degrees.enumerated().map { ($0.element, Double($0.offset) * step) }, voice: voice)
        }
    }

    struct AmbientSpec {
        var frequency: Double = 60
        var partials: [(ratio: Double, gain: Double)] = [(1, 1.0)]
        var noiseGain: Double = 0
        var lfoHz: Double = 0
        var lfoDepth: Double = 0
        var amplitude: Double = 0.022
        var duration: Double = 8
    }

    enum BloomSeason: Int { case spring, summer, autumn, winter }

    private init() {}

    var isSpatialEnabled: Bool = false
    func setSoundPosition(_ point: CGPoint, sceneSize: CGSize, nodeID: String) {}
    func detectSpatialCapability() {}

    func pitchHz(forDegree degree: Int) -> Double { LullSynth.hz(degree: degree) }

    func play(_ spec: Spec, cacheKey: String) {
        player?.playRendered("spec." + cacheKey) { LullToneEngine.render(spec, key: cacheKey) }
    }

    func prewarm(_ spec: Spec, cacheKey: String) {
        player?.prewarmRendered("spec." + cacheKey) { LullToneEngine.render(spec, key: cacheKey) }
    }

    func playSequence(_ steps: [(spec: Spec, delay: Double, cacheKey: String)]) {
        player?.playLegacySequence(steps.map { step in
            (key: "spec." + step.cacheKey, delay: step.delay, render: { LullToneEngine.render(step.spec, key: step.cacheKey) })
        })
    }

    func prewarmAmbient(id: String, spec: AmbientSpec) {
        player?.prewarmRendered("ambient." + id) { LullToneEngine.renderAmbient(spec, id: id) }
    }

    func playAmbient(id: String, spec: AmbientSpec, volume: Float, fadeIn: TimeInterval, loopCount: Int? = nil) {
        player?.playLegacyAmbient(id: id, volume: volume, fadeIn: fadeIn) { LullToneEngine.renderAmbient(spec, id: id) }
    }

    func stopAmbient(id: String, fadeOut: TimeInterval) { player?.stopLegacyAmbient(id: id, fadeOut: fadeOut) }

    func setAmbientVolume(_ volume: Float, for id: String, animated duration: TimeInterval) {
        player?.setLegacyAmbientVolume(volume, for: id, duration: duration)
    }

    func stopAllPlayback() { player?.stopEverything() }

    func transitionBloomAmbientToSeason(_ season: BloomSeason, duration: TimeInterval = 12.0) {}

    /// A preset note rendered through the physical models.
    static func render(_ spec: Spec, key: String) -> LullRenderedSound {
        var rng = LullSynth.Random(seed: LullSynth.seed(key, 0))
        var out = [Float]()
        let length = min(2.4, max(0.15, spec.voice.body * 1.6))
        for note in spec.notes {
            let f = LullSynth.speakerSafe(LullSynth.hz(degree: note.degree) * spec.pitchMultiplier)
            let x: [Float]
            switch spec.voice.kind {
            case .soft, .warm: x = LullSynth.kalimba(f, duration: length + 0.4, hardness: 0.25, rng: &rng)
            case .clay: x = LullSynth.kalimba(f, duration: length + 0.2, hardness: 0.45, rng: &rng)
            case .wood: x = LullSynth.marimba(f, duration: length + 0.2, hardness: 0.5, rng: &rng)
            case .felt: x = LullSynth.marimba(f, duration: length + 0.2, hardness: 0.1, rng: &rng)
            case .marimba: x = LullSynth.marimba(f, duration: length + 0.4, hardness: 0.3, rng: &rng)
            case .celeste: x = LullSynth.glock(f, duration: length + 0.4, hardness: 0.18, rng: &rng)
            case .glass: x = LullSynth.glock(f, duration: length + 0.4, hardness: 0.4, rng: &rng)
            case .bell: x = LullSynth.smallBell(f, duration: length + 0.6, rng: &rng)
            case .water: x = LullSynth.bubble(min(f * 2, 2200), duration: 0.12, rng: &rng)
            case .voiceLike, .choir:
                x = LullSynth.voice(f, duration: length + 0.2, vowel: .oo, breath: 0.03, attack: 0.04, release: length * 0.6, rng: &rng)
            case .air, .breath:
                x = LullSynth.voice(f, duration: length + 0.2, vowel: .mm, breath: 0.25, attack: 0.05, release: length * 0.6, rng: &rng)
            }
            LullSynth.mix(x, into: &out, at: note.delay)
        }
        LullSynth.trimTail(&out)
        let relative = 20 * log10(min(1.4, max(0.35, spec.voice.amplitude / 0.12)))
        LullSynth.normalize(&out, rmsDB: LullSoundBus.music.targetRMS, gainDB: min(0, relative))
        return LullRenderedSound(samples: out, bus: .music)
    }

    /// Old drone/noise beds map to the shared quiet room beds; a pitched spec (a held Hum note)
    /// becomes a steady hummed voice that loops seamlessly.
    static func renderAmbient(_ spec: AmbientSpec, id: String) -> LullRenderedSound {
        if spec.frequency >= 120 && spec.noiseGain < 0.5 {
            var rng = LullSynth.Random(seed: LullSynth.seed("ambient." + id, 0))
            let seconds = max(4, spec.duration)
            var x = LullSynth.voice(LullSynth.speakerSafe(spec.frequency), duration: seconds + 1, vowel: .oo, depth: 0.004,
                                    breath: 0.03, attack: 0.001, release: 0.001, rng: &rng)
            let n = LullSynth.frames(seconds)
            let cross = x.count - n
            for i in 0..<cross {
                let w = Float(i) / Float(cross)
                x[i] = x[i] * w + x[n + i] * (1 - w)
            }
            x.removeLast(cross)
            LullSynth.normalize(&x, rmsDB: LullSoundBus.music.targetRMS, gainDB: -3)
            return LullRenderedSound(samples: x, bus: .music)
        }
        let room = spec.noiseGain > 0.5 ? "breeze" : "room"
        return LullRenderedSound(samples: LullSoundBook.bed(room) ?? [Float](repeating: 0, count: 4800), bus: .ambience)
    }
}
