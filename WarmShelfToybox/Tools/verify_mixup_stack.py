#!/usr/bin/env python3
"""Check production Mix-Up registration/legacy recipes and Stack supply fit.

Needs Pillow (also used by Tools/Art); no images are changed. Gameplay and touch
behaviour still need the simulator/device checklist in Docs/MixUp-Stack-Build2.md.
"""
from pathlib import Path
from PIL import Image
import hashlib
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'App/Toys/MixUp/MixUpPart.swift').read_text()
scene = (root / 'App/Toys/MixUp/MixUpScene.swift').read_text()
stack = (root / 'App/Toys/Stack/StackScene.swift').read_text()
checks = 0

def check(condition, message):
    global checks
    assert condition, message
    checks += 1

def block(text, start):
    pos = text.index(start)
    opening = text.index('{', pos)
    depth = 1
    i = opening + 1
    while depth:
        depth += (text[i] == '{') - (text[i] == '}')
        i += 1
    return text[pos:i]

names_block = re.search(r'private static let artCharacterNames = \[(.*?)\n    \]', source, re.S).group(1)
names = re.findall(r'"([a-z0-9]+)"', names_block)
check(len(names) == len(set(names)) == 6, 'Expected six distinct felt friends')
atlas_names = {'bunny':'a', 'bear':'a', 'songbird':'a', 'fox':'b', 'mouse':'b', 'frog':'b'}
for zone in ['head', 'body', 'legs']:
    hashes = set()
    for name in names:
        key = 'mixup-friends-' + atlas_names[name]
        image = root / f'App/Resources/Assets.xcassets/{key}.imageset/{key}.png'
        with Image.open(image) as im:
            check(im.size == (1536, 1024) and im.mode == 'RGBA', f'{key} must preserve native RGBA atlas')
            row = re.search(r'"' + name + r'": \[(.*?)\],', source).group(1)
            measured = re.search(r'\.' + zone + r': CGRect\(x: (\d+), y: (\d+), width: (\d+), height: (\d+)\)', row)
            x, y, w, h = map(int, measured.groups())
            check(x >= 0 and y >= 0 and x+w <= im.width and y+h <= im.height, f'{name}-{zone} outside atlas')
            # Read-only crop for hash/alpha analysis; no raster output or edits.
            sprite = im.crop((x,y,x+w,y+h))
            alpha = list(sprite.getchannel('A').get_flattened_data())
            check(max(alpha) >= 250 and min(alpha) == 0, f'{name}-{zone} needs solid material and clear exterior')
            digest = hashlib.sha256(sprite.tobytes()).hexdigest()
            check(digest not in hashes, f'Duplicate painted {zone}: {name}')
            hashes.add(digest)

# Execute the production migration for both previously shipped pool orders.
current = re.search(r'private static let artCharacterNames = \[.*?\n    \]', source, re.S).group(0)
legacy = re.search(r'private static let legacyArtCharacterNames = \[.*?\n    \]', source, re.S).group(0)
v2 = re.search(r'private static let versionTwoArtCharacterNames = \[.*?\n    \]', source, re.S).group(0)
migration = block(source, 'static func migratedIndex')
swift = 'import Foundation\nimport CoreGraphics\nenum MixUpLibrary {\n' + current + '\n' + legacy + '\n' + v2 + '\n' + migration + '\n}\n'
swift += '''
let v1 = [0,1,1,1,4,2,0,3,1,2,2,5,5,1,5,4,1,0,3,0,1,1,5,4]
let v2 = [0,1,1,4,2,0,3,1,2,2,5,1,5,3,0,1,1,5,4]
for (version, expected) in [(0,v1),(2,v2)] {
    for index in expected.indices { precondition(MixUpLibrary.migratedIndex(index, fromVersion: version) == expected[index]) }
    precondition(MixUpLibrary.migratedIndex(-1, fromVersion: version) == expected.last!)
    precondition(MixUpLibrary.migratedIndex(expected.count, fromVersion: version) == expected.first!)
}
'''
with tempfile.TemporaryDirectory(prefix='lull-mixup-check-') as tmp:
    p = Path(tmp) / 'verify.swift'; p.write_text(swift)
    subprocess.run(['xcrun', 'swift', '-module-cache-path', str(Path(tmp) / 'cache'), str(p)], check=True)
checks += 47
check('castVersionKey' in scene and 'migratedIndex(recipe.head, fromVersion: storedVersion)' in scene,
      'Stored recipes must pass through the production migration')

# Extract the production sizing branch and positions, then verify all common
# device/orientation families leave a visible, separate, unblocked supply tray.
tray = block(stack, 'private var trayRect: CGRect').replace('private var', 'var')
scale = block(stack, 'private var pieceScale: CGFloat').replace('private var', 'var')
swift = '''import Foundation
import CoreGraphics
private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self { min(max(self, limits.lowerBound), limits.upperBound) }
}
struct Layout {
    let size: CGSize
    var groundLineY: CGFloat { 200 }
'''+scale+'\n'+tray+'''
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
    precondition(size.width * 0.34 + largestHalfWidth + 10 < supply.midX - largestHalfWidth)
}
'''
with tempfile.TemporaryDirectory(prefix='lull-stack-check-') as tmp:
    p = Path(tmp) / 'verify.swift'
    p.write_text(swift)
    subprocess.run(['xcrun', 'swift', '-module-cache-path', str(Path(tmp) / 'cache'), str(p)], check=True)
checks += 24

print(f'Mix-Up/Stack: {checks} checks passed; device interaction testing still required.')
