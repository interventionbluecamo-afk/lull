#!/usr/bin/env python3
"""Verify production Feed request state and geometry without a simulator.

Requires Python 3 and Xcode command-line tools. Scene animation and touch
behavior still require hands-on device or simulator playtesting.
"""
from pathlib import Path
import subprocess
import tempfile

r = Path(__file__).resolve().parents[1] / "App/Toys/FeedThePeople"
cs=(r/'CharacterNode.swift').read_text();fs=(r/'FeedScene.swift').read_text()
def block(source,needle):
 start=source.index(needle);op=source.index('{',start);depth=1;i=op+1
 while depth:
  depth+=(source[i]=='{')-(source[i]=='}');i+=1
 return source[start:i]
methods='\n'.join(block(cs,n) for n in ['static func artMouthPoint','func receivedFood','func fulfillDesire','func restoreWishGranted','func restoreBitesRemaining', 'var visitIsComplete'])
fixture=r'''
import Foundation
enum CharacterMood { case hungry, eating }
enum FoodKind: Equatable { case apple, carrot, banana, egg }
final class SKAction {
 var timingMode = Timing.easeIn
 enum Timing { case easeIn, easeInEaseOut, easeOut }
 static func scale(to: CGFloat, duration: Double) -> SKAction { SKAction() }
 static func fadeOut(withDuration: Double) -> SKAction { SKAction() }
 static func moveBy(x: CGFloat, y: CGFloat, duration: Double) -> SKAction { SKAction() }
 static func move(to: CGPoint, duration: Double) -> SKAction { SKAction() }
 static func wait(forDuration: Double) -> SKAction { SKAction() }
 static func removeFromParent() -> SKAction { SKAction() }
 static func group(_ a: [SKAction]) -> SKAction { SKAction() }
 static func sequence(_ a: [SKAction]) -> SKAction { SKAction() }
}
class SKNode { func run(_ a: SKAction) {} }
final class CharacterModel {
 var desiredFoods: [FoodKind] = [.apple, .carrot]
 var grantedWishCount = 0
 var hungerBites = 2
 var bitesRemaining = 2
 var mood = CharacterMood.hungry
 var headRadius: CGFloat = 104
 var wantIcons: [(kind: FoodKind, node: SKNode)] = []
 var thoughtBubble: SKNode? = nil
 var wishGranted: Bool { grantedWishCount > 0 && desiredFoods.isEmpty }
 var hasRemainingDesires: Bool { !desiredFoods.isEmpty }
 var needsMoreFood: Bool { bitesRemaining > 0 }
 func transitionTo(_ m: CharacterMood) { mood = m }
 func runHappyShimmy() {}
'''+methods+'\n}\n'+block(fs,'enum FeedServingRules')+r'''
var checks = 0
func check(_ p: @autoclosure () -> Bool) { precondition(p()); checks += 1 }
let c = CharacterModel()
let unmatched = c.fulfillDesire(.banana)
_ = c.receivedFood(countsTowardRequest: unmatched)
check(!unmatched); check(c.desiredFoods == [.apple, .carrot]); check(c.bitesRemaining == 2); check(!c.wishGranted)
// Eating is a lock against a second acceptance.
_ = c.receivedFood(countsTowardRequest: true)
check(c.bitesRemaining == 2)
c.mood = .hungry
let first = c.fulfillDesire(.apple)
_ = c.receivedFood(countsTowardRequest: first)
check(first); check(c.desiredFoods == [.carrot]); check(c.bitesRemaining == 1); check(!c.wishGranted)
c.mood = .hungry
let second = c.fulfillDesire(.carrot)
_ = c.receivedFood(countsTowardRequest: second)
check(second); check(c.desiredFoods.isEmpty); check(c.wishGranted); check(c.bitesRemaining == 0)
let restored = CharacterModel()
restored.desiredFoods = c.desiredFoods
restored.restoreBitesRemaining(c.bitesRemaining)
restored.restoreWishGranted(c.wishGranted)
check(restored.wishGranted); check(restored.bitesRemaining == 0)
// A no-request fallback friend finishes a meal, while an unmet request stays open.
let noRequest = CharacterModel()
noRequest.desiredFoods = []
check(!noRequest.receivedFood()); check(!noRequest.visitIsComplete)
noRequest.mood = .hungry
check(noRequest.receivedFood()); check(noRequest.visitIsComplete)
check(!CharacterModel().visitIsComplete); check(c.visitIsComplete)
// Mouth local coordinates reconstruct the authored pixel landmark over several scales.
for (member, ts, mouthY) in [("sprout",CGSize(width:263,height:383),CGFloat(167)),("grandmother",CGSize(width:281,height:397),CGFloat(199)),("knithat",CGSize(width:281,height:474),CGFloat(220))] {
 for radius: CGFloat in [60,80,104,128,144] {
  let w = radius * 2 / 0.78
  let h = w * ts.height / ts.width
  let p = CharacterModel.artMouthPoint(member:member,spriteSize:CGSize(width:w,height:h),anchorPoint:CGPoint(x:0.5,y:0.72))
  let topFraction = 1 - (p.y / h + 0.72)
  check(abs(topFraction * ts.height - mouthY) < 3)
  check(abs(p.x) < 0.01)
  check(p.y < 0)
 }
}
for radius: CGFloat in [30,60,80,104,128,200,400] {
 let snap = FeedServingRules.snapRadius(headRadius:radius)
 check(snap >= 40 && snap <= 60)
}
check(FeedServingRules.minimumDragTravel > 0)
print("PASS: \(checks) request-state, mouth-landmark and serving-bound checks using extracted production methods")
'''
with tempfile.TemporaryDirectory(prefix="lull-feed-verification-") as temporary_directory:
    temporary_path = Path(temporary_directory)
    swift_source = temporary_path / "feed-verification.swift"
    swift_source.write_text(fixture)
    module_cache = temporary_path / "module-cache"
    module_cache.mkdir()
    subprocess.run(
        ["xcrun", "swift", "-module-cache-path", str(module_cache), str(swift_source)],
        check=True,
    )
