import SpriteKit
import UIKit

final class ToyViewController: UIViewController {
    private let descriptor: ToyDescriptor
    private var hasPresentedToyScene = false
    private weak var currentScene: BaseToyScene?
    private let zoomTransition = ToyZoomTransition(presenting: true)

    init(descriptor: ToyDescriptor) {
        self.descriptor = descriptor
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        transitioningDelegate = zoomTransition  // gentle push-in, not a flat cut
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let skView = SKView()
        skView.ignoresSiblingOrder = true
        skView.shouldCullNonVisibleNodes = true
        skView.preferredFramesPerSecond = 120  // ProMotion; auto-caps to 60 elsewhere
        skView.backgroundColor = WarmShelfPalette.linen
        view = skView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        installParentAreaGesture()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        presentToySceneIfReady()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (view as? SKView)?.isPaused = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop any sustained toy audio (e.g. the Window's looping day/night bed). We pause
        // the SKView on dismiss instead of presenting nil, so the scene's willMove isn't
        // reliably delivered — and AVAudioPlayer loops keep going regardless of isPaused.
        ((view as? SKView)?.scene as? BaseToyScene)?.teardownToyAudio()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        (view as? SKView)?.isPaused = true
    }

    private func presentToySceneIfReady() {
        guard !hasPresentedToyScene, let skView = view as? SKView else { return }
        guard skView.bounds.width > 20, skView.bounds.height > 20 else { return }

        hasPresentedToyScene = true
        let scene = descriptor.makeScene(skView.bounds.size)
        scene.showsShelfReturnHandle = true
        scene.onReturnToShelf = { [weak self] in
            AudioManager.shared.playShelfTransition()
            self?.dismiss(animated: true)
        }
        scene.scaleMode = .resizeFill
        currentScene = scene
        skView.presentScene(
            scene,
            transition: .fade(with: WarmShelfPalette.linen, duration: WarmShelfMotion.shelfTransition)
        )
        configureAccessibility(for: scene, in: skView)
    }
    private func configureAccessibility(for scene: BaseToyScene, in skView: SKView) {
        skView.isAccessibilityElement = false
        skView.accessibilityLabel = descriptor.parentName
        skView.accessibilityHint = nil
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
        recognizer.delaysTouchesEnded = false   // default true HOLDS touchesEnded while this 2-finger
                                                // press is .possible — i.e. whenever a toddler's second
                                                // finger lands. That delay = lost releases = stuck notes.
        view.addGestureRecognizer(recognizer)
    }

    @objc private func openParentArea(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, presentedViewController == nil else { return }
        AdultGate.present(from: self) { [weak self] in
            guard let self, self.presentedViewController == nil else { return }
            let parentInfo = ParentInfoViewController()
            parentInfo.modalPresentationStyle = .formSheet
            self.present(parentInfo, animated: true)
        }
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
}
