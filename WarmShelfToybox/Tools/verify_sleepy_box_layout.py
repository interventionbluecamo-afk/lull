#!/usr/bin/env python3
"""Sleepy Box sockets sit on the shell's front face (founder, October 11: the holes didn't line up
realistically with the box; the top row ran up onto the lid).

Compiles the production `SleepyBoxShellLayout` and checks, as fractions of the shell plate, that
every socket (including its bevel, highlight and shadow) stays on the measured front face,
that rows never touch, and that larger pieces remain reachable in every supported orientation.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
scene = (root / "App/Toys/SleepyDropBox/SleepyDropBoxScene.swift").read_text()
fit_start = scene.index("enum SleepyBoxFitGeometry {")
fit_end = scene.index("\nprivate extension Comparable", fit_start)
layout = "import Foundation\n" + scene[fit_start:fit_end] + scene[scene.index("enum SleepyBoxShellLayout {"):]
checks = r'''
var passed = 0
func check(_ ok: Bool, _ what: String) {
    if !ok { print("FAIL: " + what); exit(1) }
    passed += 1
}
typealias L = SleepyBoxShellLayout
// The plate is 1065 x 946: height is 0.888 of width.
let heightOverWidth: CGFloat = 946.0 / 1065.0
let topSpan = L.socketTopInRadii * L.maxPieceRadius
let bottomSpan = L.socketBottomInRadii * L.maxPieceRadius
let halfSpanX = L.socketSpanInRadii * L.maxPieceRadius * heightOverWidth / 2
check(L.holeCenters.count == 4, "four sockets")
for h in L.holeCenters {
    check(h.fy - topSpan >= L.frontFaceTop, "no highlighted socket lip runs onto the lid")
    check(h.fy + bottomSpan <= L.holeBandBottom + 0.001, "socket shadows stay above the face")
    check(h.fx - halfSpanX >= 0.04 && h.fx + halfSpanX <= 0.96, "sockets stay inside the box's sides")
}
check(L.rowFy[1] - L.rowFy[0] >= topSpan + bottomSpan + 0.015, "a strip of wood between the two rows including shadows")
check(L.columnFx[1] - L.columnFx[0] >= 2 * halfSpanX + 0.05, "the two columns have wood between them")
check(abs((L.columnFx[0] + L.columnFx[1]) / 2 - 0.5) < 0.001, "the grid is centred on the face")
// Check the largest expression (open eyes / happy mouth), including their stroke widths.
let eyeTop = L.faceHeightFraction * 0.1 + (0.078 * 0.78 * 0.34 + 0.009 / 2) / heightOverWidth
let mouthBottom = L.faceHeightFraction * (0.1 + 0.13 / 2) + 0.0075 / 2 / heightOverWidth
check(L.faceFy - eyeTop > L.holeBandBottom + 0.006, "even open eyes sit below socket bevels")
check(L.faceFy + mouthBottom < L.drawerRecessTop - 0.006, "the smile stays above the drawer")

// Shell fit is aspect-preserving. These cover small/large phones and the iPad sizes in
// both orientations, using the scene's existing box bounds and shared radius function.
for canvas in [CGSize(width: 375, height: 667), CGSize(width: 667, height: 375),
               CGSize(width: 393, height: 852), CGSize(width: 852, height: 393),
               CGSize(width: 440, height: 956), CGSize(width: 956, height: 440),
               CGSize(width: 744, height: 1133), CGSize(width: 1133, height: 744),
               CGSize(width: 820, height: 1180), CGSize(width: 1180, height: 820),
               CGSize(width: 1024, height: 1366), CGSize(width: 1366, height: 1024)] {
    let landscape = canvas.width > canvas.height
    let bounds = CGSize(width: min(canvas.width * (landscape ? 0.62 : 0.90), 680),
                        height: min(canvas.height * (landscape ? 0.64 : 0.54), 560))
    let width = min(bounds.width, bounds.height / heightOverWidth)
    let box = CGSize(width: width, height: width * heightOverWidth)
    let r = L.pieceRadius(boxSize: box, canvasWidth: canvas.width)
    let oldRadius = min(width * 0.105, canvas.width * 0.10, 50, box.height * 0.076)
    check(r >= oldRadius * 1.20 && r <= oldRadius * 1.23, "shapes are visibly about 21 percent larger")
    check(r * 2 >= 44, "round piece is at least 44 points on the supported phone/tablet layouts")
    let centerY = canvas.height * (landscape ? 0.60 : 0.605)
    let boxBottom = centerY - box.height / 2
    let trayY = max(canvas.height * (landscape ? 0.12 : 0.115), boxBottom - r * 1.7)
    let spread = min(width * 0.82, canvas.width - r * 2.6)
    let dishWidth = min(spread + r * 2.3, canvas.width * 0.96)
    check(spread / 3 > r * 2.11 * 1.16, "even lifted stars leave space between tray neighbours")
    check(trayY - r * 1.4 > 21, "tray and resting pieces clear the bottom system-gesture edge")
    check(trayY + r * 1.1 < boxBottom, "tray back edge stays below the box")
    for slot in 0..<4 {
        let x = canvas.width / 2 - spread / 2 + spread * CGFloat(slot) / 3
        check(x - r * 1.35 > 8 && x + r * 1.35 < canvas.width - 8, "lifted pieces stay inside both screen edges")
        check(abs(x - canvas.width / 2) + r * 1.055 < dishWidth / 2, "resting star silhouette fits inside its dish")
    }
    let centers = L.holeCenters.map { CGPoint(x: $0.fx * box.width, y: $0.fy * box.height) }
    let sizes = Array(repeating: CGSize(width: r * 2.11 * 1.14, height: r * 2.02 * 1.14), count: 4)
    for i in 0..<4 {
        let capture = SleepyBoxFitGeometry.captureRadius(at: i, centers: centers, sizes: sizes)
        check(SleepyBoxFitGeometry.nearestOpening(at: centers[i], centers: centers, sizes: sizes) == i,
              "each visual opening is its own drop target")
        for j in 0..<4 where j != i {
            let other = SleepyBoxFitGeometry.captureRadius(at: j, centers: centers, sizes: sizes)
            check(capture + other < hypot(centers[i].x - centers[j].x, centers[i].y - centers[j].y),
                  "larger drop capture regions never overlap")
        }
    }
}
print("PASS: Sleepy Box shell layout, \(passed) checks")
'''
swiftc = os.environ.get("SWIFTC") or shutil.which("swiftc") or str(Path(os.environ.get("SWIFT", "swift")).with_name("swiftc"))
with tempfile.TemporaryDirectory(prefix="lull-sleepy-layout-") as directory:
    d = Path(directory)
    (d / "Layout.swift").write_text(layout)
    (d / "main.swift").write_text("import Foundation\n" + checks)
    command = (["xcrun", "swiftc"] if shutil.which("xcrun") else [swiftc]) + [
        "-module-cache-path", str(d / "cache"), str(d / "Layout.swift"), str(d / "main.swift"), "-o", str(d / "check")]
    subprocess.run(command, check=True)
    subprocess.run([str(d / "check")], check=True)
