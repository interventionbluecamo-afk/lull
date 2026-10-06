import SpriteKit

class DraggableNode: SKShapeNode {
    var isDragging = false
    var physicsProfile = ToyPhysicsProfile.softDrag
    private var touchOffset = CGPoint.zero

    func beginDrag(at point: CGPoint) {
        beginDrag(at: point, in: nil)
    }

    func beginDrag(at point: CGPoint, in scene: SKScene?) {
        isDragging = true
        let parentPoint = convertedParentPoint(from: point, in: scene)
        touchOffset = CGPoint(x: position.x - parentPoint.x, y: position.y - parentPoint.y)
        zPosition += 10
        TouchFeedbackAnimator.acknowledge(node: self, profile: physicsProfile)
    }

    func drag(to point: CGPoint) {
        drag(to: point, in: nil)
    }

    func drag(to point: CGPoint, in scene: SKScene?) {
        guard isDragging else { return }
        let parentPoint = convertedParentPoint(from: point, in: scene)
        position = CGPoint(x: parentPoint.x + touchOffset.x, y: parentPoint.y + touchOffset.y)
    }

    func endDrag() {
        guard isDragging else { return }
        isDragging = false
        zPosition -= 10
        TouchFeedbackAnimator.softSettle(node: self, profile: physicsProfile)
    }

    private func convertedParentPoint(from point: CGPoint, in scene: SKScene?) -> CGPoint {
        guard let scene, let parent else { return point }
        return parent.convert(point, from: scene)
    }
}
