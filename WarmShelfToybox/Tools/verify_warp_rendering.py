#!/usr/bin/env python3
"""Render production warp geometry with native macOS SpriteKit and no extra subdivision.

Requires macOS/Xcode and a graphical session. This is an offscreen renderer smoke
check, not a reproduction of the reported iOS 26.6.1 add_subdivs crash or device QA.
It extracts the shipped formulas, validates grid buffers, renders representative
poses and resets to an unwarped sprite. It does not build or modify the app.
"""
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
if sys.platform != "darwin" or not shutil.which("xcrun"):
    raise SystemExit("Native warp rendering requires macOS and xcrun.")
feed = (root / "App/Toys/FeedThePeople/CharacterNode.swift").read_text()
window = (root / "App/Toys/GlowWindow/GlowWindowScene.swift").read_text()
mix = (root / "App/Toys/MixUp/MixUpPart.swift").read_text()
wash = (root / "App/Toys/Wash/WashScene.swift").read_text()


def block(source, marker):
    start = source.index(marker)
    opening = source.index("{", start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


def dimensions(source, marker="SKWarpGeometryGrid(columns:"):
    tail = source[source.index(marker):]
    match = re.match(r"SKWarpGeometryGrid\(columns: (\d+), rows: (\d+)", tail)
    if not match:
        raise ValueError("Expected literal production grid dimensions")
    return tuple(map(int, match.groups()))


feed_size = dimensions(feed)
window_size = dimensions(window)
feed_prepare = block(feed, "private func prepareAuthoredGaze()").replace("private func", "func", 1)
feed_dest = block(feed, "let destinations = zip(gazeVertices, gazeWeights).map")
window_model = block(window, "enum WindowCurtainFabric {")
mix_model = block(mix, "enum MixUpSoftMotion {").replace("private static func grid", "static func grid", 1)
mix_model = mix_model.replace("return SKWarpGeometryGrid(", "return checkedGrid(")
wash_start = wash.index("var source: [SIMD2<Float>] = [], destination: [SIMD2<Float>] = []")
wash_end = wash.index("sourcePositions: source, destinationPositions: destination)", wash_start)
wash_end += len("sourcePositions: source, destinationPositions: destination)")
wash_mesh = wash[wash_start:wash_end].replace("fibres[index].warpGeometry = SKWarpGeometryGrid(", "return checkedGrid(")
wash_columns = re.search(r"private let columns = (\d+)", wash).group(1)
wash_rows = re.search(r"private let rows = (\d+)", wash).group(1)

fixture = r'''
import AppKit
import SpriteKit
let assets = URL(fileURLWithPath: CommandLine.arguments[1])
print("Starting native SpriteKit rendering"); fflush(stdout)
let app = NSApplication.shared
let view = SKView(frame: NSRect(x: 0, y: 0, width: 402, height: 600))
view.isAsynchronous = false
let scene = SKScene(size: view.bounds.size)
view.presentScene(scene)
let nativeDefault = SKSpriteNode().subdivisionLevels
var rendered = 0

func checkedGrid(columns: Int, rows: Int, sourcePositions: [SIMD2<Float>],
                 destinationPositions: [SIMD2<Float>]) -> SKWarpGeometryGrid {
    let expected = (columns + 1) * (rows + 1)
    precondition(sourcePositions.count == expected && destinationPositions.count == expected,
                 "Warp buffers must match grid dimensions before entering SpriteKit")
    precondition((sourcePositions + destinationPositions).allSatisfy { $0.x.isFinite && $0.y.isFinite },
                 "Warp positions must be finite")
    return SKWarpGeometryGrid(columns: columns, rows: rows,
                             sourcePositions: sourcePositions, destinationPositions: destinationPositions)
}
func texture(_ name: String) -> SKTexture {
    let path = assets.appendingPathComponent(name + ".imageset/" + name + ".png").path
    guard let image = NSImage(contentsOfFile: path) else { fatalError("Missing production texture: " + path) }
    return SKTexture(image: image)
}
func sprite(_ name: String, size: CGSize = CGSize(width: 270, height: 430)) -> SKSpriteNode {
    let node = SKSpriteNode(texture: texture(name))
    node.subdivisionLevels = 0
    node.size = size; node.position = CGPoint(x: 201, y: 300)
    scene.addChild(node)
    return node
}
func render() {
    autoreleasepool {
        guard let snapshot = view.texture(from: scene) else { fatalError("SpriteKit snapshot failed") }
        let pixels = snapshot.cgImage() // force a native render/readback, not only grid construction
        precondition(pixels.width > 0 && pixels.height > 0)
        rendered += 1
    }
}
func reset(_ nodes: [SKSpriteNode], label: String, startingAt first: Int) {
    nodes.forEach { precondition($0.subdivisionLevels == 0); $0.warpGeometry = nil }
    render()
    print("PASS: \(label), \(rendered - first) rendered frames including reset")
    fflush(stdout)
    scene.removeAllChildren()
}

enum AmbientAnimator { static let reduceMotion = false }
enum MixUpZone { case head, body, legs }
MIX_MODEL
WINDOW_MODEL
struct FeedMesh {
    var artSprite: SKSpriteNode? = SKSpriteNode()
    var castMember: String? = "sprout"
    var gazeVertices: [SIMD2<Float>] = []
    var gazeWeights: [Float] = []
    FEED_PREPARE
    func grid(gaze: CGPoint) -> SKWarpGeometryGrid {
        FEED_DEST
        return checkedGrid(columns: FEED_COLUMNS, rows: FEED_ROWS,
                           sourcePositions: gazeVertices, destinationPositions: destinations)
    }
}
func washGrid(_ amount: CGFloat) -> SKWarpGeometryGrid {
    let columns = WASH_COLUMNS, rows = WASH_ROWS
    let bends = [amount], index = 0
    WASH_MESH
}

print("Native SpriteKit default subdivisionLevels=\(nativeDefault); smoke check explicitly uses 0")
fflush(stdout)
var start = rendered
var feedMesh = FeedMesh()
feedMesh.prepareAuthoredGaze()
let friend = sprite("feed-cast-sprout-1")
for x: CGFloat in [-1, 0, 1] { for y: CGFloat in [-1, 0, 1] {
    friend.warpGeometry = feedMesh.grid(gaze: CGPoint(x: x, y: y)); render()
} }
reset([friend], label: "Feed gaze FEED_COLUMNS×FEED_ROWS", startingAt: start)

start = rendered
let left = sprite("window-curtain-panel", size: CGSize(width: 160, height: 400))
let right = sprite("window-curtain-panel", size: left.size)
left.position.x = 100; right.position.x = 302; right.xScale = -1
left.anchorPoint.y = 1; right.anchorPoint.y = 1
left.position.y = 500; right.position.y = 500
for (open, hem): (CGFloat, CGFloat) in [(0,0), (1,1), (1,0), (0,1), (0.5,0.4)] {
    let grid = checkedGrid(columns: WINDOW_COLUMNS, rows: WINDOW_ROWS, sourcePositions: WindowCurtainFabric.mesh,
        destinationPositions: WindowCurtainFabric.destinations(open: open, hem: hem, travelOverWidth: 0.9))
    left.warpGeometry = grid; right.warpGeometry = grid; render()
}
reset([left, right], label: "Window cloth WINDOW_COLUMNS×WINDOW_ROWS, including mirrored panel", startingAt: start)

start = rendered
let part = sprite("mixup-friends-a", size: CGSize(width: 320, height: 220))
for profile in MixUpSoftMotion.Profile.allCases {
    for amount: Float in [-1, -0.5, 0, 0.5, 1] {
        part.warpGeometry = MixUpSoftMotion.grid(profile: profile, amount: amount); render()
    }
}
reset([part], label: "Mix-Up \(MixUpSoftMotion.divisions)×\(MixUpSoftMotion.divisions), all five local profiles", startingAt: start)

start = rendered
let tufts = (0..<7).map { index -> SKSpriteNode in
    let node = sprite("wash-brush-tuft", size: CGSize(width: 150, height: 90))
    node.anchorPoint = CGPoint(x: 0.5, y: 0.915)
    node.position.y = 530 - CGFloat(index) * 60
    return node
}
for step in -4...4 {
    for (index, tuft) in tufts.enumerated() {
        tuft.warpGeometry = washGrid(CGFloat(step) * (index.isMultiple(of: 2) ? 0.05 : -0.05))
    }
    render()
}
reset(tufts, label: "Wash fibres WASH_COLUMNS×WASH_ROWS, seven simultaneous tufts", startingAt: start)
print("PASS: \(rendered) native rendered frames. macOS smoke only; iOS 26.6.1 crash is not reproduced or disproved.")
'''
replacements = {
    "MIX_MODEL": mix_model,
    "WINDOW_MODEL": window_model,
    "FEED_PREPARE": feed_prepare.replace("func prepareAuthoredGaze", "mutating func prepareAuthoredGaze", 1),
    "FEED_DEST": feed_dest,
    "FEED_COLUMNS": str(feed_size[0]),
    "FEED_ROWS": str(feed_size[1]),
    "WINDOW_COLUMNS": str(window_size[0]),
    "WINDOW_ROWS": str(window_size[1]),
    "WASH_COLUMNS": wash_columns,
    "WASH_ROWS": wash_rows,
    "WASH_MESH": wash_mesh,
}
for marker, value in replacements.items():
    fixture = fixture.replace(marker, value)
with tempfile.TemporaryDirectory(prefix="lull-warp-render-") as temporary:
    source = Path(temporary) / "WarpRendering.swift"
    source.write_text(fixture)
    print("Compiling extracted production warp formulas for native rendering...", flush=True)
    try:
        subprocess.run(["xcrun", "swift", str(source), str(root / "App/Resources/Assets.xcassets")],
                       check=True, timeout=120)
    except subprocess.TimeoutExpired:
        raise SystemExit("Native warp smoke timed out after 120 seconds; no pass is claimed.")
