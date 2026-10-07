#!/usr/bin/env python3
"""Run the production grown-up check question (AdultGateChallenge) off-device.

Checks: three spelled-out digits, typed back as digits; no digit or arithmetic shown;
wrong, partial and padded answers; randomness spread; rest constants.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "App/Shared/AdultGate.swift").read_text()
start = source.index("struct AdultGateChallenge {")
end = source.index("final class AdultGateViewController")
challenge = "import Foundation\n" + source[start:end]

checks = r'''
var passed = 0
func check(_ ok: Bool, _ what: String) {
    precondition(ok, "FAIL: " + what)
    passed += 1
}

let c = AdultGateChallenge(digits: [4, 7, 2])
check(c.prompt == "four · seven · two", "prompt spells each digit")
check(c.spokenPrompt == "four, seven, two", "VoiceOver reads the words with pauses")
check(c.answer == "472", "answer is the digits in order")
check(c.accepts("472") && c.accepts(" 472 "), "exact digits accepted, stray spaces forgiven")
check(!c.accepts("47") && !c.accepts("4720") && !c.accepts("274") && !c.accepts(""), "partial, long, reordered and empty rejected")
check(!c.accepts("13") && !c.accepts("four seven two"), "a sum or the words themselves are rejected")
check(!c.prompt.contains(where: { $0.isNumber }), "the prompt shows no digit a pre-reader could copy")

var seen = Set<String>()
var digitCounts = [Int](repeating: 0, count: 10)
var wellFormed = true
for _ in 0..<4000 {
    let r = AdultGateChallenge.random()
    wellFormed = wellFormed && r.digits.count == 3 && r.digits.allSatisfy { (0...9).contains($0) }
        && r.answer.count == 3 && r.accepts(r.answer)
    seen.insert(r.answer)
    for d in r.digits { digitCounts[d] += 1 }
}
check(wellFormed, "4,000 random questions: three digits 0-9, each accepts its own answer")
check(seen.count > 900, "questions spread across the 1,000 possibilities (saw \(seen.count))")
check(digitCounts.allSatisfy { $0 > 900 && $0 < 1500 }, "every digit appears about equally")
check(AdultGateChallenge.maxMisses == 3 && AdultGateChallenge.restDuration >= 30, "three misses rest the check for at least 30 s")
check(AdultGateChallenge.digitWords.count == 10, "ten digit words")
print("PASS: adult gate challenge, \(passed) checks")
'''

with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "AdultGateCheck.swift"
    path.write_text(challenge + checks)
    swift = ["xcrun", "swift"] if shutil.which("xcrun") else [os.environ.get("SWIFT", "swift")]
    subprocess.run(swift + ["-module-cache-path", str(Path(directory) / "ModuleCache"), str(path)], check=True)
