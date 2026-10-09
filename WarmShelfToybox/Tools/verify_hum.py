#!/usr/bin/env python3
"""Check extracted Hum expression and effect limits without device playback."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
node = (root / 'App/Toys/Hum/HumObjectNode.swift').read_text()
scene = (root / 'App/Toys/Hum/HumScene.swift').read_text()

def block(source, needle):
    start = source.index(needle)
    opening = source.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

expression = block(node, 'enum HumStrikeExpression')
budget = block(scene, 'private func reserveSoundFXSlots').replace('private func', 'func', 1)
fixture = r'''
import Foundation
final class Node {
    weak var parent: Layer?
    func removeAllActions() {}
    func removeFromParent() { parent?.children.removeAll { $0 === self }; parent = nil }
}
final class Layer { var children: [Node] = [] }
final class Effects {
    let soundFXLayer = Layer()
    BUDGET
    func emit(_ count: Int) {
        reserveSoundFXSlots(count)
        for _ in 0..<count {
            let node = Node(); node.parent = soundFXLayer; soundFXLayer.children.append(node)
        }
    }
}
var checks = 0
func check(_ condition: @autoclosure () -> Bool) { precondition(condition()); checks += 1 }
let single = HumStrikeExpression.intensity(speed: 0, interval: nil)
let repeated = HumStrikeExpression.intensity(speed: 0, interval: 0.08)
let slowSweep = HumStrikeExpression.intensity(speed: 120, interval: 0.3)
let fastSweep = HumStrikeExpression.intensity(speed: 1200, interval: 0.3)
check(repeated > single)
check(fastSweep > slowSweep)
for speed: CGFloat in [-100, 0, 120, 600, 1200, 100000, .infinity, .nan] {
    for interval: TimeInterval? in [nil, -1, 0, 0.001, 0.08, 0.45, 100, .infinity, .nan] {
        let intensity = HumStrikeExpression.intensity(speed: speed, interval: interval)
        check(intensity.isFinite && intensity >= 0.72 && intensity <= 1.45)
        let press = HumStrikeExpression.press(intensity: intensity, reduceMotion: false)
        check(press.depth >= 9 && press.depth <= 13.25)
        check(press.widthScale > 1 && press.widthScale < 1.06)
        check(press.heightScale > 0.90 && press.heightScale < 1)
        let calm = HumStrikeExpression.press(intensity: intensity, reduceMotion: true)
        check(calm.depth == 0 && calm.widthScale == 1 && calm.heightScale == 1 && calm.duration == 0)
    }
}
check(HumStrikeExpression.press(intensity: fastSweep, reduceMotion: false).depth
      > HumStrikeExpression.press(intensity: slowSweep, reduceMotion: false).depth)
check(HumStrikeExpression.clampedIntensity(.nan) == 1)
check(HumStrikeExpression.clampedIntensity(-100) == 0.72)
check(HumStrikeExpression.clampedIntensity(100) == 1.45)
// Rapid repeated strikes and held-mote emissions retain a fixed maximum, replacing oldest effects.
let effects = Effects()
for index in 0..<10000 {
    effects.emit(index.isMultiple(of: 3) ? 5 : 2)
    check(effects.soundFXLayer.children.count <= HumStrikeExpression.effectLimit)
}
check(effects.soundFXLayer.children.count == HumStrikeExpression.effectLimit)
print("PASS: \(checks) Hum speed, cadence, expression bounds, Reduce Motion and effect-budget checks")
'''.replace('BUDGET', budget)
with tempfile.TemporaryDirectory(prefix='lull-hum-check-') as temporary:
    directory = Path(temporary)
    source = directory / 'HumCheck.swift'
    source.write_text(expression + '\n' + fixture)
    toolchain = ['xcrun', 'swift'] if shutil.which('xcrun') else [os.environ.get('SWIFT', 'swift')]
    subprocess.run(toolchain + ['-module-cache-path', str(directory / 'ModuleCache'), str(source)], check=True)
