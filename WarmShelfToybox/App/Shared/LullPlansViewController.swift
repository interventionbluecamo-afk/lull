import UIKit
import StoreKit

/// The Full Toybox on its own page (founder, October 11: prices and plans don't belong among the
/// family settings). Lull Family (free week, yearly) and Keep Forever (once), Apple's subscription
/// terms, Terms of Use, Privacy Policy, Manage subscription and Restore purchases. Reached from
/// the grown-up area's "Full Toybox" row and from the welcome's "Try all nine free", always
/// behind the adult check. The child's shelf never shows any of it.
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
            return "Free week: \(d) day\(d == 1 ? "" : "s") left"
        }
        if state.hasSubscription {
            return state.planWillRenew == false ? "Lull Family: ends this year, won't renew" : "Lull Family: active"
        }
        if state.hasPurchasedFullToybox { return "All nine toys unlocked" }
        if state.hasUnseenPlanEnd { return "Lull Family has ended. See the plans" }
        return "Three toys free. See Lull Family and Keep Forever"
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
        ) { [weak self] _ in self?.render() }
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
        stack.addArrangedSubview(makeStatusHero())
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

    @objc private func close(_ sender: Any?) {
        dismiss(animated: true)
    }

    @objc private func showPrivacy() {
        let privacy = LullPrivacyViewController()
        privacy.modalPresentationStyle = .pageSheet
        present(privacy, animated: true)
    }

    // MARK: - The plans card

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
        let purchased = state.hasPurchasedFullToybox
        // Never advertise a fallback price or terms for a product the App Store didn't return.
        let family = store.product(for: LullStoreProduct.familyYearly)
        let familyPrice = family?.type == .autoRenewable ? family?.displayPrice : nil
        let keepForever = store.product(for: LullStoreProduct.lifetime)
        let keepForeverPrice = keepForever?.type == .nonConsumable ? keepForever?.displayPrice : nil
        let period = store.renewalPeriod(for: LullStoreProduct.familyYearly) ?? "year"
        let freeLength = store.isEligibleForFreeWeek == true
            ? store.freeWeekLength(for: LullStoreProduct.familyYearly) : nil
        // Screen Time can switch purchases off; say so instead of offering a dead button.
        let purchasesAllowed = AppStore.canMakePayments
        let canBuy = purchasesAllowed && !isLoadingProducts && !isPurchaseInProgress

        let eyebrow = UILabel()
        let title = UILabel()
        let body = UILabel()
        title.text = "Full Toybox"
        if state.hasKeepForever {
            eyebrow.text = "KEEP FOREVER"
            body.text = "All nine toys, and every new one, are yours for good. Thank you for supporting Lull."
        } else if purchased && state.isInFreeWeek {
            let d = state.freeWeekDaysRemaining
            eyebrow.text = "FREE WEEK · \(d) DAY\(d == 1 ? "" : "S") LEFT"
            let end = DateFormatter.localizedString(from: state.freeWeekEndDate ?? Date(), dateStyle: .long, timeStyle: .none)
            body.text = state.planWillRenew == false
                ? "All nine toys are open until \(end). Lull Family won't renew, so the shelf then goes back to the three free toys."
                : "All nine toys are open. Lull Family begins on \(end) at \(store.displayPrice(for: LullStoreProduct.familyYearly)) a \(period) unless you cancel at least a day before."
        } else if purchased && state.hasSubscription {
            eyebrow.text = "LULL FAMILY"
            body.text = state.planWillRenew == false
                ? "All nine toys stay open until this plan ends. It won't renew; Bubbles, Drop Dots, and Hum stay free afterward."
                : "All nine toys, and new ones as they arrive each season. Renews automatically each \(period)."
        } else if purchased {
            eyebrow.text = "UNLOCKED"
            body.text = "All nine toys are unlocked. Thank you for supporting Lull."
        } else {
            eyebrow.text = state.hasUnseenPlanEnd ? "LULL FAMILY HAS ENDED" : "THREE FREE TOYS · NINE TO PLAY"
            body.text = "Bubbles, Drop Dots, and Hum stay free. Open all nine toys for familiar friends, music, and quiet discovery, plus new toys each season."
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

        if !purchased {
            content.addArrangedSubview(makeLivingPreview())

            if let familyPrice {
                let buttonTitle: String
                if isPurchaseInProgress {
                    buttonTitle = "Waiting for the App Store…"
                } else if freeLength != nil {
                    buttonTitle = "Start the free week"
                } else {
                    buttonTitle = "Subscribe · \(familyPrice) a \(period)"
                }
                content.addArrangedSubview(makePlanTile(
                    eyebrow: "LULL FAMILY",
                    price: "\(familyPrice) a \(period)",
                    detail: freeLength.map { "First \($0) free, then \(familyPrice) a \(period). New toys each season. Cancel anytime." }
                        ?? "All nine toys and new ones each season. Cancel anytime.",
                    buttonTitle: buttonTitle, filled: true, identifier: "plan-family-purchase",
                    enabled: canBuy, action: #selector(purchaseFamily)
                ))
            }
            if let keepForeverPrice {
                content.addArrangedSubview(makePlanTile(
                    eyebrow: "KEEP FOREVER",
                    price: "\(keepForeverPrice) once",
                    detail: "One payment. All nine toys and every new one, for good.",
                    buttonTitle: isPurchaseInProgress ? "Waiting for the App Store…" : "Buy once · \(keepForeverPrice)",
                    filled: familyPrice == nil, identifier: "full-toybox-purchase",
                    enabled: canBuy, action: #selector(purchaseKeepForever)
                ))
            }

            let note: String?
            if familyPrice == nil && keepForeverPrice == nil {
                note = isLoadingProducts
                    ? "Loading App Store prices… You can keep playing the free toys."
                    : "The full toybox is unavailable from the App Store right now. You can keep playing the free toys."
            } else if !purchasesAllowed {
                note = "In-App Purchases are turned off in Screen Time on this device. The free toys stay open."
            } else {
                note = nil
            }
            if let note {
                content.addArrangedSubview(makeHeroNote(note, size: 13))
            }
            if !isLoadingProducts, familyPrice == nil || keepForeverPrice == nil {
                let retry = makeActionButton(title: "Reload App Store prices", style: .text)
                retry.setTitleColor(WarmShelfPalette.paperHighlight, for: .normal)
                retry.isEnabled = !isPurchaseInProgress
                retry.addTarget(self, action: #selector(reloadProducts), for: .touchUpInside)
                content.addArrangedSubview(retry)
            }
            if let familyPrice {
                // Apple's subscription terms, in full, beside the button (Guideline 3.1.2).
                let start = freeLength.map { "after the free \($0)" } ?? "from today"
                content.addArrangedSubview(makeHeroNote(
                    "Lull Family is an auto-renewing subscription: \(familyPrice) a \(period) \(start). Payment is charged to your Apple Account when you confirm\(freeLength == nil ? "" : ", but nothing is charged until the free week ends"). It renews automatically unless cancelled at least 24 hours before the end of the current period, and renewal is charged within the 24 hours before the period ends. Manage or cancel anytime in your Apple Account settings. Keep Forever is a one-time purchase.",
                    size: 12
                ))
            }
        } else if state.hasSubscription {
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
        restore.addTarget(self, action: #selector(restorePurchases), for: .touchUpInside)
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

    /// One plan on the dark card. The billed price is the largest text in the tile, ahead of
    /// any free period (Guideline 3.1.2).
    private func makePlanTile(eyebrow: String, price: String, detail: String, buttonTitle: String,
                              filled: Bool, identifier: String, enabled: Bool, action: Selector) -> UIView {
        let tile = UIView()
        tile.backgroundColor = WarmShelfPalette.paperHighlight.withAlphaComponent(filled ? 0.10 : 0.05)
        tile.layer.cornerRadius = 20
        tile.layer.borderWidth = filled ? 1.5 : 1
        tile.layer.borderColor = (filled ? WarmShelfPalette.butter : WarmShelfPalette.paperHighlight.withAlphaComponent(0.25)).cgColor

        let name = UILabel()
        name.text = eyebrow
        name.font = scaledFont(.systemFont(ofSize: 12, weight: .bold), style: .caption1)
        name.adjustsFontForContentSizeCategory = true
        name.textColor = WarmShelfPalette.butter
        name.numberOfLines = 0

        let amount = UILabel()
        amount.text = price
        amount.font = scaledFont(UIFont(name: "Georgia-Bold", size: 24) ?? .systemFont(ofSize: 24, weight: .bold), style: .title2)
        amount.adjustsFontForContentSizeCategory = true
        amount.textColor = WarmShelfPalette.paperHighlight
        amount.numberOfLines = 0

        let words = UILabel()
        words.text = detail
        words.font = scaledFont(.systemFont(ofSize: 14), style: .subheadline)
        words.adjustsFontForContentSizeCategory = true
        words.textColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.88)
        words.numberOfLines = 0

        let button = UIButton(type: .system)
        button.setTitle(buttonTitle, for: .normal)
        button.accessibilityIdentifier = identifier
        button.titleLabel?.font = scaledFont(.systemFont(ofSize: 17, weight: .bold), style: .headline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.contentEdgeInsets = UIEdgeInsets(top: 13, left: 12, bottom: 13, right: 12)
        button.layer.cornerRadius = 16
        if filled {
            button.backgroundColor = WarmShelfPalette.butter
            button.setTitleColor(WarmShelfPalette.clayInk, for: .normal)
        } else {
            button.backgroundColor = .clear
            button.layer.borderWidth = 1.5
            button.layer.borderColor = WarmShelfPalette.butter.withAlphaComponent(0.8).cgColor
            button.setTitleColor(WarmShelfPalette.butter, for: .normal)
        }
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        button.isEnabled = enabled
        button.alpha = enabled ? 1 : 0.65

        let column = UIStackView(arrangedSubviews: [name, amount, words, button])
        column.axis = .vertical
        column.spacing = 4
        column.setCustomSpacing(12, after: words)
        column.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: tile.topAnchor, constant: 16),
            column.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -16),
            column.bottomAnchor.constraint(equalTo: tile.bottomAnchor, constant: -16)
        ])
        return tile
    }

    private func makeHeroNote(_ text: String, size: CGFloat) -> UILabel {
        let note = UILabel()
        note.text = text
        note.font = scaledFont(.systemFont(ofSize: size, weight: .medium), style: .footnote)
        note.adjustsFontForContentSizeCategory = true
        note.textColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.8)
        note.textAlignment = .center
        note.numberOfLines = 0
        return note
    }


    private func makeLivingPreview() -> UIView {
        // The toys included in the unlock, shown *alive* — breathing, swaying, blinking —
        // so a grown-up feels the value before the price. (Children never see this screen.)
        let paidToyIDs = ToyRegistry.launchToyIDs
            .filter { ToyRegistry.toy(id: $0)?.accessTier == .fullToybox }
        return PaywallPreviewStrip(toyIDs: paidToyIDs)
    }

    // MARK: - Actions

    @objc private func purchaseFamily() {
        startPurchase(LullStoreProduct.familyYearly, type: .autoRenewable)
    }

    @objc private func purchaseKeepForever() {
        startPurchase(LullStoreProduct.lifetime, type: .nonConsumable)
    }

    private func startPurchase(_ productID: String, type: Product.ProductType) {
        guard !isPurchaseInProgress,
              LullPurchaseManager.shared.product(for: productID)?.type == type else { return }
        AdultGate.present(from: self) { [weak self] in
            self?.purchase(productID: productID)
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

    @objc private func restorePurchases() {
        guard !isPurchaseInProgress else { return }
        AdultGate.present(from: self) { [weak self] in
            guard let self, !self.isPurchaseInProgress else { return }
            self.isPurchaseInProgress = true
            self.statusMessage = nil
            self.render()
            Task { @MainActor in
                let restored = await LullPurchaseManager.shared.restorePurchases()
                self.isPurchaseInProgress = false
                self.statusMessage = restored
                    ? "Purchases restored. The full toybox is open."
                    : (LullPurchaseManager.shared.lastErrorMessage ?? "No Lull Family plan or Keep Forever purchase was found for this Apple Account.")
                self.render()
            }
        }
    }

    private func purchase(productID: String) {
        guard !isPurchaseInProgress,
              LullPurchaseManager.shared.product(for: productID) != nil else { return }
        isPurchaseInProgress = true
        statusMessage = nil
        render()
        Task { @MainActor in
            let purchased = await LullPurchaseManager.shared.purchase(productID)
            isPurchaseInProgress = false
            if purchased {
                let state = LullDemoState.shared
                statusMessage = state.hasKeepForever
                    ? "Keep Forever is active. All nine toys are yours, and the child's shelf stays free of locks and prices."
                    : state.isInFreeWeek
                    ? "Your free week has begun. All nine toys are open, and the child's shelf stays free of locks and prices."
                    : "Lull Family is active. All nine toys are open, and the child's shelf stays free of locks and prices."
            } else if let message = LullPurchaseManager.shared.lastErrorMessage {
                statusMessage = message
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
