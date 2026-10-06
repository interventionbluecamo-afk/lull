import UIKit

/// The grown-up room, session 11 redesign (June 12): premium-settings anatomy —
/// status hero up top, the monthly-toys value made explicit, grouped cards with
/// hairline rows and icon squircles, chevron utility rows at the foot. Clean type
/// on linen (the founder's parked Liquid Glass seed stays parked: paper IS the brand).
/// Everything here hides behind the adult gate; the child only ever gets the toys.
final class ParentInfoViewController: UIViewController {
    private let stack = UIStackView()
    private let supportEmail = "support@lull.app"
    private var statusMessage: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WarmShelfPalette.linen
        buildView()
        Task { @MainActor in
            await LullPurchaseManager.shared.loadProducts()
            render()
        }
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

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28)
        ])

        render()
    }

    // MARK: - Page

    private func render() {
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        stack.addArrangedSubview(makeHeaderBar())
        stack.setCustomSpacing(18, after: stack.arrangedSubviews.last!)

        // A grown-up has now seen the post-trial state; the shelf chip's quiet dot can rest.
        let state = LullDemoState.shared
        if !state.hasPurchasedFullToybox, state.hasTrialStarted, !state.isTrialActive {
            state.hasAcknowledgedTrialEnd = true
        }

        stack.addArrangedSubview(makeStatusHero())
        if let statusMessage {
            stack.addArrangedSubview(makeNoticeCard(text: statusMessage))
        }
        stack.addArrangedSubview(makeGrowingShelfCard())

        stack.setCustomSpacing(26, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(makeCaption("QUIET HOURS"))
        stack.addArrangedSubview(makeGroupCard([
            makeOptionGroupRow(
                icon: "hourglass", tint: WarmShelfPalette.butter,
                title: "Play timer",
                detail: "When time is up, Lull rests behind a calm moon until a grown-up wakes it.",
                labels: ["Off", "15m", "30m", "45m", "60m"],
                selectedIndex: [0, 15, 30, 45, 60].firstIndex(of: state.playTimerMinutes) ?? 0,
                action: #selector(playTimerPicked(_:))
            ),
            makeOptionGroupRow(
                icon: "moon.zzz.fill", tint: WarmShelfPalette.lavender,
                title: "Wind-down hour",
                detail: "Evenings after this hour drift warmer and sleepier across the whole toybox.",
                labels: ["5 pm", "6 pm", "7 pm", "8 pm", "9 pm"],
                selectedIndex: [17, 18, 19, 20, 21].firstIndex(of: state.windDownHour) ?? 2,
                action: #selector(windDownPicked(_:))
            )
        ]))

        stack.setCustomSpacing(26, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(makeCaption("THE SHELF"))
        var toyRows: [UIView] = []
        let hiddenToys = state.hiddenToyIDs
        for (index, toyID) in ToyRegistry.launchToyIDs.enumerated() {
            guard let toy = ToyRegistry.toy(id: toyID) else { continue }
            let isVisible = !hiddenToys.contains(toyID)
            toyRows.append(makeSwitchGroupRow(
                icon: "circle.grid.2x2.fill", tint: toyAccent(index),
                title: toy.parentName,
                detail: isVisible ? "On the child's shelf" : "Tucked away for now",
                isOn: isVisible, tag: index,
                action: #selector(toyRowTapped(_:))
            ))
        }
        stack.addArrangedSubview(makeGroupCard(toyRows))
        stack.addArrangedSubview(makeFootnote("The free shelf never goes empty — the last visible toy stays."))

        stack.setCustomSpacing(26, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(makeCaption("FEEL"))
        stack.addArrangedSubview(makeGroupCard([
            makeSwitchGroupRow(
                icon: "speaker.wave.2.fill", tint: WarmShelfPalette.waterBlue,
                title: "Sound",
                detail: "Gentle pops, ripples, food sounds, and soft taps",
                isOn: AudioManager.shared.isEnabled, tag: 0,
                action: #selector(toggleSound)
            ),
            makeSwitchGroupRow(
                icon: "hand.tap.fill", tint: WarmShelfPalette.petal,
                title: "Haptics",
                detail: "Subtle touch feedback on supported devices",
                isOn: HapticsManager.shared.isEnabled, tag: 0,
                action: #selector(toggleHaptics)
            ),
            makeSwitchGroupRow(
                icon: "wind", tint: WarmShelfPalette.sage,
                title: "Calmer motion",
                detail: "Stills the gentle idle drifting. System Reduce Motion is always respected.",
                isOn: LullDemoState.shared.isReducedMotion, tag: 0,
                action: #selector(toggleReducedMotion)
            )
        ]))

        stack.setCustomSpacing(26, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(makeCaption("WHAT YOUR CHILD NEVER SEES"))
        stack.addArrangedSubview(makePromisesCard())

        stack.setCustomSpacing(26, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(makeGroupCard([
            makeChevronRow(icon: "arrow.clockwise", tint: WarmShelfPalette.waterBlue,
                           title: "Restore purchase", action: #selector(restorePurchases)),
            makeChevronRow(icon: "envelope.fill", tint: WarmShelfPalette.butter,
                           title: "Support — \(supportEmail)", action: #selector(contactSupport)),
            makeChevronRow(icon: "arrow.counterclockwise", tint: WarmShelfPalette.petal,
                           title: "See the welcome again", action: #selector(resetOnboarding))
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

        let doneButton = makeActionButton(title: "Done", style: .text)
        doneButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        stack.addArrangedSubview(doneButton)

        stack.addArrangedSubview(makeFootnote("lull — made with patience by two people and a toddler.", centered: true))
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

        let title = UILabel()
        title.text = "The grown-up room"
        title.font = UIFont(name: "Georgia", size: 30) ?? .systemFont(ofSize: 30, weight: .semibold)
        title.textColor = WarmShelfPalette.clayInk
        title.numberOfLines = 1   // scale, never wrap — "grown-" split in half read broken
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.6

        let sub = UILabel()
        sub.text = "Boundaries, timers, and the shelf — behind the gate, never on it."
        sub.font = .systemFont(ofSize: 13.5, weight: .regular)
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
        closeChip.layer.cornerRadius = 19
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
            seal.widthAnchor.constraint(equalToConstant: 46),
            seal.heightAnchor.constraint(equalToConstant: 46),
            titles.leadingAnchor.constraint(equalTo: seal.trailingAnchor, constant: 12),
            titles.topAnchor.constraint(equalTo: bar.topAnchor),
            titles.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            titles.trailingAnchor.constraint(equalTo: closeChip.leadingAnchor, constant: -10),
            closeChip.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            closeChip.topAnchor.constraint(equalTo: bar.topAnchor),
            closeChip.widthAnchor.constraint(equalToConstant: 38),
            closeChip.heightAnchor.constraint(equalToConstant: 38)
        ])
        return bar
    }

    // MARK: - Status hero (the membership card)

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
        let price = LullPurchaseManager.shared.displayPrice(for: LullStoreProduct.lifetime)

        let eyebrow = UILabel()
        let title = UILabel()
        let body = UILabel()
        if purchased {
            eyebrow.text = "YOURS, FOREVER"
            title.text = "The whole shelf is open."
            body.text = "Every toy — and every toy still to come — is on this device for good. Thank you for backing calm, handmade play."
        } else if state.isTrialActive {
            let d = state.trialDaysRemaining
            eyebrow.text = "FREE WEEK · \(d) DAY\(d == 1 ? "" : "S") LEFT"
            title.text = d <= 1 ? "Last open day." : "Everything is open."
            body.text = d <= 1
                ? "Tomorrow the shelf settles to Bubbles, Stack, and Drop Dots — free forever. One unlock keeps it all, and your child never notices a thing."
                : "Your child has the whole toybox this week. When it ends, three toys stay free forever — or keep everything with one unlock."
        } else if state.hasTrialStarted {
            eyebrow.text = "FREE SHELF"
            title.text = "Three toys, free forever."
            body.text = "The trial week has ended. Bubbles, Stack, and Drop Dots are your child's for good — the rest are waiting exactly as they were."
        } else {
            eyebrow.text = "WELCOME"
            title.text = "The calm toybox."
            body.text = "Bubbles, Stack, and Drop Dots are free, with no child-facing locks. The full shelf is one purchase — once, forever."
        }
        eyebrow.font = .systemFont(ofSize: 11.5, weight: .heavy)
        eyebrow.textColor = WarmShelfPalette.butter
        title.font = UIFont(name: "Georgia", size: 30) ?? .systemFont(ofSize: 30, weight: .semibold)
        title.textColor = WarmShelfPalette.paperHighlight
        title.numberOfLines = 0
        body.font = .systemFont(ofSize: 14.5, weight: .regular)
        body.textColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.82)
        body.numberOfLines = 0

        let content = UIStackView(arrangedSubviews: [eyebrow, title, body])
        content.axis = .vertical
        content.spacing = 8
        content.setCustomSpacing(5, after: eyebrow)

        if state.isTrialActive, !purchased {
            content.addArrangedSubview(makeTrialDots(daysRemaining: state.trialDaysRemaining))
        }

        content.addArrangedSubview(makeLivingPreview())

        if !purchased {
            let cta = UIButton(type: .system)
            cta.setTitle(state.isTrialActive ? "Keep everything · \(price)" : "Unlock everything · \(price)", for: .normal)
            cta.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
            cta.backgroundColor = WarmShelfPalette.butter
            cta.setTitleColor(WarmShelfPalette.clayInk, for: .normal)
            cta.layer.cornerRadius = 18
            cta.translatesAutoresizingMaskIntoConstraints = false
            cta.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
            cta.addTarget(self, action: #selector(purchaseLifetime), for: .touchUpInside)
            content.addArrangedSubview(cta)

            let reassurance = UILabel()
            reassurance.text = "One payment. No subscription, no renewals, nothing to cancel."
            reassurance.font = .systemFont(ofSize: 12.5, weight: .medium)
            reassurance.textColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.62)
            reassurance.textAlignment = .center
            reassurance.numberOfLines = 0
            content.addArrangedSubview(reassurance)
            content.setCustomSpacing(8, after: cta)
        }

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

    /// Seven little days; the spent ones filled, today glowing butter.
    private func makeTrialDots(daysRemaining: Int) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 7
        row.alignment = .center
        let spent = max(0, min(7, 7 - daysRemaining))
        for i in 0..<7 {
            let dot = UIView()
            let isToday = i == spent
            dot.backgroundColor = i < spent
                ? WarmShelfPalette.paperHighlight.withAlphaComponent(0.34)
                : (isToday ? WarmShelfPalette.butter : WarmShelfPalette.paperHighlight.withAlphaComponent(0.14))
            dot.layer.cornerRadius = isToday ? 6 : 4.5
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: isToday ? 12 : 9).isActive = true
            dot.heightAnchor.constraint(equalToConstant: isToday ? 12 : 9).isActive = true
            row.addArrangedSubview(dot)
        }
        let label = UILabel()
        label.text = "your week"
        label.font = .systemFont(ofSize: 11.5, weight: .semibold)
        label.textColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.55)
        row.addArrangedSubview(label)
        row.setCustomSpacing(10, after: row.arrangedSubviews[6])
        return row
    }

    /// The clear-value card: the shelf grows, and growth is included.
    private func makeGrowingShelfCard() -> UIView {
        let card = makeRaisedCard(fill: WarmShelfPalette.paperHighlight.withAlphaComponent(0.62), radius: 22)

        let squircle = makeIconSquircle("sparkles", tint: WarmShelfPalette.terracotta)

        let title = UILabel()
        title.text = "The shelf keeps growing"
        title.font = UIFont(name: "Georgia-Bold", size: 19) ?? .systemFont(ofSize: 19, weight: .bold)
        title.textColor = WarmShelfPalette.clayInk

        let body = UILabel()
        body.text = "A new toy joins the toybox about every month — the Meadow just moved in. Every new toy is part of the same one unlock. Nothing more to buy, ever."
        body.font = .systemFont(ofSize: 14, weight: .regular)
        body.textColor = WarmShelfPalette.cocoa
        body.numberOfLines = 0

        let months = UIStackView(arrangedSubviews: [
            makeMonthChip("JUNE", detail: "Meadow", arrived: true),
            makeMonthChip("JULY", detail: "A new friend", arrived: false),
            makeMonthChip("AFTER", detail: "Always more", arrived: false)
        ])
        months.axis = .horizontal
        months.spacing = 8
        months.distribution = .fillEqually

        let titles = UIStackView(arrangedSubviews: [title, body])
        titles.axis = .vertical
        titles.spacing = 4

        let head = UIStackView(arrangedSubviews: [squircle, titles])
        head.axis = .horizontal
        head.spacing = 12
        head.alignment = .top

        let column = UIStackView(arrangedSubviews: [head, months])
        column.axis = .vertical
        column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    private func makeMonthChip(_ month: String, detail: String, arrived: Bool) -> UIView {
        let chip = UIView()
        chip.backgroundColor = arrived
            ? WarmShelfPalette.sage.withAlphaComponent(0.18)
            : WarmShelfPalette.warmCream.withAlphaComponent(0.5)
        chip.layer.cornerRadius = 14
        chip.layer.borderWidth = 1
        chip.layer.borderColor = (arrived ? WarmShelfPalette.sage : WarmShelfPalette.softLine)
            .withAlphaComponent(0.4).cgColor

        let m = UILabel()
        m.text = month
        m.font = .systemFont(ofSize: 10.5, weight: .heavy)
        m.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.6)
        m.textAlignment = .center

        let d = UILabel()
        d.text = arrived ? "\(detail) ✓" : detail
        d.font = .systemFont(ofSize: 12.5, weight: .semibold)
        d.textColor = WarmShelfPalette.clayInk
        d.textAlignment = .center
        d.adjustsFontSizeToFitWidth = true
        d.minimumScaleFactor = 0.8

        let col = UIStackView(arrangedSubviews: [m, d])
        col.axis = .vertical
        col.spacing = 2
        col.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(col)
        NSLayoutConstraint.activate([
            chip.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            col.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
            col.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 6),
            col.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -6)
        ])
        return chip
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
        row.addTarget(self, action: action, for: .touchUpInside)

        let squircle = makeIconSquircle(icon, tint: tint)
        squircle.isUserInteractionEnabled = false

        let titleLabel = makeSmallTitle(title)
        let detailLabel = makeSmallBody(detail)
        detailLabel.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.66)
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
        detailLabel.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.66)

        let pillRow = UIStackView()
        pillRow.axis = .horizontal
        pillRow.spacing = 7
        pillRow.distribution = .fillEqually
        for (i, text) in labels.enumerated() {
            let pill = UIButton(type: .system)
            pill.setTitle(text, for: .normal)
            pill.titleLabel?.font = .systemFont(ofSize: 13.5, weight: .semibold)
            pill.tag = i
            let selected = i == selectedIndex
            pill.backgroundColor = selected ? WarmShelfPalette.terracotta : WarmShelfPalette.warmCream.withAlphaComponent(0.55)
            pill.tintColor = selected ? WarmShelfPalette.paperHighlight : WarmShelfPalette.cocoa.withAlphaComponent(0.75)
            pill.layer.cornerRadius = 16
            pill.heightAnchor.constraint(equalToConstant: 36).isActive = true
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
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    private func makePromisesCard() -> UIView {
        let card = makeRaisedCard(fill: WarmShelfPalette.paperHighlight.withAlphaComponent(0.62), radius: 22)
        let promises: [(String, String, UIColor)] = [
            ("rectangle.slash", "No ads — no banners, videos, or sponsored toys", WarmShelfPalette.waterBlue),
            ("star.slash", "No stars, streaks, levels, or engineered urgency", WarmShelfPalette.butter),
            ("dollarsign.circle", "No child-facing prices or upgrade language", WarmShelfPalette.petal),
            ("eye.slash", "No tracking-based ads — play stays private", WarmShelfPalette.sage)
        ]
        let column = UIStackView(arrangedSubviews: promises.map { symbol, text, tint in
            let icon = makeIconSquircle(symbol, tint: tint)
            let label = makeSmallBody(text)
            label.font = .systemFont(ofSize: 14, weight: .medium)
            let row = UIStackView(arrangedSubviews: [icon, label])
            row.axis = .horizontal
            row.spacing = 11
            row.alignment = .center
            return row
        })
        column.axis = .vertical
        column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -15)
        ])
        return card
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
        label.font = .systemFont(ofSize: 14.5, weight: .semibold)
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
        label.font = .systemFont(ofSize: 11.5, weight: .heavy)
        label.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.55)
        return label
    }

    private func makeFootnote(_ text: String, centered: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.55)
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
        button.titleLabel?.font = .systemFont(ofSize: style == .text ? 16 : 17, weight: .semibold)
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
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = WarmShelfPalette.cocoa
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func makeSmallTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15.5, weight: .semibold)
        label.textColor = WarmShelfPalette.clayInk
        label.numberOfLines = 0
        return label
    }

    private func makeSmallBody(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = WarmShelfPalette.cocoa
        label.numberOfLines = 0
        return label
    }

    // MARK: - Actions

    @objc private func purchaseLifetime() {
        AdultGate.present(from: self) { [weak self] in
            self?.purchase(productID: LullStoreProduct.lifetime)
        }
    }

    @objc private func restorePurchases() {
        AdultGate.present(from: self) { [weak self] in
            Task { @MainActor in
                let restored = await LullPurchaseManager.shared.restorePurchases()
                self?.statusMessage = restored
                    ? "Purchases restored. Full toybox is active."
                    : (LullPurchaseManager.shared.lastErrorMessage ?? "No full toybox purchase was found.")
                self?.render()
            }
        }
    }

    @objc private func contactSupport() {
        if let url = URL(string: "mailto:\(supportEmail)") {
            UIApplication.shared.open(url)
        }
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
        Task { @MainActor in
            let purchased = await LullPurchaseManager.shared.purchase(productID)
            if purchased {
                statusMessage = "Full toybox is active. The child shelf stays free of locks and prices."
            } else if let message = LullPurchaseManager.shared.lastErrorMessage {
                statusMessage = message
            }
            render()
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}
