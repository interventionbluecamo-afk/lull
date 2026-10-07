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
    block("App/Toys/Meadow/MeadowScene.swift", "enum MeadowDandelionGeometry"),
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
// Shuffling changes loose positions only; the actual socket fit helper remains unambiguous.
let centers = [CGPoint(x: 100, y: 300), CGPoint(x: 200, y: 300), CGPoint(x: 100, y: 200), CGPoint(x: 200, y: 200)]
let sizes = Array(repeating: CGSize(width: 70, height: 70), count: 4)
for index in centers.indices {
    check(SleepyBoxFitGeometry.nearestOpening(at: centers[index], centers: centers, sizes: sizes) == index, "The socket at a shape remains the fit target")
    check(SleepyBoxFitGeometry.captureRadius(at: index, centers: centers, sizes: sizes) < 50, "Neighboring capture regions stay separate")
}
check(SleepyBoxFitGeometry.nearestOpening(at: CGPoint(x: 150, y: 250), centers: centers, sizes: sizes) == nil, "A gap between sockets cannot accept a shape")
print("PASS: \(checks) handle-departure, reachable-puff, unique-round and socket-fit checks using production helpers")
'''

with tempfile.TemporaryDirectory(prefix="lull-world-verification-") as temporary:
    directory = Path(temporary)
    source = directory / "WorldInteractions.swift"
    source.write_text("import Foundation\nimport CoreGraphics\n" + production + checks)
    toolchain = ["xcrun", "swift"] if shutil.which("xcrun") else [os.environ.get("SWIFT", "swift")]
    subprocess.run(toolchain + ["-module-cache-path", str(directory / "ModuleCache"), str(source)], check=True)
