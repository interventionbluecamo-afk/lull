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
import struct

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
check("refreshDiscoveries(celebrate: true)" in scene and "detectPatterns(celebrate: !sang && !columnCompleted && !boardNowFull" in scene,
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



def production_block(marker):
    start = scene.index(marker)
    opening = scene.index("{", start)
    depth, end = 1, opening + 1
    while depth:
        depth += (scene[end] == "{") - (scene[end] == "}")
        end += 1
    return scene[start:end]


board_art = production_block("private enum BoardArt").replace("private ", "", 1)
layout_metrics = production_block("enum DropDotsLayoutMetrics")
landscape_layout = production_block("struct DropDotsLandscapeLayout")
asset_root = root / "App/Resources/Assets.xcassets"
def png_size(slot):
    return struct.unpack(">II", (asset_root / (slot + ".imageset") / (slot + ".png")).read_bytes()[16:24])
board_size = png_size("dropdots-board")
tray_size = png_size("dropdots-tray")

hand = re.search(r"enum DropDotsHand \{.*?\n\}\n", scene, re.S).group(0)
discoveries = re.search(r"enum DropDotsDiscoveries \{.*?\n\}\n", scene, re.S).group(0)
settling = re.search(r"enum DropDotsSettling \{.*?\n\}\n", scene, re.S).group(0)
program = """
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
enum DropDotsScene { enum DropDotToken { static let felts = [0, 0, 0, 0] } }
""" + "\n".join([hand, discoveries, settling, board_art, layout_metrics, landscape_layout]) + f"\nlet boardTextureSize = CGSize(width: {board_size[0]}, height: {board_size[1]})\nlet trayTextureSize = CGSize(width: {tray_size[0]}, height: {tray_size[1]})\n" + """
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
// Each supporting dot responds after the one above, with less displacement.
// Even at iPad scale the movement remains a tiny rigid compression, not a bounce.
for radius: CGFloat in [18, 30, 52, 80] {
    var priorDelay: TimeInterval = -1
    var priorDisplacement: CGFloat = .greatestFiniteMagnitude
    for depth in 0..<4 {
        let delay = DropDotsSettling.delay(depth: depth)
        let displacement = DropDotsSettling.displacement(radius: radius, depth: depth)
        precondition(delay > priorDelay && displacement < priorDisplacement)
        precondition(displacement > 0 && displacement <= 2.2)
        precondition(delay + 0.075 + 0.42 < 0.8, "stack must finish returning to calm")
        priorDelay = delay; priorDisplacement = displacement
    }
}
// Portrait is the approved design: pin representative existing cell sizes.
precondition(abs(DropDotsLayoutMetrics.portraitCell(play: CGSize(width: 362, height: 697), artBoard: true, tablet: false) - 67.66990291262135) < 0.000001)
precondition(abs(DropDotsLayoutMetrics.portraitCell(play: CGSize(width: 347, height: 555), artBoard: true, tablet: false) - 53.88349514563107) < 0.000001)
precondition(abs(DropDotsLayoutMetrics.portraitCell(play: CGSize(width: 792, height: 1068), artBoard: true, tablet: true) - 103.6893203883495) < 0.000001)
precondition(abs(DropDotsLayoutMetrics.portraitCell(play: CGSize(width: 362, height: 697), artBoard: false, tablet: false) - 73.36842105263158) < 0.000001)

let sourceWidth = BoardArt.sourceWidth(cell: 1)
let naturalHeight = boardTextureSize.height * sourceWidth / boardTextureSize.width
let left = 1.5 + BoardArt.sourceCenter(0) * sourceWidth
let right = 1.5 + (1 - BoardArt.sourceCenter(3)) * sourceWidth
let boardHeight = (BoardArt.channelTopFy + 1 - BoardArt.channelFloorFy) * naturalHeight + 4.6 * DropDotsLayoutMetrics.tokenRadiusPerCell * 1.95
let screens: [(CGSize, CGRect)] = [
    (CGSize(width: 874, height: 402), CGRect(x: 62, y: 21, width: 750, height: 381)),
    (CGSize(width: 852, height: 393), CGRect(x: 59, y: 21, width: 734, height: 372)),
    (CGSize(width: 956, height: 440), CGRect(x: 62, y: 21, width: 832, height: 419)),
    (CGSize(width: 667, height: 375), CGRect(x: 0, y: 0, width: 667, height: 375)),
    (CGSize(width: 568, height: 320), CGRect(x: 0, y: 0, width: 568, height: 320)),
    (CGSize(width: 1180, height: 820), CGRect(x: 0, y: 20, width: 1180, height: 776)),
    (CGSize(width: 1024, height: 768), CGRect(x: 0, y: 20, width: 1024, height: 724)),
    (CGSize(width: 1376, height: 1032), CGRect(x: 0, y: 20, width: 1376, height: 988))
]
var layoutChecks = 0
for (screen, safe) in screens {
    for authored in [true, false] {
        let h = authored ? boardHeight : 5.388
        let l = authored ? left : 2.26, r = authored ? right : 2.26
        let layout = DropDotsLandscapeLayout(safeArea: safe, boardLeftPerCell: l, boardRightPerCell: r,
                                             boardHeightPerCell: h, tablet: screen.height >= 700)
        let c = layout.cell, radius = c * DropDotsLayoutMetrics.tokenRadiusPerCell
        let board = CGRect(x: layout.boardCenterX - l * c, y: layout.boardTopY - h * c,
                           width: (l + r) * c, height: h * c)
        let home = CGRect(x: safe.minX + 12, y: safe.maxY - 64, width: 52, height: 52)
        let epsilon = layout.contentRect.insetBy(dx: -0.001, dy: -0.001)
        precondition(epsilon.contains(board), "full board must fit beside the Home column")
        precondition(!board.intersects(home.insetBy(dx: -16, dy: -8)), "board overlaps shared Home")
        let shadow = CGRect(x: board.midX - board.width * 0.55, y: board.minY - c * 0.05 - board.height * 0.15,
                            width: board.width * 1.1, height: board.height * 0.3)
        precondition(epsilon.contains(shadow), "contact shadow should fit without moving the board offscreen")
        let rackHeight = board.height * (authored ? 0.85 : 0.96)
        let fittedRackWidth = min(c * 1.4, rackHeight * trayTextureSize.height / trayTextureSize.width)
        let spread = rackHeight * 0.82
        var centers: [CGPoint] = []
        for distance: CGFloat in [0.95, 2.25] {
            let rackX = board.minX - c * distance
            let rack = CGRect(x: rackX - c * 0.7, y: board.midY - rackHeight / 2, width: c * 1.4, height: rackHeight)
            precondition(epsilon.contains(rack), "both full six-dot racks must remain visible")
            precondition(!rack.intersects(home.insetBy(dx: -16, dy: -8)), "tray overlaps shared Home")
            for i in 0..<6 {
                let point = CGPoint(x: rackX, y: board.midY - (spread * CGFloat(i) / 5 - spread / 2))
                let dot = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                precondition(rack.contains(dot), "a tray dot falls outside its physical rack")
                precondition(radius * 2 <= fittedRackWidth * 0.72, "dot is wider than the tray's interior")
                centers.append(point)
            }
        }
        precondition(centers.count == 12, "all twelve hand slots remain available")
        for i in centers.indices {
            for j in centers.indices where j > i {
                precondition(hypot(centers[i].x - centers[j].x, centers[i].y - centers[j].y) > radius * 2.05,
                             "individual dots must remain separated and directly pickable")
            }
        }
        if authored, screen.width == 874 {
            precondition(c > 57 && radius * 2 > 36, "reported phone landscape must gain meaningful physical size")
            precondition(board.height > 305 && board.height < safe.height, "board should fill the landscape height")
            print("iPhone 874x402: cell=\(c), radius=\(radius), board=\(board.width)x\(board.height)")
        }
        layoutChecks += 1
    }
}
// Insets can change after the orientation callback: the new frame must change
// without changing the cell-relative registration or the twelve-slot topology.
let early = DropDotsLandscapeLayout(safeArea: CGRect(x: 0, y: 34, width: 874, height: 321),
                                    boardLeftPerCell: left, boardRightPerCell: right, boardHeightPerCell: boardHeight, tablet: false)
let final = DropDotsLandscapeLayout(safeArea: screens[0].1,
                                    boardLeftPerCell: left, boardRightPerCell: right, boardHeightPerCell: boardHeight, tablet: false)
precondition(final.cell > early.cell && final.boardTopY > early.boardTopY, "final landscape insets must refit the toy")
print("landscape geometry ok: \(layoutChecks) layout/asset cases; portrait sizes unchanged")
print("deal ok")
"""
with tempfile.TemporaryDirectory() as d:
    d = Path(d)
    (d / "main.swift").write_text(program)
    swiftc = ["xcrun", "swiftc"] if shutil.which("xcrun") else [str(Path(os.environ.get("SWIFT", "swift")).with_name("swiftc"))]
    subprocess.run(swiftc + ["-module-cache-path", str(d / "cache"), str(d / "main.swift"), "-o", str(d / "deal")], check=True)
    out = subprocess.run([str(d / "deal")], check=True, capture_output=True, text=True).stdout
    print(out.strip())
    check("landscape geometry ok" in out, "landscape board/shadow, both trays and all twelve dots fit safe bounds with unchanged portrait sizing")
    check("deal ok" in out, "2,000 deals of three per colour; home columns, rainbow rows and sorting detected")

check("jiggleColumn" not in scene and "existing stack jiggles" not in scene, "hover and landing no longer add competing stack jiggles")
check('withKey: "landingSettle"' in scene and 'body.position = .zero' in scene, "settling is replaceable and interruption restores its visual pose")
check('grid[col][row] === token' in scene and '$0?.hasLanded == true' in scene, "only real arrivals can settle and discover patterns")
check('token.position = dragTarget' in scene and 'updateDraggedToken()' in scene, "held dots follow touch without frame lag")
check("override func refreshSharedNavigationLayout()" in scene and "layoutSafeArea != landscapeSafeArea" in scene and "rebuild(gridSnap: gridSnap, traySnap: traySnap)" in scene, "final safe-area changes refit landscape while retaining grid and tray snapshots")
print(f"PASS: Drop Dots colour matching, settling and landscape layout, {passed} checks")
