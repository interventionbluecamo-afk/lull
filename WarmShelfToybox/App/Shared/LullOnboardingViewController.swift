import SpriteKit
import StoreKit
import UIKit

// MARK: - LullOnboardingViewController
//
// A warm, paged welcome that ends with the toybox open (founder, October 11: one offer, a free
// week, and onboarding good enough to win over the grown-up who is uneasy about it). Three moments:
//   1. Welcome: Wren says hello, and the nine toys are already alive on the page: value first.
//      "Set up Lull" asks the grown-up check; nothing past this page is for a child.
//   2. The family's rhythm: play timer and wind-down hour, chosen now (their investment).
//   3. "Your toybox is ready": their setup said back, the toys, the price first and largest, the
//      free week as three dated beats, four promises, the pay-once door, Apple's terms; the start
//      button pinned below with the billed price beside it. "Not now" opens the honest version.
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
    /// The billed price, beside the pinned button on the last page (Guideline 3.1.2).
    private let ctaCaption = UILabel()
    private var isLoadingProducts = false
    private var isPurchasing = false
    /// A purchase that didn't complete says why on the last page.
    private var offerMessage: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WarmShelfPalette.linen
        // The last page names the real App Store price and free week (Guideline 3.1.2); start
        // asking the App Store now, while the grown-up reads the first two pages.
        isLoadingProducts = LullPurchaseManager.shared.products.isEmpty
        setupBackground()
        setupScaffold()
        buildPages()
        updateForPage(0, animated: false)
        accessObserver = NotificationCenter.default.addObserver(
            forName: .lullAccessDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshOfferPage() }
        }
        if isLoadingProducts {
            Task { @MainActor [weak self] in
                await LullPurchaseManager.shared.loadProducts()
                self?.isLoadingProducts = false
                self?.refreshOfferPage()
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
        // Pages move only with the button: the grown-up check stands between the welcome and the
        // family's setup, so a child can't swipe past it.
        scrollView.isScrollEnabled = false
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
        primaryButton.setTitleColor(WarmShelfPalette.paperHighlight.withAlphaComponent(0.85), for: .disabled)
        primaryButton.titleLabel?.adjustsFontSizeToFitWidth = true
        primaryButton.titleLabel?.minimumScaleFactor = 0.8
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        view.addSubview(primaryButton)

        ctaCaption.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .medium))
        ctaCaption.adjustsFontForContentSizeCategory = true
        ctaCaption.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.78)
        ctaCaption.textAlignment = .center
        ctaCaption.numberOfLines = 2
        ctaCaption.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ctaCaption)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // Content scrolls above the page dots, never under them.
            scrollView.bottomAnchor.constraint(equalTo: pageDots.topAnchor, constant: -4),

            pagesStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            pagesStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            pagesStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            pagesStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            pagesStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            pageDots.bottomAnchor.constraint(equalTo: primaryButton.topAnchor, constant: -10),
            pageDots.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            primaryButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            primaryButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            primaryButton.bottomAnchor.constraint(equalTo: ctaCaption.topAnchor, constant: -8),
            primaryButton.heightAnchor.constraint(equalToConstant: 58),

            ctaCaption.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            ctaCaption.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            ctaCaption.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
    }

    private func buildPages() {
        let pages = [welcomePage(), rhythmPage(), offerPage()]
        for page in pages {
            page.translatesAutoresizingMaskIntoConstraints = false
            pagesStack.addArrangedSubview(page)
            page.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
        }
    }

    // MARK: - Page 1 — welcome

    private func welcomePage() -> UIView {
        let hero = WrenHeroView(side: 132)

        let eyebrow = makeEyebrow("WELCOME TO LULL")
        let title = makeTitle("Calm toys for\nlittle hands.")
        let body = makeBody("Nine felt-and-wood toys for ages 2–6. Scrub a muddy truck, feed hungry friends, sort colours, make music, and wander a meadow. Each one answers touch the way a real toy would.")

        // Value before anything else: the nine toys the child will find, already breathing.
        let toys = PaywallPreviewStrip(toyIDs: ToyRegistry.launchToyIDs,
                                       labelColor: WarmShelfPalette.cocoa.withAlphaComponent(0.85), rowHeight: 92)

        let chips = UIStackView(arrangedSubviews: [
            makePromiseChip("No ads", icon: "rectangle.slash", WarmShelfPalette.waterBlue),
            makePromiseChip("No scores", icon: "star.slash", WarmShelfPalette.butter),
            makePromiseChip("No pressure", icon: "leaf", WarmShelfPalette.sage)
        ])
        chips.axis = .horizontal
        chips.spacing = 8
        chips.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [hero, eyebrow, title, body, toys, chips])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .leading
        stack.setCustomSpacing(18, after: hero)
        stack.setCustomSpacing(6, after: eyebrow)
        stack.setCustomSpacing(8, after: body)
        stack.setCustomSpacing(8, after: toys)
        hero.translatesAutoresizingMaskIntoConstraints = false
        hero.widthAnchor.constraint(equalToConstant: 132).isActive = true
        hero.heightAnchor.constraint(equalToConstant: 132).isActive = true
        toys.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
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

    // MARK: - Page 3 — the toybox, and the one offer

    /// Everything a hesitant grown-up needs, on one page (founder, October 11: "it needs to save
    /// the people who are immediately uneasy; they need to see the value"). Their setup said
    /// back, the nine toys alive, the price first and largest, the free week as three dated
    /// beats, four promises, the pay-once door, Apple's terms. The start button is pinned below
    /// with the billed price beside it; "Not now" opens the honest version of the free week
    /// instead of a dead end. Reached only through the grown-up check on page one.
    private func offerPage() -> UIView {
        if LullDemoState.shared.hasPurchasedFullToybox { return toyboxOpenPage() }
        let offer = LullPlanOffer.current()

        let eyebrow = makeEyebrow("YOUR TOYBOX IS READY")
        let notNow = UIButton(type: .system)
        notNow.setTitle("Not now", for: .normal)
        notNow.titleLabel?.font = scaled(.systemFont(ofSize: 15, weight: .semibold), .subheadline)
        notNow.titleLabel?.adjustsFontForContentSizeCategory = true
        notNow.setTitleColor(WarmShelfPalette.cocoa.withAlphaComponent(0.72), for: .normal)
        notNow.accessibilityIdentifier = "offer-not-now"
        notNow.isEnabled = !isPurchasing
        notNow.addTarget(self, action: #selector(notNowTapped), for: .touchUpInside)
        notNow.setContentHuggingPriority(.required, for: .horizontal)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [eyebrow, spacer, notNow])
        header.axis = .horizontal
        header.alignment = .center

        let title = makeTitle("Your toybox is ready.")
        let summary = makeBody(setupSummary())
        summary.font = scaled(.systemFont(ofSize: 15.5, weight: .medium), .body)
        summary.adjustsFontForContentSizeCategory = true

        var rows: [UIView] = [header, title, summary]
        if let offerMessage {
            rows.append(makeMessageCard(offerMessage))
        }
        rows.append(LullOfferView(
            offer: offer, isLoading: isLoadingProducts, isBusy: isPurchasing, showsStartButton: false,
            actions: .init(
                start: { [weak self] in self?.buy(LullStoreProduct.familyYearly) },
                keepForever: { [weak self] in self?.buy(LullStoreProduct.lifetime) },
                restore: { [weak self] in self?.restore() },
                terms: { UIApplication.shared.open(LullStoreProduct.termsOfUseURL) },
                privacy: { [weak self] in self?.showPrivacy() },
                retry: { [weak self] in self?.reloadProducts() }
            )
        ))
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.setCustomSpacing(2, after: header)
        stack.setCustomSpacing(8, after: title)
        stack.setCustomSpacing(16, after: summary)
        return wrapInPage(stack)
    }

    /// The setup they just chose, said back, so the toybox is theirs before it's offered.
    private func setupSummary() -> String {
        let evening = displayHour(windDownHour)
        if playTimerMinutes == 0 {
            return "Set up for your family: no play timer, and Lull grows sleepy from \(evening)."
        }
        return "Set up for your family: Lull rests after \(playTimerMinutes) minutes of play and grows sleepy from \(evening)."
    }

    /// After the free week starts, or on a replay with the toybox already open: a happy Wren,
    /// what is open and until when, then "Open the toybox".
    private func toyboxOpenPage() -> UIView {
        let state = LullDemoState.shared
        let store = LullPurchaseManager.shared
        let period = store.renewalPeriod(for: LullStoreProduct.familyYearly) ?? "year"
        let hero = WrenHeroView(side: 120)
        hero.translatesAutoresizingMaskIntoConstraints = false
        let heroHolder = UIView()
        heroHolder.addSubview(hero)
        NSLayoutConstraint.activate([
            hero.widthAnchor.constraint(equalToConstant: 120),
            hero.heightAnchor.constraint(equalToConstant: 120),
            hero.topAnchor.constraint(equalTo: heroHolder.topAnchor),
            hero.bottomAnchor.constraint(equalTo: heroHolder.bottomAnchor),
            hero.leadingAnchor.constraint(equalTo: heroHolder.leadingAnchor)
        ])

        let eyebrow = makeEyebrow(state.isInFreeWeek ? "YOUR FREE WEEK HAS BEGUN" : "THE TOYBOX IS OPEN")
        let title = makeTitle("All nine toys\nare open.")
        var timelineRows: [UIView]
        if state.isInFreeWeek {
            let days = state.freeWeekDaysRemaining
            let end = state.freeWeekEndDate.map(LullPlanOffer.longDay) ?? "When the week ends"
            let afterWeek = state.planWillRenew == false
                ? "Lull Family won't renew, so the toybox rests until a grown-up opens it again."
                : "Lull Family begins at \(store.displayPrice(for: LullStoreProduct.familyYearly)) a \(period). To pay nothing, cancel at least 24 hours before the trial ends in Settings › your name › Subscriptions."
            timelineRows = [makeTimelineRow(dot: WarmShelfPalette.butter, label: "Today",
                                            text: "All nine toys are open for \(days) day\(days == 1 ? "" : "s"). Nothing to pay.")]
            if LullFreeWeekReminder.isScheduled, let reminder = LullFreeWeekReminder.reminderDate {
                timelineRows.append(makeTimelineRow(dot: WarmShelfPalette.sage, label: LullPlanOffer.longDay(reminder),
                                                    text: "A reminder is scheduled."))
            } else {
                timelineRows.append(makeTimelineRow(dot: WarmShelfPalette.sage, label: "Any day",
                                                    text: "No reminder is set. The grown-up area shows how many days are left."))
            }
            timelineRows.append(makeTimelineRow(dot: WarmShelfPalette.terracotta, label: end, text: afterWeek, isLast: true))
        } else {
            timelineRows = [
                makeTimelineRow(dot: WarmShelfPalette.butter, label: "Open",
                                text: state.hasKeepForever ? "Keep Forever: every toy, and every new one, for good."
                                                           : "All nine toys, plus new ones each season."),
                makeTimelineRow(dot: WarmShelfPalette.sage, label: "Your shelf",
                                text: "Keep favourite toys in reach and tuck others away in the grown-up area."),
                makeTimelineRow(dot: WarmShelfPalette.waterBlue, label: "Whenever you like",
                                text: "See or change your plan in the grown-up area. Replaying this welcome never changes it.",
                                isLast: true)
            ]
        }

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

        let stack = UIStackView(arrangedSubviews: [heroHolder, eyebrow, title, timeline])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.setCustomSpacing(18, after: heroHolder)
        stack.setCustomSpacing(6, after: eyebrow)
        stack.setCustomSpacing(18, after: title)
        return wrapInPage(stack)
    }

    private func makeMessageCard(_ text: String) -> UIView {
        let card = makeWarmCard()
        card.backgroundColor = WarmShelfPalette.sage.withAlphaComponent(0.14)
        let label = makeBody(text)
        label.font = scaled(.systemFont(ofSize: 15, weight: .semibold), .body)
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }

    private func refreshOfferPage() {
        guard pagesStack.arrangedSubviews.count == pageCount,
              let oldPage = pagesStack.arrangedSubviews.last else { return }
        pagesStack.removeArrangedSubview(oldPage)
        oldPage.removeFromSuperview()
        let page = offerPage()
        page.translatesAutoresizingMaskIntoConstraints = false
        pagesStack.addArrangedSubview(page)
        page.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
        updateForPage(currentPage, animated: false)
    }

    // MARK: - Buying (this page is already behind the grown-up check)

    private func buy(_ productID: String) {
        guard !isPurchasing, LullPurchaseManager.shared.product(for: productID) != nil else { return }
        isPurchasing = true
        offerMessage = nil
        refreshOfferPage()
        Task { @MainActor in
            let outcome = await LullPurchaseFlow.buy(productID)
            isPurchasing = false
            switch outcome {
            case .opened:
                // The open page says what's open, until when, and whether a reminder is set.
                offerMessage = nil
                HapticsManager.shared.softTap()
            case .notOpened(let reason):
                offerMessage = reason
            }
            refreshOfferPage()
        }
    }

    private func restore() {
        guard !isPurchasing else { return }
        isPurchasing = true
        offerMessage = nil
        refreshOfferPage()
        Task { @MainActor in
            let restored = await LullPurchaseManager.shared.restorePurchases()
            isPurchasing = false
            offerMessage = restored ? nil
                : (LullPurchaseManager.shared.lastErrorMessage ?? "No Lull Family plan or Keep Forever purchase was found for this Apple Account.")
            refreshOfferPage()
        }
    }

    private func reloadProducts() {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        offerMessage = nil
        refreshOfferPage()
        Task { @MainActor in
            await LullPurchaseManager.shared.loadProducts()
            isLoadingProducts = false
            refreshOfferPage()
        }
    }

    private func showPrivacy() {
        let privacy = LullPrivacyViewController()
        privacy.modalPresentationStyle = .pageSheet
        present(privacy, animated: true)
    }

    /// "Not now" never dead-ends: it opens the honest version of the free week, with the same
    /// start button, the pay-once door, and a real "Decide later".
    @objc private func notNowTapped() {
        guard !isPurchasing, presentedViewController == nil else { return }
        HapticsManager.shared.softTap()
        let pause = LullOfferPauseViewController(
            offer: LullPlanOffer.current(),
            onStart: { [weak self] in self?.buy(LullStoreProduct.familyYearly) },
            onKeepForever: { [weak self] in self?.buy(LullStoreProduct.lifetime) },
            onLater: { [weak self] in self?.finish() }
        )
        present(pause, animated: true)
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
        switch currentPage {
        case 0:
            // Everything past the welcome is for grown-ups: the family's setup and the offer.
            AdultGate.present(from: self) { [weak self] in self?.go(to: 1) }
        case 1:
            go(to: 2)
        default:
            if LullDemoState.shared.hasPurchasedFullToybox {
                finish()
                return
            }
            let offer = LullPlanOffer.current()
            if offer.familyPrice != nil {
                buy(LullStoreProduct.familyYearly)
            } else if offer.keepForeverPrice != nil {
                buy(LullStoreProduct.lifetime)
            } else {
                reloadProducts()
            }
        }
    }

    private func go(to page: Int) {
        guard page < pageCount else { return }
        scrollView.setContentOffset(CGPoint(x: CGFloat(page) * scrollView.bounds.width, y: 0), animated: true)
        updateForPage(page, animated: true)
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }

    private func updateForPage(_ page: Int, animated: Bool) {
        currentPage = page
        pageDots.currentPage = page
        var title = "Continue"
        var caption: String?
        var enabled = true
        switch page {
        case 0:
            title = "Set up Lull"
            caption = "For grown-ups: a quick check comes next."
        case 1:
            break
        default:
            if LullDemoState.shared.hasPurchasedFullToybox {
                title = "Open the toybox"
            } else if isPurchasing {
                title = "Waiting for the App Store…"
                enabled = false
            } else {
                let offer = LullPlanOffer.current()
                if let start = offer.startTitle {
                    title = start
                    caption = offer.startCaption
                    enabled = AppStore.canMakePayments
                } else if let keepForever = offer.keepForeverPrice {
                    title = "Buy once · \(keepForever)"
                    caption = "One payment. Every toy, for good."
                    enabled = AppStore.canMakePayments
                } else if isLoadingProducts {
                    title = "Connecting to the App Store…"
                    enabled = false
                } else {
                    title = "Try again"
                }
            }
        }
        // Set without a transition: a cross-dissolve here could leave the title blank.
        UIView.performWithoutAnimation {
            primaryButton.setTitle(title, for: .normal)
            primaryButton.layoutIfNeeded()
        }
        primaryButton.isEnabled = enabled
        primaryButton.alpha = enabled ? 1 : 0.62
        primaryButton.accessibilityHint = caption
        ctaCaption.text = caption
        ctaCaption.isHidden = caption == nil
        if animated { UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() } }
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
