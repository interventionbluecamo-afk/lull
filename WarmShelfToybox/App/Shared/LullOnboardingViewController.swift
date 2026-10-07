import SpriteKit
import UIKit

// MARK: - LullOnboardingViewController
//
// A warm, paged parent setup — handed over to the child at the end. Three calm moments:
//   1. Welcome: Wren says hello; the quiet promise (no ads, no scores, no pressure).
//   2. Wind-down: the grown-up picks bedtime; Lull's rooms warm and dim toward it.
//   3. Hand-off: the 7-day free toybox, what stays free, and the grown-up gate.
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
        let pages = [welcomePage(), windDownPage(), handoffPage()]
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
        let body = makeBody("Nine handmade toys for ages 2–6. Build, sort, feed, make music, and wander through a meadow. Pictures and touch invite your child to choose, try, and repeat at their own pace.")

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

    // MARK: - Page 2 — wind-down

    private func windDownPage() -> UIView {
        let eyebrow = makeEyebrow("BEDTIME, GENTLY")
        let title = makeTitle("When does the\nday wind down?")
        let body = makeBody("At your chosen hour, Lull's rooms become warmer and dimmer. It's a quiet cue you can pair with your family's evening routine.")

        let card = makeWarmCard()
        let squircle = makeIconSquircle("moon.zzz.fill", tint: WarmShelfPalette.lavender)
        let hint = makeBody("Wind-down begins around")
        hint.font = .systemFont(ofSize: 14.5, weight: .semibold)
        hint.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.85)
        let header = UIStackView(arrangedSubviews: [squircle, hint])
        header.axis = .horizontal
        header.spacing = 11
        header.alignment = .center

        let pillRow = UIStackView()
        pillRow.axis = .horizontal
        pillRow.spacing = 10
        pillRow.distribution = .fillEqually
        for hour in [18, 19, 20, 21] {
            let pill = makeTimePill(hour: hour)
            windPills.append(pill)
            pillRow.addArrangedSubview(pill)
        }
        let cardStack = UIStackView(arrangedSubviews: [header, pillRow])
        cardStack.axis = .vertical
        cardStack.spacing = 12
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
        refreshPills()

        let stack = UIStackView(arrangedSubviews: [eyebrow, title, body, card])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.setCustomSpacing(6, after: eyebrow)
        stack.setCustomSpacing(22, after: body)
        return wrapInPage(stack)
    }

    // MARK: - Page 3 — hand-off

    private func handoffPage() -> UIView {
        let eyebrow = makeEyebrow("YOUR FAMILY'S TOYBOX")
        let state = LullDemoState.shared
        let titleText: String
        let timelineRows: [UIView]
        if state.hasPurchasedFullToybox {
            titleText = "Your toybox,\nready for play."
            timelineRows = [
                makeTimelineRow(dot: WarmShelfPalette.butter, label: "Open",
                                text: "Your full toybox is unlocked. All nine toys are ready."),
                makeTimelineRow(dot: WarmShelfPalette.sage, label: "Your shelf",
                                text: "Keep favorite toys in reach and tuck others away in the grown-up area."),
                makeTimelineRow(dot: WarmShelfPalette.waterBlue, label: "Whenever you like",
                                text: "Return to familiar toys. Your purchase stays active when you replay this welcome.", isLast: true)
            ]
        } else if state.isTrialActive {
            titleText = "Your free week,\nstill open."
            let days = state.trialDaysRemaining
            timelineRows = [
                makeTimelineRow(dot: WarmShelfPalette.butter, label: "Today",
                                text: "The full toybox is open for \(days) more day\(days == 1 ? "" : "s")."),
                makeTimelineRow(dot: WarmShelfPalette.waterBlue, label: "When the week ends",
                                text: "The shelf will show Bubbles, Stack, and Drop Dots. These three stay free."),
                makeTimelineRow(dot: WarmShelfPalette.terracotta, label: "Whenever you like",
                                text: "One optional purchase keeps the full toybox open. See the price in the grown-up area.", isLast: true)
            ]
        } else if state.hasTrialStarted {
            titleText = "Three toys,\nyours to revisit."
            timelineRows = [
                makeTimelineRow(dot: WarmShelfPalette.waterBlue, label: "Your free shelf",
                                text: "Bubbles, Stack, and Drop Dots are ready to play. They stay free."),
                makeTimelineRow(dot: WarmShelfPalette.sage, label: "At your own pace",
                                text: "Choose a familiar toy, explore, and come back whenever you like."),
                makeTimelineRow(dot: WarmShelfPalette.terracotta, label: "The full toybox",
                                text: "One optional purchase opens all nine toys. See the price in the grown-up area.", isLast: true)
            ]
        } else {
            titleText = "One week,\nthe whole toybox."
            timelineRows = [
                makeTimelineRow(dot: WarmShelfPalette.butter, label: "Today",
                                text: "The whole toybox opens for seven days — all nine toys."),
                makeTimelineRow(dot: WarmShelfPalette.sage, label: "All week",
                                text: "Explore together. No payment information is needed to begin."),
                makeTimelineRow(dot: WarmShelfPalette.waterBlue, label: "After seven days",
                                text: "The shelf will show Bubbles, Stack, and Drop Dots. These three stay free."),
                makeTimelineRow(dot: WarmShelfPalette.terracotta, label: "Whenever you like",
                                text: "One optional purchase keeps the full toybox open. See the price in the grown-up area.", isLast: true)
            ]
        }
        let title = makeTitle(titleText)

        let parentOptions = UIButton(type: .system)
        parentOptions.setTitle(state.hasPurchasedFullToybox ? "Set up our shelf" : "See full toybox & price", for: .normal)
        parentOptions.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        parentOptions.titleLabel?.numberOfLines = 0
        parentOptions.titleLabel?.textAlignment = .center
        parentOptions.setTitleColor(WarmShelfPalette.terracotta, for: .normal)
        parentOptions.backgroundColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.74)
        parentOptions.layer.cornerRadius = 18
        parentOptions.layer.borderWidth = 1
        parentOptions.layer.borderColor = WarmShelfPalette.softLine.cgColor
        parentOptions.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        parentOptions.addTarget(self, action: #selector(showParentOptions), for: .touchUpInside)

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

        let exploration = makeWarmCard()
        let gSquircle = makeIconSquircle("hand.draw.fill", tint: WarmShelfPalette.terracotta)
        let gTitle = UILabel()
        gTitle.text = "Room to explore"
        gTitle.font = UIFont(name: "Georgia-Bold", size: 17) ?? .systemFont(ofSize: 17, weight: .bold)
        gTitle.textColor = WarmShelfPalette.clayInk
        gTitle.numberOfLines = 0
        let gBody = makeBody("Let your child choose, repeat, and discover. A familiar toy can invite a different idea each time.")
        gBody.font = .systemFont(ofSize: 14, weight: .regular)
        let gTitles = UIStackView(arrangedSubviews: [gTitle, gBody])
        gTitles.axis = .vertical
        gTitles.spacing = 4
        let gHead = UIStackView(arrangedSubviews: [gSquircle, gTitles])
        gHead.axis = .horizontal
        gHead.spacing = 12
        gHead.alignment = .top
        let gColumn = UIStackView(arrangedSubviews: [gHead])
        gColumn.axis = .vertical
        gColumn.spacing = 12
        gColumn.translatesAutoresizingMaskIntoConstraints = false
        exploration.addSubview(gColumn)
        NSLayoutConstraint.activate([
            gColumn.topAnchor.constraint(equalTo: exploration.topAnchor, constant: 16),
            gColumn.leadingAnchor.constraint(equalTo: exploration.leadingAnchor, constant: 16),
            gColumn.trailingAnchor.constraint(equalTo: exploration.trailingAnchor, constant: -16),
            gColumn.bottomAnchor.constraint(equalTo: exploration.bottomAnchor, constant: -16)
        ])

        let reassure = makeBody(state.hasPurchasedFullToybox
            ? "Your full toybox is open."
            : "The free week never turns into a charge. A full toybox purchase is optional.")
        reassure.font = .systemFont(ofSize: 14, weight: .semibold)
        reassure.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.75)
        reassure.textAlignment = .center

        let gate = makeWarmCard()
        let gateLabel = makeBody("Prices, settings, and purchases live in the grown-up area behind an adult check. The child's shelf is for play.")
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

        let stack = UIStackView(arrangedSubviews: [eyebrow, title, parentOptions, timeline, exploration, reassure, gate])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.setCustomSpacing(6, after: eyebrow)
        stack.setCustomSpacing(18, after: title)
        stack.setCustomSpacing(12, after: timeline)
        stack.setCustomSpacing(10, after: exploration)
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

    @objc private func showParentOptions() {
        AdultGate.present(from: self) { [weak self] in
            guard let self else { return }
            let parent = ParentInfoViewController()
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
        } else {
            finish()
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
        } else if state.isTrialActive {
            title = "Continue free week"
        } else if state.hasTrialStarted {
            title = "Open free toys"
        } else {
            title = "Start seven free days"
        }
        UIView.transition(with: primaryButton, duration: animated ? 0.2 : 0, options: .transitionCrossDissolve) {
            self.primaryButton.setTitle(title, for: .normal)
        }
    }

    private func finish() {
        LullDemoState.shared.windDownHour = windDownHour
        LullDemoState.shared.completeOnboarding()
        onComplete?()
    }

    // MARK: - Wind-down pills

    private func makeTimePill(hour: Int) -> UIButton {
        let pill = UIButton(type: .system)
        pill.setTitle(displayHour(hour), for: .normal)
        pill.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        pill.layer.cornerRadius = 16
        pill.tag = hour
        pill.heightAnchor.constraint(equalToConstant: 52).isActive = true
        pill.addTarget(self, action: #selector(pillTapped(_:)), for: .touchUpInside)
        return pill
    }

    @objc private func pillTapped(_ sender: UIButton) {
        windDownHour = sender.tag
        HapticsManager.shared.softTap()
        AudioManager.shared.playSoftTap()
        refreshPills()
    }

    private func refreshPills() {
        for pill in windPills {
            let selected = pill.tag == windDownHour
            pill.backgroundColor = selected ? WarmShelfPalette.terracotta : WarmShelfPalette.sand.withAlphaComponent(0.16)
            pill.setTitleColor(selected ? WarmShelfPalette.paperHighlight : WarmShelfPalette.cocoa, for: .normal)
            pill.layer.borderWidth = selected ? 0 : 1
            pill.layer.borderColor = WarmShelfPalette.softLine.withAlphaComponent(0.4).cgColor
        }
    }

    private func displayHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h):00"
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
