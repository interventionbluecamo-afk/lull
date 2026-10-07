#!/usr/bin/env python3
"""Verify production Mix-Up layout across phone/tablet safe areas."""
from pathlib import Path
import re, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'App/Toys/MixUp/MixUpScene.swift').read_text()
base=(root/'App/Shared/BaseToyScene.swift').read_text()
def block(text,start):
 a=text.index(start); o=text.index('{',a); d=1;i=o+1
 while d:
  d+=(text[i]=='{')-(text[i]=='}');i+=1
 return text[a:i]
need=['private var controlRadius:','private var controlTouchRadius:','private var floorY:','private var mixScale:','private var characterRootY:','private func controlPosition','private var miniFrameBaseWidth:','private var creationDisplayCapacity:','private func shelfSlotPositions']
methods='\n'.join(block(s,x).replace('private ','') for x in need)
helpers='\n'.join(block(base,x) for x in ['var isLandscapeLayout:','var isTabletLayout:','func safePlayRect'])
code='''import Foundation
import CoreGraphics
struct Insets { let top: CGFloat; let left: CGFloat; let bottom: CGFloat; let right: CGFloat }
enum MixUpZone: CaseIterable { case head, body, legs }
private extension Comparable {
 func clamped(to limits: ClosedRange<Self>) -> Self { min(max(self, limits.lowerBound), limits.upperBound) }
}
struct Layout {
 let size: CGSize
 let safeInsets: Insets
 let characterEnvelope: CGRect
 var miniFrameSize: CGSize { CGSize(width: miniFrameBaseWidth, height: miniFrameBaseWidth * 1.42) }
 enum MixUpCreationStore { static let capacity = 6 }
'''+methods+'\n'+helpers+'''
}
var checks = 0
func check(_ value: @autoclosure () -> Bool, _ label: String) {
 if !value() { fatalError(label) }; checks += 1
}
let fixtures: [(CGSize, Insets)] = [
 (CGSize(width: 320, height: 568), Insets(top:20,left:0,bottom:0,right:0)),
 (CGSize(width: 568, height: 320), Insets(top:0,left:0,bottom:0,right:0)),
 (CGSize(width: 375, height: 667), Insets(top:20,left:0,bottom:0,right:0)),
 (CGSize(width: 667, height: 375), Insets(top:0,left:0,bottom:0,right:0)),
 (CGSize(width: 393, height: 852), Insets(top:59,left:0,bottom:34,right:0)),
 (CGSize(width: 852, height: 393), Insets(top:0,left:59,bottom:21,right:59)),
 (CGSize(width: 440, height: 956), Insets(top:62,left:0,bottom:34,right:0)),
 (CGSize(width: 956, height: 440), Insets(top:0,left:62,bottom:21,right:62)),
 (CGSize(width: 768, height: 1024), Insets(top:24,left:0,bottom:20,right:0)),
 (CGSize(width: 1024, height: 768), Insets(top:24,left:0,bottom:20,right:0)),
 (CGSize(width: 744, height: 1133), Insets(top:24,left:0,bottom:20,right:0)),
 (CGSize(width: 1133, height: 744), Insets(top:24,left:0,bottom:20,right:0)),
 (CGSize(width: 1024, height: 1366), Insets(top:24,left:0,bottom:20,right:0)),
 (CGSize(width: 1366, height: 1024), Insets(top:24,left:0,bottom:20,right:0))
]
for (size, safe) in fixtures {
 let layout = Layout(size: size, safeInsets: safe,
                     characterEnvelope: CGRect(x:-60,y:-98,width:120,height:239))
 let play = layout.safePlayRect()
 let artRight = size.width / 2 + 60 * layout.mixScale * 1.014
 let control = layout.controlPosition(for: .body)
 check(control.x - layout.controlRadius - artRight >= 12, "control crosses painted body \\(size)")
 check(layout.controlRadius * 2 >= 44, "visual control too small")
 check(layout.controlTouchRadius * 2 >= 44, "touch control too small")
 check(abs(layout.characterRootY - 98 * layout.mixScale - layout.floorY) < 0.001, "feet miss floor")
 let centers = MixUpZone.allCases.map { layout.controlPosition(for:$0) }
 for center in centers {
  check(play.contains(CGPoint(x:center.x-layout.controlRadius,y:center.y-layout.controlRadius)), "control bottom outside safe play \\(size)")
  check(play.contains(CGPoint(x:center.x+layout.controlRadius,y:center.y+layout.controlRadius)), "control top outside safe play \\(size)")
 }
 check(centers[0].y-centers[1].y >= layout.controlTouchRadius*2, "head/body touch controls overlap")
 check(centers[1].y-centers[2].y >= layout.controlTouchRadius*2, "body/legs touch controls overlap")
 let capacity=layout.creationDisplayCapacity
 let positions=layout.shelfSlotPositions(count:capacity)
 let shelfPosition = layout.isLandscapeLayout
    ? CGPoint(x:play.minX+layout.miniFrameSize.width*0.6+12,y:play.midY)
    : CGPoint(x:size.width/2,y:play.maxY-layout.miniFrameSize.height/2-8)
 for position in positions {
  let frame=CGRect(x:shelfPosition.x+position.x-layout.miniFrameSize.width/2,
                   y:shelfPosition.y+position.y-layout.miniFrameSize.height/2,
                   width:layout.miniFrameSize.width,height:layout.miniFrameSize.height)
  check(play.contains(frame), "saved card outside safe play \\(size)")
  if layout.isLandscapeLayout {
   check(frame.maxX+12 < size.width/2-60*layout.mixScale, "card touches character")
  } else {
   let headTop=layout.floorY+(239+26)*layout.mixScale*1.014
   check(frame.minY-headTop >= 16, "portrait shelf touches hopped character \\(size)")
  }
 }
 print("\\(Int(size.width))×\\(Int(size.height)): scale \\(String(format:"%.2f", Double(layout.mixScale))), \\(capacity) cards")
}
print("Mix-Up room/layout: \\(checks) checks passed.")
'''
with tempfile.TemporaryDirectory(prefix='lull-mixroom-verify-') as tmp:
 p=Path(tmp)/'check.swift';p.write_text(code)
 subprocess.run(['xcrun','swift','-module-cache-path',str(Path(tmp)/'cache'),str(p)],check=True)
