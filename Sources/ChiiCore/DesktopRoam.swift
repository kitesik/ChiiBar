import CoreGraphics
import Foundation

public enum DesktopRoam {
    /// Constant walking speed; long gaps (sleep, menu tracking) never teleport the pet.
    public static func step(from position: CGPoint, toward target: CGPoint, in bounds: CGRect,
                            elapsed: Double, reduced: Bool = false) -> CGPoint {
        let x = min(bounds.maxX, max(bounds.minX, position.x))
        let y = min(bounds.maxY, max(bounds.minY, position.y))
        guard !reduced else { return CGPoint(x: x, y: y) }
        let dx = target.x - x, dy = target.y - y
        let distance = hypot(dx, dy)
        guard distance > 0 else { return CGPoint(x: x, y: y) }
        let travel = min(distance, max(0, min(elapsed, 0.1)) * 24)
        return CGPoint(x: min(bounds.maxX, max(bounds.minX, x + dx / distance * travel)),
                       y: min(bounds.maxY, max(bounds.minY, y + dy / distance * travel)))
    }
}
