"""Lull sound-design toolkit: physically informed synthesis, a shared room, and loudness checks.

Every sound in Lull's kit is rendered from these primitives by `render_kit.py`, so the whole
palette shares one tuning, one room and one loudness standard, and can be regenerated exactly.

Design rules the primitives enforce:
- No clicks: every sound starts with a raised-cosine attack (>= 1.5 ms) and ends with a fade.
- No aliasing: tones are sums of sinusoids kept below 0.45 * sample rate.
- One room: a short, warm, felt-damped room (synthetic impulse response) shared by everything.
- Loudness by category (BS.1770-style integrated loudness), peaks kept under -3 dBFS.
"""
import struct
import subprocess
import wave
from pathlib import Path

import numpy as np

SR = 48_000
RNG = np.random.default_rng(20261007)

# --- tuning -----------------------------------------------------------------------------------
# Everything tonal lives in D major pentatonic (D E F# A B): any two notes sound well together,
# so a child can never play a "wrong" note and simultaneous toys never clash.
A4 = 440.0
PENTATONIC = [0, 2, 4, 7, 9]          # semitones above D


def midi_hz(m):
    return A4 * 2 ** ((m - 69) / 12)


def scale_note(degree, octave=4):
    """degree 0.. counts pentatonic steps upward from D<octave>."""
    base = 62 + 12 * (octave - 4)       # D4 = MIDI 62
    o, d = divmod(degree, len(PENTATONIC))
    return midi_hz(base + 12 * o + PENTATONIC[d])


# --- basics -------------------------------------------------------------------------------------
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def fade(x, attack=0.0015, release=0.012):
    x = x.copy()
    a, r = max(1, int(attack * SR)), max(1, int(release * SR))
    a, r = min(a, len(x) // 2), min(r, len(x) // 2)
    x[:a] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a))
    x[-r:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, r))
    return x


def noise(n):
    return RNG.standard_normal(n)


def onepole_lp(x, cutoff):
    """Simple one-pole low-pass (6 dB/oct), cutoff in Hz (scalar or per-sample array)."""
    c = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = np.exp(-2 * np.pi * c / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def biquad(x, b, a):
    b0, b1, b2 = b
    _, a1, a2 = a
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        xi = x[i]
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def bandpass(x, f0, q):
    w = 2 * np.pi * f0 / SR
    alpha = np.sin(w) / (2 * q)
    a0 = 1 + alpha
    return biquad(x, (alpha / a0, 0, -alpha / a0), (1, -2 * np.cos(w) / a0, (1 - alpha) / a0))


def lowpass(x, f0, q=0.707):
    w = 2 * np.pi * f0 / SR
    alpha = np.sin(w) / (2 * q)
    cw = np.cos(w)
    a0 = 1 + alpha
    return biquad(x, ((1 - cw) / 2 / a0, (1 - cw) / a0, (1 - cw) / 2 / a0), (1, -2 * cw / a0, (1 - alpha) / a0))


def highpass(x, f0, q=0.707):
    w = 2 * np.pi * f0 / SR
    alpha = np.sin(w) / (2 * q)
    cw = np.cos(w)
    a0 = 1 + alpha
    return biquad(x, ((1 + cw) / 2 / a0, -(1 + cw) / a0, (1 + cw) / 2 / a0), (1, -2 * cw / a0, (1 - alpha) / a0))


# --- sources ---------------------------------------------------------------------------------
def modal(f0, ratios, decays, amps, dur, hardness=0.5, detune=0.0):
    """Struck resonator (bar, tine, bell, block): damped partials. `hardness` 0..1 brightens
    the strike (soft felt mallet .. wooden stick); higher partials decay faster."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for r, d, a in zip(ratios, decays, amps):
        f = f0 * r * (1 + detune * RNG.uniform(-1, 1))
        if f >= 0.45 * SR:
            continue
        bright = (1 + hardness * 2) ** (np.log2(max(r, 1)) * 0.6) if r > 1 else 1
        out += a * bright / (1 + 0.3 * np.log2(max(r, 1)) * (1 - hardness)) * np.exp(-t / d) \
            * np.sin(2 * np.pi * f * t + RNG.uniform(0, 2 * np.pi))
    # Strike: a tiny filtered noise tick whose brightness follows hardness.
    n = int(0.004 * SR)
    tick = noise(n) * np.exp(-np.arange(n) / (0.0008 * SR))
    tick = lowpass(tick, 1500 + 7000 * hardness)
    out[:n] += tick * 0.12 * (0.4 + hardness)
    return fade(out, attack=0.0015, release=min(0.05, dur * 0.2))


def marimba(f0, dur=1.1, hardness=0.35):
    return modal(f0, [1, 3.93, 9.2], [0.55, 0.12, 0.04], [1, 0.22, 0.06], dur, hardness)


def kalimba(f0, dur=1.4, hardness=0.4):
    return modal(f0, [1, 5.93, 2.0], [0.9, 0.08, 0.25], [1, 0.12, 0.08], dur, hardness)


def glock(f0, dur=1.6, hardness=0.3):
    return modal(f0, [1, 2.76, 5.40, 8.93], [1.1, 0.5, 0.2, 0.08], [1, 0.32, 0.12, 0.05], dur, hardness)


def small_bell(f0, dur=1.8):
    return modal(f0, [1, 2.0, 2.4, 3.0, 4.07, 5.4], [1.2, 0.7, 0.6, 0.35, 0.2, 0.12],
                 [1, 0.5, 0.42, 0.25, 0.12, 0.06], dur, hardness=0.45, detune=0.002)


def woodblock(f0, dur=0.22, hardness=0.6):
    return modal(f0, [1, 1.58, 2.43, 3.6], [0.05, 0.03, 0.018, 0.01], [1, 0.5, 0.25, 0.1], dur, hardness)


def felt_thump(f0=140, dur=0.18, softness=0.7):
    """A felt object landing: a short low body plus a muffled cloth puff."""
    t = t_axis(dur)
    body = np.sin(2 * np.pi * f0 * t * (1 - 0.25 * t / dur)) * np.exp(-t / (0.035 + 0.02 * softness))
    puff = lowpass(noise(len(t)), 900 - 400 * softness) * np.exp(-t / 0.025)
    return fade(0.9 * body + 0.35 * puff / (np.abs(puff).max() + 1e-9), attack=0.002, release=0.03)


def cloth(dur=0.35, center=1800, q=0.9, flutter=18):
    """A soft rustle (curtain, felt sliding)."""
    t = t_axis(dur)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    env *= 0.75 + 0.25 * np.sin(2 * np.pi * flutter * t + RNG.uniform(0, 6))
    x = bandpass(noise(len(t)), center, q) * env
    return fade(x, attack=0.004, release=0.04)


def bubble(f0=900, dur=0.12, rise=1.6):
    """Minnaert bubble: a damped sinusoid whose pitch rises as the bubble closes."""
    t = t_axis(dur)
    tau = dur / 4.5
    f = f0 * (1 + rise * t / dur)
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(phase) * np.exp(-t / tau)
    tick = np.zeros_like(t)
    n = int(0.0015 * SR)
    tick[:n] = noise(n) * 0.06
    return fade(x + highpass(tick, 3000), attack=0.0008, release=0.01)


def whoosh(dur=0.45, f_from=500, f_to=2200, q=1.2):
    t = t_axis(dur)
    env = np.sin(np.pi * t / dur) ** 2
    x = noise(len(t))
    y = np.zeros_like(x)
    seg = int(0.01 * SR)
    for i in range(0, len(x), seg):     # piecewise sweep of a resonant band
        f = f_from * (f_to / f_from) ** (i / len(x))
        y[i:i + seg] = bandpass(x[max(0, i - 2 * seg):i + seg], f, q)[-len(x[i:i + seg]):]
    return fade(lowpass(y, 5000) * env, attack=0.01, release=0.05)


def voice(f0, dur=1.0, vowel="oo", vibrato=5.2, depth=0.006, breath=0.04, attack=0.06, release=0.25):
    """A soft hummed vowel: harmonics shaped by two formants, gentle vibrato and breath."""
    formants = {"oo": [(320, 80), (800, 120)], "oh": [(450, 90), (850, 120)],
                "ah": [(700, 110), (1150, 140)], "mm": [(250, 60), (1100, 300)]}[vowel]
    t = t_axis(dur)
    vib = 1 + depth * np.sin(2 * np.pi * vibrato * t) * np.clip(t / 0.3, 0, 1)
    phase = 2 * np.pi * f0 * np.cumsum(vib) / SR
    out = np.zeros_like(t)
    k = 1
    while f0 * k < min(0.45 * SR, 5000):
        h = f0 * k
        gain = sum(np.exp(-((h - fc) / bw) ** 2 / 2) for fc, bw in formants) + 0.05 / k
        out += gain / k ** 0.6 * np.sin(k * phase)
        k += 1
    out /= np.abs(out).max() + 1e-9
    out += breath * lowpass(noise(len(t)), 2500)
    env = np.minimum(1, t / attack) * np.minimum(1, (dur - t) / release)
    return fade(out * np.clip(env, 0, 1), attack=0.003, release=0.02)


def tone(freqs_hz, dur, harmonics=(1.0, 0.18, 0.05), attack=0.01, release=0.08):
    """A soft additive tone following a pitch curve (array or scalar)."""
    t = t_axis(dur)
    f = np.broadcast_to(np.asarray(freqs_hz, dtype=float), t.shape)
    phase = 2 * np.pi * np.cumsum(f) / SR
    out = sum(a * np.sin((k + 1) * phase) for k, a in enumerate(harmonics) if f.max() * (k + 1) < 0.45 * SR)
    env = np.minimum(1, t / attack) * np.minimum(1, (dur - t) / release)
    return fade(out * np.clip(env, 0, 1))


# --- the room --------------------------------------------------------------------------------
def room_ir(rt60=0.42, predelay=0.006, brightness=3200):
    n = int((rt60 * 1.3 + predelay) * SR)
    t = np.arange(n) / SR
    ir = noise(n) * np.exp(-6.91 * t / rt60)
    ir = lowpass(ir, brightness)
    ir[: int(predelay * SR)] = 0
    return ir / np.sqrt((ir ** 2).sum())


ROOM = None


def in_room(x, wet=0.16):
    global ROOM
    if ROOM is None:
        ROOM = room_ir()
    n = len(x) + len(ROOM) - 1
    size = 1 << (n - 1).bit_length()
    wetsig = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ROOM, size), size)[:n]
    dry = np.concatenate([x, np.zeros(n - len(x))])
    y = (1 - wet) * dry + wet * wetsig
    # Trim the tail once it falls below -70 dB of the peak.
    thresh = np.abs(y).max() * 10 ** (-70 / 20)
    last = np.nonzero(np.abs(y) > thresh)[0]
    y = y[: (last[-1] + int(0.01 * SR)) if len(last) else len(y)]
    return fade(y, attack=0.0005, release=0.02)


# --- loudness --------------------------------------------------------------------------------
def _k_weight(x):
    # BS.1770 K-weighting at 48 kHz (shelf + high-pass).
    x = biquad(x, (1.53512485958697, -2.69169618940638, 1.19839281085285), (1, -1.69065929318241, 0.73248077421585))
    return biquad(x, (1.0, -2.0, 1.0), (1, -1.99004745483398, 0.99007225036621))


def loudness_lufs(x):
    """Integrated loudness with the BS.1770 absolute gate, using 400 ms blocks (75% overlap);
    very short sounds are measured as one block."""
    y = _k_weight(x.astype(float))
    block, hop = int(0.4 * SR), int(0.1 * SR)
    if len(y) < block:
        return -0.691 + 10 * np.log10(np.mean(y ** 2) + 1e-12)
    powers = np.array([np.mean(y[i:i + block] ** 2) for i in range(0, len(y) - block + 1, hop)])
    lk = -0.691 + 10 * np.log10(powers + 1e-12)
    gated = powers[lk > -70]
    if not len(gated):
        return -70.0
    rel = -0.691 + 10 * np.log10(gated.mean()) - 10
    gated2 = gated[(-0.691 + 10 * np.log10(gated + 1e-12)) > rel]
    return -0.691 + 10 * np.log10((gated2 if len(gated2) else gated).mean())


def normalize(x, target_lufs, peak_dbfs=-3.0):
    gain = 10 ** ((target_lufs - loudness_lufs(x)) / 20)
    y = x * gain
    peak = np.abs(y).max()
    limit = 10 ** (peak_dbfs / 20)
    if peak > limit:                # never clip: quieter beats louder-and-crushed
        y *= limit / peak
    return y


def analyse(x):
    peak = np.abs(x).max()
    return {
        "dur_ms": round(1000 * len(x) / SR),
        "peak_dbfs": round(20 * np.log10(peak + 1e-12), 1),
        "lufs": round(loudness_lufs(x), 1),
        "start_abs": round(float(abs(x[0])), 5),
        "end_abs": round(float(abs(x[-1])), 5),
        "centroid_hz": round(float((np.abs(np.fft.rfft(x)) * np.fft.rfftfreq(len(x), 1 / SR)).sum()
                                   / (np.abs(np.fft.rfft(x)).sum() + 1e-12))),
    }


# --- output ----------------------------------------------------------------------------------
def write_wav(path, x):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(x, -1, 1)
    pcm = (pcm * 32767 + RNG.uniform(-0.5, 0.5, len(pcm))).round().astype("<i2")   # TPDF-ish dither
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def write_caf(path, x):
    """16-bit 48 kHz mono CAF (uncompressed: instant start, no decoder latency)."""
    path = Path(path)
    tmp = path.with_suffix(".tmp.wav")
    write_wav(tmp, x)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(tmp), "-c:a", "pcm_s16le", "-f", "caf", str(path)], check=True)
    tmp.unlink()
