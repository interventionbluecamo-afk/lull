#!/usr/bin/env python3
"""Check the production rest coordinator with small in-memory UI stand-ins.

This verifies lifecycle ordering and state restoration, not UIKit touch dispatch or audio.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "App/Shared/ToyViewController.swift").read_text()
coordinator = source.split("final class LullRestPlaybackSuspension {", 1)[1]
coordinator = "final class LullRestPlaybackSuspension {" + coordinator.split(
    "\nfinal class ToyViewController:", 1
)[0]

fixture = r'''
import Foundation
var events: [String] = []
class UIView {}
class UIGestureRecognizer {
    var isEnabled: Bool
    init(_ enabled: Bool) { isEnabled = enabled }
}
class SKScene {}
class BaseToyScene: SKScene {
    var suspendCount = 0
    var resumeCount = 0
    func suspendToyForRest() { suspendCount += 1; events.append("suspend scene") }
    func resumeToyAfterRest() { resumeCount += 1; events.append("resume scene") }
}
class SKView: UIView {
    var scene: SKScene?
    var isPaused = false { didSet { events.append(isPaused ? "pause view" : "resume view") } }
    var isUserInteractionEnabled = true
    var gestureRecognizers: [UIGestureRecognizer]?
}
class ToyPlayView: SKView {
    var cancelCount = 0
    func cancelActiveSceneTouches() { cancelCount += 1; events.append("cancel touches") }
}
class UIViewController {
    var viewIfLoaded: UIView?
    init(_ view: UIView?) { viewIfLoaded = view }
}
'''

checks = r'''
let scene = BaseToyScene()
let view = ToyPlayView()
view.scene = scene
let enabled = UIGestureRecognizer(true)
let disabled = UIGestureRecognizer(false)
view.gestureRecognizers = [enabled, disabled]
let rest = LullRestPlaybackSuspension(presenter: UIViewController(view))!
assert(events == ["suspend scene", "cancel touches", "pause view"])
assert(view.cancelCount == 1 && scene.suspendCount == 1)
assert(view.isPaused && !view.isUserInteractionEnabled)
assert(!enabled.isEnabled && !disabled.isEnabled)
rest.resume()
assert(scene.resumeCount == 1 && !view.isPaused && view.isUserInteractionEnabled)
assert(enabled.isEnabled && !disabled.isEnabled)
assert(events.suffix(2) == ["resume scene", "resume view"])
rest.resume()
assert(scene.resumeCount == 1)
print("PASS: cancels before pause, restores interaction/gesture states, resumes once")

let heldView = ToyPlayView()
let heldScene = BaseToyScene()
heldView.scene = heldScene
heldView.isPaused = true
heldView.isUserInteractionEnabled = false
let heldRest = LullRestPlaybackSuspension(presenter: UIViewController(heldView))!
heldRest.resume()
assert(heldView.isPaused && !heldView.isUserInteractionEnabled)
print("PASS: preserves a previously paused or disabled view")

let replacementView = ToyPlayView()
let oldScene = BaseToyScene()
replacementView.scene = oldScene
let replacedRest = LullRestPlaybackSuspension(presenter: UIViewController(replacementView))!
let newScene = BaseToyScene()
replacementView.scene = newScene
replacedRest.resume()
assert(oldScene.resumeCount == 0 && newScene.resumeCount == 0)
assert(!replacementView.isPaused && replacementView.isUserInteractionEnabled)
print("PASS: scene replacement restores its host without resuming stale scene audio")

assert(LullRestPlaybackSuspension(presenter: UIViewController(nil)) == nil)
assert(LullRestPlaybackSuspension(presenter: UIViewController(UIView())) == nil)
assert(LullRestPlaybackSuspension(presenter: UIViewController(SKView())) == nil)
print("PASS: missing and non-playable views cannot be suspended")
'''

with tempfile.TemporaryDirectory(prefix="lull-rest-check-") as directory:
    check = Path(directory) / "RestCheck.swift"
    check.write_text(fixture + coordinator + checks)
    subprocess.run([
        "/usr/bin/swift", "-module-cache-path", str(Path(directory) / "ModuleCache"), str(check)
    ], check=True)
