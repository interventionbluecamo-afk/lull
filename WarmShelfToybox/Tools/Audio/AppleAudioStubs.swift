// Minimal stand-ins for the UIKit / AVFoundation / AudioToolbox API surface that
// App/Shared/AudioManager.swift uses, so the production engine can be type-checked and its
// lifecycle exercised with any Swift toolchain (`Tools/verify_audio_lifecycle.py`).
// They record what the engine asks for; they make no sound. Signatures mirror the iOS SDK.
import Foundation

// MARK: Test clock and controls

typealias CFTimeInterval = Double
var stubClock: Double = 1000
/// Every buffer any player node was asked to schedule, in order.
var stubScheduledLog: [ObjectIdentifier] = []
func CACurrentMediaTime() -> Double { stubClock }
func mach_absolute_time() -> UInt64 { UInt64(stubClock * 1_000_000_000) }

// MARK: UIKit

final class UIApplication {
    enum State { case active, inactive, background }
    static let shared = UIApplication()
    var applicationState: State = .active
    static let willResignActiveNotification = Notification.Name("UIApplicationWillResignActive")
    static let didBecomeActiveNotification = Notification.Name("UIApplicationDidBecomeActive")
}

// MARK: AudioToolbox

typealias OSType = UInt32
typealias OSStatus = Int32
typealias AudioUnitParameterID = UInt32
typealias AudioUnitScope = UInt32
typealias AudioUnitElement = UInt32
typealias AudioUnitParameterValue = Float
final class StubAudioUnit { var parameters: [AudioUnitParameterID: Float] = [:] }
typealias AudioUnit = StubAudioUnit

let kAudioUnitType_Effect: OSType = 0x6175_6678
let kAudioUnitSubType_PeakLimiter: OSType = 0x6C6D_7472
let kAudioUnitManufacturer_Apple: OSType = 0x6170_706C
let kAudioUnitScope_Global: AudioUnitScope = 0
let kLimiterParam_AttackTime: AudioUnitParameterID = 0
let kLimiterParam_DecayTime: AudioUnitParameterID = 1
let kLimiterParam_PreGain: AudioUnitParameterID = 2

struct AudioComponentDescription {
    var componentType: OSType
    var componentSubType: OSType
    var componentManufacturer: OSType
    var componentFlags: UInt32
    var componentFlagsMask: UInt32
}

@discardableResult
func AudioUnitSetParameter(_ unit: AudioUnit, _ id: AudioUnitParameterID, _ scope: AudioUnitScope,
                           _ element: AudioUnitElement, _ value: AudioUnitParameterValue, _ offset: UInt32) -> OSStatus {
    unit.parameters[id] = value
    return 0
}

// MARK: AVFoundation

typealias AVAudioFrameCount = UInt32
typealias AVAudioNodeBus = Int
typealias AVAudioNodeCompletionHandler = () -> Void

final class AVAudioFormat {
    let sampleRate: Double
    let channelCount: UInt32
    init?(standardFormatWithSampleRate sampleRate: Double, channels: UInt32) {
        self.sampleRate = sampleRate
        channelCount = channels
    }
}

final class AVAudioPCMBuffer {
    let format: AVAudioFormat
    let frameCapacity: AVAudioFrameCount
    var frameLength: AVAudioFrameCount = 0
    private let channels: UnsafeMutablePointer<UnsafeMutablePointer<Float>>
    var floatChannelData: UnsafePointer<UnsafeMutablePointer<Float>>? { UnsafePointer(channels) }

    init?(pcmFormat format: AVAudioFormat, frameCapacity: AVAudioFrameCount) {
        self.format = format
        self.frameCapacity = frameCapacity
        channels = .allocate(capacity: Int(format.channelCount))
        for c in 0..<Int(format.channelCount) {
            channels[c] = .allocate(capacity: Int(frameCapacity))
            channels[c].initialize(repeating: 0, count: Int(frameCapacity))
        }
    }
}

final class AVAudioTime {
    let hostTime: UInt64
    init(hostTime: UInt64) { self.hostTime = hostTime }
    class func hostTime(forSeconds seconds: TimeInterval) -> UInt64 { UInt64(seconds * 1_000_000_000) }
}

class AVAudioNode {
    weak var engine: AVAudioEngine?
}

final class AVAudioMixerNode: AVAudioNode {
    private var inputs = 0
    var nextAvailableInputBus: AVAudioNodeBus {
        defer { inputs += 1 }
        return inputs
    }
}

struct AVAudioPlayerNodeBufferOptions: OptionSet {
    let rawValue: UInt
    static let loops = AVAudioPlayerNodeBufferOptions(rawValue: 1)
    static let interrupts = AVAudioPlayerNodeBufferOptions(rawValue: 2)
}

final class AVAudioPlayerNode: AVAudioNode {
    var volume: Float = 1
    var pan: Float = 0
    private(set) var isPlaying = false
    private(set) var scheduled: [(buffer: AVAudioPCMBuffer, at: AVAudioTime?, options: AVAudioPlayerNodeBufferOptions)] = []
    private(set) var stopCount = 0

    func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime?, options: AVAudioPlayerNodeBufferOptions = [],
                        completionHandler: AVAudioNodeCompletionHandler? = nil) {
        scheduled.append((buffer, when, options))
        stubScheduledLog.append(ObjectIdentifier(buffer))
    }
    func play() {
        precondition(engine?.isRunning == true, "player played while the engine is stopped")
        isPlaying = true
    }
    func stop() {
        isPlaying = false
        scheduled.removeAll()
        stopCount += 1
    }
}

class AVAudioUnit: AVAudioNode {
    let audioUnit = StubAudioUnit()
}

class AVAudioUnitEffect: AVAudioUnit {
    let description: AudioComponentDescription?
    init(audioComponentDescription: AudioComponentDescription) { description = audioComponentDescription }
    override init() { description = nil }
}

enum AVAudioUnitReverbPreset: Int { case smallRoom, mediumRoom, largeRoom, largeChamber }

final class AVAudioUnitReverb: AVAudioUnitEffect {
    var wetDryMix: Float = 0
    private(set) var preset: AVAudioUnitReverbPreset?
    func loadFactoryPreset(_ preset: AVAudioUnitReverbPreset) { self.preset = preset }
}

enum AVAudioUnitEQFilterType: Int { case parametric, lowPass, highPass, resonantLowPass, resonantHighPass, bandPass, bandStop, lowShelf, highShelf }

final class AVAudioUnitEQFilterParameters {
    var filterType: AVAudioUnitEQFilterType = .parametric
    var frequency: Float = 1000
    var bandwidth: Float = 0.5
    var gain: Float = 0
    var bypass = true
}

final class AVAudioUnitEQ: AVAudioUnitEffect {
    let bands: [AVAudioUnitEQFilterParameters]
    var globalGain: Float = 0
    init(numberOfBands: Int) {
        bands = (0..<numberOfBands).map { _ in AVAudioUnitEQFilterParameters() }
        super.init()
    }
}

enum StubAudioError: Error { case failed }

final class AVAudioEngine: NSObject {
    let mainMixerNode = AVAudioMixerNode()
    private(set) var isRunning = false
    private(set) var attached: [AVAudioNode] = []
    private(set) var connections = 0
    private(set) var starts = 0
    private(set) var pauses = 0
    var failNextStart = false

    func attach(_ node: AVAudioNode) {
        precondition(!attached.contains { $0 === node }, "node attached twice")
        node.engine = self
        attached.append(node)
    }
    func connect(_ node1: AVAudioNode, to node2: AVAudioNode, format: AVAudioFormat?) { connections += 1 }
    func connect(_ node1: AVAudioNode, to node2: AVAudioNode, fromBus bus1: AVAudioNodeBus, toBus bus2: AVAudioNodeBus,
                 format: AVAudioFormat?) { connections += 1 }
    func prepare() {}
    func start() throws {
        if failNextStart { failNextStart = false; throw StubAudioError.failed }
        isRunning = true
        starts += 1
    }
    func pause() { isRunning = false; pauses += 1 }
    func stop() { isRunning = false }
}

extension Notification.Name {
    static let AVAudioEngineConfigurationChange = Notification.Name("AVAudioEngineConfigurationChange")
}

let AVAudioSessionInterruptionTypeKey = "AVAudioSessionInterruptionTypeKey"
let AVAudioSessionInterruptionOptionKey = "AVAudioSessionInterruptionOptionKey"

final class AVAudioSession: NSObject {
    struct Category: Equatable { let name: String; static let playback = Category(name: "playback"); static let ambient = Category(name: "ambient") }
    struct Mode: Equatable { let name: String; static let `default` = Mode(name: "default") }
    struct CategoryOptions: OptionSet { let rawValue: UInt; static let mixWithOthers = CategoryOptions(rawValue: 1); static let duckOthers = CategoryOptions(rawValue: 2) }
    struct SetActiveOptions: OptionSet { let rawValue: UInt; static let notifyOthersOnDeactivation = SetActiveOptions(rawValue: 1) }
    enum InterruptionType: UInt { case began = 1, ended = 0 }
    struct InterruptionOptions: OptionSet { let rawValue: UInt; static let shouldResume = InterruptionOptions(rawValue: 1) }

    static let interruptionNotification = Notification.Name("AVAudioSessionInterruption")
    static let mediaServicesWereResetNotification = Notification.Name("AVAudioSessionMediaServicesWereReset")

    private static let instance = AVAudioSession()
    static func sharedInstance() -> AVAudioSession { instance }

    private(set) var category: Category?
    private(set) var options: CategoryOptions = []
    private(set) var isActive = false
    private(set) var activations = 0
    private(set) var deactivations = 0
    var failNextActivation = false

    func setCategory(_ category: Category, mode: Mode, options: CategoryOptions = []) throws {
        self.category = category
        self.options = options
    }
    func setPreferredSampleRate(_ rate: Double) throws {}
    func setPreferredIOBufferDuration(_ duration: TimeInterval) throws {}
    func setActive(_ active: Bool, options: SetActiveOptions = []) throws {
        if active && failNextActivation { failNextActivation = false; throw StubAudioError.failed }
        isActive = active
        if active { activations += 1 } else { deactivations += 1 }
    }
}

// MARK: App collaborators

final class LullDemoState {
    static let shared = LullDemoState()
    var isSoundEnabled = true
}

final class HapticsManager {
    static let shared = HapticsManager()
    private(set) var pulses: [String] = []
    func softTap() { pulses.append("softTap") }
    func emptyTap() { pulses.append("emptyTap") }
    func celebration() { pulses.append("celebration") }
    func blockRelease() { pulses.append("blockRelease") }
    func blockPickup() { pulses.append("blockPickup") }
    func blockSettle() { pulses.append("blockSettle") }
    func mysteryShape() { pulses.append("mysteryShape") }
}
