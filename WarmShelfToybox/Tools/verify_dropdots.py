#!/usr/bin/env python3
"""Drop Dots colour matching (founder, build 5: "why did you remove the colors from the holes —
that was a big part of it. So a kid can match it, and then make 3 in a row").

Compiles the production hand-dealing code and checks, statically, that every dot colour has a
ring of its colour, the tray holds the whole finite hand, a dot that lands in its own colour's
column is welcomed home, and lifting, hovering and falling stay silent (felt, not heard).
"""
from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
scene = (root / "App/Toys/DropDots/DropDotsScene.swift").read_text()
passed = 0


def check(ok, what):
    global passed
    if not ok:
        raise SystemExit("FAIL: " + what)
    passed += 1


felts = re.search(r"static let felts: \[UIColor\] = \[(.*?)\]", scene, re.S).group(1)
felt_count = len(re.findall(r"UIColor\(hex:", felts))
names = re.search(r"static let feltNames = \[(.*?)\]", scene).group(1).split(",")
cols = int(re.search(r"private let cols = (\d+), rows = \d+", scene).group(1))
rings = re.search(r"\? \[(0x[0-9A-F, x]+)\]\.map", scene).group(1).split(",")
check(felt_count == cols == len(rings), f"one dot colour per ring ({felt_count} colours, {cols} columns, {len(rings)} rings)")
check(len(names) == felt_count, "every colour has a spoken name")
check("let n = totalTokens" in scene, "the tray shows the whole finite hand")
total = int(re.search(r"private let totalTokens = (\d+)", scene).group(1))
check(total == felt_count + 2, "the hand is one dot per ring plus a triple")
check(re.search(r"token\.feltIndex == col \{ welcomeHome\(col", scene) is not None,
      "a dot landing under its own colour is welcomed home")
check(re.search(r"feltIndex: hand\[slot % hand\.count\]", scene) is not None, "tray dots come from the dealt hand")
for cue in ["dots.pickup", "dots.hover", "dots.fall"]:
    check(f'"{cue}"' not in scene, f"{cue} stays silent (felt, not heard)")

hand = re.search(r"enum DropDotsHand \{.*?\n\}\n", scene, re.S).group(0)
program = """
enum DropDotsScene { enum DropDotToken { static let felts = [0, 0, 0, 0] } }
""" + hand + """
var tripleColours = Set<Int>()
for _ in 0..<2000 {
    let h = DropDotsHand.deal()
    precondition(h.count == 6, "six dots")
    precondition(Set(h) == Set(0..<4), "every ring colour is in the hand")
    let counts = Dictionary(grouping: h, by: { $0 }).mapValues(\\.count)
    precondition(counts.values.sorted() == [1, 1, 1, 3], "one colour three times, the rest once")
    tripleColours.insert(counts.first { $0.value == 3 }!.key)
}
precondition(tripleColours == Set(0..<4), "every colour gets its turn as the triple")
print("deal ok")
"""
with tempfile.TemporaryDirectory() as d:
    d = Path(d)
    (d / "main.swift").write_text(program)
    swiftc = ["xcrun", "swiftc"] if shutil.which("xcrun") else [str(Path(os.environ.get("SWIFT", "swift")).with_name("swiftc"))]
    subprocess.run(swiftc + ["-module-cache-path", str(d / "cache"), str(d / "main.swift"), "-o", str(d / "deal")], check=True)
    out = subprocess.run([str(d / "deal")], check=True, capture_output=True, text=True).stdout
    check("deal ok" in out, "2,000 deals: six dots, all four colours, exactly one triple, every colour gets a turn")

print(f"PASS: Drop Dots colour matching, {passed} checks")
