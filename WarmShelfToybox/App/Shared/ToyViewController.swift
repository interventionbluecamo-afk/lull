import SpriteKit
import UIKit

/// Keep the real fingers that SpriteKit received so a covering rest screen can cancel
/// their ownership before pausing. No release is interpreted as a completed play action.
final class ToyPlayView: SKView {
    private var activeTouches = Set<UITouch>()

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.formUnion(touches)
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        super.touchesCancelled(touches, with: event)
    }

    func cancelActiveSceneTouches() {
        let cancelled = activeTouches
        activeTouches.removeAll()
        if !cancelled.isEmpty { scene?.touchesCancelled(cancelled, with: nil) }
    }
}

/// Owns the exact pre-rest state of a playable SpriteKit view. An over-full-screen
/// modal cannot rely on UIViewController disappearance callbacks to stop the toy.
final class LullRestPlaybackSuspension {
    private weak var skView: SKView?
    private weak var scene: BaseToyScene?
    private let wasPaused: Bool
    private let wasInteractive: Bool
    private var recognizers: [(UIGestureRecognizer, Bool)]
    private var hasResumed = false

    init?(presenter: UIViewController) {
        guard let skView = presenter.viewIfLoaded as? SKView,
              let scene = skView.scene as? BaseToyScene else { return nil }
        self.skView = skView
        self.scene = scene
        wasPaused = skView.isPaused
        wasInteractive = skView.isUserInteractionEnabled
        recognizers = (skView.gestureRecognizers ?? []).map { ($0, $0.isEnabled) }

        // Let toys settle their held objects immediately before generic cancellation
        // drains touch ownership or schedules a return animation in their cancel path.
        scene.suspendToyForRest()
        (skView as? ToyPlayView)?.cancelActiveSceneTouches()
        skView.isUserInteractionEnabled = false
        recognizers.forEach { $0.0.isEnabled = false }
        skView.isPaused = true
    }

    func resume() {
        guard !hasResumed else { return }
        hasResumed = true
        guard let skView else { return }
        if let scene, skView.scene === scene { scene.resumeToyAfterRest() }
        skView.isPaused = wasPaused
        recognizers.forEach { $0.0.isEnabled = $0.1 }
        recognizers.removeAll()
        skView.isUserInteractionEnabled = wasInteractive
    }
}

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
        let skView = ToyPlayView()
        skView.isMultipleTouchEnabled = true
        skView.ignoresSiblingOrder = true
        skView.shouldCullNonVisibleNodes = true
        skView.preferredFramesPerSecond = 120  // ProMotion; auto-caps to 60 elsewhere
        skView.backgroundColor = WarmShelfPalette.linen
        view = skView
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        presentToySceneIfReady()
        refreshSceneNavigationAndAccessibility()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        refreshSceneNavigationAndAccessibility()
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
            self?.dismiss(animated: true)   // silent: the press was already felt
        }
        scene.scaleMode = .resizeFill
        currentScene = scene
        skView.presentScene(
            scene,
            transition: .fade(with: WarmShelfPalette.linen, duration: WarmShelfMotion.shelfTransition)
        )
        configureAccessibility(for: scene, in: skView)
    }

    private func refreshSceneNavigationAndAccessibility() {
        guard let skView = view as? SKView, let scene = currentScene else { return }
        scene.refreshSharedNavigationLayout()
        configureAccessibility(for: scene, in: skView)
    }

    private func configureAccessibility(for scene: BaseToyScene, in skView: SKView) {
        skView.isAccessibilityElement = false
        skView.accessibilityLabel = descriptor.parentName
        skView.accessibilityHint = nil
        skView.accessibilityElements = scene.accessibilityElements(in: skView)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self, weak skView, weak scene] in
            guard let self, let skView, let scene, scene === self.currentScene else { return }
            scene.refreshSharedNavigationLayout()
            skView.accessibilityElements = scene.accessibilityElements(in: skView)
        }
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
}
