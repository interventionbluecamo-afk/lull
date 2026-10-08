import Foundation
import StoreKit

enum LullAccessTier: String {
    case free
    case fullToybox
}

extension Notification.Name {
    static let lullAccessDidChange = Notification.Name("lullAccessDidChange")
    static let lullAppDidRequestRestart = Notification.Name("lullAppDidRequestRestart")
}

enum LullStoreProduct {
    static let legacyAnnual = "com.lull.full.annual"
    static let lifetime = "com.lull.full.lifetime"

    static let available = [lifetime]
    static let entitlementProductIDs = [legacyAnnual, lifetime]

    static func fallbackPrice(for productID: String) -> String {
        switch productID {
        case lifetime:
            return "$9.99"
        default:
            return ""
        }
    }

    static func label(for productID: String) -> String {
        switch productID {
        case lifetime:
            return "lifetime"
        default:
            return "unlock"
        }
    }
}

final class LullDemoState {
    static let shared = LullDemoState()

    private enum Key {
        static let hasCompletedOnboarding = "lull.hasCompletedOnboarding"
        static let legacyChildName = "lull.childName"
        static let legacyChildAge = "lull.childAge"
        static let windDownHour = "lull.windDownHour"
        static let accessTier = "lull.accessTier"
        static let trialStartDate = "lull.trialStartDate"
        static let trialEndAcknowledged = "lull.trialEndAcknowledged"
        static let soundEnabled = "lull.soundEnabled"
        static let hapticsEnabled = "lull.hapticsEnabled"
        static let reducedMotion = "lull.reducedMotion"
        static let seenHints = "lull.seenHints"
        static let legacyInvestorDemoMode = "lull.investorDemoMode"
        // Wren's unique first-breath sound, chosen once per device.
        static let wrensBreathVariant = "lull.wrens.breath.variant"
        static let hasHeardFirstBreath = "lull.wren.hasHeardFirstBreath"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.removeObject(forKey: Key.legacyChildName)
        defaults.removeObject(forKey: Key.legacyChildAge)
        migrateLegacyDemoState()
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    var wrensBreathVariant: Int {
        get { defaults.integer(forKey: Key.wrensBreathVariant) }
        set { defaults.set(newValue, forKey: Key.wrensBreathVariant) }
    }

    var hasHeardFirstBreath: Bool {
        get { defaults.bool(forKey: Key.hasHeardFirstBreath) }
        set { defaults.set(newValue, forKey: Key.hasHeardFirstBreath) }
    }

    /// The hour (24h) the child begins settling for bed. Drives the evening wind-down warmth.
    // MARK: - The living room (Window, Phase A) — placements and growth persist;
    // the room remembering what the child did IS the toy (Room Council, June 12).
    // Free placements: where the child last left each movable, normalized 0...1 of the
    // scene so it survives device↔sim size differences and rotation. nil = never moved,
    // use the built-in default spot. (Replaced the old two-slot "home index" model — a
    // 2-year-old expects a thing to stay exactly where he sets it, not snap to a slot.)
    private func place(_ kx: String, _ ky: String) -> (x: Double, y: Double)? {
        guard defaults.object(forKey: kx) != nil else { return nil }
        return (defaults.double(forKey: kx), defaults.double(forKey: ky))
    }
    private func setPlace(_ v: (x: Double, y: Double)?, _ kx: String, _ ky: String) {
        if let v { defaults.set(v.x, forKey: kx); defaults.set(v.y, forKey: ky) }
        else { defaults.removeObject(forKey: kx); defaults.removeObject(forKey: ky) }
    }
    var windowCatPlace: (x: Double, y: Double)? {
        get { place("lull.window.catX", "lull.window.catY") }
        set { setPlace(newValue, "lull.window.catX", "lull.window.catY") }
    }
    var windowBallPlace: (x: Double, y: Double)? {
        get { place("lull.window.ballX", "lull.window.ballY") }
        set { setPlace(newValue, "lull.window.ballX", "lull.window.ballY") }
    }
    var windowBlockPlace: (x: Double, y: Double)? {
        get { place("lull.window.blockX", "lull.window.blockY") }
        set { setPlace(newValue, "lull.window.blockX", "lull.window.blockY") }
    }
    var windowPlantHome: Int {
        get { defaults.integer(forKey: "lull.window.plantHome") }        // 0 floor, 1 sill (plant retired)
        set { defaults.set(newValue, forKey: "lull.window.plantHome") }
    }
    var windowToyboxOpen: Bool {                                          // the play-toys' home; open spills them out
        get { defaults.bool(forKey: "lull.window.toyboxOpen") }
        set { defaults.set(newValue, forKey: "lull.window.toyboxOpen") }
    }
    var windowPotStage: Int {
        get { max(1, min(3, defaults.object(forKey: "lull.window.potStage") as? Int ?? 1)) }
        set { defaults.set(max(1, min(3, newValue)), forKey: "lull.window.potStage") }
    }
    var windowPotLastWateredDay: Int {
        get { defaults.integer(forKey: "lull.window.potWateredDay") }    // yyyymmdd
        set { defaults.set(newValue, forKey: "lull.window.potWateredDay") }
    }
    var windowPotPendingGrowth: Bool {
        get { defaults.bool(forKey: "lull.window.potPendingGrowth") }
        set { defaults.set(newValue, forKey: "lull.window.potPendingGrowth") }
    }
    var windowGuestLastDay: Int {
        get { defaults.integer(forKey: "lull.window.guestLastDay") }     // yyyymmdd
        set { defaults.set(newValue, forKey: "lull.window.guestLastDay") }
    }

    var windDownHour: Int {
        get {
            let stored = defaults.integer(forKey: Key.windDownHour)
            return stored == 0 ? 19 : stored
        }
        set { defaults.set(newValue, forKey: Key.windDownHour) }
    }

    /// Parent-set play timer in minutes (0 = off). When play time elapses, Lull gently "rests"
    /// behind a calm moon veil until a grown-up wakes it through the gate — never a buzzer.
    var playTimerMinutes: Int {
        get { defaults.integer(forKey: "lull.playTimerMinutes") }
        set {
            defaults.set(newValue, forKey: "lull.playTimerMinutes")
            LullPlayTimer.shared.settingsChanged()
        }
    }

    /// Toys a grown-up has tucked away off the child's shelf (never deleting, just resting).
    var hiddenToyIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: "lull.hiddenToyIDs") ?? []) }
        set {
            defaults.set(Array(newValue).sorted(), forKey: "lull.hiddenToyIDs")
            NotificationCenter.default.post(name: .lullAccessDidChange, object: nil)
        }
    }

    var accessTier: LullAccessTier {
        get {
            LullAccessTier(rawValue: defaults.string(forKey: Key.accessTier) ?? "") ?? .free
        }
        set {
            guard newValue != accessTier else { return }
            defaults.set(newValue.rawValue, forKey: Key.accessTier)
            NotificationCenter.default.post(name: .lullAccessDidChange, object: nil)
        }
    }

    /// What the grown-up actually paid for (the StoreKit entitlement). Stays distinct from
    /// `hasFullToybox`, which also counts the free trial.
    var hasPurchasedFullToybox: Bool {
        accessTier == .fullToybox
    }

    /// Effective access to the full toybox: a real purchase, or an active free trial.
    var hasFullToybox: Bool {
        hasPurchasedFullToybox || isTrialActive
    }

    // MARK: - Free trial (7 days of the full toybox, then it settles back to the free shelf)

    /// Full access is free for the first 7 days so a family can fall in love with the whole
    /// shelf before deciding. After it ends, Bubbles and Stack stay free forever and the rest
    /// quietly returns to the grown-up area — never a child-facing lock or price.
    let trialDuration: TimeInterval = 7 * 24 * 60 * 60

    var trialStartDate: Date? {
        get {
            let stored = defaults.double(forKey: Key.trialStartDate)
            guard stored > 0 else { return nil }
            // A start in the future means the clock was turned back after the week began:
            // count from now instead, so moving the clock can't stretch the free week.
            let now = Date().timeIntervalSinceReferenceDate
            if stored > now + 60 {
                defaults.set(now, forKey: Key.trialStartDate)
                return Date(timeIntervalSinceReferenceDate: now)
            }
            return Date(timeIntervalSinceReferenceDate: stored)
        }
        set {
            if let date = newValue {
                defaults.set(date.timeIntervalSinceReferenceDate, forKey: Key.trialStartDate)
            } else {
                defaults.removeObject(forKey: Key.trialStartDate)
            }
        }
    }

    var hasTrialStarted: Bool { trialStartDate != nil }

    var isTrialActive: Bool {
        guard let start = trialStartDate else { return false }
        return Date() < start.addingTimeInterval(trialDuration)
    }

    /// Whole days left in the trial (rounds up, so day one reads "7 days"). 0 once it ends.
    var trialDaysRemaining: Int {
        guard let start = trialStartDate else { return 0 }
        let remaining = start.addingTimeInterval(trialDuration).timeIntervalSinceNow
        return min(7, max(0, Int(ceil(remaining / 86_400))))
    }

    /// True once a grown-up has opened the parent area after the trial lapsed — clears the
    /// quiet dot on the shelf's parent chip so it never nags forever.
    var hasAcknowledgedTrialEnd: Bool {
        get { defaults.bool(forKey: Key.trialEndAcknowledged) }
        set { defaults.set(newValue, forKey: Key.trialEndAcknowledged) }
    }

    /// The parent chip shows its quiet dot on the trial's last day and right after it ends —
    /// the one gentle, adult-facing signal that the shelf is about to change / just changed.
    var parentAttentionWanted: Bool {
        guard !hasPurchasedFullToybox, hasTrialStarted else { return false }
        if isTrialActive { return trialDaysRemaining <= 1 }
        return !hasAcknowledgedTrialEnd
    }

    func startTrialIfNeeded() {
        if trialStartDate == nil { trialStartDate = Date() }
        NotificationCenter.default.post(name: .lullAccessDidChange, object: nil)
    }

    var isSoundEnabled: Bool {
        get {
            if defaults.object(forKey: Key.soundEnabled) == nil { return true }
            return defaults.bool(forKey: Key.soundEnabled)
        }
        set { defaults.set(newValue, forKey: Key.soundEnabled) }
    }

    var isHapticsEnabled: Bool {
        get {
            if defaults.object(forKey: Key.hapticsEnabled) == nil { return true }
            return defaults.bool(forKey: Key.hapticsEnabled)
        }
        set { defaults.set(newValue, forKey: Key.hapticsEnabled) }
    }

    /// Parent-set preference for calmer motion (on top of the system Reduce Motion setting).
    var isReducedMotion: Bool {
        get { defaults.bool(forKey: Key.reducedMotion) }
        set { defaults.set(newValue, forKey: Key.reducedMotion) }
    }

    /// DEBUG-only persistent developer unlock (never honored in Release builds).
    var debugForceFullUnlock: Bool {
        get { defaults.bool(forKey: "lull.debugForceFull") }
        set { defaults.set(newValue, forKey: "lull.debugForceFull") }
    }

    /// One-time first-session hints, per toy.
    func hasSeenHint(_ id: String) -> Bool {
        (defaults.array(forKey: Key.seenHints) as? [String] ?? []).contains(id)
    }
    func markHintSeen(_ id: String) {
        var seen = defaults.array(forKey: Key.seenHints) as? [String] ?? []
        guard !seen.contains(id) else { return }
        seen.append(id)
        defaults.set(seen, forKey: Key.seenHints)
    }

    func completeOnboarding() {
        // Replaying the welcome never changes a purchase or renews an existing trial.
        startTrialIfNeeded()
        hasCompletedOnboarding = true
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        NotificationCenter.default.post(name: .lullAppDidRequestRestart, object: nil)
    }

    private func migrateLegacyDemoState() {
        guard defaults.object(forKey: Key.legacyInvestorDemoMode) != nil else { return }

        defaults.removeObject(forKey: Key.legacyInvestorDemoMode)
        defaults.set(LullAccessTier.free.rawValue, forKey: Key.accessTier)
    }
}

@MainActor
final class LullPurchaseManager {
    static let shared = LullPurchaseManager()

    private(set) var products: [Product] = []
    private var transactionUpdates: Task<Void, Never>?
    private(set) var lastErrorMessage: String?

    private init() {
        transactionUpdates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.applyVerifiedTransaction(result)
            }
        }
    }

    deinit {
        transactionUpdates?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: LullStoreProduct.available)
                .sorted { lhs, rhs in
                    let lhsIndex = LullStoreProduct.available.firstIndex(of: lhs.id) ?? 99
                    let rhsIndex = LullStoreProduct.available.firstIndex(of: rhs.id) ?? 99
                    return lhsIndex < rhsIndex
                }
            await refreshEntitlements()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Purchases are unavailable right now."
        }
    }

    func displayPrice(for productID: String) -> String {
        product(for: productID)?.displayPrice ?? LullStoreProduct.fallbackPrice(for: productID)
    }

    func product(for productID: String) -> Product? {
        products.first { $0.id == productID }
    }

    func purchase(_ productID: String) async -> Bool {
        if products.isEmpty {
            await loadProducts()
        }

        guard let product = product(for: productID) else {
            lastErrorMessage = "The full toybox isn't available from the App Store right now. Please try again later."
            return false
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard let transaction = verifiedTransaction(from: verification) else {
                    lastErrorMessage = "The purchase could not be verified."
                    return false
                }

                if isFullToyboxTransaction(transaction) {
                    LullDemoState.shared.accessTier = .fullToybox
                }
                await transaction.finish()
                lastErrorMessage = nil
                return true
            case .pending:
                lastErrorMessage = "The purchase is waiting for approval."
                return false
            case .userCancelled:
                lastErrorMessage = nil
                return false
            @unknown default:
                lastErrorMessage = "The purchase could not be completed."
                return false
            }
        } catch {
            lastErrorMessage = "The purchase could not be completed."
            return false
        }
    }

    func restorePurchases() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            lastErrorMessage = nil
            return LullDemoState.shared.hasPurchasedFullToybox
        } catch {
            lastErrorMessage = "Purchases could not be restored."
            return false
        }
    }

    func refreshEntitlements() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["LULL_DEBUG_FULL"] == "1" || LullDemoState.shared.debugForceFullUnlock {
            LullDemoState.shared.accessTier = .fullToybox
            return
        }
        #endif

        var hasValidFullToyboxEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: result) else { continue }
            if isFullToyboxTransaction(transaction) {
                hasValidFullToyboxEntitlement = true
                break
            }
        }

        LullDemoState.shared.accessTier = hasValidFullToyboxEntitlement ? .fullToybox : .free
    }

    private func applyVerifiedTransaction(_ result: VerificationResult<Transaction>) async {
        guard let transaction = verifiedTransaction(from: result) else { return }
        if isFullToyboxTransaction(transaction) {
            LullDemoState.shared.accessTier = .fullToybox
        } else if LullStoreProduct.entitlementProductIDs.contains(transaction.productID) {
            // A refund or revocation arrives as an update too: recheck instead of keeping access.
            await refreshEntitlements()
        }
        await transaction.finish()
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) -> Transaction? {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            return nil
        }
    }

    private func isFullToyboxTransaction(_ transaction: Transaction) -> Bool {
        guard LullStoreProduct.entitlementProductIDs.contains(transaction.productID) else { return false }
        guard transaction.revocationDate == nil else { return false }
        if let expirationDate = transaction.expirationDate, expirationDate < Date() {
            return false
        }
        return true
    }
}
