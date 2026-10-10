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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WarmShelfPalette.linen
        buildView()
        loadPurchaseOptions()
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

        // A grown-up has now seen the post-trial state; the shelf chip's quiet dot can rest.
        let state = LullDemoState.shared
        if !state.hasPurchasedFullToybox, state.hasTrialStarted, !state.isTrialActive {
            state.hasAcknowledgedTrialEnd = true
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
        card.backgroundColor = WarmShelfPalette.clayInk
        card.layer.cornerRadius = 26
        card.layer.shadowColor = WarmShelfPalette.contactShadow.cgColor
        card.layer.shadowOpacity = 0.14
        card.layer.shadowRadius = 20
        card.layer.shadowOffset = CGSize(width: 0, height: 12)

        let state = LullDemoState.shared
        let purchased = state.hasPurchasedFullToybox
        let product = LullPurchaseManager.shared.product(for: LullStoreProduct.lifetime)
        // Never advertise the fallback price or one-payment terms for an unknown product.
        let price = product?.type == .nonConsumable ? product?.displayPrice : nil
        // Screen Time can switch purchases off; say so instead of offering a dead button.
        let purchasesAllowed = AppStore.canMakePayments

        let eyebrow = UILabel()
        let title = UILabel()
        let body = UILabel()
        title.text = "Full Toybox"
        if purchased {
            eyebrow.text = "UNLOCKED"
            body.text = "All nine toys are unlocked. Thank you for supporting Lull."
        } else if state.isTrialActive {
            let d = state.trialDaysRemaining
            eyebrow.text = "FREE WEEK · \(d) DAY\(d == 1 ? "" : "S") LEFT"
            body.text = "Keep all nine toys for familiar friends, music, and quiet discovery. Bubbles, Little Wash, and Drop Dots stay free after your week."
        } else if state.hasTrialStarted {
            eyebrow.text = "YOUR FREE WEEK HAS ENDED"
            body.text = "Bubbles, Little Wash, and Drop Dots stay free. Open six more toys for familiar friends, music, and quiet discovery."
        } else {
            eyebrow.text = "TRY ALL NINE TOYS"
            body.text = "Finish the welcome to try all nine toys free for seven days. Bubbles, Little Wash, and Drop Dots stay free afterward."
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

        if !purchased {
            content.addArrangedSubview(makeLivingPreview())
        }

        if !purchased {
            let cta = UIButton(type: .system)
            let ctaTitle: String
            if isPurchaseInProgress {
                ctaTitle = "Waiting for the App Store…"
            } else if isLoadingProducts {
                ctaTitle = "Loading App Store price…"
            } else if let price {
                ctaTitle = "Unlock Full Toybox · \(price)"
            } else {
                ctaTitle = "Purchase unavailable"
            }
            cta.setTitle(ctaTitle, for: .normal)
            cta.titleLabel?.font = scaledFont(.systemFont(ofSize: 17, weight: .bold), style: .headline)
            cta.titleLabel?.adjustsFontForContentSizeCategory = true
            cta.contentEdgeInsets = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
            cta.accessibilityIdentifier = "full-toybox-purchase"
            cta.titleLabel?.numberOfLines = 0
            cta.titleLabel?.textAlignment = .center
            cta.backgroundColor = WarmShelfPalette.butter
            cta.setTitleColor(WarmShelfPalette.clayInk, for: .normal)
            cta.layer.cornerRadius = 18
            cta.translatesAutoresizingMaskIntoConstraints = false
            cta.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
            cta.addTarget(self, action: #selector(purchaseLifetime), for: .touchUpInside)
            cta.isEnabled = price != nil && purchasesAllowed && !isLoadingProducts && !isPurchaseInProgress
            cta.alpha = cta.isEnabled ? 1 : 0.65
            content.addArrangedSubview(cta)

            let reassurance = UILabel()
            reassurance.text = price != nil && !purchasesAllowed
                ? "In-App Purchases are turned off in Screen Time on this device. The free toys stay open."
                : price != nil
                ? "One payment. No subscription. The free week never charges you."
                : (isLoadingProducts
                    ? "The free week never turns into a charge. You can keep playing the free toys."
                    : "The full toybox purchase is unavailable right now. You can keep playing the free toys.")
            reassurance.font = scaledFont(.systemFont(ofSize: 13, weight: .medium), style: .footnote)
            reassurance.adjustsFontForContentSizeCategory = true
            reassurance.textColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.86)
            reassurance.textAlignment = .center
            reassurance.numberOfLines = 0
            content.addArrangedSubview(reassurance)
            content.setCustomSpacing(8, after: cta)

            if !isLoadingProducts, price == nil {
                let retry = makeActionButton(title: "Reload App Store price", style: .text)
                retry.setTitleColor(WarmShelfPalette.paperHighlight, for: .normal)
                retry.isEnabled = !isPurchaseInProgress
                retry.addTarget(self, action: #selector(reloadProducts), for: .touchUpInside)
                content.addArrangedSubview(retry)
            }
        }

        let restore = makeActionButton(title: "Restore purchase", style: .text)
        restore.setTitleColor(WarmShelfPalette.paperHighlight.withAlphaComponent(0.95), for: .normal)
        restore.accessibilityIdentifier = "restore-purchase"
        restore.accessibilityHint = "Checks for an existing Full Toybox purchase with your Apple Account."
        restore.isEnabled = !isPurchaseInProgress
        restore.addTarget(self, action: #selector(restorePurchases), for: .touchUpInside)
        content.addArrangedSubview(restore)

        content.setCustomSpacing(14, after: body)
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

    @objc private func purchaseLifetime() {
        guard !isPurchaseInProgress,
              LullPurchaseManager.shared.product(for: LullStoreProduct.lifetime)?.type == .nonConsumable else { return }
        AdultGate.present(from: self) { [weak self] in
            self?.purchase(productID: LullStoreProduct.lifetime)
        }
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
                    ? "Purchases restored. Full toybox is active."
                    : (LullPurchaseManager.shared.lastErrorMessage ?? "No full toybox purchase was found.")
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
              LullPurchaseManager.shared.product(for: productID)?.type == .nonConsumable else { return }
        isPurchaseInProgress = true
        statusMessage = nil
        render()
        Task { @MainActor in
            let purchased = await LullPurchaseManager.shared.purchase(productID)
            isPurchaseInProgress = false
            if purchased {
                statusMessage = "Full toybox is active. The child shelf stays free of locks and prices."
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
    static let effectiveDate = "October 7, 2026"

    static var sections: [(String, String)] {
        [
            ("The short version",
             "Lull does not collect, store on a server, share, or sell any information about you or your child. There are no accounts, ads, analytics, or tracking, and no third-party code that could do these things."),
            ("What stays on this device",
             "Your family settings (sound, haptics, calmer motion, play timer, wind-down hour, which toys are on the shelf), the date the free week began, which hints were shown, and Mix-Up creations are saved only in Lull's storage on this device. They are not sent anywhere, apart from your own iCloud or computer backups of this device. Deleting Lull deletes them."),
            ("Purchases",
             "The full toybox is a one-time In-App Purchase handled entirely by Apple. Lull never sees your name, Apple Account, or payment details; Apple tells the app only whether the full toybox is unlocked. Apple's privacy policy covers the purchase itself."),
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
