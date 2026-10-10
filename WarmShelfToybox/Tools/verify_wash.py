#!/usr/bin/env python3
"""Compile and exercise the production Foundation-only Little Wash model.

No simulator, scene doubles or copied cleaning implementation. Device feel, final-art
rig placement, frame rate and listening remain the founder's review.
"""
from pathlib import Path
import shutil
import hashlib
import json
import struct
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1] / "App/Toys/Wash/WashModel.swift"
root = source.parents[3]
rig_path = root / "Docs/LittleWash/Vehicle-rigs.json"
manifest_path = root / "Docs/LittleWash/Vehicle-art-source.json"
art_checks = 0
required_kinds = {"fireTruck", "policeCar", "tractor", "schoolBus", "digger", "iceCreamVan"}
assert rig_path.is_file() and manifest_path.is_file(), "six measured production rigs required"
rigs = json.loads(rig_path.read_text())
manifest = json.loads(manifest_path.read_text())
assert len(manifest["vehicles"]) == 6, "all six delivered vehicles registered"
assert {entry["kind"] for entry in manifest["vehicles"]} == required_kinds, "complete source manifest cast"
assert set(rigs) == required_kinds, "complete prepared rig cast"
assert manifest["canvas"] == [1600, 1000] and manifest["bodyWidth"] == 1280, "canonical body canvas"
assert manifest["wheelBottom"] == 880, "canonical wheel ground line"
art_checks += 5
for entry in manifest["vehicles"]:
    rig = rigs[entry["kind"]]
    assert rig["isMeasured"] is True, "every production rig measured from native art"
    assert rig["canvasSize"] == [1600, 1000], "rig uses canonical canvas"
    assert rig["bodyPlacement"][0] == 160 and rig["bodyPlacement"][2] == 1280, "equal body widths"
    assert rig["groundLine"] == 0.88, "rig uses canonical ground line"
    art_checks += 4
    imageset = root / "App/Resources/Assets.xcassets" / (entry["imageset"] + ".imageset")
    contents = json.loads((imageset / "Contents.json").read_text())
    filename = next(item["filename"] for item in contents["images"] if "filename" in item)
    assert filename == entry["imageset"] + ".png", "imageset points at wrong vehicle"
    art_checks += 1
    png = (imageset / filename).read_bytes()
    assert png[:8] == b"\x89PNG\r\n\x1a\n" and png[12:16] == b"IHDR", "PNG header"
    art_checks += 1
    assert struct.unpack(">II", png[16:24]) == (1600, 1000), "common canonical canvas"
    art_checks += 1
    assert png[25] == 6, "native RGBA output retains alpha channel"
    art_checks += 1
    original = root / manifest["sourceDirectory"] / entry["sourceFile"]
    original_png = original.read_bytes()
    assert hashlib.sha256(original_png).hexdigest() == rig["sourceSHA256"], "preserved original matches measured art"
    assert original_png[25] == 6, "preserved native source is RGBA"
    art_checks += 2
compiler = shutil.which("swiftc")
if compiler is None:
    raise SystemExit("Swift compiler required (install/select Xcode command-line tools).")

fixture = r'''
import Foundation
var checks = 0
func check(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
    checks += 1
}
func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.0000001 }
let middle = WashPoint(x: 0.5, y: 0.5)
let one = [WashMudPatch(center: middle, radius: 0.05)]

check(near(WashModel.falloff(distance: 0, radius: 0.2), 1), "brush centre")
check(WashModel.falloff(distance: 0.2, radius: 0.2) == 0, "edge is zero")
check(WashModel.falloff(distance: 0.21, radius: 0.2) == 0, "outside is zero")
check(WashModel.falloff(distance: 0.1, radius: 0.2) > 0, "smooth middle")
check(WashModel.falloff(distance: 0.1, radius: 0.2) > WashModel.falloff(distance: 0.15, radius: 0.2), "falloff decreases")
for invalid in [0.0, -1, Double.nan, Double.infinity] {
    check(WashModel.falloff(distance: 0.1, radius: invalid) == 0, "invalid radius")
}

var grid: [WashMudPatch] = []
for row in 0..<6 {
    for column in 0..<8 {
        grid.append(WashMudPatch(center: WashPoint(x: 0.15 + Double(column) * 0.1,
                                                 y: 0.2 + Double(row) * 0.1), radius: 0.04))
    }
}
var sponge = WashModel(patches: grid)
check(!sponge.isComplete, "dirty start")
check(sponge.cleanFraction == 0, "initial coverage")
var passes = 0
while sponge.cleanFraction < WashModel.cleanThreshold && passes < 20 {
    for patch in grid {
        sponge.applyStroke(at: patch.center, radius: 0.12, strength: 0.18, tool: .sponge)
    }
    passes += 1
}
check(passes < 20, "sponge alone cleans in bounded strokes")
check(sponge.cleanFraction >= 0.93, "93 percent clean")
check(!sponge.isComplete, "foam delays completion")
sponge.advanceTime(by: 7)
check(sponge.isComplete, "sponge alone completes after evaporation")
check(sponge.patches.count == grid.count, "denominator never drops patches")

func strokesToClean(_ tool: WashTool) -> Int {
    var model = WashModel(patches: one)
    var count = 0
    while model.cleanFraction < 0.93 && count < 50 {
        model.applyStroke(at: middle, radius: 0.1, strength: 0.18, tool: tool)
        count += 1
    }
    check(count < 50, "every tool makes finite progress")
    model.advanceTime(by: 7)
    check(model.isComplete, "every tool can finish")
    return count
}
let spongeCount = strokesToClean(.sponge)
let hoseCount = strokesToClean(.hose)
let towelCount = strokesToClean(.towel)
check(hoseCount < spongeCount, "hose faster than sponge")
check(towelCount > spongeCount, "towel cleans more slowly")

// All tool orders work: no hidden rinse-before-dry prerequisite.
let orders: [[WashTool]] = [
    [.sponge, .hose, .towel], [.sponge, .towel, .hose],
    [.hose, .sponge, .towel], [.hose, .towel, .sponge],
    [.towel, .sponge, .hose], [.towel, .hose, .sponge]
]
for order in orders {
    var model = WashModel(patches: one)
    for tool in order {
        for _ in 0..<4 { model.applyStroke(at: middle, radius: 0.1, strength: 0.18, tool: tool) }
    }
    model.advanceTime(by: 7)
    check(model.isComplete, "any tool order")
}

var foamy = WashModel(patches: [WashMudPatch(center: middle, radius: 0.05, dirt: 0, foam: 1, wetness: 1)])
foamy.advanceTime(by: 6)
check(!foamy.isComplete, "full foam remains at six seconds")
check(near(foamy.foamFraction, 1.0 / 7), "linear seven-second foam")
foamy.advanceTime(by: 1)
check(foamy.isComplete, "full foam evaporates by seven seconds")
check(near(foamy.foamFraction, 0), "no negative foam")
check(foamy.patches[0].wetness == 0, "water evaporates")
var dirtyNoFoam = WashModel(patches: [WashMudPatch(center: middle, radius: 0.05, dirt: 0.08)])
check(!dirtyNoFoam.isComplete, "92 percent insufficient")
dirtyNoFoam.applyStroke(at: middle, radius: 0.1, strength: 0.02, tool: .hose)
check(dirtyNoFoam.isComplete, "94 percent with low foam")
check(!WashModel(patches: []).isComplete, "empty model cannot finish")

var rinse = WashModel(patches: [WashMudPatch(center: middle, radius: 0.05, dirt: 0, foam: 1, wetness: 1)])
rinse.applyStroke(at: middle, radius: 0.1, strength: 0.3, tool: .hose)
check(rinse.foamFraction < 0.2, "hose rinses foam immediately")
rinse.applyStroke(at: middle, radius: 0.1, strength: 0.3, tool: .towel)
check(rinse.foamFraction == 0, "towel buffs foam")
check(rinse.patches[0].wetness < 0.3, "towel removes water")

var horizontal = WashModel(patches: one)
horizontal.applyStroke(at: WashPoint(x: 0.58, y: 0.5), radius: 0.1)
check(horizontal.cleanFraction == 0, "aspect-correct brush horizontal extent")
var vertical = WashModel(patches: one)
vertical.applyStroke(at: WashPoint(x: 0.5, y: 0.58), radius: 0.1)
check(vertical.cleanFraction > 0, "aspect-correct brush vertical extent")
var untouched = WashModel(patches: one)
let before = untouched.patches
untouched.applyStroke(at: WashPoint(x: 1.1, y: 1.1), radius: 0.1)
check(untouched.patches == before, "off-vehicle stroke does not clean")
for invalid in [0.0, -1, Double.nan, Double.infinity] {
    untouched.applyStroke(at: middle, radius: 0.1, strength: invalid)
    untouched.advanceTime(by: invalid)
    check(untouched.patches == before, "invalid strength/time is inert")
}
for tool in WashTool.allCases {
    var model = WashModel(patches: one)
    for _ in 0..<40 {
        model.applyStroke(at: middle, radius: 0.1, strength: 4, tool: tool)
        model.advanceTime(by: 0.02)
    }
    for p in model.patches {
        check((0...1).contains(p.dirt), "bounded dirt")
        check((0...1).contains(p.foam), "bounded foam")
        check((0...1).contains(p.wetness), "bounded wetness")
    }
}
// Frame slicing must not affect idle evaporation.
var longStep = WashModel(patches: [WashMudPatch(center: middle, radius: 0.05, dirt: 0, foam: 1)])
var shortSteps = longStep
longStep.advanceTime(by: 2)
for _ in 0..<120 { shortSteps.advanceTime(by: 1.0 / 60) }
check(near(longStep.foamFraction, shortSteps.foamFraction), "frame-independent decay")

for count in [1, 3, 4, 17, 48, 60] {
    var accessible = WashModel(patches: Array(grid.prefix(min(count, grid.count))))
    for _ in 0..<4 { accessible.cleanQuarter() }
    check(accessible.isComplete, "four accessible activations finish")
}

// Every bag exposes the complete cast and boundaries never repeat, over 1,200 draws.
for seed: UInt64 in [0, 1, 2, 42, 987654321] {
    var deck = WashCastDeck(seed: seed)
    var twin = WashCastDeck(seed: seed)
    var previous: WashVehicleKind?
    for _ in 0..<200 {
        var bag: Set<WashVehicleKind> = []
        for _ in 0..<6 {
            let vehicle = deck.next()
            check(vehicle != previous, "no repeat even at bag boundary")
            check(vehicle == twin.next(), "seed reproducibility")
            bag.insert(vehicle)
            previous = vehicle
        }
        check(bag.count == 6, "six draws show all six vehicles")
    }
}

var registeredRigs: [String: Any] = [:]
if CommandLine.arguments.count > 1,
   let data = try? Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])),
   let records = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    registeredRigs = records
}
for kind in WashVehicleKind.allCases {
    let rig = WashVehicleRig.forVehicle(kind)
    check(kind.imageName.hasPrefix("wash-"), "imageset convention")
    check(rig.isMeasured, "all six production rigs are measured")
    check((0...1).contains(rig.faceCenter.x) && (0...1).contains(rig.faceCenter.y), "face fractions")
    check(rig.faceRadius > 0 && rig.faceRadius < 0.2, "face radius")
    check(rig.faceCenter.y - rig.faceRadius > 0 && rig.faceCenter.y + rig.faceRadius < 1, "face in canvas")
    check(rig.wheels.count == 2, "two-wheel rig")
    if rig.isMeasured {
        guard let measured = registeredRigs[kind.rawValue] as? [String: Any],
              let face = measured["faceCenter"] as? [Double],
              let radius = measured["faceRadius"] as? Double,
              let wheels = measured["wheels"] as? [[String: Any]] else {
            fatalError("Measured rig has no committed measurement record")
        }
        check(near(face[0], rig.faceCenter.x) && near(face[1], rig.faceCenter.y), "production face matches prepared art")
        check(near(radius, rig.faceRadius), "production face radius matches art")
        check(wheels.count == rig.wheels.count, "production wheel count matches art")
        for (index, record) in wheels.enumerated() {
            let centre = record["center"] as! [Double]
            let radius = record["radius"] as! Double
            check(near(centre[0], rig.wheels[index].center.x) && near(centre[1], rig.wheels[index].center.y), "production wheel centre matches art")
            check(near(radius, rig.wheels[index].radius), "production wheel radius matches art")
        }
    }
    for wheel in rig.wheels {
        check(wheel.radius > 0 && wheel.radius < 0.25, "wheel radius")
        // Radius is fraction of height: convert horizontal extent using 1600 / 1000.
        let rx = wheel.radius / 1.6
        check(wheel.center.x - rx >= 0 && wheel.center.x + rx <= 1, "wheel horizontal extent")
        check(wheel.center.y - wheel.radius >= 0 && wheel.center.y + wheel.radius <= 1, "wheel vertical extent")
        if rig.isMeasured {
            check(near(wheel.center.y + wheel.radius, 0.88), "shared measured ground line")
        }
    }
}
print("Little Wash: \(checks) production-model checks passed; sponge-only completion in \(passes) full-vehicle passes. Device play and listening review remain with the founder.")
'''

with tempfile.TemporaryDirectory(prefix="lull-verify-wash-") as directory:
    directory = Path(directory)
    main = directory / "main.swift"
    main.write_text(fixture)
    executable = directory / "verify-wash"
    subprocess.run([compiler, "-module-cache-path", str(directory / "module-cache"),
                    str(source), str(main), "-o", str(executable)], check=True)
    subprocess.run([str(executable), str(rig_path)], check=True)
    if art_checks:
        print(f"Little Wash: {art_checks} registered-asset/provenance checks passed.")
