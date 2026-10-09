#!/usr/bin/env python3
"""Render every cue and variant in App/Shared/LullToneEngine.swift and check the whole kit.

Per sound: renders, finite, no click at either end, peak at or under -3 dBFS, audible-part RMS
never more than 3 dB over its bus target, a sane length. Kit-wide: every cue the app names exists; musical
notes land on the C major pentatonic; room beds loop without a seam. Optional --wav DIR writes
variant 0 of everything for listening.
"""
from pathlib import Path
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

import numpy as np

root = Path(__file__).resolve().parents[1]
synth = (root / "App/Shared/LullToneEngine.swift").read_text()
wav_dir = Path(sys.argv[sys.argv.index("--wav") + 1]) if "--wav" in sys.argv else None

main = r'''
import Foundation
let out = CommandLine.arguments[1]
func dump(_ name: String, _ bus: Int, _ x: [Float]) {
    var data = Data()
    var header = [UInt32(bus), UInt32(x.count)]
    data.append(Data(bytes: &header, count: 8))
    x.withUnsafeBufferPointer { data.append(Data(buffer: $0)) }
    try! data.write(to: URL(fileURLWithPath: "\(out)/\(name).f32"))
}
for id in LullSoundBook.cueIDs {
    for v in 0..<LullSoundBook.variants(for: id) {
        guard let r = LullSoundBook.render(id, variant: v) else { print("MISSING \(id)"); exit(1) }
        dump("\(id)#\(v)", r.bus.rawValue, r.samples)
    }
}
for inst in ["pluck", "kalimba", "marimba", "glock", "glass", "bell", "wood", "choir"] {
    for d in 0...19 {
        guard let r = LullSoundBook.render("note.\(inst).\(d)", variant: 0) else { print("MISSING note"); exit(1) }
        dump("note.\(inst).\(d)#0", r.bus.rawValue, r.samples)
    }
}
for room in ["room", "breeze", "airy", "night", "sleep"] {
    dump("bed.\(room)#0", 4, LullSoundBook.bed(room)!)
}
'''

TARGETS = {0: -34, 1: -29, 2: -28.5, 3: -30, 4: -49}
SR = 48000


def active_rms(x):
    p = np.abs(x).max()
    if p == 0:
        return -120
    a = np.exp(-1 / (0.010 * SR))
    env = np.empty_like(x)
    e = 0.0
    ax = np.abs(x)
    for i in range(len(x)):
        e = ax[i] if ax[i] > a * e else a * e
        env[i] = e
    act = x[env > p * 0.1]
    return 20 * np.log10(np.sqrt(np.mean(act ** 2)) + 1e-12)


passed = 0


def check(ok, what):
    global passed
    if not ok:
        raise SystemExit("FAIL: " + what)
    passed += 1


with tempfile.TemporaryDirectory() as directory:
    d = Path(directory)
    (d / "LullToneEngine.swift").write_text(synth)
    (d / "main.swift").write_text(main)
    swiftc = ["xcrun", "swiftc"] if shutil.which("xcrun") else [str(Path(os.environ.get("SWIFT", "swift")).with_name("swiftc"))]
    subprocess.run(swiftc + ["-O", "-swift-version", "5", "-module-cache-path", str(d / "cache"),
                             str(d / "LullToneEngine.swift"), str(d / "main.swift"), "-o", str(d / "render")], check=True)
    (d / "out").mkdir()
    subprocess.run([str(d / "render"), str(d / "out")], check=True)

    sounds = {}
    for f in sorted((d / "out").glob("*.f32")):
        raw = f.read_bytes()
        bus, n = struct.unpack("<II", raw[:8])
        sounds[f.stem] = (bus, np.frombuffer(raw[8:], dtype="<f4").astype(np.float64))

    # Every cue name used by the app exists in the book.
    used = set()
    for swift in (root / "App").rglob("*.swift"):
        if swift.name == "LullToneEngine.swift":
            continue
        used |= set(re.findall(r'play\(cue: "([a-z0-9.]+)"', swift.read_text()))
        used |= set(re.findall(r'prewarm\(cue: "([a-z0-9.]+)"', swift.read_text()))
        used |= set(re.findall(r'\btone\("([a-z0-9.]+)"', swift.read_text()))
        for a, b in re.findall(r'\? "([a-z0-9.]+)" : "([a-z0-9.]+)"', swift.read_text()):
            used |= {a, b}
    book = {name.split("#")[0] for name in sounds}
    missing = sorted(u for u in used if u not in book)
    check(not missing, f"every cue the app plays exists ({missing})")

    for name, (bus, x) in sounds.items():
        cue = name.split("#")[0]
        check(np.isfinite(x).all() and len(x) > 0, f"{name} renders finite samples")
        peak = 20 * np.log10(np.abs(x).max() + 1e-12)
        check(peak <= -2.9, f"{name} peak {peak:.1f} dBFS stays under -3 dBFS")
        if cue.startswith("bed."):
            check(abs(x[0] - x[-1]) < 0.01, f"{name} loops without a seam")
            check(15 <= len(x) / SR <= 16, f"{name} loop length")
            continue
        check(abs(x[0]) < 1e-3 and abs(x[-1]) < 1e-3, f"{name} starts and ends at silence (no click)")
        check(len(x) / SR <= 9.6, f"{name} length {len(x) / SR:.2f}s is bounded")
        if "#0" in name:
            rms = active_rms(x)
            # Never louder than its bus (+3 dB). Deliberately quiet cues (hovers, hints) sit lower, and the
            # engine sets loudness by ear, so bright sounds measure a few dB under their bus here.
            check(-20 <= rms - TARGETS[bus] <= 3, f"{name} RMS {rms:.1f} dB vs bus target {TARGETS[bus]}")

    # Musical notes land on the C major pentatonic (degree 0 = C3), lifted to >= 196 Hz.
    pent = [0, 2, 4, 7, 9]
    for inst in ["pluck", "kalimba", "marimba", "glock", "glass", "bell", "wood", "choir"]:
        for deg in range(20):
            x = sounds[f"note.{inst}.{deg}#0"][1][: SR]
            o, s = divmod(deg, 5)
            f = 440 * 2 ** ((48 + 12 * o + pent[s] - 69) / 12)
            while f < 196:
                f *= 2
            spec = np.abs(np.fft.rfft(x * np.hanning(len(x)), 1 << 18))
            freqs = np.fft.rfftfreq(1 << 18, 1 / SR)
            band = (freqs > f * 0.8) & (freqs < f * 1.25)
            peak_f = freqs[band][np.argmax(spec[band])]
            check(abs(peak_f / f - 1) < 0.012, f"note.{inst}.{deg} sounds at {peak_f:.1f} Hz, expected {f:.1f}")

    if wav_dir:
        import wave
        wav_dir.mkdir(parents=True, exist_ok=True)
        for name, (_, x) in sounds.items():
            if name.endswith("#0"):
                with wave.open(str(wav_dir / (name[:-2] + ".wav")), "wb") as w:
                    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
                    w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())

print(f"PASS: sound kit, {passed} checks over {len(sounds)} rendered sounds")
