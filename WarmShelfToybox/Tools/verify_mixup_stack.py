#!/usr/bin/env python3
"""Check production Mix-Up registration/legacy recipes and Stack supply/rooted tower geometry.

Needs Pillow (also used by Tools/Art) and a Swift toolchain: `xcrun swift` on a Mac,
or set SWIFT to a swift binary (e.g. a Linux toolchain). No images are changed.
Gameplay and touch behaviour still need the simulator/device checklist in
Docs/MixUp-Stack-Build2.md.
"""
from pathlib import Path
from PIL import Image
import hashlib
import os
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True     # no __pycache__ next to the art tools
sys.path.insert(0, str(root / 'Tools/Art'))
from measure_atlas import measure   # noqa: E402  (the same measurer that wires atlas C)

source = (root / 'App/Toys/MixUp/MixUpPart.swift').read_text()
scene = (root / 'App/Toys/MixUp/MixUpScene.swift').read_text()
stack = (root / 'App/Toys/Stack/StackScene.swift').read_text()
assets = root / 'App/Resources/Assets.xcassets'
checks = 0
SWIFT = [os.environ['SWIFT']] if os.environ.get('SWIFT') else ['xcrun', 'swift']
SWIFT_PRELUDE = 'import Foundation\n#if canImport(CoreGraphics)\nimport CoreGraphics\n#endif\n'

def check(condition, message):
    global checks
    assert condition, message
    checks += 1

def run_swift(code, prefix):
    with tempfile.TemporaryDirectory(prefix=prefix) as tmp:
        p = Path(tmp) / 'verify.swift'
        p.write_text(code)
        subprocess.run(SWIFT + ['-module-cache-path', str(Path(tmp) / 'cache'), str(p)], check=True)

def block(text, start):
    pos = text.index(start)
    opening = text.index('{', pos)
    depth = 1
    i = opening + 1
    while depth:
        depth += (text[i] == '{') - (text[i] == '}')
        i += 1
    return text[pos:i]

def table(name):
    return re.search(r'private static let ' + name + r'(?:: [^=]*)? = \[(.*?)\n    \]', source, re.S).group(1)

def pixels(image):
    flat = getattr(image, 'get_flattened_data', None)
    return list(flat() if flat else image.getdata())

RECT = r'CGRect\(x: (\d+), y: (\d+), width: (\d+), height: (\d+)\)'
ZONES = ['head', 'body', 'legs']
ANIMALS = ['bunny', 'bear', 'songbird', 'fox', 'mouse', 'frog']
RETURNING = ['robot', 'officer', 'firefighter']

# --- Cast order: appended only, so saved indices 0-5 keep their friend. ---
names = re.findall(r'"([a-z0-9]+)"', table('artCharacterNames'))
check(len(names) == len(set(names)) == 9, 'Expected nine distinct friends')
check(names[:6] == ANIMALS, 'The six felt animals must keep indices 0-5')
check(names[6:] == RETURNING, 'robot, officer, firefighter are appended as 6, 7, 8')

# --- Where every part comes from, parsed from the production tables. ---
atlas_for = dict(re.findall(r'"([a-z]+)": "(mixup-friends-[a-z])"', table('atlasForCharacter')))
check(atlas_for == {n: 'mixup-friends-' + ('a' if i < 3 else 'b') for i, n in enumerate(ANIMALS)},
      'Animals stay in atlases a (bunny, bear, songbird) and b (fox, mouse, frog)')
atlas_canvas = tuple(map(int, re.search(r'private static let atlasCanvas = CGSize\(width: (\d+), height: (\d+)\)', source).groups()))
check('CGSize(width: 1536, height: 1024)\n' not in block(source, 'private static func artPart'),
      'artPart must take its pixel size from the source, not a hard-coded 1536x1024')
sources = {}   # (name, zone) -> (image, (w, h), (x, y, w, h))
painted = table('paintedBounds')
for name, atlas in atlas_for.items():
    row = re.search(r'"' + name + r'": \[(.*?)\],', painted).group(1)
    for zone in ZONES:
        rect = tuple(map(int, re.search(r'\.' + zone + r': ' + RECT, row).groups()))
        sources[(name, zone)] = (atlas, atlas_canvas, rect)
single = table('singleImageParts')
for friend_block in re.finditer(r'"([a-z]+)": \[\n(.*?)\n        \],', single, re.S):
    for m in re.finditer(r'\.(head|body|legs): MixUpArtSource\(image: "([a-z0-9-]+)", pixelSize: CGSize\(width: (\d+), '
                         r'height: (\d+)\), rect: ' + RECT, friend_block.group(2)):
        sources[(friend_block.group(1), m.group(1))] = (m.group(2), (int(m.group(3)), int(m.group(4))),
                                                         tuple(map(int, m.groups()[4:])))
check(sorted({n for n, _ in sources} - set(ANIMALS)) == sorted(RETURNING)
      and all((n, z) in sources for n in RETURNING for z in ZONES),
      'Each returning friend needs a single-image source for head, body and legs')
check({sources[('robot', z)][0] for z in ZONES} == {'robot2-head', 'robot2-body', 'robot2-legs'},
      'The interim robot is the clean robot2 set')

# Atlas C stays off until measure_atlas.py has produced its rects.
c_rects = table('friendsCBounds') if re.search(r'friendsCBounds: [^=]* = \[\n', source) else ''
c_canvas = tuple(map(int, re.search(r'private static let friendsCCanvas = CGSize\(width: (\d+), height: (\d+)\)', source).groups()))
c_path = block(source, 'private static func artSource')
check('friendsCBounds[name], rects.count == MixUpZone.allCases.count' in c_path
      and 'ToyArt.texture("mixup-friends-c") != nil' in c_path,
      'Atlas C is used only with all three rects measured and its imageset present')
c_png = assets / 'mixup-friends-c.imageset/mixup-friends-c.png'
if c_rects:
    check(c_png.exists(), 'friendsCBounds is filled in but mixup-friends-c.imageset is missing')
    for name in RETURNING:
        row = re.search(r'"' + name + r'": \[(.*?)\],', c_rects).group(1)
        for zone in ZONES:
            rect = tuple(map(int, re.search(r'\.' + zone + r': ' + RECT, row).groups()))
            sources[(name, zone)] = ('mixup-friends-c', c_canvas, rect)   # C wins when present
else:
    check('private static let friendsCBounds: [String: [MixUpZone: CGRect]] = [:]' in source,
          'Until atlas C is measured, friendsCBounds must stay empty')

# --- Every part: right canvas, inside it, solid with a clear border, unique. ---
images = {}
def load(image, canvas):
    if image not in images:
        with Image.open(assets / f'{image}.imageset/{image}.png') as im:
            check(im.size == canvas and im.mode == 'RGBA', f'{image} must be a native RGBA {canvas} canvas')
            images[image] = im.copy()
    return images[image]

for zone in ZONES:
    hashes = set()
    for name in names:
        image, canvas, (x, y, w, h) = sources[(name, zone)]
        im = load(image, canvas)
        check(x >= 0 and y >= 0 and x + w <= im.width and y + h <= im.height, f'{name}-{zone} outside {image}')
        # Read-only crop for hash/alpha analysis; no raster output or edits.
        sprite = im.crop((x, y, x + w, y + h))
        alpha = pixels(sprite.getchannel('A'))
        check(max(alpha) >= 250 and min(alpha) == 0, f'{name}-{zone} needs solid material and clear exterior')
        digest = hashlib.sha256(sprite.tobytes()).hexdigest()
        check(digest not in hashes, f'Duplicate painted {zone}: {name}')
        hashes.add(digest)

# --- Registration edges: each rect hugs its painted part (chin / collar / waist / soles). ---
def hugs(rect, box, label, slack=6):
    x, y, w, h = rect
    x0, y0, x1, y1 = box
    check(x <= x0 and y <= y0 and x + w >= x1 and y + h >= y1, f'{label} rect cuts into the painted part')
    check(x0 - x <= slack and y0 - y <= slack and x + w - x1 <= slack and y + h - y1 <= slack,
          f'{label} rect is loose: its edges must sit on the chin, collar, waist and soles')

for atlas, friends in [('mixup-friends-a', ANIMALS[:3]), ('mixup-friends-b', ANIMALS[3:])] + (
        [('mixup-friends-c', RETURNING)] if c_rects else []):
    _, _, rows = measure(str(assets / f'{atlas}.imageset/{atlas}.png'), tuple(friends), quiet=True)
    for zone, row in zip(ZONES, rows):
        for name, component in zip(friends, row):
            hugs(sources[(name, zone)][2], component[:4], f'{name}-{zone}')
if not c_rects:
    for name in RETURNING:
        for zone in ZONES:
            image, canvas, rect = sources[(name, zone)]
            # alpha > 32: ignores the faint ghost despill leaves where a baked shadow was.
            box = images[image].getchannel('A').point(lambda v: 255 if v > 32 else 0).getbbox()
            hugs(rect, box, f'{name}-{zone}')
            # No baked teal key shadow left (the original robot set has ~6%).
            visible = teal = 0
            for r, g, b, a in pixels(images[image].crop((rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3]))):
                if a > 32:
                    visible += 1
                    teal += min(g, b) - r > 14 and max(r, g, b) < 117
            check(teal / visible < (0.0001 if image == 'officer-legs' else 0.01),
                  f'{image} still carries a teal key shadow ({teal}/{visible})')

# Envelope: no head may be taller (h/w) than bunny's, or the layout fixture
# CGRect(-60, -98, 120, 239) in verify_mixup_layout.py would no longer hold.
bunny_head = sources[('bunny', 'head')][2]
for name in names:
    _, _, (_, _, w, h) = sources[(name, 'head')]
    check(h * bunny_head[2] <= bunny_head[3] * w, f'{name} head is taller than bunny: envelope would grow')

# --- Execute the production migration for every previously shipped pool order. ---
current = re.search(r'private static let artCharacterNames = \[.*?\n    \]', source, re.S).group(0)
legacy = re.search(r'private static let legacyArtCharacterNames = \[.*?\n    \]', source, re.S).group(0)
v2 = re.search(r'private static let versionTwoArtCharacterNames = \[.*?\n    \]', source, re.S).group(0)
migration = block(source, 'static func migratedIndex')
expected = {
    0: [0, 1, 1, 1, 4, 2, 0, 3, 1, 2, 2, 6, 6, 1, 5, 4, 1, 0, 3, 0, 8, 7, 5, 4],   # build 1 (24 names)
    2: [0, 1, 1, 4, 2, 0, 3, 1, 2, 2, 6, 1, 5, 3, 0, 8, 7, 5, 4],                  # local v2 (19 names)
    3: [0, 1, 2, 3, 4, 5],                                                         # builds 2-3: identity
}
swift = SWIFT_PRELUDE + 'enum MixUpLibrary {\n' + current + '\n' + legacy + '\n' + v2 + '\n' + migration + '\n}\n'
swift += 'let cases: [(Int, [Int])] = [' + ', '.join(f'({v}, {a})' for v, a in expected.items()) + ']\n'
swift += '''
for (version, expected) in cases {
    for index in expected.indices { precondition(MixUpLibrary.migratedIndex(index, fromVersion: version) == expected[index]) }
    precondition(MixUpLibrary.migratedIndex(-1, fromVersion: version) == expected.last!)
    precondition(MixUpLibrary.migratedIndex(expected.count, fromVersion: version) == expected.first!)
}
'''
run_swift(swift, 'lull-mixup-check-')
checks += sum(len(a) + 2 for a in expected.values())
check('castVersionKey' in scene and 'migratedIndex(recipe.head, fromVersion: storedVersion)' in scene,
      'Stored recipes must pass through the production migration')
check('private static let castVersion = 4' in scene, 'Appending friends bumps the stored cast version to 4')

# --- Per-friend personality hooks the sound rebuild relies on. ---
check('playMixFriend(name, moment: .arrive)' in scene and 'playMixFriend(name, moment: .wholeFriend)' in scene,
      'Mix-Up must voice a friend on arrival and on the whole-friend moment')
personality = block(scene, 'private func headPersonality')
signature = block(scene, 'private func wholeFriendSignature')
for name in names:
    check(f'case "{name}"' in personality or f'"{name}",' in personality, f'{name} needs its own arrival move')
    check(f'case "{name}"' in signature, f'{name} needs its own whole-friend signature')
check('MixUpLibrary.friendlyName(' in scene and '"police officer"' in source,
      'VoiceOver must say friendly names ("police officer")')

# Extract the production sizing branch and positions, then verify all common
# device/orientation families leave a visible, separate, unblocked supply tray.
tray = block(stack, 'private var trayRect: CGRect').replace('private var', 'var')
scale = block(stack, 'private var pieceScale: CGFloat').replace('private var', 'var')
ground = block(stack, 'private func groundLineY(for canvasSize: CGSize)').replace('private func', 'func')
supply_plan = block(stack, 'enum StackSupplyPlan')
tower_geometry = block(stack, 'enum StackTowerGeometry')
restore_plan = block(stack, 'enum StackRestorePlan')
swift = SWIFT_PRELUDE + supply_plan + '\n' + tower_geometry + '\n' + restore_plan + '''\nprivate extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self { min(max(self, limits.lowerBound), limits.upperBound) }
}
struct Layout {
    let size: CGSize
    var groundLineY: CGFloat { groundLineY(for: size) }
'''+scale+'\n'+tray+'\n'+ground+'''
}
for size in [CGSize(width: 375, height: 667), CGSize(width: 667, height: 375),
             CGSize(width: 393, height: 852), CGSize(width: 852, height: 393),
             CGSize(width: 768, height: 1024), CGSize(width: 1024, height: 768),
             CGSize(width: 1032, height: 1376), CGSize(width: 1376, height: 1032)] {
    let layout = Layout(size: size)
    let supply = layout.trayRect
    let largestHalfWidth = 116 * layout.pieceScale / 2
    precondition(supply.minX >= 0 && supply.maxX <= size.width)
    precondition(supply.width >= largestHalfWidth * 2 + 12)
    let bases = StackSupplyPlan.baseFractions(for: size)
    precondition(bases == (size.width > size.height ? [0.22, 0.46] : [0.34]))
    for fraction in bases {
        let x = fraction * size.width
        precondition(x - largestHalfWidth >= 0)
        precondition(x + largestHalfWidth + 10 < supply.midX - largestHalfWidth)
    }
    if bases.count == 2 {
        precondition((bases[1] - bases[0]) * size.width > largestHalfWidth * 2 + 10)
    }
    let maximumTopY = size.height - (size.width > size.height ? 62 : 90) - 54 * layout.pieceScale
    let threshold = StackTowerGeometry.wakeThreshold(groundY: layout.groundLineY,
        maximumTopY: maximumTopY, scale: layout.pieceScale, landscape: size.width > size.height)
    precondition(threshold >= layout.groundLineY && threshold < maximumTopY)
}
// Shape variety depends on successful refill ordinal, never the number of stones left.
for variation in 0..<7 {
    let cycle = (0..<7).map { StackSupplyPlan.kindIndex(ordinal: $0, variation: variation) }
    precondition(Set(cycle) == Set(0..<4))
    precondition((0..<6).contains { cycle[$0] != cycle[$0 + 1] })
    for ordinal in 0..<7 {
        precondition(StackSupplyPlan.kindIndex(ordinal: ordinal + 7, variation: variation) == cycle[ordinal])
    }
}
let tray = CGRect(x: 280, y: 0, width: 100, height: 60)
func stone(_ index: Int, _ x: CGFloat, _ y: CGFloat,
           settled: Bool = true, held: Bool = false, rotation: CGFloat = 0) -> StackTowerGeometry.Stone {
    StackTowerGeometry.Stone(index: index, center: CGPoint(x: x, y: y),
        size: CGSize(width: 100, height: 50), settled: settled, held: held, rotation: rotation)
}
func chain(_ stones: [StackTowerGeometry.Stone], top: Int = 2) -> [Int] {
    StackTowerGeometry.supportedChain(to: top, stones: stones, groundY: 0, tray: tray)
}
let tower = [stone(0, 100, 25), stone(1, 100, 75), stone(2, 100, 125)]
precondition(chain(tower) == [0, 1, 2])
precondition(chain(Array(tower.reversed())) == [0, 1, 2])
precondition(chain([tower[0], stone(1, 100, 75, held: true), tower[2]]).isEmpty)
precondition(chain([stone(0, 100, 25, settled: false), tower[1], tower[2]]).isEmpty)
precondition(chain([tower[0], tower[1], stone(2, 100, 125, rotation: 0.6)]).isEmpty)
precondition(chain([stone(0, 100, 60), stone(1, 100, 110), stone(2, 100, 160)]).isEmpty)
precondition(chain([tower[0], stone(1, 185, 75), stone(2, 185, 125)]).isEmpty)
precondition(chain([stone(0, 330, 25), stone(1, 330, 75), stone(2, 330, 125)]).isEmpty)
precondition(chain([tower[0], tower[1], stone(2, 100, 150)]).isEmpty)
// A wide top can overlap a floating branch, but its valid rooted path still wins.
let wideTop = StackTowerGeometry.Stone(index: 2, center: CGPoint(x: 100, y: 125),
    size: CGSize(width: 200, height: 50), settled: true, held: false, rotation: 0)
precondition(chain([tower[0], tower[1], wideTop, stone(8, 180, 78)]) == [0, 1, 2])
precondition(chain([tower[0]], top: 0) == [0])
precondition(chain([], top: 99).isEmpty)
'''
swift += """
// On the shortest shipped landscape, the mandatory pebble plus smallest bean
// can trigger the payoff using the production 94% rectangular physics heights.
let short = Layout(size: CGSize(width: 667, height: 375))
let scale = short.pieceScale
let baseHeight = 74 * scale
let beanHeight = 64 * scale
let baseX = short.size.width * StackSupplyPlan.baseFractions(for: short.size)[0]
let base = StackTowerGeometry.Stone(index: 0,
    center: CGPoint(x: baseX, y: short.groundLineY + baseHeight * 0.47),
    size: CGSize(width: 116 * scale, height: baseHeight), settled: true, held: false, rotation: 0)
let bean = StackTowerGeometry.Stone(index: 1,
    center: CGPoint(x: baseX, y: short.groundLineY + baseHeight * 0.94 + beanHeight * 0.47),
    size: CGSize(width: 80 * scale, height: beanHeight), settled: true, held: false, rotation: 0)
let maximum = short.size.height - 62 - 54 * scale
let threshold = StackTowerGeometry.wakeThreshold(groundY: short.groundLineY,
    maximumTopY: maximum, scale: scale, landscape: true)
let supported = StackTowerGeometry.supportedChain(to: 1, stones: [base, bean],
    groundY: short.groundLineY, tray: short.trayRect)
precondition(supported.count >= StackTowerGeometry.minimumCount(landscape: true))
precondition(bean.topY > threshold && bean.topY <= maximum)
precondition(StackTowerGeometry.minimumCount(landscape: false) == 3)
"""
swift += """
// Two landscape bases and their tops rotate into narrow portrait as separate
// intact chains, leaving room for the actual sleeping bean in the tray.
let portrait = Layout(size: CGSize(width: 375, height: 667))
let baseWidth = 116 * portrait.pieceScale
let topWidth = 80 * portrait.pieceScale
let rootX: [CGFloat] = [0.22 * portrait.size.width, 0.46 * portrait.size.width]
let desired: [CGFloat] = [rootX[0], rootX[1], rootX[0] + 10, rootX[1] - 8, portrait.trayRect.midX]
let widths: [CGFloat] = [baseWidth, baseWidth, topWidth, topWidth, topWidth]
let restored = StackRestorePlan.separatedCenters(desired, widths: widths,
    roots: [0, 1, 0, 1, nil], rightLimit: desired[4] - topWidth / 2 - 6)
precondition(restored[0] - baseWidth / 2 >= 4)
precondition(restored[1] - restored[0] >= baseWidth + 6)
precondition(restored[3] - restored[2] >= topWidth + 6)
precondition(abs((restored[2] - restored[0]) - 10) < 0.0001)
precondition(abs((restored[3] - restored[1]) + 8) < 0.0001)
precondition(restored[4] == desired[4])
precondition(restored[1] + baseWidth / 2 + 6 <= restored[4] - topWidth / 2)
let roomy = [CGFloat(150), 310, 160, 302, 507]
precondition(StackRestorePlan.separatedCenters(roomy, widths: widths,
    roots: [0, 1, 0, 1, nil], rightLimit: 465) == roomy)
"""
run_swift(swift, 'lull-stack-check-')
checks += 60 + 63 + 12 + 3 + 8
check(stack.index('guard let placement = clearTrayPlacement(') < stack.index('supplyOrdinal += 1'),
      'Only a successful clear-tray placement advances the supply ordinal')
check('if snapshots.isEmpty {\n            lastWakeCelebration' in stack
      and 'supplyVariation = Int.random(in: 0..<7)' in block(stack, 'private func rebuildWorld'),
      'New sessions choose variation; rotation restores pieces without resetting its ordinal')
check('stack.towerSong' in block(stack, 'private func stopTowerCelebration')
      and 'stopTowerCelebration()' in block(stack, 'override func teardownToyAudio'),
      'The scene owns the brief song and bird teardown')

print(f'Mix-Up/Stack: {checks} checks passed ({len(names)} friends, {len(names) ** 3} combinations); '
      'device interaction testing still required.')
