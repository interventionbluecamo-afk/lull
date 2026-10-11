import UIKit
import StoreKit

/// Contact and policy destinations, in one place. Keep these identical to the website
/// (`LandingPageDeploy/`) and App Store Connect (Support URL, Privacy Policy URL).
enum LullLinks {
    /// FOUNDER: must be a mailbox you control before public release (see Docs/AppStore/).
    static let supportEmail = "support@lull.app"
    /// The hosted copy of `LullPrivacyViewController.sections`. nil hides "Read it on the web".
    static let privacyPolicyURL: URL? = nil
}

/// Parent-only access, preferences, and a clear description of the current toybox.
final class ParentInfoViewController: UIViewController {
    private let stack = UIStackView()
    private let supportEmail = LullLinks.supportEmail
    private var statusMessage: String?
    private var isLoadingProducts = true
    private var isPurchaseInProgress = false
    private var expandedSections: Set<Int> = []
    /// Set by the welcome's "Try all nine" so the grown-up lands on the plans, not settings.
    var opensAtPlans = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WarmShelfPalette.linen
        buildView()
        loadPurchaseOptions()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard opensAtPlans,
              let scroll = view.viewWithTag(777) as? UIScrollView,
              let plans = descendant(in: stack, identifier: "plans-card"),
              plans.bounds.height > 0 else { return }
        opensAtPlans = false
        let frame = plans.convert(plans.bounds, to: scroll)
        let minY = -scroll.adjustedContentInset.top
        let maxY = max(minY, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
        scroll.setContentOffset(CGPoint(x: 0, y: min(maxY, max(minY, frame.minY - 16))), animated: false)
    }

    #if DEBUG
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // LULL_DEBUG_PARENT_SCROLL=<points> — headless screenshots of any section.
        if let raw = ProcessInfo.processInfo.environment["LULL_DEBUG_PARENT_SCROLL"],
           let y = Double(raw), let scroll = view.viewWithTag(777) as? UIScrollView {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                scroll.setContentOffset(CGPoint(x: 0, y: y), animated: false)
            }
        }
    }
    #endif

    private func buildView() {
        let scrollView = UIScrollView()
        scrollView.tag = 777   // QA hook below finds it
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .always
        view.addSubview(scrollView)

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28)
        ])

        render()
    }

    // MARK: - Page

    private func render() {
        let scroll = view.viewWithTag(777) as? UIScrollView
        let oldOffset = scroll?.contentOffset
        let hadContent = (scroll?.contentSize.height ?? 0) > 0
        let focusedID = (UIAccessibility.focusedElement(using: .notificationVoiceOver) as? UIView)?.accessibilityIdentifier
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        stack.addArrangedSubview(makeHeaderBar())
        stack.setCustomSpacing(20, after: stack.arrangedSubviews.last!)

        // A grown-up has now seen that the plan ended; the shelf chip's quiet dot can rest.
        let state = LullDemoState.shared
        if !state.hasPurchasedFullToybox, state.hasUnseenPlanEnd {
            state.acknowledgePlanState()
        }
        if let statusMessage {
            stack.addArrangedSubview(makeNoticeCard(text: statusMessage))
        }

        stack.addArrangedSubview(makeCaption("FAMILY CONTROLS"))
        stack.addArrangedSubview(makeGroupCard([
            makeSwitchGroupRow(
                icon: "speaker.wave.2.fill", tint: WarmShelfPalette.waterBlue,
                title: "Sound", detail: "Soft sounds during play",
                isOn: AudioManager.shared.isEnabled, tag: 0,
                action: #selector(toggleSound)
            ),
            makeSwitchGroupRow(
                icon: "hand.tap.fill", tint: WarmShelfPalette.petal,
                title: "Haptics", detail: "Gentle touch feedback",
                isOn: HapticsManager.shared.isEnabled, tag: 0,
                action: #selector(toggleHaptics)
            ),
            makeSwitchGroupRow(
                icon: "wind", tint: WarmShelfPalette.sage,
                title: "Calmer motion", detail: "Less movement; also follows Reduce Motion",
                isOn: state.isReducedMotion, tag: 0,
                action: #selector(toggleReducedMotion)
            )
        ]))
        stack.addArrangedSubview(makeGroupCard([
            makeOptionGroupRow(
                icon: "hourglass", tint: WarmShelfPalette.butter,
                title: "Play timer", detail: "Lull rests when time is up. A grown-up can wake it.",
                labels: ["Off", "15m", "30m", "45m", "60m"],
                selectedIndex: [0, 15, 30, 45, 60].firstIndex(of: state.playTimerMinutes) ?? 0,
                action: #selector(playTimerPicked(_:))
            ),
            makeOptionGroupRow(
                icon: "moon.zzz.fill", tint: WarmShelfPalette.lavender,
                title: "Wind-down hour", detail: "Play feels warmer and sleepier after this time.",
                labels: ["5 pm", "6 pm", "7 pm", "8 pm", "9 pm"],
                selectedIndex: [17, 18, 19, 20, 21].firstIndex(of: state.windDownHour) ?? 2,
                action: #selector(windDownPicked(_:))
            )
        ]))

        var toyRows: [UIView] = []
        let hiddenToys = state.hiddenToyIDs
        for (index, toyID) in ToyRegistry.launchToyIDs.enumerated() {
            guard let toy = ToyRegistry.toy(id: toyID) else { continue }
            let isVisible = !hiddenToys.contains(toyID)
            let detail: String
            if ToyRegistry.isToyLocked(toyID) {
                detail = isVisible ? "Full Toybox · shown when unlocked" : "Full Toybox · tucked away"
            } else {
                detail = isVisible ? "On the child's shelf" : "Tucked away"
            }
            toyRows.append(makeSwitchGroupRow(
                icon: "circle.grid.2x2.fill", tint: toyAccent(index),
                title: toy.parentName, detail: detail,
                isOn: isVisible, tag: index,
                action: #selector(toyRowTapped(_:))
            ))
        }
        let shownCount = ToyRegistry.launchToyIDs.filter {
            !hiddenToys.contains($0) && !ToyRegistry.isToyLocked($0)
        }.count
        stack.addArrangedSubview(makeDisclosureCard(
            title: "Choose shelf toys", detail: "\(shownCount) toys on the child's shelf", section: 0,
            content: [makeGroupCard(toyRows),
                      makeFootnote("Choose which toys appear. At least one free toy stays visible.")]
        ))

        stack.setCustomSpacing(24, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(makeStatusHero())
        stack.setCustomSpacing(24, after: stack.arrangedSubviews.last!)

        let welcome = makeActionButton(title: "See the welcome again", style: .text)
        welcome.addTarget(self, action: #selector(resetOnboarding), for: .touchUpInside)
        stack.addArrangedSubview(makeDisclosureCard(
            title: "About Lull", detail: "A quiet toybox for ages 2–6", section: 1,
            content: [makeBody("Wash, post, make music, and explore. Let your child choose a familiar toy and repeat at their own pace."),
                      makeBody("No ads, scores, streaks, or child-facing purchases."), welcome]
        ))
        let policy = makeActionButton(title: "Read privacy policy", style: .text)
        policy.addTarget(self, action: #selector(showPrivacy), for: .touchUpInside)
        stack.addArrangedSubview(makeDisclosureCard(
            title: "Privacy", detail: "No child accounts or tracking", section: 2,
            content: [makeBody("Family settings and Mix-Up creations stay on this device. Apple handles purchases."), policy]
        ))
        stack.addArrangedSubview(makeGroupCard([
            makeChevronRow(icon: "envelope.fill", tint: WarmShelfPalette.butter,
                           title: "Contact support", action: #selector(contactSupport))
        ]))

        #if DEBUG
        let isUnlocked = LullDemoState.shared.debugForceFullUnlock
        let devButton = makeActionButton(
            title: isUnlocked ? "Dev: lock toys again" : "Dev: unlock all toys",
            style: .secondary
        )
        devButton.addTarget(self, action: #selector(toggleDevUnlock), for: .touchUpInside)
        stack.addArrangedSubview(devButton)
        #endif

        let doneButton = makeActionButton(title: "Back to play", style: .primary)
        doneButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        stack.addArrangedSubview(doneButton)
        stack.addArrangedSubview(makeFootnote("lull — made with patience by two people and a toddler.", centered: true))

        // Updating a switch or loading a price should not send a family back to the top.
        if hadContent, let scroll, let oldOffset {
            view.layoutIfNeeded()
            let minY = -scroll.adjustedContentInset.top
            let maxY = max(minY, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            scroll.setContentOffset(CGPoint(x: oldOffset.x, y: min(maxY, max(minY, oldOffset.y))), animated: false)
        }
        if let focusedID, let replacement = descendant(in: stack, identifier: focusedID) {
            UIAccessibility.post(notification: .layoutChanged, argument: replacement)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if isViewLoaded, stack.superview != nil, previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            render()
        }
    }

    private func descendant(in view: UIView, identifier: String) -> UIView? {
        if view.accessibilityIdentifier == identifier { return view }
        for child in view.subviews {
            if let match = descendant(in: child, identifier: identifier) { return match }
        }
        return nil
    }

    private func toyAccent(_ index: Int) -> UIColor {
        let palette = [WarmShelfPalette.terracotta, WarmShelfPalette.butter, WarmShelfPalette.sage,
                       WarmShelfPalette.waterBlue, WarmShelfPalette.lavender, WarmShelfPalette.petal]
        return palette[index % palette.count]
    }

    // MARK: - Header

    private func makeHeaderBar() -> UIView {
        let bar = UIView()

        let seal = LullHostMarkView(side: 46)
        seal.isHidden = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        seal.accessibilityElementsHidden = true

        let title = UILabel()
        title.text = "Family settings"
        title.font = scaledFont(UIFont(name: "Georgia", size: 28) ?? .systemFont(ofSize: 28, weight: .semibold), style: .title1)
        title.adjustsFontForContentSizeCategory = true
        title.accessibilityTraits = .header
        title.textColor = WarmShelfPalette.clayInk
        title.numberOfLines = 0

        let sub = UILabel()
        sub.text = "A quiet toybox for ages 2–6."
        sub.font = scaledFont(.systemFont(ofSize: 14), style: .subheadline)
        sub.adjustsFontForContentSizeCategory = true
        sub.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.78)
        sub.numberOfLines = 0

        let titles = UIStackView(arrangedSubviews: [title, sub])
        titles.axis = .vertical
        titles.spacing = 3

        let closeChip = UIButton(type: .system)
        closeChip.setImage(UIImage(systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)), for: .normal)
        closeChip.tintColor = WarmShelfPalette.cocoa
        closeChip.backgroundColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.8)
        closeChip.layer.cornerRadius = 22
        closeChip.accessibilityLabel = "Back to play"
        closeChip.accessibilityIdentifier = "parent-close"
        closeChip.layer.borderWidth = 1
        closeChip.layer.borderColor = WarmShelfPalette.softLine.withAlphaComponent(0.4).cgColor
        closeChip.addTarget(self, action: #selector(close), for: .touchUpInside)

        [seal, titles, closeChip].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            bar.addSubview($0)
        }
        NSLayoutConstraint.activate([
            seal.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            seal.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            seal.widthAnchor.constraint(equalToConstant: traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 0 : 46),
            seal.heightAnchor.constraint(equalToConstant: 46),
            titles.leadingAnchor.constraint(equalTo: seal.trailingAnchor, constant: traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 0 : 12),
            titles.topAnchor.constraint(equalTo: bar.topAnchor),
            titles.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            titles.trailingAnchor.constraint(equalTo: closeChip.leadingAnchor, constant: -10),
            closeChip.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            closeChip.topAnchor.constraint(equalTo: bar.topAnchor),
            closeChip.widthAnchor.constraint(equalToConstant: 44),
            closeChip.heightAnchor.constraint(equalToConstant: 44)
        ])
        return bar
    }

    // MARK: - Full Toybox

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
                ? "All nine toys stay open until this plan ends. It won't renew; Bubbles, Little Wash, and Drop Dots stay free afterward."
                : "All nine toys, and new ones as they arrive each season. Renews automatically each \(period)."
        } else if purchased {
            eyebrow.text = "UNLOCKED"
            body.text = "All nine toys are unlocked. Thank you for supporting Lull."
        } else {
            eyebrow.text = state.hasUnseenPlanEnd ? "LULL FAMILY HAS ENDED" : "THREE FREE TOYS · NINE TO PLAY"
            body.text = "Bubbles, Little Wash, and Drop Dots stay free. Open all nine toys for familiar friends, music, and quiet discovery, plus new toys each season."
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

    // MARK: - Group cards (the settings anatomy)

    private func makeGroupCard(_ rows: [UIView]) -> UIView {
        let card = makeRaisedCard(fill: WarmShelfPalette.paperHighlight.withAlphaComponent(0.62), radius: 22)
        let column = UIStackView()
        column.axis = .vertical
        column.spacing = 0
        for (i, row) in rows.enumerated() {
            column.addArrangedSubview(row)
            if i < rows.count - 1 {
                let line = UIView()
                line.backgroundColor = WarmShelfPalette.softLine.withAlphaComponent(0.45)
                line.translatesAutoresizingMaskIntoConstraints = false
                line.heightAnchor.constraint(equalToConstant: 1).isActive = true
                let inset = UIView()
                inset.translatesAutoresizingMaskIntoConstraints = false
                inset.addSubview(line)
                NSLayoutConstraint.activate([
                    line.leadingAnchor.constraint(equalTo: inset.leadingAnchor, constant: 58),
                    line.trailingAnchor.constraint(equalTo: inset.trailingAnchor),
                    line.topAnchor.constraint(equalTo: inset.topAnchor),
                    line.bottomAnchor.constraint(equalTo: inset.bottomAnchor)
                ])
                column.addArrangedSubview(inset)
            }
        }
        column.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4)
        ])
        return card
    }

    private func makeIconSquircle(_ symbol: String, tint: UIColor) -> UIView {
        let box = UIView()
        box.backgroundColor = tint.withAlphaComponent(0.16)
        box.layer.cornerRadius = 10
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 34).isActive = true
        box.heightAnchor.constraint(equalToConstant: 34).isActive = true
        let icon = UIImageView(image: UIImage(systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)))
        icon.tintColor = tint.withAlphaComponent(0.95)
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: box.centerYAnchor)
        ])
        return box
    }

    /// Icon + title + detail + soft switch, the whole row tappable.
    private func makeSwitchGroupRow(icon: String, tint: UIColor, title: String, detail: String,
                                    isOn: Bool, tag: Int, action: Selector) -> UIView {
        let row = UIButton(type: .custom)
        row.tag = tag
        row.isAccessibilityElement = true
        row.accessibilityIdentifier = "setting-\(NSStringFromSelector(action))-\(tag)"
        row.accessibilityLabel = title
        row.accessibilityValue = isOn ? "On" : "Off"
        row.accessibilityHint = detail
        row.accessibilityTraits = isOn ? [.button, .selected] : .button
        row.addTarget(self, action: action, for: .touchUpInside)

        let squircle = makeIconSquircle(icon, tint: tint)
        squircle.isUserInteractionEnabled = false

        let titleLabel = makeSmallTitle(title)
        let detailLabel = makeSmallBody(detail)
        detailLabel.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.82)
        let labels = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        labels.axis = .vertical
        labels.spacing = 2
        labels.isUserInteractionEnabled = false

        let toggle = UIView()
        toggle.backgroundColor = isOn ? WarmShelfPalette.terracotta : WarmShelfPalette.softLine
        toggle.layer.cornerRadius = 13.5
        toggle.isUserInteractionEnabled = false
        let knob = UIView()
        knob.backgroundColor = WarmShelfPalette.paperHighlight
        knob.layer.cornerRadius = 10
        knob.layer.shadowColor = WarmShelfPalette.contactShadow.cgColor
        knob.layer.shadowOpacity = 0.25
        knob.layer.shadowRadius = 3
        knob.layer.shadowOffset = CGSize(width: 0, height: 1)
        knob.translatesAutoresizingMaskIntoConstraints = false
        toggle.addSubview(knob)

        [squircle, labels, toggle].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 62),
            squircle.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            squircle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            labels.leadingAnchor.constraint(equalTo: squircle.trailingAnchor, constant: 11),
            labels.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            labels.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: 10),
            labels.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -10),
            labels.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -10),
            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            toggle.widthAnchor.constraint(equalToConstant: 46),
            toggle.heightAnchor.constraint(equalToConstant: 27),
            knob.centerYAnchor.constraint(equalTo: toggle.centerYAnchor),
            knob.widthAnchor.constraint(equalToConstant: 20),
            knob.heightAnchor.constraint(equalToConstant: 20),
            isOn ? knob.trailingAnchor.constraint(equalTo: toggle.trailingAnchor, constant: -3.5)
                 : knob.leadingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: 3.5)
        ])
        return row
    }

    /// Icon + title + detail + the choice pills, inside a group row.
    private func makeOptionGroupRow(icon: String, tint: UIColor, title: String, detail: String,
                                    labels: [String], selectedIndex: Int, action: Selector) -> UIView {
        let row = UIView()

        let squircle = makeIconSquircle(icon, tint: tint)
        let titleLabel = makeSmallTitle(title)
        let detailLabel = makeSmallBody(detail)
        detailLabel.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.82)

        let pillRow = UIStackView()
        // Five equally sized pills become a readable list at larger text sizes.
        pillRow.axis = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection).pointSize > 20 ? .vertical : .horizontal
        pillRow.spacing = 7
        pillRow.distribution = .fillEqually
        for (i, text) in labels.enumerated() {
            let pill = UIButton(type: .system)
            pill.setTitle(text, for: .normal)
            pill.titleLabel?.font = scaledFont(.systemFont(ofSize: 14, weight: .semibold), style: .subheadline)
            pill.titleLabel?.adjustsFontForContentSizeCategory = true
            pill.titleLabel?.numberOfLines = 0
            pill.titleLabel?.textAlignment = .center
            pill.contentEdgeInsets = UIEdgeInsets(top: 10, left: 4, bottom: 10, right: 4)
            pill.accessibilityIdentifier = "option-\(NSStringFromSelector(action))-\(i)"
            pill.accessibilityLabel = "\(title), \(text)"
            pill.tag = i
            let selected = i == selectedIndex
            pill.accessibilityTraits = selected ? [.button, .selected] : .button
            pill.backgroundColor = selected ? WarmShelfPalette.terracotta : WarmShelfPalette.warmCream.withAlphaComponent(0.55)
            pill.tintColor = selected ? WarmShelfPalette.paperHighlight : WarmShelfPalette.cocoa.withAlphaComponent(0.75)
            pill.layer.cornerRadius = 16
            pill.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            pill.addTarget(self, action: action, for: .touchUpInside)
            pillRow.addArrangedSubview(pill)
        }

        let titles = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        titles.axis = .vertical
        titles.spacing = 2

        let head = UIStackView(arrangedSubviews: [squircle, titles])
        head.axis = .horizontal
        head.spacing = 11
        head.alignment = .center

        let column = UIStackView(arrangedSubviews: [head, pillRow])
        column.axis = .vertical
        column.spacing = 11
        column.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: row.topAnchor, constant: 13),
            column.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            column.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            column.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -13)
        ])
        return row
    }

    private func makeChevronRow(icon: String, tint: UIColor, title: String, action: Selector) -> UIView {
        let row = UIButton(type: .custom)
        row.accessibilityLabel = title
        row.accessibilityIdentifier = "link-\(NSStringFromSelector(action))"
        row.isAccessibilityElement = true
        row.addTarget(self, action: action, for: .touchUpInside)

        let squircle = makeIconSquircle(icon, tint: tint)
        squircle.isUserInteractionEnabled = false
        let titleLabel = makeSmallTitle(title)
        titleLabel.isUserInteractionEnabled = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        chevron.tintColor = WarmShelfPalette.cocoa.withAlphaComponent(0.4)

        [squircle, titleLabel, chevron].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            squircle.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            squircle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: squircle.trailingAnchor, constant: 11),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -12),
            titleLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    private func makeDisclosureCard(title: String, detail: String, section: Int, content: [UIView]) -> UIView {
        let card = makeRaisedCard(fill: WarmShelfPalette.paperHighlight.withAlphaComponent(0.62), radius: 22)
        let expanded = expandedSections.contains(section)
        let button = UIButton(type: .custom)
        button.tag = section
        button.isAccessibilityElement = true
        button.accessibilityIdentifier = "disclosure-\(section)"
        button.accessibilityLabel = title
        button.accessibilityValue = expanded ? "Expanded" : "Collapsed"
        button.accessibilityHint = expanded ? "Hide details" : "Show details"
        button.addTarget(self, action: #selector(toggleSection(_:)), for: .touchUpInside)

        let heading = makeSmallTitle(title)
        let summary = makeSmallBody(detail)
        let labels = UIStackView(arrangedSubviews: [heading, summary])
        labels.axis = .vertical
        labels.spacing = 3
        labels.isUserInteractionEnabled = false
        let arrow = UIImageView(image: UIImage(systemName: expanded ? "chevron.up" : "chevron.down"))
        arrow.tintColor = WarmShelfPalette.cocoa
        arrow.setContentHuggingPriority(.required, for: .horizontal)
        [labels, arrow].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview($0)
        }
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
            labels.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
            labels.topAnchor.constraint(equalTo: button.topAnchor, constant: 14),
            labels.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -14),
            labels.trailingAnchor.constraint(equalTo: arrow.leadingAnchor, constant: -12),
            arrow.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16),
            arrow.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 15),
            arrow.heightAnchor.constraint(equalToConstant: 11)
        ])
        let column = UIStackView(arrangedSubviews: [button])
        column.axis = .vertical
        if expanded {
            let details = UIStackView(arrangedSubviews: content)
            details.axis = .vertical
            details.spacing = 12
            let inset = UIView()
            details.translatesAutoresizingMaskIntoConstraints = false
            inset.addSubview(details)
            NSLayoutConstraint.activate([
                details.leadingAnchor.constraint(equalTo: inset.leadingAnchor, constant: 16),
                details.trailingAnchor.constraint(equalTo: inset.trailingAnchor, constant: -16),
                details.topAnchor.constraint(equalTo: inset.topAnchor),
                details.bottomAnchor.constraint(equalTo: inset.bottomAnchor, constant: -16)
            ])
            column.addArrangedSubview(inset)
        }
        column.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            column.topAnchor.constraint(equalTo: card.topAnchor),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        return card
    }

    private func scaledFont(_ font: UIFont, style: UIFont.TextStyle) -> UIFont {
        UIFontMetrics(forTextStyle: style).scaledFont(for: font, compatibleWith: traitCollection)
    }

    // MARK: - Small pieces

    private func makeLivingPreview() -> UIView {
        // The toys included in the unlock, shown *alive* — breathing, swaying, blinking —
        // so a grown-up feels the value before the price. (Children never see this screen.)
        let paidToyIDs = ToyRegistry.launchToyIDs
            .filter { ToyRegistry.toy(id: $0)?.accessTier == .fullToybox }
        return PaywallPreviewStrip(toyIDs: paidToyIDs)
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

    private func makeCaption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = scaledFont(.systemFont(ofSize: 12, weight: .bold), style: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.accessibilityTraits = .header
        label.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.8)
        return label
    }

    private func makeFootnote(_ text: String, centered: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = scaledFont(.systemFont(ofSize: 13), style: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.8)
        label.numberOfLines = 0
        if centered { label.textAlignment = .center }
        return label
    }

    private func makeTintCard(color: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor = color.withAlphaComponent(0.10)
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.borderColor = WarmShelfPalette.softLine.withAlphaComponent(0.34).cgColor
        return card
    }

    private func makeRaisedCard(fill: UIColor, radius: CGFloat) -> UIView {
        let card = UIView()
        card.backgroundColor = fill
        card.layer.cornerRadius = radius
        card.layer.borderWidth = 1
        card.layer.borderColor = WarmShelfPalette.softLine.withAlphaComponent(0.38).cgColor
        card.layer.shadowColor = WarmShelfPalette.contactShadow.cgColor
        card.layer.shadowOpacity = 0.07
        card.layer.shadowRadius = 16
        card.layer.shadowOffset = CGSize(width: 0, height: 8)
        return card
    }

    private enum ActionStyle {
        case primary
        case secondary
        case text
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

    private func makeSmallTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = scaledFont(.systemFont(ofSize: 16, weight: .semibold), style: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = WarmShelfPalette.clayInk
        label.numberOfLines = 0
        return label
    }

    private func makeSmallBody(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = scaledFont(.systemFont(ofSize: 14), style: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = WarmShelfPalette.cocoa
        label.numberOfLines = 0
        return label
    }

    // MARK: - Actions

    @objc private func toggleSection(_ sender: UIButton) {
        if expandedSections.contains(sender.tag) {
            expandedSections.remove(sender.tag)
        } else {
            expandedSections.insert(sender.tag)
        }
        render()
    }

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

    @objc private func contactSupport() {
        guard let url = URL(string: "mailto:\(supportEmail)") else { return }
        UIApplication.shared.open(url) { [weak self] opened in
            guard !opened, let self else { return }
            let alert = UIAlertController(title: "Write to us",
                                          message: "No mail app is set up on this device. Our address is \(self.supportEmail).",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Copy address", style: .default) { _ in
                UIPasteboard.general.string = self.supportEmail
            })
            alert.addAction(UIAlertAction(title: "Done", style: .cancel))
            self.present(alert, animated: true)
        }
    }

    @objc private func showPrivacy() {
        let privacy = LullPrivacyViewController()
        privacy.modalPresentationStyle = .pageSheet
        present(privacy, animated: true)
    }

    @objc private func toggleSound() {
        AudioManager.shared.isEnabled.toggle()
        AudioManager.shared.playSoftTap()
        render()
    }

    @objc private func playTimerPicked(_ sender: UIButton) {
        let steps = [0, 15, 30, 45, 60]
        guard sender.tag >= 0, sender.tag < steps.count else { return }
        LullDemoState.shared.playTimerMinutes = steps[sender.tag]
        AudioManager.shared.playSoftTap()
        render()
    }

    @objc private func windDownPicked(_ sender: UIButton) {
        let hours = [17, 18, 19, 20, 21]
        guard sender.tag >= 0, sender.tag < hours.count else { return }
        LullDemoState.shared.windDownHour = hours[sender.tag]
        AudioManager.shared.playSoftTap()
        render()
    }

    @objc private func toyRowTapped(_ sender: UIButton) {
        let ids = ToyRegistry.launchToyIDs
        guard sender.tag >= 0, sender.tag < ids.count else { return }
        let id = ids[sender.tag]
        var hidden = LullDemoState.shared.hiddenToyIDs
        if hidden.contains(id) {
            hidden.remove(id)
        } else {
            hidden.insert(id)
            // Never let the child's shelf go empty.
            let stillVisible = ids.filter { !hidden.contains($0) && !ToyRegistry.isToyLocked($0) }
            if stillVisible.isEmpty {
                AudioManager.shared.playSoftTap()
                return
            }
        }
        LullDemoState.shared.hiddenToyIDs = hidden
        AudioManager.shared.playSoftTap()
        render()
    }

    @objc private func toggleReducedMotion() {
        LullDemoState.shared.isReducedMotion.toggle()
        HapticsManager.shared.softTap()
        render()
    }

    @objc private func toggleHaptics() {
        HapticsManager.shared.isEnabled.toggle()
        HapticsManager.shared.softTap()
        render()
    }

    @objc private func resetOnboarding() {
        AdultGate.present(from: self) { [weak self] in
            self?.dismiss(animated: true) {
                LullDemoState.shared.resetOnboarding()
            }
        }
    }

    #if DEBUG
    @objc private func toggleDevUnlock() {
        let nowUnlocked = !LullDemoState.shared.debugForceFullUnlock
        LullDemoState.shared.debugForceFullUnlock = nowUnlocked
        LullDemoState.shared.accessTier = nowUnlocked ? .fullToybox : .free
        NotificationCenter.default.post(name: .lullAccessDidChange, object: nil)
        statusMessage = nowUnlocked
            ? "Developer unlock on — every toy is open."
            : "Developer unlock off — toys are locked again."
        render()
    }
    #endif

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

    @objc private func close() {
        dismiss(animated: true)
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}

// MARK: - Privacy policy

/// The privacy policy, readable offline inside the gated grown-up room (Guideline 5.1.1(i)).
/// Keep `sections` word-for-word with `LandingPageDeploy/privacy.html`.
final class LullPrivacyViewController: UIViewController {
    static let effectiveDate = "October 11, 2026"

    static var sections: [(String, String)] {
        [
            ("The short version",
             "Lull does not collect, store on a server, share, or sell any information about you or your child. There are no accounts, ads, analytics, or tracking, and no third-party code that could do these things."),
            ("What stays on this device",
             "Your family settings (sound, haptics, calmer motion, play timer, wind-down hour, which toys are on the shelf), which hints were shown, a note of your current plan as Apple reports it, and Mix-Up creations are saved only in Lull's storage on this device. They are not sent anywhere, apart from your own iCloud or computer backups of this device. Deleting Lull deletes them."),
            ("Purchases",
             "The full toybox is an In-App Purchase handled entirely by Apple: the Lull Family subscription or the one-time Keep Forever purchase. Lull never sees your name, Apple Account, or payment details; Apple tells the app only whether the full toybox is open, and when a plan's free week or renewal is due. Apple's privacy policy covers the purchase itself."),
            ("Device features",
             "Lull does not use the camera, microphone, location, contacts, photos, or notifications. The shelf may read the device's tilt to move its picture gently; that motion is used in the moment and never saved."),
            ("Children",
             "Lull is made for children aged 2 to 6. We do not knowingly collect personal information from children, and the app gives a child no way to type, share, or send information. Settings, purchases, and links live in the grown-up area behind an adult check."),
            ("If you contact us",
             "If you email us, we receive the address and whatever you choose to write. We use it only to reply, never for marketing, and we delete it on request."),
            ("Changes and contact",
             "If this policy changes, the new version will be in the app and on our website with a new date. Questions: \(LullLinks.supportEmail). Effective \(effectiveDate).")
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WarmShelfPalette.linen

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)

        let column = UIStackView()
        column.axis = .vertical
        column.spacing = 8
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)

        let title = UILabel()
        title.text = "Privacy"
        title.font = UIFontMetrics(forTextStyle: .largeTitle)
            .scaledFont(for: UIFont(name: "Georgia", size: 30) ?? .systemFont(ofSize: 30, weight: .semibold))
        title.adjustsFontForContentSizeCategory = true
        title.textColor = WarmShelfPalette.clayInk
        title.accessibilityTraits = .header
        column.addArrangedSubview(title)
        column.setCustomSpacing(16, after: title)

        for (heading, body) in Self.sections {
            let h = UILabel()
            h.text = heading
            h.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 16, weight: .bold))
            h.adjustsFontForContentSizeCategory = true
            h.textColor = WarmShelfPalette.clayInk
            h.numberOfLines = 0
            h.accessibilityTraits = .header
            let b = UILabel()
            b.text = body
            b.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 15))
            b.adjustsFontForContentSizeCategory = true
            b.textColor = WarmShelfPalette.cocoa
            b.numberOfLines = 0
            column.addArrangedSubview(h)
            column.setCustomSpacing(4, after: h)
            column.addArrangedSubview(b)
            column.setCustomSpacing(18, after: b)
        }

        if LullLinks.privacyPolicyURL != nil {
            let web = UIButton(type: .system)
            web.setTitle("Read it on the web", for: .normal)
            web.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            web.setTitleColor(WarmShelfPalette.terracotta, for: .normal)
            web.contentHorizontalAlignment = .leading
            web.addTarget(self, action: #selector(openWeb), for: .touchUpInside)
            column.addArrangedSubview(web)
        }

        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        done.setTitleColor(WarmShelfPalette.paperHighlight, for: .normal)
        done.backgroundColor = WarmShelfPalette.clayInk
        done.layer.cornerRadius = 18
        done.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        done.addTarget(self, action: #selector(close), for: .touchUpInside)
        column.addArrangedSubview(done)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 28),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -28),
            column.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 24),
            column.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -24)
        ])
    }

    @objc private func openWeb() {
        if let url = LullLinks.privacyPolicyURL { UIApplication.shared.open(url) }
    }

    @objc private func close() { dismiss(animated: true) }
}
