#!/usr/bin/env python3
"""Check actual Window control geometry and touch branches without a simulator.

SpriteKit/audio are light stubs here. These checks verify bounded interaction
state; rendered appearance, finger feel, and device audio still need playtesting.
"""
from pathlib import Path
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT / "App/Toys/GlowWindow/GlowWindowScene.swift"
source = SOURCE.read_text()


def body(marker):
    start = source.index(marker)
    opening = source.index("{", start)
    depth, end = 1, opening + 1
    while depth:
        if source[end] == "{":
            depth += 1
        elif source[end] == "}":
            depth -= 1
        end += 1
    return source[opening + 1:end - 1]


def function(marker):
    start = source.index(marker)
    opening = source.index("{", start)
    return source[start:opening + 1] + body(marker) + "}"


SWIFT_TEMPLATE = r'''
import Foundation
import CoreGraphics
struct UIEdgeInsets { var top:CGFloat; var left:CGFloat; var bottom:CGFloat; var right:CGFloat }
enum AmbientAnimator { static var reduceMotion = false }
struct SKAction {
 static func sequence(_ actions:[SKAction])->SKAction{SKAction()}
 static func scale(to:CGFloat,duration:TimeInterval)->SKAction{SKAction()}
}
class Node { var position=CGPoint.zero; func removeAction(forKey:String){}; func setScale(_ value:CGFloat){}; func run(_ action:SKAction,withKey:String){} }
class HapticsManager { static let shared=HapticsManager(); enum Style{case soft}; func impact(style:Style,intensity:CGFloat){} }
final class Harness {
 enum Grab{case dial}
 var size=CGSize(width:390,height:844)
 var safeInsets=UIEdgeInsets(top:47,left:0,bottom:34,right:0)
 var windowRect=CGRect.zero
 var windowCenter=CGPoint.zero
 var windowInner=CGRect.zero
 var floorTopY:CGFloat=0
 var dialRadius:CGFloat=44.85
 var dialCenter=CGPoint.zero
 var dialLastAngle:CGFloat?
 var dialVelocity:CGFloat=0
 var dialTouchStart=CGPoint.zero
 var dialTouchMoved=false
 var dialAngleRange:CGFloat = .pi * 1.7
 var dayPhase:CGFloat=0.2
 var dialNode:Node! = Node()
 var dialKnob:Node! = Node()
 var grabs:[Int:Grab]=[:]
 var tickCount=0
 var releasedPoint=CGPoint(x:0,y:0)
 func applyPhase(animated:Bool){}
 func dialTick(){tickCount += 1}
 func configure(width:CGFloat,height:CGFloat,insets:UIEdgeInsets){
  size=CGSize(width:width,height:height);safeInsets=insets
  let landscape=width>height
__WINDOW_LAYOUT__
  dialCenter=resolvedDialCenter()
 }
__GEOMETRY_HELPERS__
 func begin(at p:CGPoint,touch:Int=0){
  for _ in 0..<1 {let pr=p
__DIAL_BEGIN__
  }
 }
 func move(at p:CGPoint,touch:Int=0){
  guard grabs[touch] == .dial else{return}
  for _ in 0..<1 {let pr=p
__DIAL_MOVE__
  }
 }
 func end(cancelled:Bool,touch:Int=0,at release:CGPoint?=nil){
 releasedPoint=release ?? dialTouchStart
  switch grabs[touch] {
  case .dial:__DIAL_END__
  case .none:break
  }
  grabs.removeValue(forKey:touch)
 }
}
extension Int {func location(in scene:Harness)->CGPoint {scene.releasedPoint}}
var checks=0
func check(_ condition:Bool,_ message:String){checks += 1;precondition(condition,message)}
let sizes:[(CGFloat,CGFloat)]=[(375,667),(667,375),(390,844),(844,390),(744,1133),(1133,744),(820,1180),(1180,820),(834,1210),(1210,834)]
let insetSets=[UIEdgeInsets(top:0,left:0,bottom:0,right:0),UIEdgeInsets(top:59,left:0,bottom:34,right:0),UIEdgeInsets(top:0,left:59,bottom:21,right:59),UIEdgeInsets(top:24,left:0,bottom:20,right:0)]
for (w,h) in sizes {for inset in insetSets {
 let s=Harness();s.configure(width:w,height:h,insets:inset)
 let r=s.dialRadius*1.35
 check(s.dialCenter.x-r>=inset.left+11.999,"left control clipped")
 check(s.dialCenter.x+r<=w-inset.right-11.999,"right control clipped")
 check(s.dialCenter.y-r>=inset.bottom+11.999,"bottom control clipped")
 check(s.dialCenter.y+r<=h-inset.top-11.999,"top control clipped")
}}
func scene()->Harness{let s=Harness();s.configure(width:390,height:844,insets:insetSets[1]);return s}
let tap=scene();tap.begin(at:tap.dialCenter);tap.end(cancelled:false)
check(abs(tap.dayPhase-0.4)<0.0001,"stationary tap did not advance")
let cancel=scene();cancel.begin(at:cancel.dialCenter);cancel.end(cancelled:true)
check(cancel.dayPhase==0.2 && cancel.dialVelocity==0,"cancel advanced day")
let jitter=scene();let rim=CGPoint(x:jitter.dialCenter.x+jitter.dialRadius,y:jitter.dialCenter.y)
jitter.begin(at:rim);jitter.move(at:CGPoint(x:rim.x,y:rim.y+8))
check(jitter.dayPhase==0.2,"tap jitter changed phase")
jitter.end(cancelled:false);check(abs(jitter.dayPhase-0.4)<0.0001,"tap jitter prevented advance")
let drag=scene();let c=drag.dialCenter;let r=drag.dialRadius
drag.begin(at:CGPoint(x:c.x+r,y:c.y));drag.move(at:CGPoint(x:c.x-r,y:c.y))
check(abs(drag.dayPhase-0.2)<=0.020001,"angular event jumped phase")
check(abs(drag.dialVelocity)<=0.004001,"inertia unbounded")
let beforeEnd=drag.dayPhase;drag.end(cancelled:false)
check(drag.dayPhase==beforeEnd,"drag unexpectedly also tapped")
let hub=scene();let hc=hub.dialCenter;let hr=hub.dialRadius
hub.begin(at:CGPoint(x:hc.x+hr,y:hc.y));hub.move(at:hc)
check(hub.dayPhase==0.2 && hub.dialLastAngle==nil && hub.dialVelocity==0,"hub changed phase or kept inertia")
hub.move(at:CGPoint(x:hc.x-hr,y:hc.y))
check(hub.dayPhase==0.2,"hub exit did not rebase")
hub.move(at:CGPoint(x:hc.x-hr*cos(0.3),y:hc.y+hr*sin(0.3)))
check(abs(hub.dayPhase-0.2)<=0.020001,"posthub event jumped phase")
let hubPhase=hub.dayPhase;hub.end(cancelled:false)
check(hub.dayPhase==hubPhase,"hub-crossing drag treated as tap")
let ownership=scene();let oc=ownership.dialCenter
ownership.begin(at:oc,touch:0);ownership.begin(at:CGPoint(x:oc.x+30,y:oc.y),touch:1)
check(ownership.grabs.count==1 && ownership.grabs[1]==nil,"second finger stole dial")
ownership.end(cancelled:true,touch:1)
check(ownership.grabs[0] == .dial,"unowned cancel cleared owner")
ownership.end(cancelled:false,touch:0)
check(abs(ownership.dayPhase-0.4)<0.0001,"owner lost tap")
let wrap=scene();wrap.dayPhase=0.96;wrap.begin(at:wrap.dialCenter);wrap.end(cancelled:false)
check(wrap.dayPhase==0,"night tap did not wrap")
let releaseOnly=scene();let rc=releaseOnly.dialCenter
releaseOnly.begin(at:rc);releaseOnly.end(cancelled:false,at:CGPoint(x:rc.x+40,y:rc.y))
check(releaseOnly.dayPhase==0.2,"missing finalmove event became tap")
print("PASS \(checks) native checks: safe control bounds, tap/jitter/cancel, hub exit, angular cap, drag ownership, night wrap")

'''

helpers = "\n".join(function(marker) for marker in [
    "private func resolvedDialCenter()", "private func clamp(",
    "private func angleDelta(", "private func setPhase(",
    "private func advanceDayPhase()",
])
rebuild = body("private func rebuild()")
layout_start = rebuild.index("        let winW =")
layout_end = rebuild.index("        floorTopY = size.height * 0.24")
layout_end += len("        floorTopY = size.height * 0.24")
radius_line = next(line for line in rebuild.splitlines() if "dialRadius = min(size.width" in line)
layout = rebuild[layout_start:layout_end] + "\n" + radius_line
replacements = {
    "__GEOMETRY_HELPERS__": helpers,
    "__WINDOW_LAYOUT__": layout,
    "__DIAL_BEGIN__": body("if hypot(pr.x - dialCenter.x, pr.y - dialCenter.y) < dialRadius * 1.35"),
    "__DIAL_MOVE__": body("override func touchesMoved").split("case .dial:", 1)[1].split("case .curtainL:", 1)[0],
    "__DIAL_END__": body("private func endTouches").split("case .dial:", 1)[1].split("case .curtainL, .curtainR:", 1)[0],
}
for token, replacement in replacements.items():
    assert SWIFT_TEMPLATE.count(token) == 1, token
    SWIFT_TEMPLATE = SWIFT_TEMPLATE.replace(token, replacement)

active_begin = body("override func touchesBegan")
assert "grabs[touch] = .room" not in active_begin
assert "LULL_DEBUG_ROOM_PAN" not in source
assert active_begin.index("acknowledgeSkyTap(at: p)") < active_begin.index("flyBird(toward: p)")
night_branch = active_begin.split("if dayPhase > 0.65", 1)[1]
assert night_branch.index("acknowledgeSkyTap(at: p)") < night_branch.index("shootingStar(toward: p)")
assert "AmbientAnimator.reduceMotion" not in body("private func acknowledgeSkyTap")
assert "glassFlash" not in body("private func shootingStar")
assert "lastCometTime >= 1.6" in body("private func shootingStar")
assert body("private func shootingStar").count("launchComet(") == 1
assert "if lampOn, lampGlow != nil" in body("private func spawnMote")
print("PASS active paths: pan inactive; sky acknowledgment precedes cooldown and works in Reduce Motion; one guarded comet; real lamp required for motes", flush=True)

with tempfile.TemporaryDirectory(prefix="lull-window-check-") as temporary:
    root = Path(temporary)
    harness = root / "WindowFocused.swift"
    harness.write_text(SWIFT_TEMPLATE)
    subprocess.run(["xcrun", "swiftc", "-frontend", "-parse", str(SOURCE)], check=True)
    subprocess.run(["xcrun", "swift", "-module-cache-path", str(root / "module-cache"), str(harness)], check=True)
