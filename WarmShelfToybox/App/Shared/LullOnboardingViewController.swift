import SpriteKit
import StoreKit
import UIKit

// MARK: - LullOnboardingViewController
//
// A warm, paged parent setup — handed over to the child at the end. Three calm moments:
//   1. Welcome: Wren says hello; the quiet promise (no ads, no scores, no pressure).
//   2. Wind-down: the grown-up picks bedtime; Lull's rooms warm and dim toward it.
//   3. Hand-off: what stays free, Lull Family (free week) and Keep Forever, and the grown-up gate.
// Built from warm handmade cards on warm paper, to match the toys themselves.

final class LullOnboardingViewController: UIViewController {
    var onComplete: (() -> Void)?

    private let scrollView = UIScrollView()
    private let pagesStack = UIStackView()
    private let pageDots = UIPageControl()
    private let primaryButton = UIButton(type: .system)
    private let backgroundGradient = CAGradientLayer()
    private var accessObserver: NSObjectProtocol?

    private var windDownHour = LullDemoState.shared.windDownHour
    private var windPills: [UIButton] = []
    /// A first welcome suggests 30 minutes; a replay shows what the family already chose.
    private var playTimerMinutes = LullDemoState.shared.hasChosenPlayTimer ? LullDemoState.shared.playTimerMinutes : 30
    private var timerPills: [UIButton] = []
    private let timerStatus = UILabel()
    private let pageCount = 3
    private var currentPage = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WarmShelfPalette.linen
        setupBackground()
        setupScaffold()
        buildPages()
        updateForPage(0, animated: false)
        accessObserver = NotificationCenter.default.addObserver(
            forName: .lullAccessDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshHandoffPage() }
        }
        // The last page names the real App Store prices and free week (Guideline 3.1.2).
        // Offline, it falls back to pointing at the grown-up area.
        if LullPurchaseManager.shared.products.isEmpty {
            Task { @MainActor [weak self] in
                await LullPurchaseManager.shared.loadProducts()
                self?.refreshHandoffPage()
            }
        }
    }

    deinit {
        if let accessObserver { NotificationCenter.default.removeObserver(accessObserver) }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradient.frame = view.bounds
        // Keep the paging offset correct across rotation.
        scrollView.contentOffset = CGPoint(x: CGFloat(currentPage) * scrollView.bounds.width, y: 0)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if DEBUG
        // LULL_DEBUG_ONBOARD_PAGE=n jumps to a page (QA / store screenshots).
        if let v = ProcessInfo.processInfo.environment["LULL_DEBUG_ONBOARD_PAGE"],
           let page = Int(v), page > 0, page < pageCount, currentPage == 0 {
            scrollView.setContentOffset(CGPoint(x: CGFloat(page) * scrollView.bounds.width, y: 0), animated: false)
            updateForPage(page, animated: false)
        }
        #endif
    }

    // MARK: - Scaffold

    private func setupBackground() {
        backgroundGradient.colors = [
            WarmShelfPalette.paperHighlight.withAlphaComponent(0.6).cgColor,
            WarmShelfPalette.linen.cgColor,
            WarmShelfPalette.warmCream.withAlphaComponent(0.5).cgColor
        ]
        backgroundGradient.locations = [0, 0.55, 1]
        view.layer.insertSublayer(backgroundGradient, at: 0)
    }

    private func setupScaffold() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.delegate = self
        view.addSubview(scrollView)

        pagesStack.axis = .horizontal
        pagesStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(pagesStack)

        pageDots.numberOfPages = pageCount
        pageDots.currentPageIndicatorTintColor = WarmShelfPalette.terracotta
        pageDots.pageIndicatorTintColor = WarmShelfPalette.softLine
        pageDots.translatesAutoresizingMaskIntoConstraints = false
        pageDots.isUserInteractionEnabled = false
        view.addSubview(pageDots)

        primaryButton.setTitle("Continue", for: .normal)
        primaryButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        primaryButton.backgroundColor = WarmShelfPalette.terracotta
        primaryButton.setTitleColor(WarmShelfPalette.paperHighlight, for: .normal)
        primaryButton.layer.cornerRadius = 26
        primaryButton.layer.shadowColor = WarmShelfPalette.contactShadow.cgColor
        primaryButton.layer.shadowOpacity = 0.16
        primaryButton.layer.shadowRadius = 14
        primaryButton.layer.shadowOffset = CGSize(width: 0, height: 8)
        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        view.addSubview(primaryButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: primaryButton.topAnchor, constant: -16),

            pagesStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            pagesStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            pagesStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            pagesStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            pagesStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            pageDots.bottomAnchor.constraint(equalTo: primaryButton.topAnchor, constant: -16),
            pageDots.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            primaryButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            primaryButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            primaryButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            primaryButton.heightAnchor.constraint(equalToConstant: 58)
        ])
    }

    private func buildPages() {
        let pages = [welcomePage(), rhythmPage(), handoffPage()]
        for page in pages {
            page.translatesAutoresizingMaskIntoConstraints = false
            pagesStack.addArrangedSubview(page)
            page.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
        }
    }

    // MARK: - Page 1 — welcome

    private func welcomePage() -> UIView {
        let hero = WrenHeroView(side: 180)

        let eyebrow = makeEyebrow("WELCOME TO LULL")
        let title = makeTitle("Little hands.\nRoom to explore.")
        let body = makeBody("Nine felt-and-wood toys for ages 2–6. Wash, sort, feed, make music, and wander through a meadow. Pictures and touch invite your child to choose, try, and repeat at their own pace.")

        let privacy = makeBody("No child account. Play and family settings are saved on this device.")
        privacy.font = .systemFont(ofSize: 13.5, weight: .medium)
        privacy.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.72)

        let chips = UIStackView(arrangedSubviews: [
            makePromiseChip("No ads", icon: "rectangle.slash", WarmShelfPalette.waterBlue),
            makePromiseChip("No scores", icon: "star.slash", WarmShelfPalette.butter),
            makePromiseChip("No pressure", icon: "leaf", WarmShelfPalette.sage)
        ])
        chips.axis = .horizontal
        chips.spacing = 8
        chips.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [hero, eyebrow, title, body, chips, privacy])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .leading
        stack.setCustomSpacing(22, after: hero)
        stack.setCustomSpacing(6, after: eyebrow)
        hero.translatesAutoresizingMaskIntoConstraints = false
        hero.widthAnchor.constraint(equalToConstant: 180).isActive = true
        hero.heightAnchor.constraint(equalToConstant: 180).isActive = true
        return wrapInPage(stack)
    }

    // MARK: - Page 2 — the family's rhythm (play timer + wind-down)

    /// Few toy apps let a grown-up end play gently, so this page makes both settings plain:
    /// what each does, the choice, and where to change it later (founder, October 11).
    private func rhythmPage() -> UIView {
        let eyebrow = makeEyebrow("YOUR FAMILY'S RHYTHM")
        let title = makeTitle("Play, then rest.")
        let body = makeBody("Lull can end play gently and grow sleepy in the evening. Choose both now; you can change them anytime.")

        // Play timer, first: the one parents ask about.
        let timerPillRow = UIStackView()
        timerPillRow.axis = .horizontal
        timerPillRow.spacing = 8
        timerPillRow.distribution = .fillEqually
        for minutes in [0, 15, 30, 45, 60] {
            let pill = makeChoicePill(title: minutes == 0 ? "Off" : "\(minutes)", tag: minutes,
                                      action: #selector(timerPillTapped(_:)))
            pill.accessibilityLabel = minutes == 0 ? "Play timer off" : "Play timer, \(minutes) minutes"
            timerPills.append(pill)
            timerPillRow.addArrangedSubview(pill)
        }
        timerStatus.font = scaled(.systemFont(ofSize: 14.5, weight: .semibold), .subheadline)
        timerStatus.adjustsFontForContentSizeCategory = true
        timerStatus.textColor = WarmShelfPalette.clayInk
        timerStatus.numberOfLines = 0
        let restNote = makeSettingNote(symbol: "moon.stars.fill", tint: WarmShelfPalette.lavender,
            text: "When time is up, the screen settles into a night sky with a soft moon. No alarms. Only a grown-up can wake Lull, even if the app is closed and reopened.")
        let timerCard = makeSettingCard(symbol: "hourglass", tint: WarmShelfPalette.butter, title: "Play timer",
                                        detail: "Minutes of play before Lull rests.",
                                        content: [timerPillRow, timerStatus, restNote])

        // Wind-down hour, second.
        let windPillRow = UIStackView()
        windPillRow.axis = .horizontal
        windPillRow.spacing = 8
        windPillRow.distribution = .fillEqually
        for hour in [17, 18, 19, 20, 21] {
            let pill = makeChoicePill(title: displayHour(hour), tag: hour, action: #selector(pillTapped(_:)))
            pill.accessibilityLabel = "Wind-down at \(hour - 12) PM"
            windPills.append(pill)
            windPillRow.addArrangedSubview(pill)
        }
        let windCard = makeSettingCard(symbol: "moon.zzz.fill", tint: WarmShelfPalette.lavender, title: "Wind-down hour",
                                       detail: "After this hour, Lull's rooms turn warmer and dimmer: a quiet cue for your evening routine.",
                                       content: [windPillRow])

        // Where to find them again, shown as the real button.
        let whereCard = makeWarmCard()
        let button = UIImageView(image: UIImage(systemName: "person.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)))
        button.tintColor = WarmShelfPalette.cocoa.withAlphaComponent(0.75)
        button.backgroundColor = WarmShelfPalette.sand.withAlphaComponent(0.3)
        button.contentMode = .center
        button.layer.cornerRadius = 22
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isAccessibilityElement = false
        let whereText = makeBody("Change these anytime: tap this button at the bottom right of the shelf, then answer the grown-up check. Sound, haptics, calmer motion and which toys are on the shelf are there too.")
        whereText.font = scaled(.systemFont(ofSize: 14, weight: .medium), .footnote)
        whereText.adjustsFontForContentSizeCategory = true
        whereText.translatesAutoresizingMaskIntoConstraints = false
        whereCard.addSubview(button)
        whereCard.addSubview(whereText)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: whereCard.leadingAnchor, constant: 16),
            button.centerYAnchor.constraint(equalTo: whereCard.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
            whereText.topAnchor.constraint(equalTo: whereCard.topAnchor, constant: 14),
            whereText.leadingAnchor.constraint(equalTo: button.trailingAnchor, constant: 14),
            whereText.trailingAnchor.constraint(equalTo: whereCard.trailingAnchor, constant: -16),
            whereText.bottomAnchor.constraint(equalTo: whereCard.bottomAnchor, constant: -14)
        ])
        refreshPills()

        let stack = UIStackView(arrangedSubviews: [eyebrow, title, body, timerCard, windCard, whereCard])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.setCustomSpacing(6, after: eyebrow)
        stack.setCustomSpacing(20, after: body)
        return wrapInPage(stack)
    }

    /// A settings card in the parent area's language: icon, bold name, one plain line, controls.
    private func makeSettingCard(symbol: String, tint: UIColor, title: String, detail: String, content: [UIView]) -> UIView {
        let card = makeWarmCard()
        let name = UILabel()
        name.text = title
        name.font = scaled(.systemFont(ofSize: 17, weight: .bold), .headline)
        name.adjustsFontForContentSizeCategory = true
        name.textColor = WarmShelfPalette.clayInk
        name.numberOfLines = 0
        name.accessibilityTraits = .header
        let line = makeBody(detail)
        line.font = scaled(.systemFont(ofSize: 14.5), .subheadline)
        line.adjustsFontForContentSizeCategory = true
        let words = UIStackView(arrangedSubviews: [name, line])
        words.axis = .vertical
        words.spacing = 2
        let header = UIStackView(arrangedSubviews: [makeIconSquircle(symbol, tint: tint), words])
        header.axis = .horizontal
        header.spacing = 12
        header.alignment = .top
        let column = UIStackView(arrangedSubviews: [header] + content)
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

    private func makeSettingNote(symbol: String, tint: UIColor, text: String) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        icon.tintColor = tint
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.isAccessibilityElement = false
        let label = makeBody(text)
        label.font = scaled(.systemFont(ofSize: 13.5), .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.85)
        let row = UIStackView(arrangedSubviews: [icon, label])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .firstBaseline
        return row
    }

    private func scaled(_ font: UIFont, _ style: UIFont.TextStyle) -> UIFont {
        UIFontMetrics(forTextStyle: style).scaledFont(for: font)
    }

    // MARK: - Page 3 — hand-off

    private func handoffPage() -> UIView {
        let eyebrow = makeEyebrow("YOUR FAMILY'S TOYBOX")
        let state = LullDemoState.shared
        let store = LullPurchaseManager.shared
        let family = store.product(for: LullStoreProduct.familyYearly)
        let familyPrice = family?.type == .autoRenewable ? family?.displayPrice : nil
        let period = store.renewalPeriod(for: LullStoreProduct.familyYearly) ?? "year"
        let keepForever = store.product(for: LullStoreProduct.lifetime)
        let keepForeverPrice = keepForever?.type == .nonConsumable ? keepForever?.displayPrice : nil
        let titleText: String
        let timelineRows: [UIView]
        if state.hasPurchasedFullToybox && state.isInFreeWeek {
            titleText = "Your free week,\nstill open."
            let days = state.freeWeekDaysRemaining
            let afterWeek = state.planWillRenew == false
                ? "The shelf goes back to Bubbles, Drop Dots, and Hum. These three stay free."
                : "Lull Family continues at \(store.displayPrice(for: LullStoreProduct.familyYearly)) a \(period) unless you cancel in your Apple Account settings at least a day before."
            timelineRows = [
                makeTimelineRow(dot: WarmShelfPalette.butter, label: "Today",
                                text: "All nine toys are open for \(days) more day\(days == 1 ? "" : "s")."),
                makeTimelineRow(dot: WarmShelfPalette.waterBlue, label: "When the week ends", text: afterWeek),
                makeTimelineRow(dot: WarmShelfPalette.terracotta, label: "Whenever you like",
                                text: "See or cancel your plan in the grown-up area.", isLast: true)
            ]
        } else if state.hasPurchasedFullToybox {
            titleText = "Your toybox,\nready for play."
            timelineRows = [
                makeTimelineRow(dot: WarmShelfPalette.butter, label: "Open",
                                text: "Your full toybox is unlocked. All nine toys are ready."),
                makeTimelineRow(dot: WarmShelfPalette.sage, label: "Your shelf",
                                text: "Keep favorite toys in reach and tuck others away in the grown-up area."),
                makeTimelineRow(dot: WarmShelfPalette.waterBlue, label: "Whenever you like",
                                text: "Return to familiar toys. Replaying this welcome never changes your purchase.", isLast: true)
            ]
        } else {
            titleText = "Three toys to keep,\nnine to play."
            let familyText: String
            if let familyPrice, let free = store.isEligibleForFreeWeek == true
                ? store.freeWeekLength(for: LullStoreProduct.familyYearly) : nil {
                familyText = "All nine toys, and new ones each season. First \(free) free, then \(familyPrice) a \(period). Cancel anytime."
            } else if let familyPrice {
                familyText = "All nine toys, and new ones each season, for \(familyPrice) a \(period). Cancel anytime."
            } else {
                familyText = "All nine toys, and new ones each season, starting with a free week. Prices are in the grown-up area."
            }
            timelineRows = [
                makeTimelineRow(dot: WarmShelfPalette.waterBlue, label: "Free, always",
                                text: "Bubbles, Drop Dots, and Hum. No ads, no accounts, nothing to pay."),
                makeTimelineRow(dot: WarmShelfPalette.butter, label: "Lull Family", text: familyText),
                makeTimelineRow(dot: WarmShelfPalette.terracotta, label: "Keep Forever",
                                text: keepForeverPrice.map { "Or pay \($0) once and keep every toy for good." }
                                    ?? "Or pay once and keep every toy for good.", isLast: true)
            ]
        }
        let title = makeTitle(titleText)

        let parentOptions = UIButton(type: .system)
        parentOptions.setTitle(state.hasPurchasedFullToybox ? "Set up our shelf" : "Start with the free toys", for: .normal)
        parentOptions.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        parentOptions.titleLabel?.numberOfLines = 0
        parentOptions.titleLabel?.textAlignment = .center
        parentOptions.setTitleColor(WarmShelfPalette.terracotta, for: .normal)
        parentOptions.backgroundColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.74)
        parentOptions.layer.cornerRadius = 18
        parentOptions.layer.borderWidth = 1
        parentOptions.layer.borderColor = WarmShelfPalette.softLine.cgColor
        parentOptions.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        parentOptions.accessibilityIdentifier = state.hasPurchasedFullToybox ? "welcome-set-up-shelf" : "welcome-free-toys"
        parentOptions.addTarget(self, action: #selector(secondaryTapped), for: .touchUpInside)

        let timeline = makeWarmCard()
        let rows = UIStackView(arrangedSubviews: timelineRows)
        rows.axis = .vertical
        rows.spacing = 0
        rows.translatesAutoresizingMaskIntoConstraints = false
        timeline.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: timeline.topAnchor, constant: 18),
            rows.leadingAnchor.constraint(equalTo: timeline.leadingAnchor, constant: 18),
            rows.trailingAnchor.constraint(equalTo: timeline.trailingAnchor, constant: -18),
            rows.bottomAnchor.constraint(equalTo: timeline.bottomAnchor, constant: -18)
        ])

        let gate = makeWarmCard()
        let gateLabel = makeBody("Prices, settings, and purchases stay in the grown-up area, behind an adult check. The child's shelf is only for play.")
        gateLabel.font = .systemFont(ofSize: 14, weight: .medium)
        gateLabel.translatesAutoresizingMaskIntoConstraints = false
        let seal = LullHostMarkView(side: 46)
        seal.translatesAutoresizingMaskIntoConstraints = false
        gate.addSubview(seal)
        gate.addSubview(gateLabel)
        NSLayoutConstraint.activate([
            seal.leadingAnchor.constraint(equalTo: gate.leadingAnchor, constant: 16),
            seal.centerYAnchor.constraint(equalTo: gate.centerYAnchor),
            seal.widthAnchor.constraint(equalToConstant: 46),
            seal.heightAnchor.constraint(equalToConstant: 46),
            gateLabel.topAnchor.constraint(equalTo: gate.topAnchor, constant: 16),
            gateLabel.leadingAnchor.constraint(equalTo: seal.trailingAnchor, constant: 14),
            gateLabel.trailingAnchor.constraint(equalTo: gate.trailingAnchor, constant: -16),
            gateLabel.bottomAnchor.constraint(equalTo: gate.bottomAnchor, constant: -16)
        ])

        let stack = UIStackView(arrangedSubviews: [eyebrow, title, timeline, parentOptions, gate])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.setCustomSpacing(6, after: eyebrow)
        stack.setCustomSpacing(18, after: title)
        stack.setCustomSpacing(16, after: timeline)
        stack.setCustomSpacing(16, after: parentOptions)
        return wrapInPage(stack)
    }

    private func refreshHandoffPage() {
        guard pagesStack.arrangedSubviews.count == pageCount,
              let oldPage = pagesStack.arrangedSubviews.last else { return }
        pagesStack.removeArrangedSubview(oldPage)
        oldPage.removeFromSuperview()
        let page = handoffPage()
        page.translatesAutoresizingMaskIntoConstraints = false
        pagesStack.addArrangedSubview(page)
        page.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
        updateForPage(currentPage, animated: false)
    }

    @objc private func secondaryTapped() {
        if LullDemoState.shared.hasPurchasedFullToybox {
            showParentOptions(atPlans: false)
        } else {
            HapticsManager.shared.softTap()
            AudioManager.shared.playSoftTap()
            finish()
        }
    }

    private func showParentOptions(atPlans: Bool) {
        AdultGate.present(from: self) { [weak self] in
            guard let self else { return }
            let parent = ParentInfoViewController()
            parent.opensAtPlans = atPlans
            parent.modalPresentationStyle = .fullScreen
            self.present(parent, animated: true)
        }
    }

    /// One row of the trial timeline: a clay dot with a connecting thread, a bold beat
    /// label, and plain words under it.
    private func makeTimelineRow(dot: UIColor, label: String, text: String, isLast: Bool = false) -> UIView {
        let row = UIView()

        let dotView = UIView()
        dotView.backgroundColor = dot
        dotView.layer.cornerRadius = 7
        dotView.layer.borderWidth = 1.5
        dotView.layer.borderColor = WarmShelfPalette.paperHighlight.cgColor
        dotView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(dotView)

        let thread = UIView()
        thread.backgroundColor = WarmShelfPalette.softLine.withAlphaComponent(isLast ? 0 : 0.5)
        thread.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(thread)

        let beat = UILabel()
        beat.text = label
        beat.font = .systemFont(ofSize: 15, weight: .bold)
        beat.textColor = WarmShelfPalette.clayInk
        beat.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(beat)

        let words = makeBody(text)
        words.font = .systemFont(ofSize: 14, weight: .regular)
        words.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(words)

        NSLayoutConstraint.activate([
            dotView.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            dotView.topAnchor.constraint(equalTo: row.topAnchor, constant: 3),
            dotView.widthAnchor.constraint(equalToConstant: 14),
            dotView.heightAnchor.constraint(equalToConstant: 14),

            thread.centerXAnchor.constraint(equalTo: dotView.centerXAnchor),
            thread.topAnchor.constraint(equalTo: dotView.bottomAnchor, constant: 3),
            thread.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            thread.widthAnchor.constraint(equalToConstant: 2),

            beat.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 12),
            beat.topAnchor.constraint(equalTo: row.topAnchor),
            beat.trailingAnchor.constraint(equalTo: row.trailingAnchor),

            words.leadingAnchor.constraint(equalTo: beat.leadingAnchor),
            words.topAnchor.constraint(equalTo: beat.bottomAnchor, constant: 2),
            words.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            words.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: isLast ? 0 : -16)
        ])
        return row
    }

    // MARK: - Paging

    @objc private func primaryTapped() {
        HapticsManager.shared.softTap()
        AudioManager.shared.playSoftTap()
        if currentPage < pageCount - 1 {
            let next = currentPage + 1
            scrollView.setContentOffset(CGPoint(x: CGFloat(next) * scrollView.bounds.width, y: 0), animated: true)
            updateForPage(next, animated: true)
        } else if LullDemoState.shared.hasPurchasedFullToybox {
            finish()
        } else {
            // The free week is the App Store's: a grown-up starts it from the plans.
            showParentOptions(atPlans: true)
        }
    }

    private func updateForPage(_ page: Int, animated: Bool) {
        currentPage = page
        pageDots.currentPage = page
        let state = LullDemoState.shared
        let title: String
        if page != pageCount - 1 {
            title = "Continue"
        } else if state.hasPurchasedFullToybox {
            title = "Open toybox"
        } else if LullPurchaseManager.shared.isEligibleForFreeWeek == true {
            title = "Try all nine free"
        } else {
            title = "See all nine toys"
        }
        UIView.transition(with: primaryButton, duration: animated ? 0.2 : 0, options: .transitionCrossDissolve) {
            self.primaryButton.setTitle(title, for: .normal)
        }
    }

    private func finish() {
        LullDemoState.shared.windDownHour = windDownHour
        LullDemoState.shared.playTimerMinutes = playTimerMinutes   // also starts a fresh sitting
        LullDemoState.shared.completeOnboarding()
        onComplete?()
    }

    // MARK: - Choice pills (play timer and wind-down)

    private func makeChoicePill(title: String, tag: Int, action: Selector) -> UIButton {
        let pill = UIButton(type: .system)
        pill.setTitle(title, for: .normal)
        pill.titleLabel?.font = scaled(.systemFont(ofSize: 16, weight: .bold), .body)
        pill.titleLabel?.adjustsFontForContentSizeCategory = true
        pill.titleLabel?.adjustsFontSizeToFitWidth = true
        pill.titleLabel?.minimumScaleFactor = 0.7
        pill.layer.cornerRadius = 16
        pill.tag = tag
        pill.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        pill.addTarget(self, action: action, for: .touchUpInside)
        return pill
    }

    @objc private func pillTapped(_ sender: UIButton) {
        windDownHour = sender.tag
        HapticsManager.shared.softTap()
        AudioManager.shared.playSoftTap()
        refreshPills()
    }

    @objc private func timerPillTapped(_ sender: UIButton) {
        playTimerMinutes = sender.tag
        HapticsManager.shared.softTap()
        AudioManager.shared.playSoftTap()
        refreshPills()
        UIAccessibility.post(notification: .announcement, argument: timerStatus.text)
    }

    private func refreshPills() {
        for pill in windPills { style(pill, selected: pill.tag == windDownHour) }
        for pill in timerPills { style(pill, selected: pill.tag == playTimerMinutes) }
        timerStatus.text = playTimerMinutes == 0
            ? "Off: Lull never rests on its own."
            : "Lull will rest after \(playTimerMinutes) minutes of play."
    }

    private func style(_ pill: UIButton, selected: Bool) {
        pill.backgroundColor = selected ? WarmShelfPalette.terracotta : WarmShelfPalette.sand.withAlphaComponent(0.16)
        pill.setTitleColor(selected ? WarmShelfPalette.paperHighlight : WarmShelfPalette.cocoa, for: .normal)
        pill.layer.borderWidth = selected ? 0 : 1
        pill.layer.borderColor = WarmShelfPalette.softLine.withAlphaComponent(0.4).cgColor
        pill.accessibilityTraits = selected ? [.button, .selected] : .button
    }

    private func displayHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h) pm"
    }

    // MARK: - Building blocks (warm handmade cards)

    private func wrapInPage(_ content: UIView) -> UIView {
        let page = UIView()
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceVertical = true
        page.addSubview(scroll)
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: page.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: page.bottomAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 30),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -30),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
        return page
    }

    private func makeWarmCard() -> UIView {
        let card = UIView()
        card.backgroundColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.62)
        card.layer.cornerRadius = 22
        card.layer.borderWidth = 1
        card.layer.borderColor = WarmShelfPalette.softLine.withAlphaComponent(0.4).cgColor
        card.layer.shadowColor = WarmShelfPalette.contactShadow.cgColor
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 16
        card.layer.shadowOffset = CGSize(width: 0, height: 9)
        return card
    }

    private func makePromiseChip(_ text: String, icon: String, _ color: UIColor) -> UIView {
        let chip = UIView()
        chip.backgroundColor = color.withAlphaComponent(0.14)
        chip.layer.cornerRadius = 16
        chip.layer.borderWidth = 1
        chip.layer.borderColor = color.withAlphaComponent(0.34).cgColor
        let iconView = UIImageView(image: UIImage(systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)))
        iconView.tintColor = color.withAlphaComponent(0.95)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12.5, weight: .bold)
        label.textColor = WarmShelfPalette.clayInk
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(iconView)
        chip.addSubview(label)
        NSLayoutConstraint.activate([
            chip.heightAnchor.constraint(equalToConstant: 34),
            iconView.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 9),
            iconView.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 4),
            label.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -10)
        ])
        return chip
    }

    /// The parent area's icon language, shared — one design system, both rooms.
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

    private func makeEyebrow(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .heavy)
        label.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.6)
        return label
    }

    private func makeTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont(name: "Georgia", size: 34) ?? .systemFont(ofSize: 34, weight: .semibold)
        label.textColor = WarmShelfPalette.clayInk
        label.numberOfLines = 0
        return label
    }

    private func makeBody(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = WarmShelfPalette.cocoa
        label.numberOfLines = 0
        return label
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}

extension LullOnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int((scrollView.contentOffset.x / max(1, scrollView.bounds.width)).rounded())
        if page != currentPage { updateForPage(page, animated: true) }
    }
}

// MARK: - WrenHeroView — a live little Wren who says hello

private final class WrenHeroView: UIView {
    private let skView = SKView()

    init(side: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: side, height: side))
        backgroundColor = .clear
        skView.backgroundColor = .clear
        skView.allowsTransparency = true
        skView.ignoresSiblingOrder = true
        skView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(skView)
        NSLayoutConstraint.activate([
            skView.topAnchor.constraint(equalTo: topAnchor),
            skView.leadingAnchor.constraint(equalTo: leadingAnchor),
            skView.trailingAnchor.constraint(equalTo: trailingAnchor),
            skView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard skView.scene == nil, bounds.width > 10 else { return }
        let scene = WrenHeroScene(size: bounds.size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        skView.presentScene(scene)
    }
}

private final class WrenHeroScene: SKScene {
    private var host: LullHostNode?
    override func didMove(to view: SKView) {
        let scale = (size.width * 0.46) / (58 * 2)
        let wren = LullHostNode(scale: scale)
        wren.position = CGPoint(x: size.width / 2, y: size.height * 0.46)
        addChild(wren)
        wren.setExpression(.smile, animated: false)
        wren.startIdleBlink()
        host = wren
        // A gentle hello a beat after appearing.
        run(.sequence([.wait(forDuration: 0.6), .run { [weak wren] in wren?.setExpression(.laugh) },
                       .wait(forDuration: 1.6), .run { [weak wren] in wren?.setExpression(.smile) }]))
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        host?.giggle()
    }
}
