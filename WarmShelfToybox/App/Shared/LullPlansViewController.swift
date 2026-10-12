import UIKit
import StoreKit
import UserNotifications

// MARK: - The offer, in words

/// What the App Store returned for the two ways to open the toybox, as plain words for the
/// welcome, the Full Toybox page and the "not sure yet" sheet. Every price, period and free week
/// comes from StoreKit; nothing is advertised for a product the App Store didn't return.
@MainActor
struct LullPlanOffer {
    /// "$29.99", nil until the App Store returns Lull Family.
    var familyPrice: String?
    /// "year".
    var period: String
    /// "week" when this Apple Account can still start Lull Family's free week; otherwise nil.
    var freeLength: String?
    /// 7 for a week; nil when the free period isn't counted in days or weeks.
    var freeDays: Int?
    /// "$2.50": the yearly price spread over twelve months, always shown smaller.
    var monthly: String?
    var familyShared: Bool
    /// "$59.99", nil until the App Store returns Keep Forever.
    var keepForeverPrice: String?
    var keepForeverShared: Bool

    static func current() -> LullPlanOffer {
        let store = LullPurchaseManager.shared
        let family = store.product(for: LullStoreProduct.familyYearly)
        let keepForever = store.product(for: LullStoreProduct.lifetime)
        let familyPrice = family?.type == .autoRenewable ? family?.displayPrice : nil
        let canStartFreeWeek = familyPrice != nil && store.isEligibleForFreeWeek == true
        var offer = LullPlanOffer(
            familyPrice: familyPrice,
            period: store.renewalPeriod(for: LullStoreProduct.familyYearly) ?? "year",
            freeLength: canStartFreeWeek ? store.freeWeekLength(for: LullStoreProduct.familyYearly) : nil,
            freeDays: canStartFreeWeek ? store.freeTrialDays(for: LullStoreProduct.familyYearly) : nil,
            monthly: familyPrice == nil ? nil : store.monthlyEquivalent(for: LullStoreProduct.familyYearly),
            familyShared: store.isFamilyShareable(LullStoreProduct.familyYearly),
            keepForeverPrice: keepForever?.type == .nonConsumable ? keepForever?.displayPrice : nil,
            keepForeverShared: store.isFamilyShareable(LullStoreProduct.lifetime)
        )
        #if DEBUG
        // LULL_DEBUG_PLANS_PREVIEW=1 lays the offer out with launch values when the App Store
        // has none (simulator QA and the review screenshot). The buttons stay inert: no product.
        if ProcessInfo.processInfo.environment["LULL_DEBUG_PLANS_PREVIEW"] == "1",
           offer.familyPrice == nil, offer.keepForeverPrice == nil {
            offer = LullPlanOffer(familyPrice: "$29.99", period: "year", freeLength: "week", freeDays: 7,
                                  monthly: "$2.50", familyShared: true, keepForeverPrice: "$59.99",
                                  keepForeverShared: true)
        }
        #endif
        return offer
    }

    var hasPrices: Bool { familyPrice != nil || keepForeverPrice != nil }

    /// "7 days free", or "First week free" when the App Store counts it differently.
    var freeHeadline: String? {
        guard let free = freeLength else { return nil }
        if let days = freeDays { return "\(days) days free" }
        return "First \(free) free"
    }

    /// The start button's words.
    var startTitle: String? {
        guard let price = familyPrice else { return nil }
        guard let free = freeLength else { return "Subscribe · \(price) a \(period)" }
        return free == "week" ? "Start my free week" : "Start the free \(free)"
    }

    /// The line beside every start button: the billed price, in plain words (Guideline 3.1.2).
    var startCaption: String? {
        guard let price = familyPrice else { return nil }
        if let free = freeHeadline { return "\(free), then \(price) a \(period). To pay nothing, cancel at least 24 hours before the trial ends." }
        return "\(price) a \(period), renewing each \(period). Cancel anytime."
    }

    /// Apple's subscription terms, in full (Guideline 3.1.2).
    var legalText: String? {
        guard let price = familyPrice else {
            return keepForeverPrice == nil ? nil : "Keep Forever is a one-time purchase, charged to your Apple Account when you confirm."
        }
        let start = freeLength.map { " after the free \($0)" } ?? ""
        let charged = freeLength.map { "when the free \($0) ends" } ?? "when you confirm"
        let keepForever = keepForeverPrice == nil ? "" : " Keep Forever is a one-time purchase."
        return "Lull Family is an auto-renewing subscription: \(price) a \(period)\(start). Payment is charged to your Apple Account \(charged). It renews automatically unless cancelled at least 24 hours before the end of the current period, and renewal is charged within the 24 hours before the period ends. Manage or cancel anytime in your Apple Account settings.\(keepForever)"
    }

    /// "October 18": a day of the free week counted from today.
    static func dayLabel(afterDays days: Int, from start: Date = Date()) -> String {
        let date = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        return longDay(date)
    }

    static func longDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return formatter.string(from: date)
    }
}

// MARK: - The reminder

/// One quiet reminder, two days before the App Store's free week ends, so no family meets the
/// first charge by surprise (the Blinkist pattern: say when the reminder comes and when the
/// charge comes, then keep the promise). Only after a grown-up allows notifications, only on
/// this device, silent, and retired as soon as the plan is cancelled or the week is over.
@MainActor
enum LullFreeWeekReminder {
    static let identifier = "lull.freeWeekReminder"
    static let daysBefore = 2
    private static let scheduledKey = "lull.freeWeekReminder.scheduled"

    /// True while a reminder is waiting for this free week.
    static var isScheduled: Bool { UserDefaults.standard.bool(forKey: scheduledKey) }

    /// When the reminder would arrive for the current free week; nil when there is none to set.
    static var reminderDate: Date? {
        let state = LullDemoState.shared
        guard state.isInFreeWeek, state.planWillRenew != false, let end = state.freeWeekEndDate,
              let date = Calendar.current.date(byAdding: .day, value: -daysBefore, to: end),
              date > Date().addingTimeInterval(60) else { return nil }
        return date
    }

    /// Asks for permission (a grown-up has just started the free week, or tapped "Remind me"),
    /// then sets the reminder. Returns whether one is now set.
    static func requestAndSchedule() async -> Bool {
        guard reminderDate != nil else { return false }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])) ?? false
        guard granted else { return false }
        await sync()
        return isScheduled
    }

    /// Keeps the one reminder in step with the plan. Never asks for permission.
    static func sync() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        UserDefaults.standard.set(false, forKey: scheduledKey)
        guard let fireDate = reminderDate, let end = LullDemoState.shared.freeWeekEndDate else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let store = LullPurchaseManager.shared
        let price = store.displayPrice(for: LullStoreProduct.familyYearly)
        let period = store.renewalPeriod(for: LullStoreProduct.familyYearly) ?? "year"
        let content = UNMutableNotificationContent()
        content.title = "Lull's free week ends in \(daysBefore) days"
        content.body = "On \(LullPlanOffer.longDay(end)), Lull Family begins at \(price) a \(period). "
            + "To pay nothing, cancel at least 24 hours before the trial ends in Settings › your name › Subscriptions."
        content.sound = nil   // Lull never makes a sound on its own.
        let when = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(identifier: identifier, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false))
        do {
            try await center.add(request)
            UserDefaults.standard.set(true, forKey: scheduledKey)
        } catch {
            UserDefaults.standard.set(false, forKey: scheduledKey)
        }
    }
}

// MARK: - Buying

/// One way to buy, shared by the welcome and the Full Toybox page. Both are only ever shown
/// behind the adult check, so a button goes straight to Apple's own confirmation sheet (Face ID
/// or password, and Ask to Buy on a child's account).
@MainActor
enum LullPurchaseFlow {
    enum Outcome {
        /// The toybox is open; the words say how, and until when.
        case opened(String)
        /// Cancelled (nil), or a reason worth showing.
        case notOpened(String?)
    }

    static func buy(_ productID: String) async -> Outcome {
        let store = LullPurchaseManager.shared
        guard store.product(for: productID) != nil else {
            return .notOpened("The App Store isn't reachable right now. Please try again in a moment.")
        }
        guard await store.purchase(productID) else { return .notOpened(store.lastErrorMessage) }
        let state = LullDemoState.shared
        if state.hasKeepForever {
            return .opened("Keep Forever is yours. All nine toys, and every new one, for good.")
        }
        if state.isInFreeWeek {
            let end = state.freeWeekEndDate.map(LullPlanOffer.longDay) ?? "the end of the week"
            // Offer to schedule the reminder now, while the grown-up is here.
            let reminded = await LullFreeWeekReminder.requestAndSchedule()
            let reminder = reminded
                ? LullFreeWeekReminder.reminderDate.map { " A reminder is scheduled for \(LullPlanOffer.longDay($0))." } ?? " A reminder is scheduled."
                : " No reminder is set. The grown-up area shows the days left."
            return .opened("Your free week has begun. All nine toys are open until \(end). To pay nothing, cancel at least 24 hours before the trial ends.\(reminder)")
        }
        return .opened("Lull Family is active. All nine toys are open.")
    }
}

// MARK: - The offer view

/// The one offer, on warm paper: the nine toys alive, the price first and largest, the free week
/// as three dated beats, the promises that answer a hesitant grown-up, then the quieter choices
/// (pay once, restore) and Apple's terms. Shared by the welcome's last page and the Full Toybox
/// page, so a family meets the same words in both places.
@MainActor
final class LullOfferView: UIView {
    struct Actions {
        var start: () -> Void
        var keepForever: () -> Void
        var restore: () -> Void
        var terms: () -> Void
        var privacy: () -> Void
        var retry: () -> Void
    }

    private let offer: LullPlanOffer
    private let actions: Actions
    private let isLoading: Bool
    private let isBusy: Bool
    private let showsStartButton: Bool

    /// - Parameter showsStartButton: false where the page pins its own start button (the welcome).
    init(offer: LullPlanOffer, isLoading: Bool, isBusy: Bool, showsStartButton: Bool, actions: Actions) {
        self.offer = offer
        self.actions = actions
        self.isLoading = isLoading
        self.isBusy = isBusy
        self.showsStartButton = showsStartButton
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { nil }

    private var canPay: Bool { AppStore.canMakePayments }

    private func build() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Value before price: the same felt toys the child will find, breathing.
        stack.addArrangedSubview(PaywallPreviewStrip(toyIDs: ToyRegistry.launchToyIDs,
                                                     labelColor: WarmShelfPalette.cocoa.withAlphaComponent(0.85),
                                                     rowHeight: 80))
        if let price = offer.familyPrice {
            stack.addArrangedSubview(makePlanCard(price: price))
        } else if offer.keepForeverPrice == nil {
            stack.addArrangedSubview(makeStoreStatusCard())
        }
        if offer.hasPrices, !canPay {
            stack.addArrangedSubview(makeNote("In-App Purchases are turned off in Screen Time on this device. A grown-up can turn them on in Settings › Screen Time."))
        }
        stack.addArrangedSubview(makePromisesCard())
        if let keepForeverPrice = offer.keepForeverPrice {
            stack.addArrangedSubview(makeKeepForeverCard(price: keepForeverPrice))
        }
        stack.addArrangedSubview(makeLinksRow())
        if let legal = offer.legalText {
            stack.addArrangedSubview(makeFinePrint(legal))
        }
    }

    // MARK: Plan card

    /// Lull Family: the billed price first and largest (Guideline 3.1.2), what it includes, a
    /// small monthly figure, then — for a family that can still start it — the free week as
    /// three dated beats: today, the reminder, the first charge.
    private func makePlanCard(price: String) -> UIView {
        let card = makeCard(highlighted: true)
        card.accessibilityIdentifier = "offer-family"

        let header = UIStackView(arrangedSubviews: [makeEyebrow("LULL FAMILY")])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8
        if let free = offer.freeHeadline {
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            header.addArrangedSubview(spacer)
            header.addArrangedSubview(makePill(free.uppercased()))
        }

        let amount = makeLabel("\(price) a \(offer.period)",
                               font: UIFont(name: "Georgia-Bold", size: 30) ?? .systemFont(ofSize: 30, weight: .bold),
                               style: .title1, color: WarmShelfPalette.clayInk)
        let includes = makeLabel("Every toy, plus new ones each season.",
                                 font: .systemFont(ofSize: 15.5, weight: .medium), style: .body,
                                 color: WarmShelfPalette.cocoa)
        let column = UIStackView(arrangedSubviews: [header, amount, includes])
        column.axis = .vertical
        column.spacing = 6
        column.setCustomSpacing(10, after: header)
        column.setCustomSpacing(4, after: amount)
        var lastInfo: UIView = includes
        var extras: [String] = []
        if let monthly = offer.monthly { extras.append("About \(monthly) a month") }
        if offer.familyShared { extras.append(extras.isEmpty ? "For the whole family" : "for the whole family") }
        if !extras.isEmpty {
            let small = makeLabel(extras.joined(separator: " · "), font: .systemFont(ofSize: 13.5, weight: .semibold),
                                  style: .footnote, color: WarmShelfPalette.cocoa.withAlphaComponent(0.72))
            column.addArrangedSubview(small)
            lastInfo = small
        }
        column.setCustomSpacing(16, after: lastInfo)
        if offer.freeLength != nil {
            let divider = makeDivider()
            column.addArrangedSubview(divider)
            column.setCustomSpacing(16, after: divider)
            let timeline = makeTimeline(price: price)
            column.addArrangedSubview(timeline)
            column.setCustomSpacing(18, after: timeline)
        }
        if showsStartButton, let title = offer.startTitle {
            let start = makeButton(title: isBusy ? "Waiting for the App Store…" : title, filled: true)
            start.accessibilityIdentifier = "plan-family-purchase"
            start.isEnabled = canPay && !isBusy
            start.alpha = start.isEnabled ? 1 : 0.6
            start.addAction(UIAction { [actions] _ in actions.start() }, for: .touchUpInside)
            column.addArrangedSubview(start)
            column.setCustomSpacing(8, after: start)
            if let caption = offer.startCaption {
                let small = makeLabel(caption, font: .systemFont(ofSize: 13, weight: .medium), style: .footnote,
                                      color: WarmShelfPalette.cocoa.withAlphaComponent(0.75))
                small.textAlignment = .center
                column.addArrangedSubview(small)
            }
        }
        fill(card, with: column, inset: 18)
        return card
    }

    private func makeTimeline(price: String) -> UIView {
        var beats: [(String, String, UIColor)] = [
            ("Today", "All nine toys open. Nothing to pay today.", WarmShelfPalette.butter)
        ]
        let charge = "Lull Family begins at \(price) a \(offer.period). To pay nothing, cancel at least 24 hours before the trial ends."
        if let days = offer.freeDays, days > LullFreeWeekReminder.daysBefore {
            beats.append((LullPlanOffer.dayLabel(afterDays: days - LullFreeWeekReminder.daysBefore),
                          "With notifications enabled, Lull can remind you that the free week is ending.", WarmShelfPalette.sage))
            beats.append((LullPlanOffer.dayLabel(afterDays: days), charge, WarmShelfPalette.terracotta))
        } else {
            beats.append(("When the free \(offer.freeLength ?? "week") ends", charge, WarmShelfPalette.terracotta))
        }

        let column = UIStackView()
        column.axis = .vertical
        for (index, beat) in beats.enumerated() {
            let isLast = index == beats.count - 1
            let row = UIView()
            row.isAccessibilityElement = true
            row.accessibilityLabel = "\(beat.0): \(beat.1)"

            let dot = UIView()
            dot.backgroundColor = beat.2
            dot.layer.cornerRadius = 6
            dot.layer.borderWidth = 1.5
            dot.layer.borderColor = WarmShelfPalette.paperHighlight.cgColor
            dot.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(dot)

            let thread = UIView()
            thread.backgroundColor = WarmShelfPalette.softLine.withAlphaComponent(isLast ? 0 : 0.6)
            thread.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(thread)

            let when = makeLabel(beat.0, font: .systemFont(ofSize: 15, weight: .bold), style: .subheadline,
                                 color: WarmShelfPalette.clayInk)
            let what = makeLabel(beat.1, font: .systemFont(ofSize: 14.5), style: .subheadline,
                                 color: WarmShelfPalette.cocoa)
            for label in [when, what] {
                label.translatesAutoresizingMaskIntoConstraints = false
                row.addSubview(label)
            }
            NSLayoutConstraint.activate([
                dot.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                dot.topAnchor.constraint(equalTo: row.topAnchor, constant: 3),
                dot.widthAnchor.constraint(equalToConstant: 12),
                dot.heightAnchor.constraint(equalToConstant: 12),
                thread.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
                thread.topAnchor.constraint(equalTo: dot.bottomAnchor, constant: 3),
                thread.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                thread.widthAnchor.constraint(equalToConstant: 2),
                when.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 12),
                when.topAnchor.constraint(equalTo: row.topAnchor),
                when.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                what.leadingAnchor.constraint(equalTo: when.leadingAnchor),
                what.topAnchor.constraint(equalTo: when.bottomAnchor, constant: 1),
                what.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                what.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: isLast ? 0 : -14)
            ])
            column.addArrangedSubview(row)
        }
        return column
    }

    private func makeStoreStatusCard() -> UIView {
        let card = makeCard(highlighted: false)
        var rows: [UIView] = []
        if isLoading {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.color = WarmShelfPalette.cocoa
            spinner.startAnimating()
            let words = makeLabel("Connecting to the App Store…", font: .systemFont(ofSize: 15, weight: .semibold),
                                  style: .body, color: WarmShelfPalette.cocoa)
            let row = UIStackView(arrangedSubviews: [spinner, words])
            row.axis = .horizontal
            row.spacing = 10
            row.alignment = .center
            rows.append(row)
        } else {
            rows.append(makeLabel("The App Store isn't reachable right now.",
                                  font: .systemFont(ofSize: 16, weight: .bold), style: .headline,
                                  color: WarmShelfPalette.clayInk))
            rows.append(makeLabel("Check the connection, then try again. Nothing has been charged.",
                                  font: .systemFont(ofSize: 14.5), style: .subheadline, color: WarmShelfPalette.cocoa))
            if showsStartButton {
                let retry = makeButton(title: "Try again", filled: false)
                retry.addAction(UIAction { [actions] _ in actions.retry() }, for: .touchUpInside)
                rows.append(retry)
            }
        }
        let column = UIStackView(arrangedSubviews: rows)
        column.axis = .vertical
        column.spacing = 8
        fill(card, with: column, inset: 18)
        return card
    }

    // MARK: Promises

    /// The answers to "what if I forget?", "can I get out?", "is it for all of us?" and "what
    /// about my child's data?" — the four reasons a grown-up hesitates.
    private func makePromisesCard() -> UIView {
        let card = makeCard(highlighted: false)
        let trial = offer.freeLength != nil
        var rows: [UIView] = [makeEyebrow("NO SURPRISES")]
        if trial {
            rows.append(makePromise("bell.fill", tint: WarmShelfPalette.butter, title: "An optional reminder before you pay",
                                    detail: "Allow notifications to set a reminder two days before the week ends."))
        }
        rows.append(makePromise("hand.tap.fill", tint: WarmShelfPalette.sage, title: "Cancel in a few taps",
                                detail: trial
                                    ? "In Settings › your name › Subscriptions. To pay nothing, cancel at least 24 hours before the trial ends."
                                    : "In Settings › your name › Subscriptions, whenever you like."))
        if offer.familyShared || offer.keepForeverShared {
            rows.append(makePromise("person.2.fill", tint: WarmShelfPalette.waterBlue, title: "One purchase, the whole family",
                                    detail: "Everyone in your Family Sharing group plays on their own iPhone or iPad."))
        }
        rows.append(makePromise("lock.shield.fill", tint: WarmShelfPalette.lavender,
                                title: "Nothing about your child leaves this device",
                                detail: "No ads, no accounts, no tracking. Ever."))
        let column = UIStackView(arrangedSubviews: rows)
        column.axis = .vertical
        column.spacing = 14
        column.setCustomSpacing(12, after: rows[0])
        fill(card, with: column, inset: 18)
        return card
    }

    private func makePromise(_ symbol: String, tint: UIColor, title: String, detail: String) -> UIView {
        let box = UIView()
        box.backgroundColor = tint.withAlphaComponent(0.18)
        box.layer.cornerRadius = 10
        box.translatesAutoresizingMaskIntoConstraints = false
        let icon = UIImageView(image: UIImage(systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)))
        icon.tintColor = tint
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(icon)
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: 34),
            box.heightAnchor.constraint(equalToConstant: 34),
            icon.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: box.centerYAnchor)
        ])
        box.isAccessibilityElement = false

        let name = makeLabel(title, font: .systemFont(ofSize: 15.5, weight: .bold), style: .headline,
                             color: WarmShelfPalette.clayInk)
        let words = makeLabel(detail, font: .systemFont(ofSize: 14), style: .subheadline,
                              color: WarmShelfPalette.cocoa)
        let text = UIStackView(arrangedSubviews: [name, words])
        text.axis = .vertical
        text.spacing = 2
        let row = UIStackView(arrangedSubviews: [box, text])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .top
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(title). \(detail)"
        return row
    }

    // MARK: Keep Forever, links, terms

    private func makeKeepForeverCard(price: String) -> UIView {
        let card = makeCard(highlighted: offer.familyPrice == nil)
        card.accessibilityIdentifier = "offer-keep-forever"
        let title = makeLabel(offer.familyPrice == nil ? "Keep Forever" : "Rather not subscribe?",
                              font: .systemFont(ofSize: 16, weight: .bold), style: .headline,
                              color: WarmShelfPalette.clayInk)
        let shared = offer.keepForeverShared ? " Shared with your family." : ""
        let words = makeLabel("Pay \(price) once. All nine toys and every new one, yours for good.\(shared)",
                              font: .systemFont(ofSize: 14.5), style: .subheadline, color: WarmShelfPalette.cocoa)
        let buy = makeButton(title: isBusy ? "Waiting for the App Store…" : "Buy once · \(price)",
                             filled: offer.familyPrice == nil)
        buy.accessibilityIdentifier = "full-toybox-purchase"
        buy.isEnabled = canPay && !isBusy
        buy.alpha = buy.isEnabled ? 1 : 0.6
        buy.addAction(UIAction { [actions] _ in actions.keepForever() }, for: .touchUpInside)
        let column = UIStackView(arrangedSubviews: [title, words, buy])
        column.axis = .vertical
        column.spacing = 4
        column.setCustomSpacing(12, after: words)
        fill(card, with: column, inset: 18)
        return card
    }

    private func makeLinksRow() -> UIView {
        let restore = makeTextButton("Restore purchases")
        restore.accessibilityIdentifier = "restore-purchase"
        restore.accessibilityHint = "Checks your Apple Account for Lull Family or Keep Forever."
        restore.isEnabled = !isBusy
        restore.addAction(UIAction { [actions] _ in actions.restore() }, for: .touchUpInside)
        let terms = makeTextButton("Terms of Use")
        terms.accessibilityIdentifier = "terms-of-use"
        terms.addAction(UIAction { [actions] _ in actions.terms() }, for: .touchUpInside)
        let privacy = makeTextButton("Privacy Policy")
        privacy.accessibilityIdentifier = "plans-privacy-policy"
        privacy.addAction(UIAction { [actions] _ in actions.privacy() }, for: .touchUpInside)
        let row = UIStackView(arrangedSubviews: [restore, terms, privacy])
        row.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        row.distribution = .fillEqually
        return row
    }

    // MARK: Pieces

    private func makeCard(highlighted: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = WarmShelfPalette.paperHighlight.withAlphaComponent(highlighted ? 0.92 : 0.66)
        card.layer.cornerRadius = 22
        card.layer.borderWidth = highlighted ? 1.5 : 1
        card.layer.borderColor = (highlighted ? WarmShelfPalette.butter : WarmShelfPalette.softLine.withAlphaComponent(0.45)).cgColor
        card.layer.shadowColor = WarmShelfPalette.contactShadow.cgColor
        card.layer.shadowOpacity = highlighted ? 0.12 : 0.07
        card.layer.shadowRadius = 16
        card.layer.shadowOffset = CGSize(width: 0, height: 8)
        return card
    }

    private func fill(_ card: UIView, with content: UIView, inset: CGFloat) {
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: inset),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -inset)
        ])
    }

    private func makeEyebrow(_ text: String) -> UILabel {
        let label = makeLabel(text, font: .systemFont(ofSize: 12, weight: .heavy), style: .caption1,
                              color: WarmShelfPalette.cocoa.withAlphaComponent(0.62))
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }

    private func makePill(_ text: String) -> UIView {
        let pill = UIView()
        pill.backgroundColor = WarmShelfPalette.butter.withAlphaComponent(0.28)
        pill.layer.cornerRadius = 11
        let label = makeLabel(text, font: .systemFont(ofSize: 11.5, weight: .heavy), style: .caption2,
                              color: WarmShelfPalette.clayInk)
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10)
        ])
        pill.setContentHuggingPriority(.required, for: .horizontal)
        pill.setContentCompressionResistancePriority(.required, for: .horizontal)
        return pill
    }

    private func makeDivider() -> UIView {
        let line = UIView()
        line.backgroundColor = WarmShelfPalette.softLine.withAlphaComponent(0.5)
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    private func makeNote(_ text: String) -> UIView {
        let card = makeCard(highlighted: false)
        let label = makeLabel(text, font: .systemFont(ofSize: 14, weight: .semibold), style: .subheadline,
                              color: WarmShelfPalette.cocoa)
        fill(card, with: label, inset: 14)
        return card
    }

    private func makeFinePrint(_ text: String) -> UILabel {
        let label = makeLabel(text, font: .systemFont(ofSize: 12), style: .caption1,
                              color: WarmShelfPalette.cocoa.withAlphaComponent(0.68))
        label.textAlignment = .center
        return label
    }

    private func makeLabel(_ text: String, font: UIFont, style: UIFont.TextStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFontMetrics(forTextStyle: style).scaledFont(for: font)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func makeButton(title: String, filled: Bool) -> UIButton {
        var config = filled ? UIButton.Configuration.filled() : UIButton.Configuration.plain()
        config.title = title
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .bold))
            return outgoing
        }
        config.titleAlignment = .center
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        config.background.cornerRadius = 18
        if filled {
            config.baseBackgroundColor = WarmShelfPalette.terracotta
            config.baseForegroundColor = WarmShelfPalette.paperHighlight
        } else {
            config.baseForegroundColor = WarmShelfPalette.terracotta
            config.background.strokeColor = WarmShelfPalette.terracotta.withAlphaComponent(0.7)
            config.background.strokeWidth = 1.5
        }
        let button = UIButton(configuration: config)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        return button
    }

    private func makeTextButton(_ title: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = WarmShelfPalette.terracotta
        config.titleAlignment = .center
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 4, bottom: 10, trailing: 4)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 14, weight: .semibold))
            return outgoing
        }
        let button = UIButton(configuration: config)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return button
    }
}

// MARK: - "Not sure yet?"

/// What a hesitant grown-up sees on "Not now": not a guilt trip, the honest version. How the
/// free week works, in one breath, then the same start button, the pay-once door, and a real
/// way out. A family that leaves finds the toybox waiting behind the grown-up button.
@MainActor
final class LullOfferPauseViewController: UIViewController {
    private let offer: LullPlanOffer
    private let onStart: () -> Void
    private let onKeepForever: () -> Void
    private let onLater: () -> Void

    init(offer: LullPlanOffer, onStart: @escaping () -> Void, onKeepForever: @escaping () -> Void,
         onLater: @escaping () -> Void) {
        self.offer = offer
        self.onStart = onStart
        self.onKeepForever = onKeepForever
        self.onLater = onLater
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.custom(identifier: .init("lull.pause")) { context in
                min(560, context.maximumDetentValue)
            }, .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WarmShelfPalette.linen

        let trial = offer.freeLength != nil
        // Wren, centred above the words.
        let mark = LullHostMarkView(side: 64)
        let markHolder = UIView()
        markHolder.addSubview(mark)
        NSLayoutConstraint.activate([
            mark.topAnchor.constraint(equalTo: markHolder.topAnchor),
            mark.bottomAnchor.constraint(equalTo: markHolder.bottomAnchor),
            mark.centerXAnchor.constraint(equalTo: markHolder.centerXAnchor)
        ])
        let title = UILabel()
        title.text = trial ? "Not sure yet?\nThat's okay." : "Not ready yet?\nThat's okay."
        title.font = UIFontMetrics(forTextStyle: .title1).scaledFont(for: UIFont(name: "Georgia", size: 28) ?? .systemFont(ofSize: 28, weight: .semibold))
        title.adjustsFontForContentSizeCategory = true
        title.textColor = WarmShelfPalette.clayInk
        title.textAlignment = .center
        title.numberOfLines = 0

        let body = UILabel()
        body.text = trial
            ? "Here's how the free week works. Your child plays with all nine toys. Allow notifications to set a reminder two days before the week ends. To pay nothing, cancel in Settings at least 24 hours before the trial ends."
            : "Whenever you're ready, a grown-up can open the toybox from the button at the bottom of the shelf."
        body.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 16))
        body.adjustsFontForContentSizeCategory = true
        body.textColor = WarmShelfPalette.cocoa
        body.textAlignment = .center
        body.numberOfLines = 0

        var rows: [UIView] = [markHolder, title, body]
        if let startTitle = offer.startTitle {
            rows.append(makeButton(startTitle, style: .filled) { [weak self] in self?.close(then: self?.onStart) })
            if let caption = offer.startCaption {
                let small = UILabel()
                small.text = caption
                small.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .medium))
                small.adjustsFontForContentSizeCategory = true
                small.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.75)
                small.textAlignment = .center
                small.numberOfLines = 0
                rows.append(small)
            }
        }
        if let keepForeverPrice = offer.keepForeverPrice {
            rows.append(makeButton("Pay \(keepForeverPrice) once instead", style: .outlined) { [weak self] in
                self?.close(then: self?.onKeepForever)
            })
        }
        rows.append(makeButton("Decide later", style: .text) { [weak self] in self?.close(then: self?.onLater) })

        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        stack.setCustomSpacing(14, after: markHolder)
        stack.setCustomSpacing(20, after: body)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 30),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.centerXAnchor.constraint(equalTo: scroll.frameLayoutGuide.centerXAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -56),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 460)
        ])
    }

    private enum Style { case filled, outlined, text }

    private func makeButton(_ title: String, style: Style, action: @escaping () -> Void) -> UIButton {
        var config: UIButton.Configuration
        switch style {
        case .filled:
            config = .filled()
            config.baseBackgroundColor = WarmShelfPalette.terracotta
            config.baseForegroundColor = WarmShelfPalette.paperHighlight
        case .outlined:
            config = .plain()
            config.baseForegroundColor = WarmShelfPalette.terracotta
            config.background.strokeColor = WarmShelfPalette.terracotta.withAlphaComponent(0.7)
            config.background.strokeWidth = 1.5
        case .text:
            config = .plain()
            config.baseForegroundColor = WarmShelfPalette.cocoa.withAlphaComponent(0.8)
        }
        config.title = title
        config.titleAlignment = .center
        config.background.cornerRadius = 18
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        let weight: UIFont.Weight = style == .text ? .semibold : .bold
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: style == .text ? 16 : 17, weight: weight))
            return outgoing
        }
        let button = UIButton(configuration: config)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: style == .text ? 44 : 54).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func close(then action: (() -> Void)?) {
        dismiss(animated: true) { action?() }
    }
}

// MARK: - The Full Toybox page

/// The Full Toybox on its own page (founder, October 11: prices and plans don't belong among the
/// family settings). Before the toybox is open it shows the one offer (`LullOfferView`); after,
/// what the family has: the free week's days left and its reminder, the plan, or Keep Forever,
/// with Manage subscription, Restore purchases, Terms of Use and Privacy Policy. Reached only
/// through the adult check: from the grown-up area's "Full Toybox" row and from the resting
/// shelf's grown-up button. The child's shelf never shows any of it.
final class LullPlansViewController: UIViewController {
    private let stack = UIStackView()
    private var statusMessage: String?
    private var isLoadingProducts = true
    private var isPurchaseInProgress = false

    /// One line for the grown-up area's Full Toybox row.
    static func statusLine() -> String {
        let state = LullDemoState.shared
        if state.hasKeepForever { return "Keep Forever: every toy, for good" }
        if state.hasPurchasedFullToybox, state.isInFreeWeek {
            let d = state.freeWeekDaysRemaining
            let left = "Free week: \(d) day\(d == 1 ? "" : "s") left"
            if state.planWillRenew == false { return "\(left) · won't renew" }
            guard let end = state.freeWeekEndDate else { return left }
            return "\(left) · Lull Family from \(LullPlanOffer.longDay(end))"
        }
        if state.hasSubscription {
            return state.planWillRenew == false ? "Lull Family: ends this year, won't renew" : "Lull Family: active"
        }
        if state.hasPurchasedFullToybox { return "All nine toys open" }
        if state.hasUnseenPlanEnd { return "Lull Family has ended · open the toybox again" }
        if LullPurchaseManager.shared.isEligibleForFreeWeek == true {
            return "Not open yet · start the free week"
        }
        return "Not open yet · see Lull Family and Keep Forever"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WarmShelfPalette.linen
        let scroll = UIScrollView()
        scroll.tag = 778
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        view.addSubview(scroll)
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -22),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -28)
        ])
        loadPurchaseOptions()
        // Ask to Buy approvals, renewals and refunds arrive while the page is open.
        accessObserver = NotificationCenter.default.addObserver(
            forName: .lullAccessDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.render() }
        }
    }

    private var accessObserver: NSObjectProtocol?

    deinit {
        if let accessObserver { NotificationCenter.default.removeObserver(accessObserver) }
    }

    private func render() {
        let scroll = view.viewWithTag(778) as? UIScrollView
        let oldOffset = scroll?.contentOffset
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        // A grown-up has now seen that the plan ended; the shelf chip's quiet dot can rest.
        let state = LullDemoState.shared
        if !state.hasPurchasedFullToybox, state.hasUnseenPlanEnd {
            state.acknowledgePlanState()
        }
        stack.addArrangedSubview(makeHeader())
        if let statusMessage {
            stack.addArrangedSubview(makeNoticeCard(text: statusMessage))
        }
        if state.hasPurchasedFullToybox {
            stack.addArrangedSubview(makeStatusHero())
        } else {
            stack.addArrangedSubview(makeOfferIntro())
            stack.addArrangedSubview(LullOfferView(
                offer: LullPlanOffer.current(), isLoading: isLoadingProducts, isBusy: isPurchaseInProgress,
                showsStartButton: true,
                actions: .init(
                    start: { [weak self] in self?.purchase(productID: LullStoreProduct.familyYearly) },
                    keepForever: { [weak self] in self?.purchase(productID: LullStoreProduct.lifetime) },
                    restore: { [weak self] in self?.restorePurchases() },
                    terms: { [weak self] in self?.openTerms() },
                    privacy: { [weak self] in self?.showPrivacy() },
                    retry: { [weak self] in self?.reloadProducts() }
                )
            ))
        }
        if let scroll, let oldOffset {
            view.layoutIfNeeded()
            let maxY = max(-scroll.adjustedContentInset.top,
                           scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            scroll.setContentOffset(CGPoint(x: 0, y: min(maxY, oldOffset.y)), animated: false)
        }
    }

    private func makeHeader() -> UIView {
        let title = UILabel()
        title.text = "Full Toybox"
        title.font = scaledFont(UIFont(name: "Georgia", size: 28) ?? .systemFont(ofSize: 28, weight: .semibold), style: .title1)
        title.adjustsFontForContentSizeCategory = true
        title.accessibilityTraits = .header
        title.textColor = WarmShelfPalette.clayInk
        title.numberOfLines = 0
        let close = UIButton(type: .system)
        close.setTitle("Done", for: .normal)
        close.titleLabel?.font = scaledFont(.systemFont(ofSize: 17, weight: .semibold), style: .headline)
        close.titleLabel?.adjustsFontForContentSizeCategory = true
        close.tintColor = WarmShelfPalette.terracotta
        close.accessibilityIdentifier = "plans-done"
        close.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        close.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [title, close])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        return row
    }

    /// One sentence above the offer: what the toybox is, or that the plan ended.
    private func makeOfferIntro() -> UIView {
        let label = makeBody(LullDemoState.shared.hasUnseenPlanEnd
            ? "Lull Family has ended, so the toybox is resting. Open it again whenever you're ready."
            : "Nine calm felt-and-wood toys, ready to open. New toys arrive each season.")
        label.font = scaledFont(.systemFont(ofSize: 16), style: .body)
        return label
    }

    @objc private func close(_ sender: Any?) {
        dismiss(animated: true)
    }

    @objc private func showPrivacy() {
        let privacy = LullPrivacyViewController()
        privacy.modalPresentationStyle = .pageSheet
        present(privacy, animated: true)
    }

    // MARK: - What the family has

    private func makeStatusHero() -> UIView {
        let card = UIView()
        card.accessibilityIdentifier = "plans-card"
        card.backgroundColor = WarmShelfPalette.clayInk
        card.layer.cornerRadius = 26
        card.layer.shadowColor = WarmShelfPalette.contactShadow.cgColor
        card.layer.shadowOpacity = 0.14
        card.layer.shadowRadius = 20
        card.layer.shadowOffset = CGSize(width: 0, height: 12)

        let state = LullDemoState.shared
        let store = LullPurchaseManager.shared
        let period = store.renewalPeriod(for: LullStoreProduct.familyYearly) ?? "year"

        let eyebrow = UILabel()
        let title = UILabel()
        let body = UILabel()
        title.text = "Full Toybox"
        if state.hasKeepForever {
            eyebrow.text = "KEEP FOREVER"
            body.text = "All nine toys, and every new one, are yours for good. Thank you for supporting Lull."
        } else if state.isInFreeWeek {
            let d = state.freeWeekDaysRemaining
            eyebrow.text = "FREE WEEK · \(d) DAY\(d == 1 ? "" : "S") LEFT"
            let end = LullPlanOffer.longDay(state.freeWeekEndDate ?? Date())
            body.text = state.planWillRenew == false
                ? "All nine toys are open until \(end). Lull Family won't renew, so the toybox then rests until a grown-up opens it again."
                : "All nine toys are open. On \(end), Lull Family begins at \(store.displayPrice(for: LullStoreProduct.familyYearly)) a \(period). To pay nothing, cancel at least 24 hours before the trial ends with Manage subscription below."
        } else if state.hasSubscription {
            eyebrow.text = "LULL FAMILY"
            body.text = state.planWillRenew == false
                ? "All nine toys stay open until this plan ends. It won't renew; after that the toybox rests until a grown-up opens it again."
                : "All nine toys, and new ones as they arrive each season. Renews automatically each \(period)."
        } else {
            eyebrow.text = "OPEN"
            body.text = "All nine toys are open. Thank you for supporting Lull."
        }
        eyebrow.font = scaledFont(.systemFont(ofSize: 12, weight: .bold), style: .caption1)
        eyebrow.adjustsFontForContentSizeCategory = true
        eyebrow.numberOfLines = 0
        eyebrow.textColor = WarmShelfPalette.butter
        title.font = scaledFont(UIFont(name: "Georgia", size: 28) ?? .systemFont(ofSize: 28, weight: .semibold), style: .title1)
        title.adjustsFontForContentSizeCategory = true
        title.accessibilityTraits = .header
        title.textColor = WarmShelfPalette.paperHighlight
        title.numberOfLines = 0
        body.font = scaledFont(.systemFont(ofSize: 15), style: .body)
        body.adjustsFontForContentSizeCategory = true
        body.textColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.9)
        body.numberOfLines = 0

        let content = UIStackView(arrangedSubviews: [eyebrow, title, body])
        content.axis = .vertical
        content.spacing = 8
        content.setCustomSpacing(5, after: eyebrow)
        content.setCustomSpacing(14, after: body)

        if state.hasSubscription {
            if state.isInFreeWeek, !LullFreeWeekReminder.isScheduled, LullFreeWeekReminder.reminderDate != nil {
                let remind = makeActionButton(title: "Remind me \(LullFreeWeekReminder.daysBefore) days before it ends", style: .secondary)
                remind.accessibilityIdentifier = "free-week-reminder"
                remind.backgroundColor = WarmShelfPalette.butter
                remind.layer.borderWidth = 0
                remind.setTitleColor(WarmShelfPalette.clayInk, for: .normal)
                remind.isEnabled = !isPurchaseInProgress
                remind.addTarget(self, action: #selector(setReminder), for: .touchUpInside)
                content.addArrangedSubview(remind)
            }
            let manage = makeActionButton(title: "Manage subscription", style: .secondary)
            manage.accessibilityIdentifier = "manage-subscription"
            manage.backgroundColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.12)
            manage.layer.borderColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.3).cgColor
            manage.setTitleColor(WarmShelfPalette.paperHighlight, for: .normal)
            manage.isEnabled = !isPurchaseInProgress
            manage.addTarget(self, action: #selector(manageSubscription), for: .touchUpInside)
            content.addArrangedSubview(manage)
        }

        let terms = makeActionButton(title: "Terms of Use", style: .text)
        terms.setTitleColor(WarmShelfPalette.paperHighlight.withAlphaComponent(0.95), for: .normal)
        terms.accessibilityIdentifier = "terms-of-use"
        terms.addTarget(self, action: #selector(openTerms), for: .touchUpInside)
        let privacy = makeActionButton(title: "Privacy Policy", style: .text)
        privacy.setTitleColor(WarmShelfPalette.paperHighlight.withAlphaComponent(0.95), for: .normal)
        privacy.accessibilityIdentifier = "plans-privacy-policy"
        privacy.addTarget(self, action: #selector(showPrivacy), for: .touchUpInside)
        let links = UIStackView(arrangedSubviews: [terms, privacy])
        links.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        links.distribution = .fillEqually
        content.addArrangedSubview(links)

        let restore = makeActionButton(title: "Restore purchases", style: .text)
        restore.setTitleColor(WarmShelfPalette.paperHighlight.withAlphaComponent(0.95), for: .normal)
        restore.accessibilityIdentifier = "restore-purchase"
        restore.accessibilityHint = "Checks your Apple Account for Lull Family or Keep Forever."
        restore.isEnabled = !isPurchaseInProgress
        restore.addTarget(self, action: #selector(restorePurchasesTapped), for: .touchUpInside)
        content.addArrangedSubview(restore)

        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        return card
    }

    // MARK: - Actions

    @objc private func setReminder() {
        guard !isPurchaseInProgress else { return }
        Task { @MainActor in
            let set = await LullFreeWeekReminder.requestAndSchedule()
            statusMessage = set
                ? LullFreeWeekReminder.reminderDate.map { "A reminder is scheduled for \(LullPlanOffer.longDay($0))." } ?? "A reminder is scheduled."
                : "No reminder is set. This page always shows the days left. Check that notifications are enabled for Lull in Settings, then try again."
            render()
        }
    }

    @objc private func manageSubscription() {
        guard !isPurchaseInProgress else { return }
        AdultGate.present(from: self) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                if let scene = self.view.window?.windowScene {
                    do {
                        try await AppStore.showManageSubscriptions(in: scene)
                    } catch {
                        _ = await UIApplication.shared.open(LullStoreProduct.manageSubscriptionsURL)
                    }
                } else {
                    _ = await UIApplication.shared.open(LullStoreProduct.manageSubscriptionsURL)
                }
                await LullPurchaseManager.shared.refreshEntitlements()
                self.render()
            }
        }
    }

    @objc private func openTerms() {
        UIApplication.shared.open(LullStoreProduct.termsOfUseURL)
    }

    @objc private func restorePurchasesTapped() {
        restorePurchases()
    }

    private func restorePurchases() {
        guard !isPurchaseInProgress else { return }
        isPurchaseInProgress = true
        statusMessage = nil
        render()
        Task { @MainActor in
            let restored = await LullPurchaseManager.shared.restorePurchases()
            isPurchaseInProgress = false
            statusMessage = restored
                ? "Purchases restored. The toybox is open."
                : (LullPurchaseManager.shared.lastErrorMessage ?? "No Lull Family plan or Keep Forever purchase was found for this Apple Account.")
            render()
        }
    }

    /// This page is only ever shown behind the adult check, so a plan's button goes straight to
    /// Apple's own confirmation sheet rather than asking the grown-up a second question.
    private func purchase(productID: String) {
        guard !isPurchaseInProgress,
              LullPurchaseManager.shared.product(for: productID) != nil else { return }
        isPurchaseInProgress = true
        statusMessage = nil
        render()
        Task { @MainActor in
            let outcome = await LullPurchaseFlow.buy(productID)
            isPurchaseInProgress = false
            switch outcome {
            case .opened(let words): statusMessage = words
            case .notOpened(let reason): statusMessage = reason
            }
            render()
        }
    }

    @objc private func reloadProducts() {
        guard !isLoadingProducts, !isPurchaseInProgress else { return }
        loadPurchaseOptions()
    }

    private func loadPurchaseOptions() {
        isLoadingProducts = true
        render()
        Task { @MainActor in
            await LullPurchaseManager.shared.loadProducts()
            isLoadingProducts = false
            render()
        }
    }

    // MARK: - Small pieces

    private enum ActionStyle {
        case primary
        case secondary
        case text
    }

    private func scaledFont(_ font: UIFont, style: UIFont.TextStyle) -> UIFont {
        UIFontMetrics(forTextStyle: style).scaledFont(for: font, compatibleWith: traitCollection)
    }

    private func makeNoticeCard(text: String) -> UIView {
        let card = makeTintCard(color: WarmShelfPalette.sage)
        let label = makeBody(text)
        label.font = scaledFont(.systemFont(ofSize: 15, weight: .semibold), style: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 15),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -15),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }

    private func makeTintCard(color: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor = color.withAlphaComponent(0.10)
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.borderColor = WarmShelfPalette.softLine.withAlphaComponent(0.34).cgColor
        return card
    }

    private func makeActionButton(title: String, style: ActionStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.accessibilityIdentifier = "parent-action-\(title)"
        button.titleLabel?.font = scaledFont(.systemFont(ofSize: style == .text ? 16 : 17, weight: .semibold), style: .headline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        button.layer.cornerRadius = 18
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: style == .text ? 44 : 54).isActive = true

        switch style {
        case .primary:
            button.backgroundColor = WarmShelfPalette.clayInk
            button.tintColor = WarmShelfPalette.paperHighlight
        case .secondary:
            button.backgroundColor = WarmShelfPalette.warmCream.withAlphaComponent(0.42)
            button.tintColor = WarmShelfPalette.cocoa
            button.layer.borderWidth = 1
            button.layer.borderColor = WarmShelfPalette.softLine.withAlphaComponent(0.34).cgColor
        case .text:
            button.backgroundColor = .clear
            button.tintColor = WarmShelfPalette.terracotta
        }

        return button
    }

    private func makeBody(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = scaledFont(.systemFont(ofSize: 16), style: .body)
        label.textColor = WarmShelfPalette.cocoa
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }
}
