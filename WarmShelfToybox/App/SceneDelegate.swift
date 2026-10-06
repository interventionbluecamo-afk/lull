import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = WarmShelfPalette.linen
        self.window = window
        installRestartObserver()
        window.rootViewController = makeInitialRootViewController()
        window.makeKeyAndVisible()
        refreshPurchaseEntitlements()
    }

    private func makeInitialRootViewController() -> UIViewController {
        #if DEBUG
        // Jump straight into one toy for screenshot/visual review: LULL_DEBUG_TOY=glowboard|host|…
        if let toyID = ProcessInfo.processInfo.environment["LULL_DEBUG_TOY"] {
            if toyID == "host" { return HostPreviewViewController() }
            if toyID == "parent" { return ParentInfoViewController() }   // the grown-up room, gate skipped
            if let descriptor = ToyRegistry.toy(id: toyID) {
                return ToyViewController(descriptor: descriptor)
            }
        }
        // LULL_DEBUG_FORCE_ONBOARDING=1 shows the welcome regardless of stored state
        // (sim cfprefsd caches resurrect old prefs across reinstalls — QA/store shots).
        if ProcessInfo.processInfo.environment["LULL_DEBUG_FORCE_ONBOARDING"] == "1" {
            let onboarding = LullOnboardingViewController()
            onboarding.onComplete = { [weak self] in self?.showShelf(animated: true) }
            return onboarding
        }
        #endif

        if LullDemoState.shared.hasCompletedOnboarding {
            return ToyShelfViewController()
        }

        let onboarding = LullOnboardingViewController()
        onboarding.onComplete = { [weak self] in
            self?.showShelf(animated: true)
        }
        return onboarding
    }

    private func showShelf(animated: Bool) {
        guard let window else { return }
        let shelf = ToyShelfViewController()
        guard animated else {
            window.rootViewController = shelf
            return
        }

        UIView.transition(
            with: window,
            duration: 0.42,
            options: [.transitionCrossDissolve, .allowAnimatedContent],
            animations: {
                window.rootViewController = shelf
            }
        )
    }

    private func installRestartObserver() {
        NotificationCenter.default.addObserver(
            forName: .lullAppDidRequestRestart,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let window = self.window else { return }
            let onboarding = LullOnboardingViewController()
            onboarding.onComplete = { [weak self] in self?.showShelf(animated: true) }
            UIView.transition(
                with: window,
                duration: 0.35,
                options: [.transitionCrossDissolve, .allowAnimatedContent],
                animations: {
                    window.rootViewController = onboarding
                }
            )
        }
    }

    private func refreshPurchaseEntitlements() {
        Task { @MainActor in
            await LullPurchaseManager.shared.refreshEntitlements()
        }
    }
}
