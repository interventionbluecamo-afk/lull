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
check("let n = totalTokens" in scene and "slots: perRow..<totalTokens" in scene and "slots: 0..<perRow" in scene,
      "the two tray rows show the whole finite hand")
total = int(re.search(r"private let totalTokens = (\d+)", scene).group(1))
check(total == felt_count * 3, "the hand is three dots of every ring colour")
check(re.search(r"Int\.random\(in: 0\.\.<80\) == 0", scene) is not None, "golden dots stay a once-in-a-while delight")
check("refreshDiscoveries(celebrate: true)" in scene and "detectPatterns(withSound: !sang)" in scene,
      "one song per landing: a bigger discovery replaces the smaller chimes")
check(scene.count("refreshDiscoveries(celebrate: false)") >= 2, "rotation and sending a dot back re-notice quietly")
check(re.search(r"token\.feltIndex == col \{ welcomeHome\(col", scene) is not None,
      "a dot landing under its own colour is welcomed home")
check(re.search(r"feltIndex: hand\[slot % hand\.count\]", scene) is not None, "tray dots come from the dealt hand")
for cue in ["dots.pickup", "dots.hover", "dots.fall"]:
    check(f'"{cue}"' not in scene, f"{cue} stays silent (felt, not heard)")

# Colour rounds (founder, October 11): every set has four clearly different felts a toddler can
# tell apart (in colour and in brightness), unique names, and arrives after each pour.
import colorsys
sets_src = re.search(r"enum DropDotsColourSets \{(.*?)\n\}\n", scene, re.S).group(1)
extra = re.findall(r"\[\(UIColor\(hex: 0x([0-9A-F]{6})\), \"(\w+)\"\), \(UIColor\(hex: 0x([0-9A-F]{6})\), \"(\w+)\"\),\s*\(UIColor\(hex: 0x([0-9A-F]{6})\), \"(\w+)\"\), \(UIColor\(hex: 0x([0-9A-F]{6})\), \"(\w+)\"\)\]", sets_src)
check(len(extra) >= 3, f"at least three new felt sets after the board's own ({len(extra)})")
def rgb(h): return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
def lab_like(c):
    r, g, b = c; return (0.299*r + 0.587*g + 0.114*b, r - g, (r + g) / 2 - b)
for entry in extra:
    colours = [rgb(entry[i]) for i in (0, 2, 4, 6)]
    names = [entry[i] for i in (1, 3, 5, 7)]
    check(len(set(names)) == 4, f"four names in the {names[0]} set")
    for i in range(4):
        for j in range(i + 1, 4):
            a, b = lab_like(colours[i]), lab_like(colours[j])
            d = sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5
            check(d > 0.18, f"{names[i]} and {names[j]} are clearly different ({d:.2f})")
check("self?.nextColourRound()" in scene and 'withKey: "dots.nextRound"' in scene, "a new set arrives after each pour")
check("ringTints.append((upper, lower))" in scene, "the rings re-tint with each set")
check("DropDotToken.roundFelts = DropDotToken.felts" in scene, "each visit starts on the board's own felts")

hand = re.search(r"enum DropDotsHand \{.*?\n\}\n", scene, re.S).group(0)
discoveries = re.search(r"enum DropDotsDiscoveries \{.*?\n\}\n", scene, re.S).group(0)
program = """
enum DropDotsScene { enum DropDotToken { static let felts = [0, 0, 0, 0] } }
""" + hand + discoveries + """
var orders = Set<[Int]>()
for _ in 0..<2000 {
    let h = DropDotsHand.deal()
    precondition(h.count == 12, "twelve dots")
    let counts = Dictionary(grouping: h, by: { $0 }).mapValues(\\.count)
    precondition(counts == [0: 3, 1: 3, 2: 3, 3: 3], "three of every colour")
    orders.insert(h)
}
precondition(orders.count > 1500, "the tray order changes from visit to visit")

// grid[c][r]: row 3 is the bottom.
let empty: [[Int?]] = Array(repeating: Array(repeating: nil, count: 4), count: 4)
var g = empty
precondition(DropDotsDiscoveries.homeColumns(g).isEmpty && DropDotsDiscoveries.rainbowRows(g).isEmpty)
g[2][3] = 2; g[2][2] = 2
precondition(DropDotsDiscoveries.homeColumns(g).isEmpty, "two at home is not yet a home column")
g[2][1] = 2
precondition(DropDotsDiscoveries.homeColumns(g) == [2], "three blues in the blue column")
g[2][0] = 0
precondition(DropDotsDiscoveries.homeColumns(g) == [2], "a guest on top doesn't spoil it")
var r = empty
r[0][3] = 1; r[1][3] = 0; r[2][3] = 3; r[3][3] = 2
precondition(DropDotsDiscoveries.rainbowRows(r) == [3], "four different colours across a row")
r[3][3] = 1
precondition(DropDotsDiscoveries.rainbowRows(r).isEmpty, "a repeated colour is not a rainbow")
var sorted = empty
for c in 0..<4 { for row in 1...3 { sorted[c][row] = c } }
precondition(DropDotsDiscoveries.isSorted(sorted, handSize: 12), "every dot home is sorted")
precondition(DropDotsDiscoveries.homeColumns(sorted) == [0, 1, 2, 3], "and every column is home")
precondition(DropDotsDiscoveries.rainbowRows(sorted) == [1, 2, 3], "a sorted board is rainbow rows too")
var almostSorted = sorted
almostSorted[3][1] = nil
precondition(!DropDotsDiscoveries.isSorted(almostSorted, handSize: 12), "a dot still in the tray: not yet")
var mixed = sorted
mixed[0][1] = 1; mixed[1][1] = 0
precondition(!DropDotsDiscoveries.isSorted(mixed, handSize: 12), "a dot in another colour's column: not sorted")
print("deal ok")
"""
with tempfile.TemporaryDirectory() as d:
    d = Path(d)
    (d / "main.swift").write_text(program)
    swiftc = ["xcrun", "swiftc"] if shutil.which("xcrun") else [str(Path(os.environ.get("SWIFT", "swift")).with_name("swiftc"))]
    subprocess.run(swiftc + ["-module-cache-path", str(d / "cache"), str(d / "main.swift"), "-o", str(d / "deal")], check=True)
    out = subprocess.run([str(d / "deal")], check=True, capture_output=True, text=True).stdout
    check("deal ok" in out, "2,000 deals of three per colour; home columns, rainbow rows and sorting detected")

print(f"PASS: Drop Dots colour matching, {passed} checks")
