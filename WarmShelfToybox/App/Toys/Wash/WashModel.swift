import Foundation

/// Coordinates are fractions of the vehicle canvas, with y measured from its top.
struct WashPoint: Equatable {
    var x: Double
    var y: Double
}

enum WashTool: String, CaseIterable {
    case sponge, hose, towel

    var mudMultiplier: Double {
        switch self {
        case .sponge: return 1
        case .hose: return 1.6
        case .towel: return 0.4
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

    var imageName: String {
        switch self {
        case .fireTruck: return "wash-fire-truck"
        case .policeCar: return "wash-police-car"
        case .tractor: return "wash-tractor"
        case .schoolBus: return "wash-school-bus"
        case .digger: return "wash-digger"
        case .iceCreamVan: return "wash-ice-cream-van"
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
    static let maximumCompletionFoam: Double = 0.035
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
    var isComplete: Bool {
        !patches.isEmpty && cleanFraction >= Self.cleanThreshold
            && foamFraction <= Self.maximumCompletionFoam
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
                patches[index].foam = Self.unit(beforeFoam + lifted * 0.9 + amount * 0.18)
                patches[index].wetness = Self.unit(patches[index].wetness + amount * 0.08)
            case .hose:
                patches[index].foam = max(0, beforeFoam - amount * 2.8)
                patches[index].wetness = Self.unit(patches[index].wetness + amount * 0.65)
            case .towel:
                patches[index].foam = max(0, beforeFoam - amount * 1.8)
                patches[index].wetness = max(0, patches[index].wetness - amount * 2.5)
            }
            added += max(0, patches[index].foam - beforeFoam)
        }
        return WashStrokeResult(affectedPatches: affected, removedMud: removed, addedFoam: added)
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

/// A seeded shuffle bag permits reproducible tests and preserves the cast across rotation.
/// Six deliveries contain all six kinds; bag boundaries also never repeat a vehicle.
struct WashCastDeck {
    private var state: UInt64
    private var remaining: [WashVehicleKind] = []
    private var previous: WashVehicleKind?

    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> WashVehicleKind {
        if remaining.isEmpty {
            remaining = WashVehicleKind.allCases
            for index in stride(from: remaining.count - 1, through: 1, by: -1) {
                remaining.swapAt(index, Int(randomWord() % UInt64(index + 1)))
            }
            if remaining.last == previous {
                remaining.swapAt(remaining.count - 1, 0)
            }
        }
        let kind = remaining.removeLast()
        previous = kind
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
        }
    }
}
