#!/usr/bin/env python3
"""Verify production Feed request state and geometry without a simulator.

Requires Python 3 and Xcode command-line tools. Scene animation and touch
behavior still require hands-on device or simulator playtesting.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

r = Path(__file__).resolve().parents[1] / "App/Toys/FeedThePeople"
cs=(r/'CharacterNode.swift').read_text();fs=(r/'FeedScene.swift').read_text()
def block(source,needle):
 start=source.index(needle);op=source.index('{',start);depth=1;i=op+1
 while depth:
  depth+=(source[i]=='{')-(source[i]=='}');i+=1
 return source[start:i]
methods='\n'.join(block(cs,n) for n in ['struct CastRig','static func artMouthPoint','func receivedFood','func fulfillDesire','func restoreWishGranted','func restoreBitesRemaining', 'var visitIsComplete'])
methods += '\n' + next(line for line in cs.splitlines() if 'static let chewBeatDuration:' in line)
fixture=r'''
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
enum CharacterMood { case hungry, eating, satisfied, resting }
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
'''+methods+'\n}\n'+block(cs,'enum FeedCastCatalog')+'\n'+block(fs,'enum FeedServingRules')+'\n'+block(fs,'struct FeedCastRotation')+'\n'+block(fs,'struct FeedPlateFoodRotation')+r'''
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
// Mouth local coordinates reconstruct the painted mouth (measured on the registered
// runtime exports, design pass 2) over several scales, with the sprite sized and anchored
// exactly as buildArtCharacter does.
for (member, ts, mouthY) in [("sprout",CGSize(width:760,height:1187),CGFloat(617)),("grandmother",CGSize(width:760,height:1149),CGFloat(580)),("knithat",CGSize(width:760,height:1211),CGFloat(694))] {
 let rig = CharacterModel.CastRig.of(member)
 for radius: CGFloat in [60,80,104,128,144] {
  let w = radius * 2 / rig.headWidth
  let h = w * ts.height / ts.width
  let anchor = CGPoint(x:0.5,y:1 - rig.headCentre)
  let p = CharacterModel.artMouthPoint(member:member,spriteSize:CGSize(width:w,height:h),anchorPoint:anchor)
  let topFraction = 1 - (p.y / h + anchor.y)
  check(abs(topFraction * ts.height - mouthY) < 3)
  check(abs(p.x) < 0.01)
  check(p.y < 0)          // the mouth sits below the head centre
  check(abs(w * rig.headWidth - radius * 2) < 0.01)   // the painted head is 2 x headRadius wide
 }
}
for radius: CGFloat in [30,60,80,104,128,200,400] {
 let snap = FeedServingRules.snapRadius(headRadius:radius)
 check(snap >= 40 && snap <= 60)
}
check(FeedServingRules.minimumDragTravel > 0)
// Pending food and departure must wait for the complete chew, then visibly settle.
let chew = CharacterModel.chewBeatDuration
check(FeedServingRules.nextBiteDelay(mood:.eating,eatingDuration:chew) >= chew + 0.3)
check(FeedServingRules.completedVisitDelay(mood:.eating,wishGranted:true,eatingDuration:chew)
      >= chew + FeedServingRules.wishLaughDuration + 0.3)
check(FeedServingRules.completedVisitDelay(mood:.satisfied,wishGranted:true,eatingDuration:chew)
      >= FeedServingRules.wishLaughDuration + 0.3)
check(FeedServingRules.completedVisitDelay(mood:.eating,wishGranted:false,eatingDuration:chew) >= 2.8)
check(FeedServingRules.nextBiteDelay(mood:.satisfied,eatingDuration:chew) < chew)
// Rotation changes the layout scale, not the visitor's identity or base head size.
for radius: CGFloat in [60,80,104,128,144] {
 for (oldScale,newScale): (CGFloat,CGFloat) in [(1.54,1.0),(1.0,1.54),(1.74,1.2),(1.2,1.74)] {
  let rotated = FeedServingRules.rescaledHeadRadius(radius * oldScale,from:oldScale,to:newScale)
  check(abs(rotated - radius * newScale) < 0.001)
  let restored = FeedServingRules.rescaledHeadRadius(rotated,from:newScale,to:oldScale)
  check(abs(restored - radius * oldScale) < 0.001)
 }
}
// An above-head minimum used to force the bubble outside a short landscape phone.
for (bounds,head,origin) in [
 (CGRect(x:14,y:48,width:362,height:723),CGFloat(123),CGPoint(x:195,y:440)),
 (CGRect(x:73,y:35,width:706,height:344),CGFloat(82),CGPoint(x:426,y:290)),
 (CGRect(x:14,y:34,width:806,height:1124),CGFloat(128),CGPoint(x:417,y:640)),
 (CGRect(x:14,y:34,width:1152,height:772),CGFloat(104),CGPoint(x:590,y:500))
] {
 let halfHeight = head * 0.78
 let point = FeedServingRules.thoughtBubblePosition(desiredLocalY:head * 1.7,
   preferredSide:0,headRadius:head,halfHeight:halfHeight,characterPosition:origin,visibleBounds:bounds)
 let world = CGPoint(x:origin.x + point.x,y:origin.y + point.y)
 check(world.y + halfHeight <= bounds.maxY + 0.001)
 check(world.y - halfHeight >= bounds.minY - 0.001)
 check(world.x + head * 0.86 <= bounds.maxX + 0.001)
 check(world.x - head * 0.86 >= bounds.minX - 0.001)
 if bounds.height < 400 { check(point.x > head * 1.2); check(point.y < head) }
}

// Replacement friends start offscreen. Bubble offsets must be derived from their final home,
// not their temporary arrival position, and must remain legal once the friend gets there.
let landscapeBounds = CGRect(x:73,y:35,width:706,height:344)
let home = CGPoint(x:426,y:290)
for arrival in [CGPoint(x:-214,y:290), CGPoint(x:1066,y:290)] {
 let origin = FeedServingRules.bubbleLayoutOrigin(current:arrival,home:home)
 check(origin == home)
 let local = FeedServingRules.thoughtBubblePosition(desiredLocalY:82 * 1.7,
   preferredSide:0,headRadius:82,halfHeight:82 * 0.78,
   characterPosition:origin,visibleBounds:landscapeBounds)
 let arrived = CGPoint(x:home.x + local.x,y:home.y + local.y)
 check(arrived.x - 82 * 0.86 >= landscapeBounds.minX)
 check(arrived.x + 82 * 0.86 <= landscapeBounds.maxX)
 check(arrived.y + 82 * 0.78 <= landscapeBounds.maxY)
}
check(FeedServingRules.bubbleLayoutOrigin(current:home,home:nil) == home)
// A finger on the pictured mouth may be holding the food's edge. Every illustrated shape
// remains accepted at landscape sizes, while a remote food cannot be served by a mouth tap.
for radius: CGFloat in [78.4,82.74,104,128] {
 for food in [CGSize(width:64,height:98), CGSize(width:79,height:84),
              CGSize(width:104,height:68), CGSize(width:73,height:95)] {
  let mouth = CGPoint(x:426,y:245)
  for offset in [CGPoint(x:food.width * 0.5,y:0),CGPoint(x:0,y:food.height * 0.5),
                 CGPoint(x:-food.width * 0.5,y:0),CGPoint(x:0,y:-food.height * 0.5)] {
   let center = CGPoint(x:mouth.x + offset.x,y:mouth.y + offset.y)
   check(FeedServingRules.acceptsFood(center:center,finger:mouth,mouth:mouth,
     headRadius:radius,foodSize:food))
  }
  check(!FeedServingRules.acceptsFood(center:CGPoint(x:mouth.x + 500,y:mouth.y),
    finger:mouth,mouth:mouth,headRadius:radius,foodSize:food))
  check(!FeedServingRules.acceptsFood(center:CGPoint(x:mouth.x + 500,y:mouth.y),
    finger:CGPoint(x:mouth.x + 500,y:mouth.y),mouth:mouth,headRadius:radius,foodSize:food))
 }
 check(FeedServingRules.proceduralMouthY(headRadius:radius) == -radius * 0.08)
}
// Every new scene rotates a four-item window; empty/small pools remain legal and unique.
for count in 1...10 {
 let pool = Array(0..<count)
 for offset in -2...20 {
  let menu = FeedServingRules.menu(from:pool,offset:offset)
  check(menu.count == min(4,count))
  check(Set(menu).count == menu.count)
  check(menu.allSatisfy { pool.contains($0) })
 }
}
check(FeedServingRules.menu(from:[Int](),offset:0).isEmpty)
check(FeedServingRules.menu(from:Array(0..<8),offset:0) != FeedServingRules.menu(from:Array(0..<8),offset:1))
// Visitor refresh preserves every outstanding pictured request in a finite four-food menu.
for count in 2...10 {
 let pool = Array(0..<count)
 for offset in 0..<count {
  for first in pool { for second in pool {
   let requested = [first, second]
   let menu = FeedServingRules.menu(from:pool,offset:offset,preserving:requested)
   check(menu.count == min(4,count)); check(Set(menu).count == menu.count)
   check(requested.allSatisfy { menu.contains($0) })
  }}
 }
}
check(FeedServingRules.menu(from:[0,1],offset:0,preserving:[99]) == [0,1])
// Only the eaten plate varies. One repeatedly used plate reaches every catalog
// food while the other three choices stay still, with no duplicate or immediate repeat.
for count in 4...10 {
 let catalog = Array(0..<count)
 for usedIndex in 0..<4 {
  var menu = [0,1,2,3]
  var seen = Set(menu)
  var rotation = FeedPlateFoodRotation<Int>()
  let untouched = menu.enumerated().filter { $0.offset != usedIndex }.map(\.element)
  for _ in 0..<80 {
   let old = menu[usedIndex]
   let occupied = menu.enumerated().filter { $0.offset != usedIndex }.map(\.element)
   let next = rotation.replacement(for:old,from:catalog,excluding:occupied,preserving:[],unfinishedVisit:false)
   menu[usedIndex] = next; seen.insert(next)
   check(menu.count == 4 && Set(menu).count == 4)
   check(menu.enumerated().filter { $0.offset != usedIndex }.map(\.element) == untouched)
   check(count == 4 ? next == old : next != old)
  }
  check(seen == Set(catalog))
 }
}
var protectedPlate = FeedPlateFoodRotation<Int>()
check(protectedPlate.replacement(for:0,from:Array(0..<10),excluding:[1,2,3],preserving:[0],unfinishedVisit:false) == 0)
check(protectedPlate.replacement(for:0,from:Array(0..<10),excluding:[1,2,3],preserving:[],unfinishedVisit:true) == 0)
check(protectedPlate.replacement(for:0,from:[],excluding:[],preserving:[],unfinishedVisit:false) == 0)

// Every friend must appear once per bag, including across scene re-entry; bag boundaries
// must never repeat a neighbour. Catalog reorder and duplicate names do not reset progress.
for count in 2...8 {
 let names = (0..<count).map { "friend\($0)" }
 var rotation = FeedCastRotation()
 var last: String? = nil
 for cycle in 0..<40 {
  var bag = [String]()
  for index in 0..<count {
   let available = (cycle + index).isMultiple(of:2) ? names : Array(names.reversed()) + [names[0]]
   let member = rotation.next(from:available)!
   check(member != last); last = member; bag.append(member)
  }
  check(Set(bag) == Set(names)); check(bag.count == Set(bag).count)
 }
}
var single = FeedCastRotation()
check(single.next(from:[]) == nil)
check(single.next(from:["one"]) == "one")
check(single.next(from:["one"]) == "one")
var changed = FeedCastRotation()
_ = changed.next(from:["a","b"])
check(changed.next(from:["c"]) == "c")
check(changed.next(from:[]) == nil)
check(changed.next(from:["d"]) == "d")
// A new cast may use explicit measured landmarks. All six runtime textures are required.
let catalogData = Data(#"{"version":1,"cast":[{"name":"newfriend","friendlyName":"the new friend","headWidth":0.9,"headCentre":0.42,"mouth":0.54}]}"#.utf8)
let catalog = FeedCastCatalog.decode(catalogData)!
check(catalog.count == 1 && catalog[0].mouth == 0.54)
let allFrames = Set((1...6).map { "feed-cast-newfriend-\($0)" })
check(FeedCastCatalog.completeCast(catalog) { allFrames.contains($0) }.count == 1)
check(FeedCastCatalog.completeCast(catalog) { allFrames.subtracting(["feed-cast-newfriend-6"]).contains($0) }.isEmpty)
check(FeedCastCatalog.decode(Data(#"{"version":2,"cast":[]}"#.utf8)) == nil)
check(FeedCastCatalog.decode(Data(#"{"version":1,"cast":[{"name":"scarf","friendlyName":"parked","headWidth":0.9,"headCentre":0.4,"mouth":0.5}]}"#.utf8))!.isEmpty)
print("PASS: \(checks) Feed request, mouth/edge, arrival bubble, menu/request preservation, consumed-plate variety, complete-cast bags, catalog, timing and rotation checks using extracted production methods")

'''
with tempfile.TemporaryDirectory(prefix="lull-feed-verification-") as temporary_directory:
    temporary_path = Path(temporary_directory)
    swift_source = temporary_path / "feed-verification.swift"
    swift_source.write_text(fixture)
    module_cache = temporary_path / "module-cache"
    module_cache.mkdir()
    subprocess.run(
        (["xcrun", "swift"] if shutil.which("xcrun") else [os.environ.get("SWIFT", "swift")])
        + ["-module-cache-path", str(module_cache), str(swift_source)],
        check=True,
    )
