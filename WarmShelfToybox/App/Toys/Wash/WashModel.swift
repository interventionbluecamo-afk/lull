import CoreGraphics
import Foundation

/// Coordinates are fractions of the vehicle canvas, with y measured from its top.
struct WashPoint: Equatable {
    var x: Double
    var y: Double
}

enum WashTool: String, CaseIterable {
    case sponge, hose

    var mudMultiplier: Double {
        switch self {
        case .sponge: return 1
        case .hose: return 1.6
        }
    }
}

enum WashVehicleKind: String, CaseIterable {
    case fireTruck
    case policeCar
    case tractor
    case schoolBus
    case digger
    case iceCreamVan
    case garbageTruck
    case mailTruck
    case camper
    case towTruck
    case ambulance
    case helicopter

    var isFlying: Bool { self == .helicopter }
    static var roadVehicles: [Self] { allCases.filter { !$0.isFlying } }

    var imageName: String {
        switch self {
        case .fireTruck: return "wash-fire-truck"
        case .policeCar: return "wash-police-car"
        case .tractor: return "wash-tractor"
        case .schoolBus: return "wash-school-bus"
        case .digger: return "wash-digger"
        case .iceCreamVan: return "wash-ice-cream-van"
        case .garbageTruck: return "wash-garbage-truck"
        case .mailTruck: return "wash-mail-truck"
        case .camper: return "wash-camper"
        case .towTruck: return "wash-tow-truck"
        case .ambulance: return "wash-ambulance"
        case .helicopter: return "wash-helicopter"
        }
    }
    var spokenName: String {
        switch self {
        case .fireTruck: return "fire truck"
        case .policeCar: return "police car"
        case .tractor: return "tractor"
        case .schoolBus: return "school bus"
        case .digger: return "digger"
        case .iceCreamVan: return "ice cream van"
        case .garbageTruck: return "garbage truck"
        case .mailTruck: return "mail truck"
        case .camper: return "camper van"
        case .towTruck: return "tow truck"
        case .ambulance: return "ambulance"
        case .helicopter: return "helicopter"
        }
    }
}

struct WashMudPatch: Equatable {
    let center: WashPoint
    let radius: Double
    var dirt: Double = 1
    var foam: Double = 0
    var wetness: Double = 0
}

struct WashStrokeResult {
    let affectedPatches: Int
    let removedMud: Double
    let addedFoam: Double
}

/// The production cleaning state; rendering and timing ownership belong to WashScene.
/// Every patch begins with a unit of mud. Never drop a difficult patch from the denominator.
struct WashModel {
    static let foamLifetime: Double = 7
    static let cleanThreshold: Double = 0.93
    private(set) var patches: [WashMudPatch]
    /// Distance is measured in canvas-height units, keeping a brush circular in world space.
    let canvasAspectRatio: Double

    init(patches: [WashMudPatch], canvasAspectRatio: Double = 1.6) {
        self.canvasAspectRatio = canvasAspectRatio.isFinite && canvasAspectRatio > 0
            ? canvasAspectRatio : 1.6
        self.patches = patches.map { patch in
            var p = patch
            p.dirt = p.dirt.isFinite ? Self.unit(p.dirt) : 1
            p.foam = Self.unit(p.foam)
            p.wetness = Self.unit(p.wetness)
            return p
        }
    }

    var cleanFraction: Double {
        guard !patches.isEmpty else { return 0 }
        return 1 - patches.reduce(0) { $0 + $1.dirt } / Double(patches.count)
    }
    var foamFraction: Double {
        guard !patches.isEmpty else { return 0 }
        return patches.reduce(0) { $0 + $1.foam } / Double(patches.count)
    }
    /// The mud decides. Foam no longer gates the finish: a toddler who keeps scrubbing used to
    /// keep re-foaming and never reach it, or wait up to seven silent seconds for foam to fade
    /// (build 7 jury review). The finale melts the last foam and specks away (`settleFinish`).
    var isComplete: Bool {
        !patches.isEmpty && cleanFraction >= Self.cleanThreshold
    }

    /// A smooth, compact falloff: no dirt is changed outside the brush's footprint.
    static func falloff(distance: Double, radius: Double) -> Double {
        guard distance.isFinite, radius.isFinite, distance >= 0, radius > 0,
              distance < radius else { return 0 }
        let remaining = 1 - pow(distance / radius, 2)
        return remaining * remaining
    }

    /// Radius is a fraction of canvas HEIGHT. Strength is mud removed at the centre of one sampled stroke. The scene should scale
    /// it by measured movement/time, cap frame deltas, and avoid advancing a suspended toy.
    @discardableResult
    mutating func applyStroke(at point: WashPoint, radius: Double,
                              strength: Double = 0.18, tool: WashTool = .sponge) -> WashStrokeResult {
        guard point.x.isFinite, point.y.isFinite, strength.isFinite, strength > 0,
              radius.isFinite, radius > 0 else {
            return WashStrokeResult(affectedPatches: 0, removedMud: 0, addedFoam: 0)
        }
        var affected = 0
        var removed = 0.0
        var added = 0.0
        for index in patches.indices {
            let p = patches[index].center
            let distance = hypot((p.x - point.x) * canvasAspectRatio, p.y - point.y)
            let amount = min(1, strength) * Self.falloff(distance: distance, radius: radius)
            guard amount > 0 else { continue }
            affected += 1
            let beforeDirt = patches[index].dirt
            let beforeFoam = patches[index].foam
            patches[index].dirt = max(0, beforeDirt - amount * tool.mudMultiplier)
            let lifted = beforeDirt - patches[index].dirt
            removed += lifted
            switch tool {
            case .sponge:
                // Foam comes from mud: a clean patch scrubbed again stays clean, not freshly foamed.
                patches[index].foam = Self.unit(beforeFoam + lifted * 0.9 + amount * 0.18 * beforeDirt)
                patches[index].wetness = Self.unit(patches[index].wetness + amount * 0.08)
            case .hose:
                patches[index].foam = max(0, beforeFoam - amount * 2.8)
                patches[index].wetness = Self.unit(patches[index].wetness + amount * 0.65)
            }
            added += max(0, patches[index].foam - beforeFoam)
        }
        return WashStrokeResult(affectedPatches: affected, removedMud: removed, addedFoam: added)
    }

    /// The finale: the last foam, water and specks melt away together in about 0.6 s.
    mutating func settleFinish(by seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        let step = seconds / 0.6
        for index in patches.indices {
            patches[index].foam = max(0, patches[index].foam - step)
            patches[index].wetness = max(0, patches[index].wetness - step)
            patches[index].dirt = max(0, patches[index].dirt - step)
        }
    }

    /// Full-strength foam disappears in seven seconds without requiring another tool.
    mutating func advanceTime(by seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        for index in patches.indices {
            patches[index].foam = max(0, patches[index].foam - seconds / Self.foamLifetime)
            patches[index].wetness = max(0, patches[index].wetness - seconds / 3.5)
        }
    }

    /// Accessible activation cleans one quarter, including its foam; four activations suffice.
    /// Choose the dirtiest remaining patches so repeated activations always make progress.
    mutating func cleanQuarter() {
        guard !patches.isEmpty else { return }
        let ordered = patches.indices.sorted {
            if patches[$0].dirt == patches[$1].dirt { return $0 < $1 }
            return patches[$0].dirt > patches[$1].dirt
        }
        let remaining = ordered.filter { patches[$0].dirt > 0 || patches[$0].foam > 0 }
        for index in remaining.prefix(Int(ceil(Double(patches.count) / 4))) {
            patches[index].dirt = 0
            patches[index].foam = 0
            patches[index].wetness = 0
        }
    }

    private static func unit(_ value: Double) -> Double {
        value.isFinite ? max(0, min(1, value)) : 0
    }
}

/// A seeded road-vehicle shuffle bag preserves variety and survives rotation.
/// The helicopter is an occasional extra visit after four completed washes; it never
/// displaces a road vehicle from the bag, and it cannot visit twice in a row.
struct WashCastDeck {
    private var state: UInt64
    private var remaining: [WashVehicleKind] = []
    private var previous: WashVehicleKind?
    private var previousRoad: WashVehicleKind?
    private(set) var completedWashes = 0

    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func recordCompletion() {
        if completedWashes < Int.max { completedWashes += 1 }
    }

    mutating func next() -> WashVehicleKind {
        if completedWashes >= 4, previous != .helicopter, randomWord() % 6 == 0 {
            previous = .helicopter
            return .helicopter
        }
        if remaining.isEmpty {
            remaining = WashVehicleKind.roadVehicles
            for index in stride(from: remaining.count - 1, through: 1, by: -1) {
                remaining.swapAt(index, Int(randomWord() % UInt64(index + 1)))
            }
            if remaining.last == previousRoad {
                remaining.swapAt(remaining.count - 1, 0)
            }
        }
        let kind = remaining.removeLast()
        previous = kind
        previousRoad = kind
        return kind
    }

    private mutating func randomWord() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

struct WashWheelRig: Equatable {
    let center: WashPoint
    /// Radius is a fraction of canvas HEIGHT, not width.
    let radius: Double
}

struct WashVehicleRig {
    let faceCenter: WashPoint
    /// Radius is a fraction of canvas HEIGHT. Vehicle canvases are 1600 × 1000.
    let faceRadius: Double
    let wheels: [WashWheelRig]
    /// True for rigs measured from the preserved native artwork.
    let isMeasured: Bool
    /// Main rotor hub, in the same top-origin canvas coordinates as the face.
    var rotorCenter: WashPoint? = nil
    /// Width of the rotor's complete padded canvas as a fraction of vehicle canvas width.
    var rotorWidth: Double = 0.75

    static func forVehicle(_ kind: WashVehicleKind) -> WashVehicleRig {
        switch kind {
        case .fireTruck:
            return WashVehicleRig(
                faceCenter: WashPoint(x: 0.71899299, y: 0.36888544), faceRadius: 0.07182816,
                wheels: [
                    WashWheelRig(center: WashPoint(x: 0.28777890, y: 0.75631164), radius: 0.12368836),
                    WashWheelRig(center: WashPoint(x: 0.70474975, y: 0.75591098), radius: 0.12408902),
                ], isMeasured: true)
        case .policeCar:
            return WashVehicleRig(
                faceCenter: WashPoint(x: 0.54336735, y: 0.35793481), faceRadius: 0.06778844,
                wheels: [
                    WashWheelRig(center: WashPoint(x: 0.28854044, y: 0.75706822), radius: 0.12293178),
                    WashWheelRig(center: WashPoint(x: 0.72147976, y: 0.75849460), radius: 0.12150540),
                ], isMeasured: true)
        case .tractor:
            return WashVehicleRig(
                faceCenter: WashPoint(x: 0.38781431, y: 0.30428523), faceRadius: 0.07839910,
                wheels: [
                    WashWheelRig(center: WashPoint(x: 0.29628441, y: 0.71432942), radius: 0.16567058),
                    WashWheelRig(center: WashPoint(x: 0.74659196, y: 0.75935367), radius: 0.12064633),
                ], isMeasured: true)
        case .schoolBus:
            return WashVehicleRig(
                faceCenter: WashPoint(x: 0.72864450, y: 0.40449020), faceRadius: 0.07201046,
                wheels: [
                    WashWheelRig(center: WashPoint(x: 0.30138161, y: 0.77212696), radius: 0.10787304),
                    WashWheelRig(center: WashPoint(x: 0.72334925, y: 0.76977334), radius: 0.11022666),
                ], isMeasured: true)
        case .digger:
            return WashVehicleRig(
                faceCenter: WashPoint(x: 0.38797954, y: 0.42263636), faceRadius: 0.07363636,
                wheels: [
                    WashWheelRig(center: WashPoint(x: 0.25419409, y: 0.78425957), radius: 0.09574043),
                    WashWheelRig(center: WashPoint(x: 0.51525321, y: 0.79097097), radius: 0.08902903),
                ], isMeasured: true)
        case .iceCreamVan:
            return WashVehicleRig(
                faceCenter: WashPoint(x: 0.72712766, y: 0.38724263), faceRadius: 0.07492971,
                wheels: [
                    WashWheelRig(center: WashPoint(x: 0.29682172, y: 0.75727581), radius: 0.12272419),
                    WashWheelRig(center: WashPoint(x: 0.71206662, y: 0.75755859), radius: 0.12244141),
                ], isMeasured: true)
        case .garbageTruck:
            return WashVehicleRig(
                faceCenter: WashPoint(x: 0.73458384, y: 0.44894407), faceRadius: 0.05434909,
                wheels: [
                    WashWheelRig(center: WashPoint(x: 0.32146526, y: 0.75686835), radius: 0.12313165),
                    WashWheelRig(center: WashPoint(x: 0.73428810, y: 0.76414213), radius: 0.11585787),
                ], isMeasured: true)
        case .mailTruck:
            return WashVehicleRig(
                faceCenter: WashPoint(x: 0.68210306, y: 0.38926836), faceRadius: 0.06764860,
                wheels: [
                    WashWheelRig(center: WashPoint(x: 0.25308087, y: 0.76425455), radius: 0.11574545),
                    WashWheelRig(center: WashPoint(x: 0.73792026, y: 0.76420480), radius: 0.11579520),
                ], isMeasured: true)
        case .camper:
            return WashVehicleRig(
                faceCenter: WashPoint(x: 0.69923322, y: 0.38842065), faceRadius: 0.05121363,
                wheels: [
                    WashWheelRig(center: WashPoint(x: 0.29785442, y: 0.75556214), radius: 0.12443786),
                    WashWheelRig(center: WashPoint(x: 0.70516709, y: 0.75319399), radius: 0.12680601),
                ], isMeasured: true)
        case .towTruck:
            return WashVehicleRig(
                faceCenter: WashPoint(x: 0.65296607, y: 0.37909038), faceRadius: 0.06491773,
                wheels: [
                    WashWheelRig(center: WashPoint(x: 0.30181224, y: 0.75078247), radius: 0.12921753),
                    WashWheelRig(center: WashPoint(x: 0.74080488, y: 0.75331052), radius: 0.12668948),
                ], isMeasured: true)
        case .ambulance:
            return WashVehicleRig(
                faceCenter: WashPoint(x: 0.66813851, y: 0.33723105), faceRadius: 0.06759765,
                wheels: [
                    WashWheelRig(center: WashPoint(x: 0.28987049, y: 0.72659756), radius: 0.15340244),
                    WashWheelRig(center: WashPoint(x: 0.72253096, y: 0.72967189), radius: 0.15032811),
                ], isMeasured: true)
        case .helicopter:
            return WashVehicleRig(
                faceCenter: WashPoint(x: 0.73166638, y: 0.43759272), faceRadius: 0.08469188,
                wheels: [
                ], isMeasured: true,
                rotorCenter: WashPoint(x: 0.60075994, y: 0.12729920), rotorWidth: 0.75000000)
        }
    }
}

/// A wide vehicle stays wide in either orientation. Portrait moves the wash into the middle
/// of the floor instead of letting the landscape background push it down beside the tools.
struct WashLayout {
    let tray: CGRect
    let canvas: CGSize
    let vehicleHome: CGPoint
    let toolCenters: [CGPoint]
    let toolSide: CGFloat

    init(screen: CGSize, play: CGRect) {
        let landscape = screen.width > screen.height
        let trayHeight = min(112, max(74, play.height * 0.18))
        let trayWidth = landscape ? min(104, play.width * 0.18) : min(play.width * 0.76, 360)
        let traySize = landscape
            ? CGSize(width: trayWidth, height: min(play.height * 0.83, 236))
            : CGSize(width: trayWidth, height: trayHeight)
        let trayCenter = landscape
            ? CGPoint(x: play.maxX - trayWidth / 2, y: play.midY)
            : CGPoint(x: play.midX, y: play.minY + trayHeight / 2 + 5)
        tray = CGRect(x: trayCenter.x - traySize.width / 2, y: trayCenter.y - traySize.height / 2,
                      width: traySize.width, height: traySize.height)
        let availableHeight = landscape ? play.height * 0.96 : max(90, play.maxY - tray.maxY - 20)
        let availableWidth = landscape ? max(100, play.width - trayWidth - 25) : play.width
        // The authored road bodies use the middle 80% of their transparent canvas. Even
        // the helicopter's wider rotor remains onscreen with this small portrait increase.
        let width = min(availableWidth * (landscape ? 0.96 : 1.10), availableHeight * 1.6,
                        landscape ? 830 : 900)
        canvas = CGSize(width: width, height: width / 1.6)
        if landscape {
            vehicleHome = CGPoint(x: play.minX + availableWidth / 2, y: play.midY)
        } else {
            let lowest = tray.maxY + 20
            let highest = max(lowest, play.maxY - canvas.height * WashBayFit.wheelGroundFy)
            let ground = min(highest, max(lowest, screen.height * 0.34))
            vehicleHome = CGPoint(x: play.midX, y: ground + canvas.height * (WashBayFit.wheelGroundFy - 0.5))
        }
        toolSide = min(traySize.width, trayHeight) * 0.76
        toolCenters = [CGFloat(-0.24), CGFloat(0.24)].map { offset in
            landscape ? CGPoint(x: trayCenter.x, y: trayCenter.y - offset * traySize.height)
                : CGPoint(x: trayCenter.x + offset * traySize.width, y: trayCenter.y)
        }
    }
}

/// Where the painted bay stands so a vehicle's wheels rest on its floor (founder, October 11:
/// vehicles floated above the ground, a lot in portrait and a little in landscape). Measured on
/// wash-bay.png: the wall meets the floor at 0.61 of the picture's height, and a vehicle standing
/// mid-bay touches the floor at 0.79. Scene coordinates, y up.
enum WashBayFit {
    static let floorContactFy: CGFloat = 0.79
    /// The portrait composition gives the lower half to the floor, with its drain inside
    /// the phone crop. Both fractions are measured down from the source picture's top.
    static let portraitContactFy: CGFloat = 0.66
    /// Every measured rig's wheels touch the ground at 0.88 of the vehicle canvas (verify_wash).
    static let wheelGroundFy: CGFloat = 0.88

    /// The floor contact line when the bay simply fills the screen, centred.
    static func restingGround(screen: CGSize, art: CGSize, contactFy: CGFloat = floorContactFy) -> CGFloat {
        screen.height / 2 + fillHeight(screen: screen, art: art) * (0.5 - contactFy)
    }

    /// The bay's frame that still covers the whole screen and puts its floor contact line at
    /// `ground`, zooming in only as much as that needs.
    static func frame(screen: CGSize, art: CGSize, ground: CGFloat, contactFy: CGFloat = floorContactFy) -> CGRect {
        let aspect = art.width / max(1, art.height)
        let c = min(0.99, max(0.01, contactFy))
        let g = min(max(ground, 0), screen.height)
        let height = max(fillHeight(screen: screen, art: art), g / (1 - c), (screen.height - g) / c)
        let width = height * aspect
        let centerY = g + height * (c - 0.5)
        return CGRect(x: screen.width / 2 - width / 2, y: centerY - height / 2, width: width, height: height)
    }

    private static func fillHeight(screen: CGSize, art: CGSize) -> CGFloat {
        let aspect = art.width / max(1, art.height)
        return max(screen.height, screen.width / max(0.01, aspect))
    }
}
