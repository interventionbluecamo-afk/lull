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
    /// Lull Family: an auto-renewable yearly plan whose introductory offer is the free week.
    static let familyYearly = "com.lull.family.yearly"
    /// Never sold; kept so any sandbox or legacy entitlement still unlocks.
    static let legacyAnnual = "com.lull.full.annual"
    /// Keep Forever: the one-time, non-consumable unlock.
    static let lifetime = "com.lull.full.lifetime"

    static let available = [familyYearly, lifetime]
    static let entitlementProductIDs = [familyYearly, legacyAnnual, lifetime]
    static let subscriptionProductIDs = [familyYearly, legacyAnnual]

    /// Apple's standard licence agreement, linked beside the plans (Guideline 3.1.2).
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Fallback when Apple's in-app manage sheet can't be shown.
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    static func fallbackPrice(for productID: String) -> String {
        switch productID {
        case familyYearly:
            return "$29.99"
        case lifetime:
            return "$59.99"
        default:
            return ""
        }
    }

    static func label(for productID: String) -> String {
        switch productID {
        case familyYearly, legacyAnnual:
            return "Lull Family"
        case lifetime:
            return "Keep Forever"
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
        static let legacyTrialStartDate = "lull.trialStartDate"
        static let legacyTrialEndAcknowledged = "lull.trialEndAcknowledged"
        static let planProductID = "lull.plan.productID"
        static let planFreeWeekEnd = "lull.plan.freeWeekEnd"
        static let planWillRenew = "lull.plan.willRenew"
        static let planLapsed = "lull.plan.lapsed"
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
        // The on-device free week was replaced by the App Store's free week (Lull Family).
        defaults.removeObject(forKey: Key.legacyTrialStartDate)
        defaults.removeObject(forKey: Key.legacyTrialEndAcknowledged)
        migrateLegacyDemoState()
        migrateRetiredToyPreferences()
    }

    /// Little Wash takes Stack's shelf place without renewing trials or
    /// touching StoreKit entitlements. Preserve a family's tucked-away choice.
    private func migrateRetiredToyPreferences() {
        var hidden = Set(defaults.stringArray(forKey: "lull.hiddenToyIDs") ?? [])
        if hidden.remove("stack") != nil {
            hidden.insert("wash")
            defaults.set(Array(hidden).sorted(), forKey: "lull.hiddenToyIDs")
        }
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

    /// What the grown-up has from the App Store: Keep Forever, or Lull Family (including its
    /// free week, which Apple runs as the plan's introductory offer).
    var hasPurchasedFullToybox: Bool {
        accessTier == .fullToybox
    }

    /// Effective access to the full toybox. There is no local trial: every free week is the
    /// App Store's, so access is exactly the StoreKit entitlement.
    var hasFullToybox: Bool {
        hasPurchasedFullToybox
    }

    // MARK: - The plan behind the access (cached from StoreKit for the grown-up area)

    /// What StoreKit reported at the last entitlement check. Plain values so this state stays
    /// testable without StoreKit.
    struct PlanSnapshot: Equatable {
        var productID: String
        /// When the App Store's free week ends, if this access is still inside it.
        var freeWeekEnds: Date?
        /// nil when unknown (offline, or a one-time purchase).
        var willRenew: Bool?
    }

    var planProductID: String? {
        guard hasPurchasedFullToybox else { return nil }
        return defaults.string(forKey: Key.planProductID)
    }

    var hasKeepForever: Bool { planProductID == LullStoreProduct.lifetime }

    var hasSubscription: Bool {
        guard let id = planProductID else { return false }
        return LullStoreProduct.subscriptionProductIDs.contains(id)
    }

    var freeWeekEndDate: Date? {
        guard hasSubscription else { return nil }
        let stored = defaults.double(forKey: Key.planFreeWeekEnd)
        return stored > 0 ? Date(timeIntervalSinceReferenceDate: stored) : nil
    }

    var isInFreeWeek: Bool {
        guard let end = freeWeekEndDate else { return false }
        return Date() < end
    }

    /// Whole days left in the App Store's free week (rounds up, so day one reads "7 days").
    var freeWeekDaysRemaining: Int {
        guard isInFreeWeek, let end = freeWeekEndDate else { return 0 }
        return min(7, max(1, Int(ceil(end.timeIntervalSinceNow / 86_400))))
    }

    var planWillRenew: Bool? {
        guard hasSubscription, defaults.object(forKey: Key.planWillRenew) != nil else { return nil }
        return defaults.bool(forKey: Key.planWillRenew)
    }

    /// A Lull Family plan ended and the shelf went back to the free toys; true until a
    /// grown-up has seen the parent area.
    var hasUnseenPlanEnd: Bool {
        defaults.bool(forKey: Key.planLapsed)
    }

    func applyPlan(_ plan: PlanSnapshot?) {
        let hadSubscription = hasSubscription
        if let plan {
            defaults.set(plan.productID, forKey: Key.planProductID)
            if let end = plan.freeWeekEnds {
                defaults.set(end.timeIntervalSinceReferenceDate, forKey: Key.planFreeWeekEnd)
            } else {
                defaults.removeObject(forKey: Key.planFreeWeekEnd)
            }
            if let renew = plan.willRenew {
                defaults.set(renew, forKey: Key.planWillRenew)
            } else {
                defaults.removeObject(forKey: Key.planWillRenew)
            }
            defaults.set(false, forKey: Key.planLapsed)
            // Post even when the tier is unchanged: the parent area shows the plan's details.
            if accessTier == .fullToybox {
                NotificationCenter.default.post(name: .lullAccessDidChange, object: nil)
            }
            accessTier = .fullToybox
        } else {
            if hadSubscription { defaults.set(true, forKey: Key.planLapsed) }
            defaults.removeObject(forKey: Key.planProductID)
            defaults.removeObject(forKey: Key.planFreeWeekEnd)
            defaults.removeObject(forKey: Key.planWillRenew)
            accessTier = .free
        }
    }

    func acknowledgePlanState() {
        defaults.set(false, forKey: Key.planLapsed)
    }

    /// The parent chip shows its quiet dot on the free week's last day and right after a
    /// plan ends: the one gentle, adult-facing signal that the shelf is about to change or
    /// just did. It rests once the grown-up room has been visited.
    var parentAttentionWanted: Bool {
        if isInFreeWeek { return freeWeekDaysRemaining <= 1 }
        return !hasPurchasedFullToybox && hasUnseenPlanEnd
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
        // Replaying the welcome never changes a purchase or a plan; the App Store owns both.
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
    /// Whether this Apple Account can still start Lull Family's free week. nil until known.
    private(set) var isEligibleForFreeWeek: Bool?

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
            if let subscription = product(for: LullStoreProduct.familyYearly)?.subscription,
               subscription.introductoryOffer?.paymentMode == .freeTrial {
                isEligibleForFreeWeek = await subscription.isEligibleForIntroOffer
            } else {
                isEligibleForFreeWeek = false
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

    /// The plan's free period as App Store Connect set it: "week" (reads "First week free")
    /// or "7 days". nil when the plan has no free introductory offer.
    func freeWeekLength(for productID: String) -> String? {
        guard let offer = product(for: productID)?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        return offer.period.value == 1 ? Self.unitName(offer.period.unit) : Self.describe(offer.period)
    }

    /// "year", "month", "6 months": the renewal period, for "$29.99 a year".
    func renewalPeriod(for productID: String) -> String? {
        guard let period = product(for: productID)?.subscription?.subscriptionPeriod else { return nil }
        return period.value == 1 ? Self.unitName(period.unit) : Self.describe(period)
    }

    private static func unitName(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "period"
        }
    }

    private static func describe(_ period: Product.SubscriptionPeriod) -> String {
        "\(period.value) \(unitName(period.unit))\(period.value == 1 ? "" : "s")"
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
                    // A brand-new plan renews unless the grown-up turns it off later.
                    let willRenew: Bool? = product.subscription == nil ? nil : true
                    LullDemoState.shared.applyPlan(snapshot(for: transaction, willRenew: willRenew))
                    if transaction.offerType == .introductory { isEligibleForFreeWeek = false }
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

        var best: Transaction?
        for await result in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: result),
                  isFullToyboxTransaction(transaction) else { continue }
            // Keep Forever outranks a plan: it never ends.
            if transaction.productID == LullStoreProduct.lifetime {
                best = transaction
                break
            }
            if best == nil { best = transaction }
        }

        guard let best else {
            LullDemoState.shared.applyPlan(nil)
            return
        }
        var willRenew: Bool?
        if best.productType == .autoRenewable {
            willRenew = await willAutoRenew(best)
        }
        LullDemoState.shared.applyPlan(snapshot(for: best, willRenew: willRenew))
    }

    private func snapshot(for transaction: Transaction, willRenew: Bool?) -> LullDemoState.PlanSnapshot {
        let inFreeWeek = transaction.productType == .autoRenewable && transaction.offerType == .introductory
        return LullDemoState.PlanSnapshot(
            productID: transaction.productID,
            freeWeekEnds: inFreeWeek ? transaction.expirationDate : nil,
            willRenew: willRenew
        )
    }

    private func willAutoRenew(_ transaction: Transaction) async -> Bool? {
        var plan = self.product(for: transaction.productID)
        if plan == nil {
            plan = try? await Product.products(for: [transaction.productID]).first
        }
        guard let statuses = try? await plan?.subscription?.status else { return nil }
        for status in statuses {
            guard case .verified(let renewal) = status.renewalInfo,
                  case .verified(let current) = status.transaction,
                  current.originalID == transaction.originalID else { continue }
            return renewal.willAutoRenew
        }
        return nil
    }

    private func applyVerifiedTransaction(_ result: VerificationResult<Transaction>) async {
        guard let transaction = verifiedTransaction(from: result) else { return }
        if LullStoreProduct.entitlementProductIDs.contains(transaction.productID) {
            // Purchases, renewals, Ask to Buy approvals, refunds and revocations all arrive
            // here: recheck everything rather than trusting one transaction.
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
