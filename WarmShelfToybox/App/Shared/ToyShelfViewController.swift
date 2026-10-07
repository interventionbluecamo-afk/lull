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
        LullPlayTimer.shared.activate()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessDidChange),
            name: .lullAccessDidChange,
            object: nil
        )
    }

    /// A quiet 8pt dot on the parent chip — meaningless to a child, unmissable to the adult
    /// who already knows the chip. Appears on the trial's last day and just after it ends;
    /// rests once the grown-up room has been visited.
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

        let launchScene = WarmShelfLaunchScene(size: skView.bounds.size)
        launchScene.onComplete = { [weak self, weak skView] in
            guard let self, let skView else { return }
            self.presentShelfScene(in: skView, animated: true)
        }
        skView.presentScene(launchScene)
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
        skView.accessibilityElements = scene.accessibilityElements(in: skView)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self, weak skView, weak scene] in
            guard let self, let skView, let scene, scene === self.currentScene else { return }
            skView.accessibilityElements = scene.accessibilityElements(in: skView)
        }
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
        guard let skView = view as? SKView, hasPresentedInitialScene else { return }
        presentShelfScene(in: skView, animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
}
