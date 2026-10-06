import UIKit

/// A gentle "push-in" transition: opening a toy grows the world up into view (instead of
/// a flat modal cut), and closing it eases back down. Calm easing, no bounce — premium
/// without being flashy.
final class ToyZoomTransition: NSObject, UIViewControllerAnimatedTransitioning, UIViewControllerTransitioningDelegate {
    private let presenting: Bool

    init(presenting: Bool) {
        self.presenting = presenting
        super.init()
    }

    // MARK: Transitioning delegate

    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        ToyZoomTransition(presenting: true)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        ToyZoomTransition(presenting: false)
    }

    // MARK: Animator

    func transitionDuration(using context: UIViewControllerContextTransitioning?) -> TimeInterval {
        if AmbientAnimator.reduceMotion { return 0.20 }
        return presenting ? 0.36 : 0.28
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        let container = context.containerView

        if presenting {
            guard let toView = context.view(forKey: .to) else { context.completeTransition(false); return }
            container.addSubview(toView)
            toView.frame = context.finalFrame(for: context.viewController(forKey: .to)!)
            toView.transform = AmbientAnimator.reduceMotion
                ? .identity
                : CGAffineTransform(scaleX: 0.94, y: 0.94)
            toView.alpha = 0
            let duration = transitionDuration(using: context)
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
            ) {
                toView.transform = .identity
                toView.alpha = 1
            } completion: { _ in
                context.completeTransition(!context.transitionWasCancelled)
            }
        } else {
            guard let fromView = context.view(forKey: .from) else { context.completeTransition(false); return }
            let duration = transitionDuration(using: context)
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction]
            ) {
                fromView.transform = AmbientAnimator.reduceMotion
                    ? .identity
                    : CGAffineTransform(scaleX: 0.96, y: 0.96)
                fromView.alpha = 0
            } completion: { _ in
                fromView.transform = .identity
                context.completeTransition(!context.transitionWasCancelled)
            }
        }
    }
}
