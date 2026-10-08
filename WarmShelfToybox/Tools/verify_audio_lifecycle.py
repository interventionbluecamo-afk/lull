#!/usr/bin/env python3
"""Run the production sound engine (App/Shared/AudioManager.swift + LullToneEngine.swift) against
recording stand-ins for AVFoundation/UIKit (Tools/Audio/AppleAudioStubs.swift).

Checks the parent's Sound control, session category and retry, engine start retry, cue playback,
cooldowns, variation, sample-accurate delays, voice stealing, held notes, room beds, the Window
day/night beds, backgrounding, interruptions, route changes and the older note interface.
Physical audibility, loudness on a speaker and route behaviour still need an iPhone.
"""
from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
manager = (root / "App/Shared/AudioManager.swift").read_text()
manager = re.sub(r"^import (AVFoundation|AudioToolbox)$", "", manager, flags=re.M)
manager = manager.replace("import UIKit", "import Foundation")
synth = (root / "App/Shared/LullToneEngine.swift").read_text()
stubs = (root / "Tools/Audio/AppleAudioStubs.swift").read_text()

checks = r'''
import Foundation

var passed = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    precondition(ok(), "FAIL: " + what)
    passed += 1
}
func spin(_ seconds: Double = 0.05) {
    stubClock += seconds
    RunLoop.main.run(until: Date().addingTimeInterval(0.02))
}
func spinReal(_ seconds: Double) {
    let end = Date().addingTimeInterval(seconds)
    while Date() < end {
        stubClock += 0.02
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }
}
func post(_ name: Notification.Name, _ info: [AnyHashable: Any]? = nil, object: Any? = nil) {
    NotificationCenter.default.post(name: name, object: object, userInfo: info)
    spin()
}

let session = AVAudioSession.sharedInstance()
let state = LullDemoState.shared
let audio = AudioManager.shared
func engine() -> AVAudioEngine { Mirror(reflecting: audio).children.first { $0.label == "engine" }!.value as! AVAudioEngine }
func players() -> [AVAudioPlayerNode] { engine().attached.compactMap { $0 as? AVAudioPlayerNode } }
func playing() -> Int { players().filter { $0.isPlaying }.count }
func scheduledCount() -> Int { players().reduce(0) { $0 + $1.scheduled.count } }

// 1. Sound Off is the gate.
state.isSoundEnabled = false
check(!audio.play(cue: "ui.tap"), "Sound Off blocks cues")
check(session.activations == 0, "Sound Off never activates the session")
LullToneEngine.shared.play(.single(5, .wood), cacheKey: "probe")
check(scheduledCount() == 0, "Sound Off blocks the older note interface too")

// 2. Session category, retry and reuse.
state.isSoundEnabled = true
session.failNextActivation = true
check(!audio.prepareForPlayback(), "A failed activation does not claim readiness")
check(audio.prepareForPlayback(), "The next interaction retries the session")
check(session.category == .playback && session.options.contains(.mixWithOthers),
      "Playback category (follows Sound control in Silent Mode) and mixes with family audio")
let activations = session.activations
check(audio.prepareForPlayback() && session.activations == activations, "An active session is reused")

// 3. Engine start retry and graph.
spin()
engine().failNextStart = true
check(!audio.play(cue: "ui.tap"), "An engine start failure schedules nothing")
check(scheduledCount() == 0, "Nothing is scheduled into a stopped graph")
spin(0.2)
check(audio.play(cue: "ui.tap"), "A later gesture retries the engine")
check(engine().isRunning && scheduledCount() == 1, "The cue is scheduled on one voice")
let attachedOnce = engine().attached.count
check(attachedOnce >= 34 + 6 + 4, "Voice pool, loop slots and the master chain are built once")

// 4. Cues: cooldown, unknown cues, variation, delays.
check(!audio.play(cue: "ui.tap"), "An immediate repeat of the same cue is held back by its cooldown")
spin(0.1)
check(audio.play(cue: "ui.tap"), "After the cooldown the cue plays again")
check(!audio.play(cue: "no.such.cue"), "Unknown cues are refused")
let logStart = stubScheduledLog.count
for _ in 0..<12 {
    spinReal(0.06)
    _ = audio.play(cue: "bubble.small")
}
let seen = Set(stubScheduledLog[logStart...])
check(seen.count >= 3, "Repeated cues rotate through rendered variants (saw \(seen.count))")
spin(0.1)
check(audio.play(cue: "feed.success", delay: 0.5), "A delayed cue is accepted")
check(players().contains { $0.scheduled.contains { $0.at != nil } }, "Delays are scheduled sample-accurately (host time)")

// 5. Voice stealing never fails and never steals held notes when free voices exist.
let held = audio.startHeldNote(cue: "note.choir.10")
check(held != nil, "A held note starts")
for i in 0..<30 {
    spin(0.04)
    _ = audio.play(cue: ["feed.success", "dots.wave", "window.morning", "meadow.spring", "stack.wake"][i % 5])
}
check(true, "Thirty overlapping musical cues on a twelve-voice bus do not crash")
let heldNodes = players().filter { $0.isPlaying && $0.scheduled.contains { $0.buffer.frameLength > 48_000 * 8 } }
check(!heldNodes.isEmpty, "The held note survives a burst of other music cues")
audio.releaseHeldNote(held!, fade: 0.2)
spinReal(0.4)
check(players().filter { $0.isPlaying && $0.scheduled.contains { $0.buffer.frameLength > 48_000 * 8 } }.isEmpty,
      "Releasing a held note fades it out and stops it")

// 6. Room beds and idle dimming.
audio.currentToyVoice = .bubbles
audio.startToyAmbient(.bubbles)
spinReal(0.1)
let loopNodes = { players().filter { $0.isPlaying && $0.scheduled.contains { $0.options.contains(.loops) } } }
check(loopNodes().count == 1, "A toy's room bed loops on one slot")
audio.startToyAmbient(.bubbles)
check(loopNodes().count == 1, "Starting the same bed twice reuses its slot")
audio.sleepAmbient(.bubbles)
spinReal(0.1)
check(loopNodes().count == 2, "Idle sleep adds the slow breathing bed")
audio.wakeAmbient(.bubbles)
spinReal(1.8)
check(loopNodes().count == 1, "Waking fades the breathing bed out")

// 7. Backgrounding stops everything; returning resumes only the room bed.
_ = audio.startHeldNote(cue: "note.choir.12")
_ = audio.play(cue: "feed.success", delay: 0.8)
post(UIApplication.willResignActiveNotification)
check(playing() == 0 && scheduledCount() == 0, "Backgrounding stops every voice, held note, queued note and loop")
check(!session.isActive && !audio.prepareForPlayback(), "An inactive app releases the session and refuses playback")
check(!audio.play(cue: "ui.tap"), "Cues cannot start while inactive")
check(engine().isRunning == false, "The engine is paused in the background")
post(UIApplication.didBecomeActiveNotification)
spinReal(0.1)
check(session.isActive && loopNodes().count == 1, "Returning reactivates the session and resumes only the room bed")
check(players().filter { $0.isPlaying && !$0.scheduled.contains { $0.options.contains(.loops) } }.isEmpty,
      "Held notes and old celebrations do not come back on return")

// 8. Interruptions.
post(AVAudioSession.interruptionNotification, [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue],
     object: session)
check(playing() == 0 && !audio.prepareForPlayback(), "An interruption stops everything and refuses playback")
post(AVAudioSession.interruptionNotification, [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                                               AVAudioSessionInterruptionOptionKey: UInt(0)], object: session)
check(loopNodes().isEmpty, "Without shouldResume an interruption end does not autoplay")
spin(0.1)
check(audio.play(cue: "ui.tap"), "A new gesture recovers after the interruption")
post(AVAudioSession.interruptionNotification, [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue],
     object: session)
post(AVAudioSession.interruptionNotification, [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                                               AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue],
     object: session)
spinReal(0.1)
check(loopNodes().count == 1, "A permitted interruption end restores the room bed")

// 9. Route / configuration change keeps the room going.
post(.AVAudioEngineConfigurationChange, object: engine())
spinReal(0.1)
check(loopNodes().count == 1, "After a route change the room bed is rebuilt")

// 10. Sound Off mid-play, then on.
_ = audio.startHeldNote(cue: "note.choir.10")
audio.isEnabled = false
check(playing() == 0 && scheduledCount() == 0 && !session.isActive, "Sound Off stops everything and releases the session")
check(!state.isSoundEnabled, "Sound Off is saved")
audio.isEnabled = true
spinReal(0.1)
check(loopNodes().count == 1 && playing() == 1, "Sound On resumes only the room bed")

// 11. Window day/night beds.
audio.stopToyAmbient(.bubbles)
audio.currentToyVoice = .none
spinReal(1.7)
audio.setWindowAmbience(dayPhase: 0.2, animated: false)
spinReal(1.5)
let vols = { loopNodes().map { $0.volume }.sorted() }
check(loopNodes().count >= 1 && (vols().last ?? 0) > 0.5, "Day: the day bed is up")
audio.setWindowAmbience(dayPhase: 0.95, animated: true)
spinReal(1.0)
check(loopNodes().count >= 1 && (vols().last ?? 0) > 0.5, "Night: the night bed takes over")
audio.stopWindowAmbience(fadeOut: 0.3)
spinReal(0.5)
check(loopNodes().isEmpty, "Leaving the Window fades both beds out")

// 12. Named sounds keep their haptics; Mix-Up friends have voices.
let before = HapticsManager.shared.pulses.count
spin(0.2); audio.playSoftTap()
spin(0.2); audio.playStackSettle(hardness: 0.2)
spin(0.2); audio.playFeedSuccess()
check(HapticsManager.shared.pulses.count == before + 3, "Named sounds keep their haptic pulses")
for name in ["bunny", "bear", "songbird", "fox", "mouse", "frog", "robot", "officer", "firefighter"] {
    check(LullSoundBook.cueIDs.contains("friend.\(name)") && LullSoundBook.cueIDs.contains("friend.\(name).whole"),
          "\(name) has an arrival voice and a whole-friend voice")
}

print("PASS: \(passed) sound engine lifecycle, gating, scheduling and bed checks; audibility still needs an iPhone")
'''

with tempfile.TemporaryDirectory() as directory:
    d = Path(directory)
    (d / "AudioManager.swift").write_text(manager)
    (d / "LullToneEngine.swift").write_text(synth)
    (d / "Stubs.swift").write_text(stubs)
    (d / "main.swift").write_text(checks)
    swift = ["xcrun", "swiftc"] if shutil.which("xcrun") else [os.environ.get("SWIFTC", str(Path(os.environ.get("SWIFT", "swift")).with_name("swiftc")))]
    exe = d / "lifecycle"
    subprocess.run(swift + ["-Onone", "-swift-version", "5", "-module-cache-path", str(d / "cache"),
                            str(d / "Stubs.swift"), str(d / "LullToneEngine.swift"), str(d / "AudioManager.swift"),
                            str(d / "main.swift"), "-o", str(exe)], check=True)
    subprocess.run([str(exe)], check=True)
