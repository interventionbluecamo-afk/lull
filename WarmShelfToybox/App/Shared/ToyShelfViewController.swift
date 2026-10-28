import SpriteKit
import UIKit

final class ToyShelfViewController: UIViewController {
    private var hasPresentedInitialScene = false
    #if DEBUG
    private var hasPresentedDebugToy = false
    #endif
    private weak var currentScene: ToyShelfScene?
    private var builtToyIDs: [String] = []

    override func loadView() {
        let skView = ToyPlayView()
        skView.ignoresSiblingOrder = true
        skView.shouldCullNonVisibleNodes = true
        skView.preferredFramesPerSecond = 120  // ProMotion; auto-caps to 60 elsewhere
        skView.backgroundColor = WarmShelfPalette.linen
        view = skView
    }

    private let parentButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        installParentAreaGesture()
        installParentButton()
        refreshRestingCard()
        LullPlayTimer.shared.activate()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessDidChange),
            name: .lullAccessDidChange,
            object: nil
        )
    }

    /// A quiet 8pt dot on the parent chip — meaningless to a child, unmissable to the adult
    /// who already knows the chip. Appears on the App Store free week's last day and just
    /// after a Lull Family plan ends; rests once the grown-up room has been visited.
    private let parentAttentionDot = UIView()

    private func refreshParentAttentionDot() {
        parentAttentionDot.isHidden = !LullDemoState.shared.parentAttentionWanted
    }

    private func installParentButton() {
        parentButton.translatesAutoresizingMaskIntoConstraints = false
        parentButton.backgroundColor = WarmShelfPalette.sand.withAlphaComponent(0.30)
        parentButton.tintColor = WarmShelfPalette.cocoa.withAlphaComponent(0.5)
        parentButton.layer.cornerRadius = 22
        parentButton.alpha = 0.7
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        parentButton.setImage(UIImage(systemName: "person.fill", withConfiguration: config), for: .normal)
        parentButton.accessibilityLabel = "Grown-up area"
        parentButton.addTarget(self, action: #selector(parentButtonTapped), for: .touchUpInside)
        view.addSubview(parentButton)
        NSLayoutConstraint.activate([
            parentButton.widthAnchor.constraint(equalToConstant: 44),
            parentButton.heightAnchor.constraint(equalToConstant: 44),
            parentButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -14),
            parentButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14)
        ])

        parentAttentionDot.translatesAutoresizingMaskIntoConstraints = false
        parentAttentionDot.backgroundColor = WarmShelfPalette.terracotta.withAlphaComponent(0.9)
        parentAttentionDot.layer.cornerRadius = 4
        parentAttentionDot.isUserInteractionEnabled = false
        parentButton.addSubview(parentAttentionDot)
        NSLayoutConstraint.activate([
            parentAttentionDot.widthAnchor.constraint(equalToConstant: 8),
            parentAttentionDot.heightAnchor.constraint(equalToConstant: 8),
            parentAttentionDot.topAnchor.constraint(equalTo: parentButton.topAnchor, constant: 5),
            parentAttentionDot.trailingAnchor.constraint(equalTo: parentButton.trailingAnchor, constant: -5)
        ])
        refreshParentAttentionDot()
    }

    @objc private func parentButtonTapped() {
        presentParentArea()
    }

    // MARK: - The resting shelf

    /// Before a grown-up opens the toybox (the free week, the plan, or Keep Forever), and after
    /// a plan ends, the shelf rests: the room, Wren, two plain lines and a button for a grown-up.
    /// Never a price or a lock on the child's side; the offer lives behind the grown-up check.
    private var restingCard: UIView?

    private func refreshRestingCard() {
        guard !LullDemoState.shared.hasFullToybox else {
            restingCard?.removeFromSuperview()
            restingCard = nil
            return
        }
        guard restingCard == nil else { return }
        let card = makeRestingCard()
        view.insertSubview(card, belowSubview: parentButton)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            card.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28)
        ])
        let fill = card.widthAnchor.constraint(equalToConstant: 400)
        fill.priority = .defaultHigh
        fill.isActive = true
        restingCard = card
        if !(UIAccessibility.isReduceMotionEnabled || LullDemoState.shared.isReducedMotion) {
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 14)
            UIView.animate(withDuration: 0.5, delay: 0.35, options: [.curveEaseOut]) {
                card.alpha = 1
                card.transform = .identity
            }
        }
    }

    private func makeRestingCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.accessibilityIdentifier = "shelf-resting"
        card.backgroundColor = WarmShelfPalette.paperHighlight.withAlphaComponent(0.94)
        card.layer.cornerRadius = 28
        card.layer.borderWidth = 1
        card.layer.borderColor = WarmShelfPalette.softLine.withAlphaComponent(0.5).cgColor
        card.layer.shadowColor = WarmShelfPalette.contactShadow.cgColor
        card.layer.shadowOpacity = 0.16
        card.layer.shadowRadius = 22
        card.layer.shadowOffset = CGSize(width: 0, height: 12)

        let mark = LullHostMarkView(side: 84)
        let markHolder = UIView()
        markHolder.addSubview(mark)
        NSLayoutConstraint.activate([
            mark.topAnchor.constraint(equalTo: markHolder.topAnchor),
            mark.bottomAnchor.constraint(equalTo: markHolder.bottomAnchor),
            mark.centerXAnchor.constraint(equalTo: markHolder.centerXAnchor)
        ])

        let title = UILabel()
        title.text = "Nine toys are waiting"
        title.font = UIFontMetrics(forTextStyle: .title1).scaledFont(for: UIFont(name: "Georgia", size: 26) ?? .systemFont(ofSize: 26, weight: .semibold))
        title.adjustsFontForContentSizeCategory = true
        title.textColor = WarmShelfPalette.clayInk
        title.textAlignment = .center
        title.numberOfLines = 0
        title.accessibilityTraits = .header

        let words = UILabel()
        words.text = "A grown-up can open the toybox."
        words.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 16))
        words.adjustsFontForContentSizeCategory = true
        words.textColor = WarmShelfPalette.cocoa
        words.textAlignment = .center
        words.numberOfLines = 0

        var config = UIButton.Configuration.filled()
        config.title = "I'm a grown-up"
        config.image = UIImage(systemName: "person.fill",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
        config.imagePadding = 8
        config.baseBackgroundColor = WarmShelfPalette.terracotta
        config.baseForegroundColor = WarmShelfPalette.paperHighlight
        config.background.cornerRadius = 18
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .bold))
            return outgoing
        }
        let button = UIButton(configuration: config)
        button.accessibilityIdentifier = "shelf-resting-grown-up"
        button.accessibilityHint = "Asks the grown-up check, then shows how to open the toybox."
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        button.addTarget(self, action: #selector(openToyboxForGrownUp), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [markHolder, title, words, button])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(16, after: markHolder)
        stack.setCustomSpacing(20, after: words)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 26),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24)
        ])
        return card
    }

    /// The grown-up check, then the Full Toybox page with the one offer.
    @objc private func openToyboxForGrownUp() {
        guard presentedViewController == nil else { return }
        AdultGate.present(from: self) { [weak self] in
            guard let self, self.presentedViewController == nil else { return }
            let plans = LullPlansViewController()
            plans.modalPresentationStyle = .pageSheet
            self.present(plans, animated: true)
        }
    }

    private func presentParentArea() {
        guard presentedViewController == nil else { return }
        AdultGate.present(from: self) { [weak self] in
            guard let self, self.presentedViewController == nil else { return }
            let parentInfo = ParentInfoViewController()
            parentInfo.modalPresentationStyle = .formSheet
            self.present(parentInfo, animated: true)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        presentInitialSceneIfReady()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (view as? SKView)?.isPaused = false
        refreshParentAttentionDot()
        // If the free trial elapsed while the child was inside a toy, the shelf's toy set has
        // changed underneath us — quietly rebuild so it matches the current access.
        if hasPresentedInitialScene,
           let skView = view as? SKView,
           ToyRegistry.childShelfToys.map(\.id) != builtToyIDs {
            presentShelfScene(in: skView, animated: true)
            return
        }
        currentScene?.prepareForShelfInteraction()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        (view as? SKView)?.isPaused = true
    }

    private func presentInitialSceneIfReady() {
        guard let skView = view as? SKView else { return }
        guard !hasPresentedInitialScene, skView.bounds.width > 20, skView.bounds.height > 20 else { return }
        hasPresentedInitialScene = true

        // No separate loading animation (founder, build 7: "I hate the loading screen"). The
        // launch screen is the shelf's own room, so the shelf continues the same picture and its
        // toys rise onto the shelf: no flash, no wait, and play starts about two seconds sooner.
        presentShelfScene(in: skView, animated: false)
    }

    private func presentShelfScene(in skView: SKView, animated: Bool) {
        let scene = ToyShelfScene(size: skView.bounds.size)
        builtToyIDs = ToyRegistry.childShelfToys.map(\.id)
        scene.onToySelected = { [weak self] toyID in
            guard let descriptor = ToyRegistry.toy(id: toyID) else { return }
            self?.present(ToyViewController(descriptor: descriptor), animated: true)
        }
        currentScene = scene
        if animated {
            skView.presentScene(scene, transition: .fade(with: WarmShelfPalette.linen, duration: 0.38))
        } else {
            skView.presentScene(scene)
        }
        configureAccessibility(for: scene, in: skView)
        presentDebugToyIfRequested()
        #if DEBUG
        if ProcessInfo.processInfo.environment["LULL_DEBUG_GATE"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in self?.presentParentArea() }
        }
        if ProcessInfo.processInfo.environment["LULL_DEBUG_PARENT"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                guard let self, self.presentedViewController == nil else { return }
                let parentInfo = ParentInfoViewController()
                parentInfo.modalPresentationStyle = .formSheet
                self.present(parentInfo, animated: true)
            }
        }
        #endif
    }

    private func presentDebugToyIfRequested() {
        #if DEBUG
        guard !hasPresentedDebugToy else { return }
        guard let toyID = ProcessInfo.processInfo.environment["LULL_DEBUG_OPEN_TOY"] else { return }
        guard let descriptor = ToyRegistry.toy(id: toyID) else { return }
        hasPresentedDebugToy = true

        // Retry until the launch→shelf transition has settled — otherwise the open is
        // silently dropped while a transition is in flight (QA capture reliability).
        func attempt(_ tries: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self else { return }
                guard self.presentedViewController == nil, self.viewIfLoaded?.window != nil else {
                    if tries > 0 { attempt(tries - 1) }
                    return
                }
                self.present(ToyViewController(descriptor: descriptor), animated: true)
            }
        }
        attempt(8)
        #endif
    }

    private func configureAccessibility(for scene: ToyShelfScene, in skView: SKView) {
        skView.isAccessibilityElement = false
        skView.accessibilityLabel = "Lull toy shelf"
        skView.accessibilityElements = accessibleElements(for: scene, in: skView)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self, weak skView, weak scene] in
            guard let self, let skView, let scene, scene === self.currentScene else { return }
            skView.accessibilityElements = self.accessibleElements(for: scene, in: skView)
        }
    }

    /// The toys, then the resting card (when the toybox is closed) and the grown-up chip, so
    /// VoiceOver never finds a dead end.
    private func accessibleElements(for scene: ToyShelfScene, in skView: SKView) -> [Any] {
        var elements: [Any] = scene.accessibilityElements(in: skView)
        if let restingCard { elements.append(restingCard) }
        elements.append(parentButton)
        return elements
    }

    private func installParentAreaGesture() {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(openParentArea(_:)))
        recognizer.minimumPressDuration = 1.4
        recognizer.numberOfTouchesRequired = 2
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false   // never hold the scene's touch releases hostage (see ToyViewController)
        view.addGestureRecognizer(recognizer)
    }

    @objc private func openParentArea(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        presentParentArea()
    }

    @objc private func accessDidChange() {
        refreshParentAttentionDot()
        refreshRestingCard()
        if let skView = view as? SKView, let scene = currentScene {
            skView.accessibilityElements = accessibleElements(for: scene, in: skView)
        }
        guard let skView = view as? SKView, hasPresentedInitialScene else { return }
        presentShelfScene(in: skView, animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    // An intentional second edge swipe still leaves the app. Guided Access is the full lock.
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { [.top, .bottom] }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
}
