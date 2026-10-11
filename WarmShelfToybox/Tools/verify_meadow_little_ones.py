#!/usr/bin/env python3
"""Meadow "find the little ones" (founder, October 11).

Compiles the production model from App/Toys/Meadow/MeadowLittleOnes.swift and checks hiding
places, finding, the parade along her path, the hop over flowers, going home, and that a
visit's places survive a rotation. Static checks cover the scene: the little ones never touch
her flower trail, the finale plays once, and sounds answer outcomes only.
"""
from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "App/Toys/Meadow/MeadowLittleOnes.swift").read_text()
scene = (root / "App/Toys/Meadow/MeadowScene.swift").read_text()
# CGVector is CoreGraphics-only; on Linux, a minimal stand-in with the members the model uses.
VECTOR = """
#if !canImport(CoreGraphics)
struct CGVector: Equatable { var dx: CGFloat; var dy: CGFloat; static let zero = CGVector(dx: 0, dy: 0) }
#endif
"""
model = "import Foundation\n" + VECTOR + source.split("// MARK: - The little ones on screen", 1)[0].replace("import SpriteKit\n", "")
passed = 0


def check(ok, what):
    global passed
    if not ok:
        raise SystemExit("FAIL: " + what)
    passed += 1


node = source.split("// MARK: - The little ones on screen", 1)[1]
check("flowerTrail" not in source and "stamp(" not in source, "the little ones never stamp or change her flowers")
check("if model.allHome, !finaleDone {" in node and "finaleDone = true" in node, "the all-home finale plays once")
check("littleOnes: littleOnes?.model.snapshot" in scene and "buildLittleOnes(restoring: snap?.littleOnes)" in scene,
      "a rotation keeps who was found and who is home")
check("private let littleOnesSeed" in scene, "one seed per visit keeps the hiding places across a rebuild")
answer = re.search(r"private func answerLittleOnes.*?\n    }\n", scene, re.S).group(0)
check("events.found > 0" in answer and "events.arrived > 0" in answer and "AudioManager.shared.play" in answer,
      "sounds answer outcomes only: joining, going home, all home")
check(re.search(r"AmbientAnimator\.reduceMotion", node) is not None, "Reduce Motion is respected")

checks = r'''
import Foundation
var passed = 0
func check(_ ok: Bool, _ what: String) {
    if !ok { print("FAIL: " + what); exit(1) }
    passed += 1
}
func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

// A phone (390 x 844) and an iPad (820 x 1180): the world is 2.6 x the long side, square.
for canvas in [CGSize(width: 390, height: 844), CGSize(width: 820, height: 1180)] {
    let side = max(canvas.width, canvas.height) * 2.6
    let world = CGSize(width: side, height: side)
    let homeRadius = min(canvas.width, canvas.height) * 0.30
    let landmarks = [(-0.27, 0.21), (0.26, -0.23), (0.04, 0.34), (-0.23, -0.30), (0.31, 0.13),
                     (-0.33, -0.07), (0.10, -0.38), (-0.10, 0.13), (0.14, -0.10)]
        .map { CGPoint(x: side * $0.0, y: side * $0.1) }
    let watchMe = min(canvas.width, canvas.height) * 0.42
    for seed in UInt64(1)...200 {
        let spots = MeadowLittleOnesModel.hidingSpots(worldSize: world, homeRadius: homeRadius, avoid: landmarks, seed: seed)
        check(spots.count == 5, "five little ones")
        for (i, p) in spots.enumerated() {
            check(abs(p.x) <= side / 2 - 50 && abs(p.y) <= side / 2 - 50, "every hiding place is reachable")
            check(dist(p, .zero) > watchMe + MeadowLittleOnesModel.findRadius, "her first-visit wander doesn't find one by itself")
            check(dist(p, .zero) > homeRadius * 1.5, "none hide in the home garden")
            check(landmarks.allSatisfy { dist($0, p) >= 110 }, "none hide under a landmark")
            for q in spots[(i + 1)...] { check(dist(p, q) >= side / 2 * 0.15, "spread out across the meadow") }
        }
        let again = MeadowLittleOnesModel.hidingSpots(worldSize: world, homeRadius: homeRadius, avoid: landmarks, seed: seed)
        check(again == spots, "the same visit hides them in the same places after a rotation")
    }
    let a = MeadowLittleOnesModel.hidingSpots(worldSize: world, homeRadius: homeRadius, avoid: landmarks, seed: 7)
    let b = MeadowLittleOnesModel.hidingSpots(worldSize: world, homeRadius: homeRadius, avoid: landmarks, seed: 8)
    check(a != b, "a new visit hides them somewhere new")
}

// Finding, following, going home.
var m = MeadowLittleOnesModel(worldSize: CGSize(width: 2200, height: 2200), homeRadius: 117, avoid: [], seed: 42)
check(!m.houseVisible && m.homeCount == 0, "the house waits until the first little one is found")
let first = m.spots[0]
_ = m.motherMoved(to: CGPoint(x: first.x + 200, y: first.y))
check(m.parade.isEmpty, "passing far away finds no one")
let r1 = m.motherMoved(to: CGPoint(x: first.x + MeadowLittleOnesModel.findRadius - 4, y: first.y))
check(r1.found == [0] && m.parade == [0] && m.houseVisible, "walking near one: it joins, and the house appears")

// Walk a straight line: follower k sits (k+1) gaps behind her along her path.
var line = MeadowLittleOnesModel(worldSize: CGSize(width: 2200, height: 2200), homeRadius: 117, avoid: [], seed: 3)
for x in stride(from: CGFloat(0), through: 300, by: 2) { _ = line.motherMoved(to: CGPoint(x: x, y: -900)) }
let mother = CGPoint(x: 300, y: -900)
for k in 0..<4 {
    let p = line.paradePoint(k, mother: mother)
    check(abs(p.x - (300 - CGFloat(k + 1) * MeadowLittleOnesModel.paradeGap)) < 4.5 && abs(p.y + 900) < 0.01,
          "the parade follows in her steps, evenly spaced")
}
var short = MeadowLittleOnesModel(worldSize: CGSize(width: 2200, height: 2200), homeRadius: 117, avoid: [], seed: 3)
_ = short.motherMoved(to: CGPoint(x: 0, y: 0)); _ = short.motherMoved(to: CGPoint(x: 10, y: 0))
check(dist(short.paradePoint(3, mother: CGPoint(x: 10, y: 0)), CGPoint(x: 0, y: 0)) < 0.01, "a short path bunches them at its start")

// Hopping between flowers.
let flowers = [CGPoint(x: 100, y: 5), CGPoint(x: 126, y: -5)]
let over = MeadowLittleOnesModel.flowerHop(at: CGPoint(x: 100, y: 0), flowers: flowers)
check(over.lift > 0.6 && over.nudge.dy < 0, "over a flower: up, and a step away from it")
let between = MeadowLittleOnesModel.flowerHop(at: CGPoint(x: 113, y: 0), flowers: flowers)
check(between.lift < over.lift, "between flowers: lower")
let clear = MeadowLittleOnesModel.flowerHop(at: CGPoint(x: 300, y: 0), flowers: flowers)
check(clear.lift == 0 && clear.nudge == .zero, "no flowers near: walking on the ground")
let dead = MeadowLittleOnesModel.flowerHop(at: CGPoint(x: 100, y: 5), flowers: flowers)
check(dead.lift == 1 && dead.nudge.dy > 0, "exactly on a flower still steps off it")

// Going home, in parade order; all five home once.
var home = MeadowLittleOnesModel(worldSize: CGSize(width: 2200, height: 2200), homeRadius: 117, avoid: [], seed: 9)
for i in 0..<3 { _ = home.motherMoved(to: home.spots[i]) }
check(home.parade.count == 3, "three following")
let arrive = home.motherMoved(to: home.house)
check(arrive.arrived.count == 3 && home.homeCount == 3 && home.parade.isEmpty, "at the house, the parade goes in")
let empty = home.motherMoved(to: home.house)
check(empty.arrived.isEmpty, "visiting the house alone changes nothing")
for i in 3..<5 { _ = home.motherMoved(to: home.spots[i]) }
_ = home.motherMoved(to: home.house)
check(home.allHome && home.homeCount == 5, "all five home")
let snap = home.snapshot
let restored = MeadowLittleOnesModel(restoring: snap)
check(restored.snapshot == snap && restored.allHome, "a rotation restores everyone where they were")
check(dist(MeadowLittleOnesModel.housePosition(homeRadius: 117), .zero) < 117 && dist(MeadowLittleOnesModel.housePosition(homeRadius: 117), .zero) > 40,
      "the house stands in the home garden, beside her starting place")

print("PASS: \(passed) model checks")
'''

swiftc = os.environ.get("SWIFTC") or shutil.which("swiftc") or str(Path(os.environ.get("SWIFT", "swift")).with_name("swiftc"))
with tempfile.TemporaryDirectory(prefix="lull-meadow-little-") as directory:
    d = Path(directory)
    (d / "Model.swift").write_text(model)
    (d / "main.swift").write_text(checks)
    command = (["xcrun", "swiftc"] if shutil.which("xcrun") else [swiftc]) + [
        "-module-cache-path", str(d / "cache"), str(d / "Model.swift"), str(d / "main.swift"), "-o", str(d / "check")]
    subprocess.run(command, check=True)
    out = subprocess.run([str(d / "check")], capture_output=True, text=True)
    print(out.stdout.strip())
    if out.returncode != 0:
        raise SystemExit(1)
print(f"PASS: Meadow little ones, {passed} scene checks")
