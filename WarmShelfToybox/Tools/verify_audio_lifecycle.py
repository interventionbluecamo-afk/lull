#!/usr/bin/env python3
"""Run production audio control paths with instrumented session/player stand-ins.

Checks preference gating, session retry, lifecycle notifications, complete voice teardown,
and cancellation of delayed notes. Physical audibility and route changes require an iPhone.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]


def block(relative, needle):
    source = (root / relative).read_text()
    start = source.index(needle)
    opening = source.index("{", start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


manager = "App/Shared/AudioManager.swift"
engine = "App/Shared/LullToneEngine.swift"
manager_methods = "\n".join(block(manager, needle) for needle in [
    "var isEnabled: Bool", "func prepareForPlayback()", "private func observeAudioLifecycle()",
    "private func deactivateAudioSession()", "private func suspendPlayback()",
    "private func silenceWindowAmbience()", "private func resumeRoomAudio()",
])
engine_methods = "\n".join(block(engine, needle) for needle in [
    "private func startIfNeeded()", "func stopAllPlayback()", "func play(_ spec: Spec",
    "func prewarm(_ spec: Spec", "func prewarmAmbient(id:", "func playSequence(_ steps:",
    "private func commitStopAmbient(id:", "func playOnceBuffer(_ buffer:",
])

standins = r'''
import Foundation
import CoreGraphics

enum TestFailure: Error { case requested }
final class LullDemoState {
    static let shared = LullDemoState()
    var isSoundEnabled = true
}
final class UIApplication {
    static let shared = UIApplication()
    enum State { case active, inactive, background }
    var applicationState = State.active
    static let willResignActiveNotification = Notification.Name("willResignActive")
    static let didBecomeActiveNotification = Notification.Name("didBecomeActive")
}
let AVAudioSessionInterruptionTypeKey = "type"
let AVAudioSessionInterruptionOptionKey = "option"
final class AVAudioSession: NSObject {
    static let shared = AVAudioSession()
    static func sharedInstance() -> AVAudioSession { shared }
    static let interruptionNotification = Notification.Name("audioInterruption")
    enum Category { case playback }
    enum Mode { case `default` }
    enum InterruptionType: UInt { case began = 1, ended = 0 }
    struct InterruptionOptions: OptionSet {
        let rawValue: UInt
        static let shouldResume = Self(rawValue: 1)
    }
    struct CategoryOptions: OptionSet {
        let rawValue: UInt
        static let mixWithOthers = Self(rawValue: 1)
    }
    struct SetActiveOptions: OptionSet {
        let rawValue: UInt
        static let notifyOthersOnDeactivation = Self(rawValue: 1)
    }
    var active = false
    var categoryCalls = 0
    var activationCalls = 0
    var shouldFail = false
    var mixEnabled = false
    func setCategory(_ category: Category, mode: Mode, options: CategoryOptions) throws {
        categoryCalls += 1
        mixEnabled = options.contains(.mixWithOthers)
        if shouldFail { throw TestFailure.requested }
    }
    func setActive(_ active: Bool, options: SetActiveOptions = []) throws {
        if active {
            activationCalls += 1
            if shouldFail { throw TestFailure.requested }
        }
        self.active = active
    }
}
final class AVAudioPlayer {
    var isPlaying = true
    var volume: Float = 0.12
    var currentTime: Double = 4
    var stopCalls = 0
    func stop() { stopCalls += 1; isPlaying = false }
}
final class AVAudioPCMBuffer {}
final class AVAudioPlayerNode {
    struct BufferOptions: OptionSet {
        let rawValue: Int
        static let interrupts = Self(rawValue: 1)
    }
    var isPlaying = false
    var volume: Float = 1
    var scheduled = 0
    var stopCalls = 0
    var completion: (() -> Void)?
    func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at: Int?, options: BufferOptions,
                        completionHandler: (() -> Void)? = nil) {
        scheduled += 1
        completion = completionHandler
    }
    func play() { isPlaying = true }
    func stop() { stopCalls += 1; isPlaying = false }
}
final class FakeEngine {
    var isRunning = false
    var shouldFail = false
    var startCalls = 0
    var detachCalls = 0
    var attached = Set<ObjectIdentifier>()
    let mainMixerNode = AVAudioPlayerNode()
    func start() throws {
        startCalls += 1
        if shouldFail { throw TestFailure.requested }
        isRunning = true
    }
    func pause() { isRunning = false }
    func attach(_ node: AVAudioPlayerNode) { attached.insert(ObjectIdentifier(node)) }
    func detach(_ node: AVAudioPlayerNode) {
        precondition(attached.remove(ObjectIdentifier(node)) != nil, "A node must detach exactly once")
        detachCalls += 1
    }
    func connect(_ node: AVAudioPlayerNode, to: AVAudioPlayerNode, format: Int) {}
}
final class AudioManager {
    static let shared = AudioManager()
    enum SoundProfile: Hashable { case recorded }
    enum WindowAmbienceChannel: Hashable { case morning, night }
    enum LullSoundVoice { case none, feed }
    private var players: [SoundProfile: [AVAudioPlayer]] = [:]
    private var lastPlayTime: [SoundProfile: TimeInterval] = [:]
    private var windowAmbiencePlayers: [WindowAmbienceChannel: AVAudioPlayer] = [:]
    private var windowAmbienceTargets: [WindowAmbienceChannel: Float] = [:]
    private var windowAmbienceFadeGen: [WindowAmbienceChannel: Int] = [:]
    private var windowAmbienceActive = false
    private var windowDayPhase: CGFloat?
    private var sessionIsActive = false
    private var applicationIsActive = UIApplication.shared.applicationState == .active
    private var audioIsInterrupted = false
    private var audioObservers: [NSObjectProtocol] = []
    var currentToyVoice = LullSoundVoice.none
    var resumedRoomVoices = 0
    var resumedWindowPhases: [CGFloat] = []
    private init() { observeAudioLifecycle() }
    func startToyAmbient(_ voice: LullSoundVoice) { if voice != .none { resumedRoomVoices += 1 } }
    func setWindowAmbience(dayPhase: CGFloat, animated: Bool) { resumedWindowPhases.append(dayPhase) }
    func seedRecorded(_ player: AVAudioPlayer, window: AVAudioPlayer) {
        players[.recorded] = [player]
        lastPlayTime[.recorded] = 3
        windowAmbiencePlayers[.morning] = window
        windowAmbienceTargets[.morning] = 0.12
        windowAmbienceFadeGen[.morning] = 7
        windowAmbienceActive = true
        windowDayPhase = 0.64
    }
    var recordedCleanupPassed: Bool {
        lastPlayTime.isEmpty && !windowAmbienceActive && windowAmbienceTargets[.morning] == 0 &&
        windowAmbienceFadeGen[.morning] == 8
    }
'''

engine_header = r'''
}
final class LullToneEngine {
    static let shared = LullToneEngine()
    struct Spec {}
    struct AmbientSpec {}
    let engine = FakeEngine()
    private let format = 0
    private var pool: [AVAudioPlayerNode] = []
    private var nextNode = 0
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var started = false
    private var playbackGeneration = 0
    private var oneShotNodes: [ObjectIdentifier: AVAudioPlayerNode] = [:]
    private var ambientNodes: [String: AVAudioPlayerNode] = [:]
    private var ambientFadeGen: [String: Int] = [:]
    var renderCalls = 0
    private init() {
        for _ in 0..<8 { let node = AVAudioPlayerNode(); engine.attach(node); pool.append(node) }
    }
    private func render(_ spec: Spec) -> AVAudioPCMBuffer? { renderCalls += 1; return AVAudioPCMBuffer() }
    private func renderAmbient(_ spec: AmbientSpec) -> AVAudioPCMBuffer? { renderCalls += 1; return AVAudioPCMBuffer() }
    func seedAmbient(_ node: AVAudioPlayerNode) {
        engine.attach(node); node.play()
        ambientNodes["held"] = node
        ambientFadeGen["held"] = 5
    }
    var scheduledNotes: Int { pool.reduce(0) { $0 + $1.scheduled } }
    var latestOneShot: AVAudioPlayerNode? { oneShotNodes.values.first }
    var teardownPassed: Bool {
        ambientNodes.isEmpty && oneShotNodes.isEmpty && !started && !engine.isRunning &&
        pool.allSatisfy { !$0.isPlaying } && ambientFadeGen["held"] == 6
    }
'''

checks = r'''
}
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
}
func runQueued(_ duration: Double = 0.04) { RunLoop.main.run(until: Date().addingTimeInterval(duration)) }
func resign() { NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil) }
func foreground() { NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil) }
func interrupt(_ type: AVAudioSession.InterruptionType, shouldResume: Bool = false) {
    NotificationCenter.default.post(name: AVAudioSession.interruptionNotification,
                                    object: AVAudioSession.sharedInstance(),
                                    userInfo: [AVAudioSessionInterruptionTypeKey: type.rawValue,
                                               AVAudioSessionInterruptionOptionKey: shouldResume ? UInt(1) : UInt(0)])
}
let manager = AudioManager.shared
let tone = LullToneEngine.shared
let session = AVAudioSession.sharedInstance()
let spec = LullToneEngine.Spec()
manager.isEnabled = false
let initialActivations = session.activationCalls
tone.prewarm(spec, cacheKey: "warm")
tone.prewarmAmbient(id: "warm-room", spec: LullToneEngine.AmbientSpec())
tone.prewarm(spec, cacheKey: "warm")
check(tone.renderCalls == 2, "Warming renders each uncached buffer once, even with Sound Off")
check(session.activationCalls == initialActivations && tone.engine.startCalls == 0,
      "Prewarming never activates playback")
tone.play(spec, cacheKey: "blocked")
tone.playOnceBuffer(AVAudioPCMBuffer(), volume: 0.1)
check(tone.scheduledNotes == 0 && tone.latestOneShot == nil, "Saved Sound Off blocks direct synth and one-shot calls")

session.shouldFail = true
manager.isEnabled = true
check(!manager.prepareForPlayback(), "Activation failure does not claim readiness")
session.shouldFail = false
check(manager.prepareForPlayback(), "A later interaction retries the session successfully")
check(session.mixEnabled, "The playback category keeps the family's other audio mixing")
let activeCalls = session.activationCalls
check(manager.prepareForPlayback() && session.activationCalls == activeCalls, "An active session is reused")
tone.engine.shouldFail = true
tone.play(spec, cacheKey: "warm")
check(tone.scheduledNotes == 0, "An engine failure cannot schedule into a stopped graph")
tone.engine.shouldFail = false
tone.play(spec, cacheKey: "warm")
check(tone.scheduledNotes == 1, "A later gesture retries a failed engine start")

let recorded = AVAudioPlayer(), window = AVAudioPlayer(), held = AVAudioPlayerNode()
manager.seedRecorded(recorded, window: window)
tone.seedAmbient(held)
tone.playOnceBuffer(AVAudioPCMBuffer(), volume: 0.1)
let oneShot = tone.latestOneShot!
tone.playSequence([(spec: spec, delay: 0.15, cacheKey: "old-celebration")])
manager.isEnabled = false
check(!recorded.isPlaying && recorded.currentTime == 0, "Sound Off stops existing recorded effects immediately")
check(!window.isPlaying && window.volume == 0 && window.currentTime == 0,
      "Sound Off silences recorded Window loops immediately")
check(manager.recordedCleanupPassed, "Sound Off invalidates Window fades and clears interaction cooldowns")
check(!held.isPlaying && !oneShot.isPlaying && tone.teardownPassed,
      "Sound Off stops pooled, held and temporary synth voices and pauses the engine")
let detachCount = tone.engine.detachCalls
oneShot.completion?()
runQueued()
check(tone.engine.detachCalls == detachCount, "A stale one-shot completion cannot detach a stopped node twice")
let notesBeforeResume = tone.scheduledNotes
manager.currentToyVoice = .feed
manager.isEnabled = true
runQueued(0.22)
check(tone.scheduledNotes == notesBeforeResume, "Switching Sound back on cannot resurrect a cancelled celebration")
check(manager.resumedRoomVoices == 1 && manager.resumedWindowPhases.last == 0.64,
      "Sound On resumes room ambience at the current Window phase")

tone.play(spec, cacheKey: "warm")
resign()
let notesBeforeInactive = tone.scheduledNotes
check(!session.active && !manager.prepareForPlayback(), "Inactive app releases the session and rejects playback")
tone.play(spec, cacheKey: "inactive")
check(tone.scheduledNotes == notesBeforeInactive, "Synth calls cannot start audio while the app is inactive")
foreground()
check(session.active && manager.prepareForPlayback(), "Foreground reactivates an enabled session")
tone.play(spec, cacheKey: "warm")
check(tone.scheduledNotes == notesBeforeInactive + 1, "Fresh gestures play after a foreground return")

interrupt(.began)
let notesBeforeInterruption = tone.scheduledNotes
tone.play(spec, cacheKey: "interrupted")
foreground()
check(!manager.prepareForPlayback() && tone.scheduledNotes == notesBeforeInterruption,
      "An interruption blocks playback even if a foreground notification arrives")
let roomsBeforeEnd = manager.resumedRoomVoices
interrupt(.ended)
check(manager.resumedRoomVoices == roomsBeforeEnd, "Without shouldResume, an interruption end does not autoplay")
tone.play(spec, cacheKey: "warm")
check(tone.scheduledNotes == notesBeforeInterruption + 1, "A new gesture can recover after an interruption ends")
interrupt(.began)
interrupt(.ended, shouldResume: true)
check(manager.resumedRoomVoices == roomsBeforeEnd + 1, "A permitted interruption end restores the room bed")
manager.isEnabled = false
resign()
foreground()
interrupt(.began)
interrupt(.ended, shouldResume: true)
check(!session.active && !manager.prepareForPlayback() && !LullDemoState.shared.isSoundEnabled,
      "Lifecycle recovery never overrides the parent's saved Sound Off preference")
print("PASS: \(checks) production audio preference, retry, lifecycle and cancellation checks; physical audibility still requires device testing")
'''

with tempfile.TemporaryDirectory(prefix="lull-audio-verification-") as temporary:
    directory = Path(temporary)
    source = directory / "AudioLifecycle.swift"
    source.write_text(standins + manager_methods + engine_header + engine_methods + checks)
    toolchain = ["xcrun", "swift"] if shutil.which("xcrun") else [os.environ.get("SWIFT", "swift")]
    subprocess.run(toolchain + ["-module-cache-path", str(directory / "ModuleCache"), str(source)], check=True)
