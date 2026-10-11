#!/usr/bin/env python3
"""Play timer per sitting (founder, October 11): it survives force-quit, an hour away starts a
fresh sitting, and only a grown-up or that hour clears the rest.

Compiles the production `LullPlaySitting` from App/Shared/AdultGate.swift and drives it
through relaunches (a new value rebuilt from the saved fields), pauses and clock changes.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "App/Shared/AdultGate.swift").read_text()
start = source.index("struct LullPlaySitting: Equatable {")
end = source.index("\n/// Counts gentle foreground play time.", start)
model = "import Foundation\n" + source[start:end]

checks = r'''
import Foundation
var passed = 0
func check(_ ok: Bool, _ what: String) {
    if !ok { print("FAIL: " + what); exit(1) }
    passed += 1
}
let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }
/// What a relaunch sees: only the saved fields, no running stretch.
func relaunch(_ s: LullPlaySitting) -> LullPlaySitting {
    var r = LullPlaySitting()
    r.played = s.played; r.lastActive = s.lastActive; r.resting = s.resting
    return r
}

var s = LullPlaySitting()
s.resume(at: at(0))
check(abs(s.elapsed(at: at(10)) - 600) < 0.01, "counts play while Lull is in front")
check(!s.isDue(limitMinutes: 30, at: at(29.9)) && s.isDue(limitMinutes: 30, at: at(30)), "due exactly at the limit")
check(!s.isDue(limitMinutes: 0, at: at(500)), "Off never rests")

s.pause(at: at(10))
s.resume(at: at(25))
check(abs(s.elapsed(at: at(25)) - 600) < 0.01, "time in the background doesn't count")

// Force-quit: the last tick checkpointed at minute 34; the app dies without a pause.
s.checkpoint(at: at(34))
var after = relaunch(s)
let fresh = after.resume(at: at(40))
check(!fresh && abs(after.elapsed(at: at(40)) - 19 * 60) < 0.01, "a relaunch within the hour keeps the sitting")
check(after.isDue(limitMinutes: 30, at: at(51)), "and the limit still arrives")

// The rest is showing, then Lull is swiped away and reopened.
after.resting = true
after.checkpoint(at: at(52))
var reopened = relaunch(after)
reopened.resume(at: at(55))
check(reopened.resting && reopened.isDue(limitMinutes: 30, at: at(55)), "force-quit can't skip the rest")
check(reopened.isDue(limitMinutes: 45, at: at(55)), "the rest holds even if the limit is still ahead")

// An hour away starts fresh.
var away = relaunch(reopened)
// Reopening at minute 55 was the last moment Lull was in front.
let wasFresh = away.resume(at: at(55 + 60))
check(wasFresh && !away.resting && away.elapsed(at: at(115)) < 0.01, "an hour away is a fresh sitting")
var almost = relaunch(reopened)
check(!almost.resume(at: at(55 + 59)) && almost.resting, "59 minutes away is not")

// A grown-up wakes Lull.
var woke = reopened
woke.startFresh(at: at(56), active: true)
check(!woke.resting && woke.elapsed(at: at(56)) < 0.01 && woke.activeSince != nil, "waking starts a fresh sitting")

// Turning the clock back is not time away.
var back = relaunch(after)
check(!back.resume(at: at(-300)) && back.resting, "a clock turned back keeps the sitting")

// Checkpoints never double count.
var steady = LullPlaySitting()
steady.resume(at: at(0))
for m in stride(from: 0.0, through: 30, by: 1.0 / 3.0) { steady.checkpoint(at: at(m)) }
check(abs(steady.elapsed(at: at(30)) - 1800) < 0.01, "20-second checkpoints add up exactly")
check(steady.resume(at: at(31)) == false && abs(steady.elapsed(at: at(31)) - 1860) < 0.01,
      "resume while already in front changes nothing")

print("PASS: \(passed) play timer checks (per sitting, survives relaunch, an hour away is fresh)")
'''

swiftc = os.environ.get("SWIFTC") or shutil.which("swiftc") or str(Path(os.environ.get("SWIFT", "swift")).with_name("swiftc"))
with tempfile.TemporaryDirectory(prefix="lull-play-timer-") as directory:
    d = Path(directory)
    (d / "Model.swift").write_text(model)
    (d / "main.swift").write_text(checks)
    command = (["xcrun", "swiftc"] if shutil.which("xcrun") else [swiftc]) + [
        "-module-cache-path", str(d / "cache"), str(d / "Model.swift"), str(d / "main.swift"), "-o", str(d / "check")]
    subprocess.run(command, check=True)
    subprocess.run([str(d / "check")], check=True)
