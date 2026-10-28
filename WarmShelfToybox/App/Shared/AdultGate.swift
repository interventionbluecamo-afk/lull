import UIKit

/// The grown-up check. A calm, on-brand modal (never the native system alert),
/// because this is the doorway to the parent area and purchases.
enum AdultGate {
    static func present(from presenter: UIViewController, onSuccess: @escaping () -> Void) {
        let gate = AdultGateViewController(onSuccess: onSuccess)
        gate.modalPresentationStyle = .overFullScreen
        gate.modalTransitionStyle = .crossDissolve
        presenter.present(gate, animated: true)
    }
}

/// The question itself, kept free of UIKit so it can be checked off-device.
///
/// Three digits spelled out as words ("four · seven · two"), typed back as digits. A pre-reader
/// can't decode the words, and a toddler mashing the number pad has 1 in 1,000 odds per try.
/// Every miss draws a new question; three misses in a row rest the check for half a minute.
struct AdultGateChallenge {
    static let digitWords = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
    static let maxMisses = 3
    static let restDuration: TimeInterval = 30

    let digits: [Int]

    init(digits: [Int]) { self.digits = digits }

    static func random() -> AdultGateChallenge {
        AdultGateChallenge(digits: (0..<3).map { _ in Int.random(in: 0...9) })
    }

    var prompt: String { digits.map { Self.digitWords[$0] }.joined(separator: " · ") }
    var spokenPrompt: String { digits.map { Self.digitWords[$0] }.joined(separator: ", ") }
    var answer: String { digits.map(String.init).joined() }

    func accepts(_ typed: String) -> Bool {
        typed.trimmingCharacters(in: .whitespaces) == answer
    }
}

final class AdultGateViewController: UIViewController, UIGestureRecognizerDelegate {
    private let onSuccess: () -> Void
    private var challenge = AdultGateChallenge.random()
    private var answer = ""
    private static var consecutiveMisses = 0
    private static var restingUntil: Date? {
        get {
            let value = UserDefaults.standard.double(forKey: "lull.adultGate.restUntil")
            return value > 0 ? Date(timeIntervalSinceReferenceDate: value) : nil
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSinceReferenceDate, forKey: "lull.adultGate.restUntil")
            } else {
                UserDefaults.standard.removeObject(forKey: "lull.adultGate.restUntil")
            }
        }
    }
    private var restTimer: Timer?
    private let card = UIView()
    private let scroll = UIScrollView()
    private let bodyStack = UIStackView()
    private let questionStack = UIStackView()
    private let promptLabel = UILabel()
    private let answerLabel = UILabel()
    private var digitButtons: [UIButton] = []
    private var cardWidth: NSLayoutConstraint!
    private var questionWidth: NSLayoutConstraint!

    init(onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { restTimer?.invalidate() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WarmShelfPalette.raisin.withAlphaComponent(0.42)
        view.accessibilityViewIsModal = true
        buildCard()
        showChallenge()
        let outside = UITapGestureRecognizer(target: self, action: #selector(cancel))
        outside.delegate = self
        view.addGestureRecognizer(outside)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder() // Hardware digits work without opening a system keyboard.
        UIAccessibility.post(notification: .screenChanged, argument: promptLabel)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let available = view.safeAreaLayoutGuide.layoutFrame.size
        let wide = available.width > 600 && available.height < 540
            && !traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let axis: NSLayoutConstraint.Axis = wide ? .horizontal : .vertical
        if bodyStack.axis != axis {
            bodyStack.axis = axis
            bodyStack.alignment = wide ? .center : .fill
            questionWidth.isActive = wide
            cardWidth.constant = wide ? 740 : 420
        }
    }

    private func label(_ text: String, size: CGFloat, style: UIFont.TextStyle, bold: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = WarmShelfPalette.clayInk
        label.font = UIFontMetrics(forTextStyle: style).scaledFont(
            for: .systemFont(ofSize: size, weight: bold ? .semibold : .regular))
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func buildCard() {
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = WarmShelfPalette.cardSurface
        card.layer.cornerRadius = 28
        card.layer.borderWidth = 2
        card.layer.borderColor = WarmShelfPalette.sage.cgColor
        card.layer.shadowColor = WarmShelfPalette.contactShadow.cgColor
        card.layer.shadowOpacity = 0.18
        card.layer.shadowRadius = 24
        card.layer.shadowOffset = CGSize(width: 0, height: 12)
        view.addSubview(card)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = true
        card.addSubview(scroll)

        let eyebrow = label("GROWN-UP CHECK", size: 11, style: .caption1, bold: true)
        let title = label("Enter these numbers\nas digits", size: 22, style: .title2, bold: true)
        promptLabel.font = UIFontMetrics(forTextStyle: .title2).scaledFont(
            for: UIFont(name: "Georgia-Bold", size: 26) ?? .boldSystemFont(ofSize: 26))
        promptLabel.adjustsFontForContentSizeCategory = true
        promptLabel.textColor = WarmShelfPalette.terracotta
        promptLabel.textAlignment = .center
        promptLabel.numberOfLines = 0
        promptLabel.accessibilityIdentifier = "adult-gate-question"
        answerLabel.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: .monospacedDigitSystemFont(ofSize: 28, weight: .medium))
        answerLabel.adjustsFontForContentSizeCategory = true
        answerLabel.textAlignment = .center
        answerLabel.textColor = WarmShelfPalette.clayInk
        answerLabel.backgroundColor = WarmShelfPalette.warmCream
        answerLabel.layer.cornerRadius = 14
        answerLabel.clipsToBounds = true
        answerLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        answerLabel.isAccessibilityElement = true
        answerLabel.accessibilityLabel = "Your answer"
        answerLabel.accessibilityIdentifier = "adult-gate-answer"
        questionStack.axis = .vertical
        questionStack.spacing = 12
        [eyebrow, title, promptLabel, answerLabel].forEach { questionStack.addArrangedSubview($0) }

        let keypad = UIStackView()
        keypad.axis = .vertical
        keypad.spacing = 8
        for values in [[1, 2, 3], [4, 5, 6], [7, 8, 9], [-1, 0, -2]] {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.distribution = .fillEqually
            for value in values {
                if value == -1 { row.addArrangedSubview(UIView()); continue }
                var configuration = UIButton.Configuration.filled()
                configuration.baseBackgroundColor = WarmShelfPalette.sand.withAlphaComponent(0.35)
                configuration.baseForegroundColor = WarmShelfPalette.clayInk
                configuration.cornerStyle = .medium
                configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 6, bottom: 10, trailing: 6)
                if value == -2 { configuration.image = UIImage(systemName: "delete.left") }
                else { configuration.title = String(value) }
                configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var attributes = incoming
                    attributes.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: .systemFont(ofSize: 24, weight: .medium))
                    return attributes
                }
                let key = UIButton(configuration: configuration)
                key.tag = value
                key.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
                key.accessibilityLabel = value == -2 ? "Delete last digit" : String(value)
                key.accessibilityIdentifier = value == -2 ? "adult-gate-delete" : "adult-gate-digit-\(value)"
                key.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
                digitButtons.append(key)
                row.addArrangedSubview(key)
            }
            keypad.addArrangedSubview(row)
        }
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Not now", for: .normal)
        cancelButton.titleLabel?.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 16))
        cancelButton.titleLabel?.adjustsFontForContentSizeCategory = true
        cancelButton.tintColor = WarmShelfPalette.cocoa
        cancelButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        let input = UIStackView(arrangedSubviews: [keypad, cancelButton])
        input.axis = .vertical
        input.spacing = 6
        bodyStack.axis = .vertical
        bodyStack.spacing = 18
        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.addArrangedSubview(questionStack)
        bodyStack.addArrangedSubview(input)
        scroll.addSubview(bodyStack)

        let preferredWidth = card.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -32)
        preferredWidth.priority = UILayoutPriority(998)
        cardWidth = card.widthAnchor.constraint(equalToConstant: 420)
        cardWidth.priority = UILayoutPriority(999)
        questionWidth = questionStack.widthAnchor.constraint(equalTo: bodyStack.widthAnchor, multiplier: 0.46)
        let naturalHeight = scroll.heightAnchor.constraint(equalTo: bodyStack.heightAnchor, constant: 40)
        naturalHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            preferredWidth, cardWidth, naturalHeight,
            card.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, constant: -32),
            card.heightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor, constant: -24),
            scroll.topAnchor.constraint(equalTo: card.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bodyStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            bodyStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            bodyStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            bodyStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            bodyStack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    private var isResting: Bool {
        guard let until = Self.restingUntil else { return false }
        if until > Date() { return true }
        Self.restingUntil = nil
        Self.consecutiveMisses = 0
        return false
    }

    private func showChallenge() {
        restTimer?.invalidate()
        restTimer = nil
        answer = ""
        updateAnswer()
        let resting = isResting
        digitButtons.forEach { $0.isEnabled = !resting }
        promptLabel.text = resting ? "Let's try again\nin a moment" : challenge.prompt
        promptLabel.accessibilityLabel = resting ? "Let's try again in a moment" : challenge.spokenPrompt
        if resting {
            restTimer = Timer.scheduledTimer(withTimeInterval: max(0.5, Self.restingUntil?.timeIntervalSinceNow ?? 0), repeats: false) { [weak self] _ in
                guard let self else { return }
                self.challenge = .random()
                self.showChallenge()
                UIAccessibility.post(notification: .announcement, argument: self.challenge.spokenPrompt)
            }
        }
    }

    private func updateAnswer() {
        let characters = answer.map(String.init)
        answerLabel.text = (characters + Array(repeating: "–", count: max(0, 3 - characters.count))).joined(separator: "  ")
        answerLabel.accessibilityValue = answer.isEmpty ? "No digits entered" : characters.joined(separator: ", ")
    }

    @objc private func keyTapped(_ sender: UIButton) { enter(sender.tag == -2 ? nil : sender.tag) }

    private func enter(_ digit: Int?) {
        guard !isResting else { return }
        if let digit {
            guard answer.count < 3 else { return }
            answer.append(String(digit))
        } else if !answer.isEmpty { answer.removeLast() }
        updateAnswer()
        guard answer.count == 3 else { return }
        if challenge.accepts(answer) {
            Self.consecutiveMisses = 0
            restTimer?.invalidate()
            let completion = onSuccess
            dismiss(animated: true, completion: completion)
        } else {
            if !AmbientAnimator.reduceMotion {
                let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
                shake.values = [-6, 6, -3, 3, 0]
                shake.duration = 0.3
                card.layer.add(shake, forKey: "shake")
            }
            HapticsManager.shared.emptyTap()
            Self.consecutiveMisses += 1
            if Self.consecutiveMisses >= AdultGateChallenge.maxMisses {
                Self.restingUntil = Date().addingTimeInterval(AdultGateChallenge.restDuration)
            }
            challenge = .random()
            showChallenge()
            UIAccessibility.post(notification: .announcement, argument: isResting ? promptLabel.text : "Try these numbers: \(challenge.spokenPrompt)")
        }
    }

    override var canBecomeFirstResponder: Bool { true }
    override var keyCommands: [UIKeyCommand]? {
        (0...9).map { UIKeyCommand(input: String($0), modifierFlags: [], action: #selector(hardwareKey(_:))) }
            + [UIKeyCommand(input: "\u{8}", modifierFlags: [], action: #selector(hardwareKey(_:))),
               UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(cancel))]
    }
    @objc private func hardwareKey(_ key: UIKeyCommand) { enter(key.input.flatMap(Int.init)) }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view?.isDescendant(of: card) ?? false)
    }

    @objc private func cancel() {
        restTimer?.invalidate()
        dismiss(animated: true)
    }

    override var prefersStatusBarHidden: Bool { true }
}

// MARK: - Play timer ("Lull is resting")

/// The play timer's arithmetic, kept free of UIKit so it can be checked off-device.
///
/// One *sitting* is play with less than an hour away. It survives backgrounding, relaunch and
/// force-quit, so swiping Lull away can't reset the count or skip the rest; only a grown-up
/// (waking Lull or changing the timer) or an hour away starts a fresh sitting.
struct LullPlaySitting: Equatable {
    static let freshAfterAway: TimeInterval = 60 * 60

    /// Seconds played in this sitting, not counting the stretch running now.
    var played: TimeInterval = 0
    /// When the stretch running now began; nil while Lull is in the background. Never saved.
    var activeSince: Date?
    /// The last moment play was known to be happening (saved every tick and on pause).
    var lastActive: Date?
    /// The rest veil is up and waiting for a grown-up.
    var resting = false

    func elapsed(at now: Date) -> TimeInterval {
        played + (activeSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    func isDue(limitMinutes: Int, at now: Date) -> Bool {
        limitMinutes > 0 && (resting || elapsed(at: now) >= TimeInterval(limitMinutes * 60))
    }

    /// Lull is in front again. Returns true when an hour or more away made it a fresh sitting.
    /// A clock turned back never counts as time away.
    @discardableResult
    mutating func resume(at now: Date) -> Bool {
        guard activeSince == nil else { return false }
        var fresh = false
        if let lastActive, now.timeIntervalSince(lastActive) >= Self.freshAfterAway {
            played = 0
            resting = false
            fresh = true
        }
        activeSince = now
        lastActive = now
        return fresh
    }

    mutating func pause(at now: Date) {
        checkpoint(at: now)
        activeSince = nil
    }

    /// Fold the running stretch into `played`, so a force-quit loses at most one tick.
    mutating func checkpoint(at now: Date) {
        if let start = activeSince {
            played += max(0, now.timeIntervalSince(start))
            activeSince = now
        }
        lastActive = now
    }

    mutating func startFresh(at now: Date, active: Bool) {
        played = 0
        resting = false
        activeSince = active ? now : nil
        lastActive = now
    }
}

/// Counts gentle foreground play time. When the parent-set limit elapses, Lull doesn't buzz or
/// slam anything shut — the room simply gets sleepy: a calm moon veil settles over the screen
/// and a grown-up wakes the app back up through the gate. The sitting is saved as play goes,
/// so the rest comes back after a relaunch until a grown-up wakes Lull or an hour has passed.
final class LullPlayTimer {
    static let shared = LullPlayTimer()

    private enum Key {
        static let played = "lull.timer.played"
        static let lastActive = "lull.timer.lastActive"
        static let resting = "lull.timer.resting"
    }

    private let defaults = UserDefaults.standard
    private var sitting = LullPlaySitting()
    private var ticker: Timer?
    private weak var restController: LullRestViewController?
    private var retryScheduled = false

    private init() {
        sitting.played = defaults.double(forKey: Key.played)
        let last = defaults.double(forKey: Key.lastActive)
        sitting.lastActive = last > 0 ? Date(timeIntervalSinceReferenceDate: last) : nil
        sitting.resting = defaults.bool(forKey: Key.resting)
        NotificationCenter.default.addObserver(self, selector: #selector(resume), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pause), name: UIApplication.willResignActiveNotification, object: nil)
    }

    /// Minutes played in this sitting (for the grown-up area).
    var minutesPlayed: Int { Int(sitting.elapsed(at: Date()) / 60) }

    /// Called once from the shelf so the singleton starts observing/ticking.
    func activate() {
        resume()
        guard ticker == nil else { return }
        ticker = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.sitting.checkpoint(at: Date())
            self.save()
            self.checkLimit()
        }
        // A rest that was showing when Lull was swiped away comes straight back.
        scheduleRetry(after: 0.8)
    }

    func settingsChanged() {
        // A new limit starts a fresh, fair sitting.
        sitting.startFresh(at: Date(), active: sitting.activeSince != nil)
        save()
    }

    func parentWoke() {
        settingsChanged()
    }

    @objc private func resume() {
        if sitting.resume(at: Date()), let rest = restController {
            // An hour or more away: a fresh sitting, so the veil lifts by itself.
            rest.wakeWithoutGrownUp()
        }
        save()
        scheduleRetry(after: 0.8)
    }

    @objc private func pause() {
        sitting.pause(at: Date())
        save()
    }

    private func save() {
        defaults.set(sitting.played, forKey: Key.played)
        defaults.set(sitting.lastActive?.timeIntervalSinceReferenceDate ?? 0, forKey: Key.lastActive)
        defaults.set(sitting.resting, forKey: Key.resting)
    }

    private func scheduleRetry(after delay: TimeInterval) {
        guard !retryScheduled else { return }
        retryScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.retryScheduled = false
            self?.checkLimit()
        }
    }

    private func checkLimit() {
        let minutes = LullDemoState.shared.playTimerMinutes
        guard restController == nil, LullDemoState.shared.hasCompletedOnboarding,
              sitting.isDue(limitMinutes: minutes, at: Date()) else { return }
        // Parent setup, the grown-up check, and purchases stay usable when the deadline
        // arrives. Try again shortly once a child play screen is visible again.
        guard UIApplication.shared.applicationState == .active,
              let top = LullPlayTimer.topmostViewController(),
              top is ToyViewController || top is ToyShelfViewController,
              !top.isBeingPresented, !top.isBeingDismissed,
              top.transitionCoordinator == nil,
              top.viewIfLoaded?.window != nil,
              let suspension = LullRestPlaybackSuspension(presenter: top) else {
            scheduleRetry(after: 1)
            return
        }
        sitting.resting = true
        save()
        let rest = LullRestViewController()
        rest.onWake = { suspension.resume() }
        rest.modalPresentationStyle = .overFullScreen
        rest.modalTransitionStyle = .crossDissolve
        restController = rest
        top.present(rest, animated: true)
    }

    static func topmostViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

/// The rest veil: a deep, calm night with a big soft moon. "Lull is resting." Tapping anywhere
/// asks the grown-up question; a right answer wakes the toybox with a fresh timer.
final class LullRestViewController: UIViewController {
    var onWake: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.10, green: 0.11, blue: 0.21, alpha: 1)

        let moon = UIView()
        moon.translatesAutoresizingMaskIntoConstraints = false
        moon.backgroundColor = UIColor(red: 0.95, green: 0.93, blue: 0.84, alpha: 1)
        moon.layer.cornerRadius = 64
        moon.layer.shadowColor = UIColor(red: 0.85, green: 0.88, blue: 1.0, alpha: 1).cgColor
        moon.layer.shadowOpacity = 0.55
        moon.layer.shadowRadius = 48
        moon.layer.shadowOffset = .zero
        view.addSubview(moon)

        for (dx, dy, r) in [(-22, 10, 13), (18, -16, 9), (8, 26, 7)] {
            let crater = UIView()
            crater.translatesAutoresizingMaskIntoConstraints = false
            crater.backgroundColor = UIColor(red: 0.88, green: 0.85, blue: 0.74, alpha: 1)
            crater.layer.cornerRadius = CGFloat(r)
            moon.addSubview(crater)
            NSLayoutConstraint.activate([
                crater.centerXAnchor.constraint(equalTo: moon.centerXAnchor, constant: CGFloat(dx)),
                crater.centerYAnchor.constraint(equalTo: moon.centerYAnchor, constant: CGFloat(dy)),
                crater.widthAnchor.constraint(equalToConstant: CGFloat(r * 2)),
                crater.heightAnchor.constraint(equalToConstant: CGFloat(r * 2))
            ])
        }

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Lull is resting"
        title.font = UIFont(name: "Georgia", size: 30) ?? .systemFont(ofSize: 30, weight: .semibold)
        title.textColor = UIColor(red: 0.96, green: 0.94, blue: 0.86, alpha: 1)
        title.textAlignment = .center
        view.addSubview(title)

        let subtitle = UILabel()
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.text = "A grown-up can wake it"
        subtitle.font = .systemFont(ofSize: 15, weight: .medium)
        subtitle.textColor = UIColor(red: 0.96, green: 0.94, blue: 0.86, alpha: 0.55)
        subtitle.textAlignment = .center
        view.addSubview(subtitle)

        NSLayoutConstraint.activate([
            moon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            moon.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            moon.widthAnchor.constraint(equalToConstant: 128),
            moon.heightAnchor.constraint(equalToConstant: 128),
            title.topAnchor.constraint(equalTo: moon.bottomAnchor, constant: 34),
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            subtitle.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        // A slow, sleepy breath on the moon.
        UIView.animate(withDuration: 2.6, delay: 0, options: [.autoreverse, .repeat, .curveEaseInOut]) {
            moon.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }

        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(askGrownUp)))
    }

    /// An hour away made a fresh sitting: lift the veil without the grown-up check.
    func wakeWithoutGrownUp() {
        let onWake = self.onWake
        self.onWake = nil
        dismiss(animated: true, completion: onWake)
    }

    @objc private func askGrownUp() {
        guard presentedViewController == nil else { return }
        AdultGate.present(from: self) { [weak self] in
            guard let self else { return }
            let onWake = self.onWake
            self.onWake = nil
            LullPlayTimer.shared.parentWoke()
            self.dismiss(animated: true, completion: onWake)
        }
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}
