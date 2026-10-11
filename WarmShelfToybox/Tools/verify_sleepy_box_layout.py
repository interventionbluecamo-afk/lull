#!/usr/bin/env python3
"""Sleepy Box sockets sit on the shell's front face (founder, October 11: the holes didn't line up
realistically with the box; the top row ran up onto the lid).

Compiles the production `SleepyBoxShellLayout` and checks, as fractions of the shell plate, that
every socket (bevel included) stays on the measured front face, below the lid and above the face,
that rows and columns never touch, and that the face sits clear of the sockets and the drawer.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
scene = (root / "App/Toys/SleepyDropBox/SleepyDropBoxScene.swift").read_text()
layout = "import Foundation\n" + scene[scene.index("enum SleepyBoxShellLayout {"):]
checks = r'''
var passed = 0
func check(_ ok: Bool, _ what: String) {
    if !ok { print("FAIL: " + what); exit(1) }
    passed += 1
}
typealias L = SleepyBoxShellLayout
// The plate is 1065 x 946: height is 0.888 of width.
let heightOverWidth: CGFloat = 946.0 / 1065.0
let halfSpanY = L.socketSpanInRadii * L.maxPieceRadius / 2
let halfSpanX = halfSpanY * heightOverWidth
check(L.holeCenters.count == 4, "four sockets")
for h in L.holeCenters {
    check(h.fy - halfSpanY >= L.frontFaceTop, "no socket runs onto the lid")
    check(h.fy + halfSpanY <= L.holeBandBottom + 0.001, "sockets stay above the face")
    check(h.fx - halfSpanX >= 0.04 && h.fx + halfSpanX <= 0.96, "sockets stay inside the box's sides")
}
check(L.rowFy[1] - L.rowFy[0] >= 2 * halfSpanY + 0.015, "a strip of wood between the two rows")
check(L.columnFx[1] - L.columnFx[0] >= 2 * halfSpanX + 0.05, "the two columns have wood between them")
check(abs((L.columnFx[0] + L.columnFx[1]) / 2 - 0.5) < 0.001, "the grid is centred on the face")
// The face draws about +-0.2 of its 0.20-plate-height box around its anchor.
let faceHalf: CGFloat = 0.20 * 0.2
check(L.faceFy - faceHalf > L.holeBandBottom, "the face sits below the sockets")
check(L.faceFy + faceHalf < L.drawerRecessTop, "the face sits above the drawer")
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
