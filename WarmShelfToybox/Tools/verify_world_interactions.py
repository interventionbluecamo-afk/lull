#!/usr/bin/env python3
"""Exercise extracted production handle, dandelion, and round-layout helpers.

Uses a Swift toolchain; gestures, rendering and rotation restoration still need device play.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]


def block(relative, needle):
    source = (root / relative).read_text()
    start = source.index(needle)
    opening = source.index("{", start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


production = "\n".join([
    block("App/Toys/DropDots/DropDotsScene.swift", "enum DropDotsHandleGesture"),
    "enum DropDotsScene { enum DropDotToken { static let felts = [0, 1, 2, 3] } }",
    block("App/Toys/DropDots/DropDotsScene.swift", "enum DropDotsHand"),
    block("App/Toys/DropDots/DropDotsScene.swift", "private enum BoardArt").replace("private ", "", 1),
    block("App/Toys/Meadow/MeadowScene.swift", "enum MeadowDandelionGeometry"),
    block("App/Toys/Meadow/MeadowScene.swift", "enum MeadowWorldGeometry"),
    block("App/Toys/Meadow/MeadowScene.swift", "struct MeadowFlowerTrail"),
    block("App/Toys/SleepyDropBox/SleepyDropBoxScene.swift", "enum SleepyBoxRoundLayout"),
    block("App/Toys/SleepyDropBox/SleepyDropBoxScene.swift", "enum SleepyBoxFitGeometry"),
])

checks = r'''
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
}
// Handle departure wins over the pull threshold, including a diagonal downward exit.
for cell: CGFloat in [24, 60, 120] {
    let handle = CGRect(x: 200, y: 140, width: cell * 2, height: cell * 0.6)
    let startY = handle.midY
    let corridor = handle.insetBy(dx: -cell * 0.4, dy: -cell * 0.4)
    let threshold = max(12, cell * 0.2)
    func decide(_ x: CGFloat, _ y: CGFloat) -> DropDotsHandleGesture.Decision {
        DropDotsHandleGesture.decision(at: CGPoint(x: x, y: y), startY: startY, handle: handle, cell: cell)
    }
    check(decide(handle.midX, startY) == .hold, "A stationary palm cannot pour")
    check(decide(handle.midX, startY - threshold) == .hold, "Subthreshold movement cannot pour")
    check(decide(handle.midX, startY - threshold - 1) == .pour, "A deliberate downward pull pours")
    check(decide(corridor.minX - 1, startY) == .cancel, "Leaving left cancels")
    check(decide(corridor.maxX + 1, startY) == .cancel, "Leaving right cancels")
    check(decide(corridor.maxX + 1, startY - threshold - 30) == .cancel, "Sideways departure outranks a downward pull")
    check(decide(handle.midX, corridor.maxY + 1) == .cancel, "Leaving above cancels")
}
// Four-column composition: every ring, throat and resting channel has one live centre.
check(BoardArt.sourceColumns.count == 4, "Exactly four painted channels")
check(Set(BoardArt.sourceColumns).count == 4, "No duplicated channel strips")
for cell: CGFloat in [24, 60, 88, 132] {
    let width = BoardArt.sourceWidth(cell: cell)
    for column in 0..<3 {
        check(BoardArt.stripSpan(column, cell: cell).upperBound >= BoardArt.stripSpan(column + 1, cell: cell).lowerBound, "Composed wood has no filtering seam at any supported size")
    }
    for column in 0..<4 {
        let source = BoardArt.sourceCenter(column)
        let bounds = BoardArt.sourceBounds(column)
        check(bounds.contains(source), "Painted mouth is inside its strip")
        check((source - bounds.lowerBound) * width > cell * 0.45, "Left channel wall clears the dot")
        check((bounds.upperBound - source) * width > cell * 0.45, "Right channel wall clears the dot")
        let origin = CGFloat(column) * cell - source * width
        check(abs(origin + source * width - CGFloat(column) * cell) < 0.001, "Painted mouth and channel sit on the live dot centre")
    }
}
// Four coloured rings share four dot colours. The complete visible hand includes one
// of each plus two more of one colour, so a three-in-a-row pattern is always possible.
for _ in 0..<1000 {
    let hand = DropDotsHand.deal()
    check(hand.count == BoardArt.sourceColumns.count + 2, "Six visible dots, no hidden reserve")
    check(Set(hand) == Set(0..<BoardArt.sourceColumns.count), "Every dot colour has a matching ring")
    let counts = Dictionary(grouping: hand, by: { $0 }).mapValues(\.count)
    check(counts.values.sorted() == [1, 1, 1, 3], "Exactly one available colour can make three in a row")
}
// Offering or restoring a puff never puts its body beyond the felt world's edge.
for canvas in [CGSize(width: 375, height: 812), CGSize(width: 812, height: 375), CGSize(width: 820, height: 1180)] {
    let side = max(canvas.width, canvas.height) * 2.6
    let world = CGSize(width: side, height: side)
    for preferred in [CGPoint.zero, CGPoint(x: side, y: side), CGPoint(x: -side, y: -side), CGPoint(x: side / 2 + 140, y: 90)] {
        let point = MeadowDandelionGeometry.position(preferred: preferred, worldSize: world)
        check(abs(point.x) <= side / 2 - 64, "Puff remains horizontally reachable")
        check(abs(point.y) <= side / 2 - 64, "Puff remains vertically reachable")
        check(MeadowDandelionGeometry.position(preferred: point, worldSize: world) == point, "Restoring a legal puff does not move it")
    }
}
// Soft bounds keep the same world coordinates and cover the entire viewport in both orientations.
for canvas in [CGSize(width: 375, height: 667), CGSize(width: 667, height: 375),
               CGSize(width: 393, height: 852), CGSize(width: 852, height: 393),
               CGSize(width: 768, height: 1024), CGSize(width: 1024, height: 768)] {
    let side = max(canvas.width, canvas.height) * 2.6
    let world = CGSize(width: side, height: side)
    let ground = MeadowWorldGeometry.groundSize(worldSize: world)
    check(ground.width > world.width && ground.height > world.height, "Felt bleeds past every world edge")
    check(MeadowWorldGeometry.leadTarget(.zero, worldSize: world) == .zero, "The home garden does not move")
    for value: CGFloat in [-100000, -side, -side * 0.4, 0, side * 0.4, side, 100000] {
        let preferred = CGPoint(x: value, y: -value)
        let target = MeadowWorldGeometry.leadTarget(preferred, worldSize: world)
        check(abs(target.x) <= side / 2 - 50 && abs(target.y) <= side / 2 - 50, "A lead stays inside invisible bounds")
        check(MeadowWorldGeometry.position(target, worldSize: world) == target, "A softened target needs no hard stop")
        let offset = MeadowWorldGeometry.cameraOffset(CGPoint(x: canvas.width / 2 - target.x, y: canvas.height / 2 - target.y), worldSize: world, canvas: canvas)
        check(offset.x - ground.width / 2 < 0 && offset.x + ground.width / 2 > canvas.width, "Ground covers both horizontal screen edges")
        check(offset.y - ground.height / 2 < 0 && offset.y + ground.height / 2 > canvas.height, "Ground covers both vertical screen edges")
    }
    let near = MeadowWorldGeometry.leadTarget(CGPoint(x: side / 2 - 200, y: 0), worldSize: world)
    let farther = MeadowWorldGeometry.leadTarget(CGPoint(x: side / 2 - 100, y: 0), worldSize: world)
    check(farther.x > near.x && farther.x - near.x < 100, "The outer lead eases smoothly instead of hitting an edge")
}
// Long walks recycle a fixed pool; stationary samples do not plant or allocate flowers.
var flowerTrail = MeadowFlowerTrail()
check(flowerTrail.stamp(behind: .zero, heading: 0) == 0, "The first step plants behind the ladybug")
check(flowerTrail.positions[0].x < 0, "A new flower sits behind the ladybug")
check(flowerTrail.stamp(behind: CGPoint(x: 25, y: 0), heading: 0) == nil, "Short or stationary steps do not pile up flowers")
for index in 1...10000 {
    let slot = flowerTrail.stamp(behind: CGPoint(x: CGFloat(index) * MeadowFlowerTrail.spacing, y: 0), heading: 0)
    check(slot == index % MeadowFlowerTrail.capacity, "The flower slot recycles in order")
    check(flowerTrail.positions.count <= MeadowFlowerTrail.capacity, "Long walks keep the fixed pool bound")
}
let savedTrail = flowerTrail
var restoredTrail = savedTrail
check(restoredTrail.positions == savedTrail.positions && restoredTrail.nextSlot == savedTrail.nextSlot, "A garden snapshot keeps every live flower and next slot")
check(restoredTrail.stamp(behind: savedTrail.lastWalkPoint!, heading: 0) == nil, "Rotation cannot double-plant the last step")
restoredTrail = MeadowFlowerTrail()
check(restoredTrail.positions.isEmpty && restoredTrail.nextSlot == 0 && restoredTrail.lastWalkPoint == nil, "Frost resets every pooled slot and spacing anchor")
// Complete rounds always retain four unique slots and visibly change the last order.
var order = [0, 1, 2, 3]
for _ in 0..<100 {
    let next = SleepyBoxRoundLayout.shuffledSlots(order)
    check(next.sorted() == [0, 1, 2, 3], "Every shape has exactly one slot")
    check(next != order, "A completed round changes the order")
    order = next
}
check(SleepyBoxRoundLayout.shuffledSlots([]).isEmpty, "An empty layout is safe")
check(SleepyBoxRoundLayout.shuffledSlots([0]) == [0], "A single slot is stable")
for round in 0...12 {
    check(SleepyBoxRoundLayout.shouldExchange(after: round) == (round > 0), "Every completed round exchanges the box; round zero stays stable")
}
// Reordered sockets retain the same shape fit targets and separated capture regions.
let centers = [CGPoint(x: 100, y: 300), CGPoint(x: 200, y: 300), CGPoint(x: 100, y: 200), CGPoint(x: 200, y: 200)]
let sizes = Array(repeating: CGSize(width: 70, height: 70), count: 4)
for index in centers.indices {
    check(SleepyBoxFitGeometry.nearestOpening(at: centers[index], centers: centers, sizes: sizes) == index, "The socket at a shape remains the fit target")
    check(SleepyBoxFitGeometry.captureRadius(at: index, centers: centers, sizes: sizes) < 50, "Neighboring capture regions stay separate")
}
check(SleepyBoxFitGeometry.nearestOpening(at: CGPoint(x: 150, y: 250), centers: centers, sizes: sizes) == nil, "A gap between sockets cannot accept a shape")
print("PASS: \(checks) handle-departure, reachable-puff, meadow bounds/pool, unique-round and socket-fit checks using production helpers")
'''

with tempfile.TemporaryDirectory(prefix="lull-world-verification-") as temporary:
    directory = Path(temporary)
    source = directory / "WorldInteractions.swift"
    source.write_text("import Foundation\nimport CoreGraphics\n" + production + checks)
    toolchain = ["xcrun", "swift"] if shutil.which("xcrun") else [os.environ.get("SWIFT", "swift")]
    subprocess.run(toolchain + ["-module-cache-path", str(directory / "ModuleCache"), str(source)], check=True)
