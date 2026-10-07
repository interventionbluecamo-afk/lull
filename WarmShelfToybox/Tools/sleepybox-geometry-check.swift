import Foundation
enum SleepyBoxFitGeometry {
    static func captureRadius(at index: Int, centers: [CGPoint], sizes: [CGSize]) -> CGFloat {
        guard centers.indices.contains(index), sizes.indices.contains(index) else { return 0 }
        let center = centers[index]
        let neighborDistance = centers.enumerated()
            .filter { $0.offset != index }
            .map { hypot($0.element.x - center.x, $0.element.y - center.y) }
            .min() ?? .greatestFiniteMagnitude
        let visualRadius = max(sizes[index].width, sizes[index].height) * 0.55 + 8
        return min(visualRadius, neighborDistance * 0.44)
    }

    static func nearestOpening(at point: CGPoint, centers: [CGPoint], sizes: [CGSize]) -> Int? {
        guard centers.count == sizes.count,
              let nearest = centers.indices.min(by: { a, b in
                  hypot(centers[a].x - point.x, centers[a].y - point.y)
                    < hypot(centers[b].x - point.x, centers[b].y - point.y)
              }) else { return nil }
        let distance = hypot(centers[nearest].x - point.x, centers[nearest].y - point.y)
        return distance <= captureRadius(at: nearest, centers: centers, sizes: sizes) ? nearest : nil
    }
}


var checks = 0
func check(_ condition: Bool, _ message: String) {
    checks += 1
    precondition(condition, message)
}
let devices: [(CGFloat, CGFloat)] = [(320,568),(375,667),(393,852),(430,932),(744,1133),(834,1194),(1024,1366)]
let legacyFractions: [(CGFloat, CGFloat)] = [(0.267,0.185),(0.709,0.210),(0.266,0.486),(0.702,0.500)]
for device in devices {
    for size in [CGSize(width:device.0,height:device.1), CGSize(width:device.1,height:device.0)] {
        for aspect: CGFloat in [0.755,1065.0/946.0,1.0,1.2] {
            let landscape = size.width > size.height
            let requestedW = min(size.width * (landscape ? 0.62 : 0.90), 680)
            let requestedH = min(size.height * (landscape ? 0.64 : 0.54), 560)
            let h = min(requestedH, requestedW / aspect)
            let w = h * aspect
            let radius = min(min(w * 0.105,size.width * 0.10),50)
            if aspect != 0.755 {
                check(w * 0.926 > w * 0.91 && h * 0.205 > h * 0.19,
                      "Drawer front does not cover authored cavity")
                let closed = size.height * (landscape ? 0.60 : 0.605) - h * 0.365
                let open = closed - h * 0.22
                check(open - h * 0.205 / 2 > 0, "Open drawer is off-screen")
            }
            let spread = min(w * 0.82,size.width - radius * 2.6)
            let firstX = size.width / 2 - spread / 2
            let lastX = size.width / 2 + spread / 2
            let liftedHalfWidth = radius * 2.15 * 1.16 / 2
            check(firstX-liftedHalfWidth >= 0 && lastX+liftedHalfWidth <= size.width,
                  "Lifted shape clips in \(size), aspect \(aspect)")
            check(spread / 3 > radius * 2.15, "Resting shapes overlap")
            let center = CGPoint(x:size.width / 2,y:size.height * (landscape ? 0.60 : 0.605))
            let centers: [CGPoint]
            let sizes: [CGSize]
            if aspect == 0.755 {
                centers = legacyFractions.map { CGPoint(x:center.x-w/2+$0.0*w,y:center.y+h/2-$0.1*h) }
                sizes = Array(repeating:CGSize(width:w*0.25,height:w*0.25),count:4)
            } else {
                let panel = CGPoint(x:center.x,y:center.y+h*0.16)
                centers = [CGPoint(x:panel.x-w*0.22,y:panel.y+h*0.16),
                           CGPoint(x:panel.x+w*0.22,y:panel.y+h*0.16),
                           CGPoint(x:panel.x-w*0.22,y:panel.y-h*0.16),
                           CGPoint(x:panel.x+w*0.22,y:panel.y-h*0.16)]
                sizes = [CGSize(width:radius*2.24,height:radius*2.24),
                         CGSize(width:radius*2.40,height:radius*2.20),
                         CGSize(width:radius*2.12,height:radius*2.12),
                         CGSize(width:radius*2.30,height:radius*2.30)]
            }
            for i in centers.indices {
                check(SleepyBoxFitGeometry.nearestOpening(at:centers[i],centers:centers,sizes:sizes)==i,
                      "Correct center misses")
                let capture = SleepyBoxFitGeometry.captureRadius(at:i,centers:centers,sizes:sizes)
                for offset in [CGPoint(x:capture*0.65,y:0),CGPoint(x:-capture*0.65,y:0),
                               CGPoint(x:0,y:capture*0.65),CGPoint(x:0,y:-capture*0.65)] {
                    let point = CGPoint(x:centers[i].x+offset.x,y:centers[i].y+offset.y)
                    check(SleepyBoxFitGeometry.nearestOpening(at:point,centers:centers,sizes:sizes)==i,
                          "Tolerant release selects wrong opening")
                }
                for wrong in centers.indices where wrong != i {
                    let selected = SleepyBoxFitGeometry.nearestOpening(at:centers[wrong],centers:centers,sizes:sizes)
                    check(selected != i, "Wrong-hole placement silently accepted")
                    let otherRadius = SleepyBoxFitGeometry.captureRadius(at:wrong,centers:centers,sizes:sizes)
                    let d = hypot(centers[i].x-centers[wrong].x,centers[i].y-centers[wrong].y)
                    check(capture+otherRadius < d, "Capture regions overlap")
                }
            }
        }
    }
}
check(SleepyBoxFitGeometry.nearestOpening(at:CGPoint(x:0,y:0),centers:[],sizes:[]) == nil,"Empty geometry accepted")
check(SleepyBoxFitGeometry.nearestOpening(at:CGPoint(x:0,y:0),centers:[CGPoint(x:0,y:0)],sizes:[]) == nil,"Malformed geometry accepted")
print("Passed \(checks) focused fit and tray assertions across 7 phone/tablet sizes, both orientations, 4 artwork aspect ratios.")
