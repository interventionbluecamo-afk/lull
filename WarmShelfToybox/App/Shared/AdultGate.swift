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

final class AdultGateViewController: UIViewController {
    private let onSuccess: () -> Void
    private let left = Int.random(in: 4...9)
    private let right = Int.random(in: 5...9)
    private var answer: Int { left + right }

    private let card = UIView()
    private let field = UITextField()
    private let promptLabel = UILabel()

    init(onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WarmShelfPalette.raisin.withAlphaComponent(0.42)
        buildCard()

        let tapOutside = UITapGestureRecognizer(target: self, action: #selector(cancel))
        tapOutside.cancelsTouchesInView = false
        view.addGestureRecognizer(tapOutside)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        card.alpha = 0
        UIView.animate(withDuration: 0.26, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: []) {
            self.card.transform = .identity
            self.card.alpha = 1
        }
        field.becomeFirstResponder()
    }

    private func buildCard() {
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = WarmShelfPalette.cardSurface
        card.layer.cornerRadius = 28
        card.layer.borderWidth = 3
        card.layer.borderColor = WarmShelfPalette.sage.withAlphaComponent(0.85).cgColor
        card.layer.shadowColor = WarmShelfPalette.contactShadow.cgColor
        card.layer.shadowOpacity = 0.18
        card.layer.shadowRadius = 24
        card.layer.shadowOffset = CGSize(width: 0, height: 12)
        // Block taps on the card from reaching the dismiss gesture.
        card.addGestureRecognizer(UITapGestureRecognizer(target: nil, action: nil))
        view.addSubview(card)

        let eyebrow = UILabel()
        eyebrow.text = "GROWN-UP CHECK"
        eyebrow.font = .systemFont(ofSize: 11, weight: .heavy)
        eyebrow.textColor = WarmShelfPalette.cocoa.withAlphaComponent(0.6)
        eyebrow.textAlignment = .center

        let title = UILabel()
        title.text = "A quick question\nfor a grown-up"
        title.numberOfLines = 0
        title.textAlignment = .center
        title.font = UIFont(name: "Georgia", size: 26) ?? .systemFont(ofSize: 26, weight: .semibold)
        title.textColor = WarmShelfPalette.clayInk

        promptLabel.text = "\(left)  +  \(right)  =  ?"
        promptLabel.textAlignment = .center
        promptLabel.font = UIFont(name: "Georgia-Bold", size: 34) ?? .systemFont(ofSize: 34, weight: .bold)
        promptLabel.textColor = WarmShelfPalette.terracotta

        field.translatesAutoresizingMaskIntoConstraints = false
        field.keyboardType = .numberPad
        field.textAlignment = .center
        field.font = UIFont(name: "Georgia-Bold", size: 28) ?? .systemFont(ofSize: 28, weight: .bold)
        field.textColor = WarmShelfPalette.clayInk
        field.backgroundColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.6)
        field.layer.cornerRadius = 16
        field.layer.borderWidth = 1
        field.layer.borderColor = WarmShelfPalette.softLine.withAlphaComponent(0.5).cgColor
        field.heightAnchor.constraint(equalToConstant: 60).isActive = true
        field.addTarget(self, action: #selector(answerChanged), for: .editingChanged)

        let continueButton = UIButton(type: .system)
        continueButton.setTitle("Continue", for: .normal)
        continueButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        continueButton.tintColor = WarmShelfPalette.paperHighlight
        continueButton.backgroundColor = WarmShelfPalette.clayInk
        continueButton.layer.cornerRadius = 18
        continueButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        continueButton.addTarget(self, action: #selector(submit), for: .touchUpInside)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Not now", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        cancelButton.tintColor = WarmShelfPalette.cocoa.withAlphaComponent(0.8)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [eyebrow, title, promptLabel, field, continueButton, cancelButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(20, after: promptLabel)
        stack.setCustomSpacing(18, after: field)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 28),
            card.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -28),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 26),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22)
        ])
    }

    @objc private func answerChanged() {
        // Auto-submit when the right answer is typed.
        if field.text == "\(answer)" { submit() }
    }

    @objc private func submit() {
        guard field.text?.trimmingCharacters(in: .whitespaces) == "\(answer)" else {
            rejectShake()
            return
        }
        view.endEditing(true)
        dismiss(animated: true) { [weak self] in self?.onSuccess() }
    }

    private func rejectShake() {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [-10, 10, -8, 8, -4, 4, 0]
        shake.duration = 0.4
        card.layer.add(shake, forKey: "shake")
        field.text = ""
        HapticsManager.shared.emptyTap()
    }

    @objc private func cancel() {
        view.endEditing(true)
        dismiss(animated: true)
    }

    override var prefersStatusBarHidden: Bool { true }
}

// MARK: - Play timer ("Lull is resting")

/// Counts gentle foreground play time. When the parent-set limit elapses, Lull doesn't buzz or
/// slam anything shut — the room simply gets sleepy: a calm moon veil settles over the screen
/// and a grown-up wakes the app back up through the gate.
final class LullPlayTimer {
    static let shared = LullPlayTimer()

    private var accumulated: TimeInterval = 0
    private var lastResume: Date?
    private var ticker: Timer?
    private var restPresented = false

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(resume), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pause), name: UIApplication.willResignActiveNotification, object: nil)
    }

    /// Called once from the shelf so the singleton starts observing/ticking.
    func activate() {
        resume()
        guard ticker == nil else { return }
        ticker = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.checkLimit()
        }
    }

    func settingsChanged() {
        // A new limit starts a fresh, fair window.
        accumulated = 0
        lastResume = Date()
        restPresented = false
    }

    func parentWoke() {
        settingsChanged()
    }

    @objc private func resume() {
        if lastResume == nil { lastResume = Date() }
    }

    @objc private func pause() {
        if let start = lastResume { accumulated += Date().timeIntervalSince(start) }
        lastResume = nil
    }

    private var elapsed: TimeInterval {
        accumulated + (lastResume.map { Date().timeIntervalSince($0) } ?? 0)
    }

    private func checkLimit() {
        let minutes = LullDemoState.shared.playTimerMinutes
        guard minutes > 0, !restPresented, LullDemoState.shared.hasCompletedOnboarding else { return }
        guard elapsed >= TimeInterval(minutes * 60) else { return }
        guard let top = LullPlayTimer.topmostViewController(), !(top is LullRestViewController) else { return }
        restPresented = true
        let rest = LullRestViewController()
        rest.modalPresentationStyle = .overFullScreen
        rest.modalTransitionStyle = .crossDissolve
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

    @objc private func askGrownUp() {
        guard presentedViewController == nil else { return }
        AdultGate.present(from: self) { [weak self] in
            LullPlayTimer.shared.parentWoke()
            self?.dismiss(animated: true)
        }
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}
