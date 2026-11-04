#!/usr/bin/env python3
"""Meadow "find the little ones" (founder, October 11).

Compiles the production model from App/Toys/Meadow/MeadowLittleOnes.swift and checks hiding
places, finding, the parade along her path, the hop over flowers, going home, and that a
visit's places survive a rotation. Static checks cover the scene: the little ones never touch
her flower trail, the first-five welcome plays once, recurrence stays bounded, and sounds answer outcomes only.
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
#if canImport(CoreGraphics)
import CoreGraphics
#else
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
check("if model.warmthCount == MeadowLittleOnesModel.count, !finaleDone {" in node and "finaleDone = true" in node,
      "the first-five welcome plays once, not once per replenished batch")
check("littleOnes: littleOnes?.snapshot" in scene and "buildLittleOnes(restoring: snap?.littleOnes)" in scene,
      "a rotation keeps who was found and who is home")
check("private let littleOnesSeed" in scene, "one seed per visit keeps the hiding places across a rebuild")
answer = re.search(r"private func answerLittleOnes.*?\n    }\n", scene, re.S).group(0)
check("events.found > 0" in answer and "events.arrived > 0" in answer and "AudioManager.shared.play" in answer,
      "sounds answer outcomes only: joining, going home, all home")
check(re.search(r"AmbientAnimator\.reduceMotion", node) is not None, "Reduce Motion is respected")
check("for i in model.replenish" in node and "hideAgain(i)" in node,
      "replenishment resets existing baby and leaf nodes")
check("groundDetailLayer.zPosition = 3" in scene and "trailLayer.zPosition = 4" in scene,
      "scenery stays underneath the flower trail")

checks = r'''
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
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
check(m.houseVisible && m.homeCount == 0 && m.places.allSatisfy { $0 == .hidden },
      "home is visible before any little ones are found")
let unopenedVisit = MeadowLittleOnesModel(restoring: m.snapshot)
check(unopenedVisit.houseVisible && unopenedVisit.snapshot == m.snapshot,
      "rotation keeps home visible while all five are still hiding")
let first = m.spots[0]
_ = m.motherMoved(to: CGPoint(x: first.x + 200, y: first.y))
check(m.parade.isEmpty, "passing far away finds no one")
let r1 = m.motherMoved(to: CGPoint(x: first.x + MeadowLittleOnesModel.findRadius - 4, y: first.y))
check(r1.found == [0] && m.parade == [0] && m.houseVisible, "walking near one: it joins, and home remains visible")

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

// Rotation keeps the full path, not just the list of followers.
let rotated = MeadowLittleOnesModel(restoring: line.snapshot)
for k in 0..<5 {
    check(rotated.paradePoint(k, mother: mother) == line.paradePoint(k, mother: mother), "rotation preserves each path target")
}
var tablet = MeadowLittleOnesModel(worldSize: CGSize(width: 3000, height: 3000), homeRadius: 246, avoid: [], seed: 3, paradeSpacing: 78)
for x in stride(from: CGFloat(0), through: 700, by: 7) { _ = tablet.motherMoved(to: CGPoint(x: x, y: -900)) }
check(abs(tablet.paradePoint(0, mother: CGPoint(x: 700, y: -900)).x - tablet.paradePoint(1, mother: CGPoint(x: 700, y: -900)).x - 78) < 0.01, "tablet babies have room between their bodies")
var results: [MeadowFollowerMotion] = []
for fps in [30, 60, 120] {
    var motion = MeadowFollowerMotion(position: .zero, heading: .pi - 0.05)
    for frame in 0..<fps * 2 {
        let before = motion.position
        motion.step(toward: CGPoint(x: 120 + Double(frame) / Double(fps) * 100, y: 0), hop: 1, dt: 1 / Double(fps))
        check(dist(before, motion.position) <= 280 / CGFloat(fps) + 0.001, "joining never teleports")
    }
    results.append(motion)
}
check(dist(results[0].position, results[2].position) < 3, "following looks consistent at 30 and 120 Hz")
check(abs(results[2].lift - 1) < 0.001, "hop eases to its target")
var turn = MeadowFollowerMotion(position: .zero, heading: .pi - 0.05)
turn.step(toward: CGPoint(x: -100, y: -1), hop: 0, dt: 1 / 60)
check(abs(turn.heading - (.pi - 0.05)) < 0.05, "heading crosses the angle boundary by the short turn")

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
check(restored.snapshot == snap && restored.allHome && restored.houseVisible, "a rotation restores everyone where they were, with home visible")
check(dist(MeadowLittleOnesModel.housePosition(homeRadius: 117), .zero) < 117 && dist(MeadowLittleOnesModel.housePosition(homeRadius: 117), .zero) > 40,
      "the house stands in the home garden, beside her starting place")


// Continual exploration reuses five delivered slots, preserving a steady welcome glow.
let viewport = CGRect(x: -240, y: -400, width: 480, height: 800)
var recurring = MeadowLittleOnesModel(restoring: home.snapshot)
for _ in 0..<60 {
    check(recurring.replenish(dt: 1.0 / 20, mother: recurring.house, visibleWorld: viewport).isEmpty,
          "arrivals have a quiet rest before any slot is reused")
}
let pausedSnapshot = recurring.snapshot
var rotatedRecurrence = MeadowLittleOnesModel(restoring: pausedSnapshot)
var recycled: [Int] = []
for _ in 0..<220 {
    let first = recurring.replenish(dt: 1.0 / 20, mother: recurring.house, visibleWorld: viewport)
    let afterRotation = rotatedRecurrence.replenish(dt: 1.0 / 20, mother: rotatedRecurrence.house, visibleWorld: viewport)
    check(first == afterRotation && recurring.snapshot == rotatedRecurrence.snapshot,
          "rotation preserves countdown, random sequence, hiding positions and warmth")
    recycled += first
}
check(Set(recycled) == Set(0..<5), "all five become available again without restarting")
check(recurring.homeCount == 0 && recurring.places.allSatisfy { $0 == .hidden }, "new places are hidden, not auto-found")
check(recurring.warmthCount == 5, "replenishment never cools the house")
for i in 0..<5 {
    check(!viewport.insetBy(dx: -96, dy: -96).contains(recurring.spots[i]), "new hiding place stays outside visible rectangle plus margin")
    check(dist(recurring.spots[i], home.spots[i]) >= 198, "a delivered slot uses a fresh place")
    check(dist(recurring.spots[i], recurring.house) >= 192, "a new little one cannot immediately rejoin the mother")
}

// A fully visible world has nowhere safe to hide: wait, never pop a baby into view.
var visibleEverywhere = MeadowLittleOnesModel(restoring: home.snapshot)
let wholeWorld = CGRect(x: -3000, y: -3000, width: 6000, height: 6000)
for _ in 0..<600 {
    check(visibleEverywhere.replenish(dt: 0.05, mother: .zero, visibleWorld: wholeWorld).isEmpty,
          "no candidate is ever allowed inside the visible world")
}
check(visibleEverywhere.allHome && visibleEverywhere.warmthCount == 5, "blocked placement keeps deliveries and warmth")
for dt: TimeInterval in [0, -1, .infinity, .nan] {
    let before = visibleEverywhere.snapshot
    _ = visibleEverywhere.replenish(dt: dt, mother: .zero, visibleWorld: viewport)
    check(visibleEverywhere.snapshot == before, "invalid or paused delta never consumes the quiet rest")
}

// One hundred further trips retain exactly five slots and a bounded trail; no history grows.
for _ in 0..<100 {
    for i in 0..<5 { _ = recurring.motherMoved(to: recurring.spots[i]) }
    let delivery = recurring.motherMoved(to: recurring.house)
    check(delivery.arrived.count == 5, "each new group can be found and led home")
    for _ in 0..<240 { _ = recurring.replenish(dt: 0.05, mother: recurring.house, visibleWorld: viewport) }
    check(recurring.places.allSatisfy { $0 == .hidden }, "continued play always restores available hiding slots")
    check(recurring.spots.count == 5 && recurring.places.count == 5 && recurring.restRemaining.count == 5,
          "recurrence keeps fixed slot storage")
    check(recurring.parade.isEmpty && recurring.trail.count <= 53, "parade and sampled trail remain bounded")
    check(recurring.warmthCount == 5, "later visits do not escalate the welcome")
}

// Scenery density and material placement are deterministic and sparse across routes.
for seed in UInt64(1)...20 {
    let worldSize = CGSize(width: 2200, height: 2200)
    let avoid = [CGPoint(x: 500, y: 300), CGPoint(x: -500, y: -500)]
    let clusters = MeadowGroundDetails.layout(worldSize: worldSize, homeRadius: 117, avoid: avoid, seed: seed)
    check(clusters == MeadowGroundDetails.layout(worldSize: worldSize, homeRadius: 117, avoid: avoid, seed: seed),
          "rotation redraws the same clusters")
    check(clusters.count >= 60 && clusters.count <= MeadowGroundDetails.maximumClusters,
          "bounded clusters fill the long routes without growing during play")
    for (i, cluster) in clusters.enumerated() {
        check(abs(cluster.position.x) < 1000 && abs(cluster.position.y) < 1000, "detail stays in the play world")
        check(dist(cluster.position, .zero) > 117 * 1.4 + 30, "home remains uncluttered")
        check(avoid.allSatisfy { dist(cluster.position, $0) > 125 }, "detail leaves landmarks clear")
        check((0..<3).contains(cluster.style), "only the three restrained material groups are used")
        check(clusters[(i + 1)...].allSatisfy { dist(cluster.position, $0.position) > 150 },
              "clusters retain clear walking space between them")
    }
}

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
