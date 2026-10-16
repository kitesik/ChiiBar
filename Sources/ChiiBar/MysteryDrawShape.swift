import ChiiCore
import SwiftUI

/// Deliberately receives no draw result: its entire reveal tease is outcome-independent.
enum MysteryDrawShape {
    static func draw(_ context: GraphicsContext, elapsed: Double) {
        let shapes: [FriendID] = [.momonga, .usagi, .anoko, .kani, .hachiware, .shisa]
        let cycle = max(0, elapsed) / 0.62
        let index = Int(cycle) % shapes.count
        let phase = cycle - floor(cycle)
        let blend = phase * phase * (3 - 2 * phase)
        let stretch = sin(phase * .pi)
        var c = context
        // A fluid squeeze makes the transition itself the focus, not a recognizable outline.
        c.translateBy(x: 0, y: -56)
        c.scaleBy(x: 1 + stretch * 0.32, y: 1 - stretch * 0.30)
        c.translateBy(x: 0, y: 56)
        c.drawLayer { layer in
            layer.addFilter(.alphaThreshold(min: 0.24, color: .black))
            layer.addFilter(.blur(radius: 3 + stretch * 5))
            layer.drawLayer { masks in
                var before = masks
                before.opacity = 1 - blend
                _ = SpriteArt.draw(before, shapes[index], base: .zero, size: 72, pose: Pose(), silhouette: true)
                var after = masks
                after.opacity = blend
                _ = SpriteArt.draw(after, shapes[(index + 1) % shapes.count], base: .zero, size: 72, pose: Pose(), silhouette: true)
            }
        }
    }
}
