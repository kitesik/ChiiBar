import ChiiCore
import SwiftUI

/// Small, unmistakable accessories, without covering the original body or face.
enum HomeOutfitArt {
    static func draw(_ ctx: GraphicsContext, outfit: HomeOutfit, width: CGFloat, height: CGFloat, friend: FriendID) {
        guard outfit.isVisible else { return }
        var c = ctx
        c.scaleBy(x: width, y: height)
        func paint(_ path: Path, _ color: Color) {
            c.fill(path, with: .color(color))
            c.stroke(path, with: .color(Ink.outline), style: StrokeStyle(lineWidth: 0.012, lineJoin: .round))
        }
        func polygon(_ points: [(CGFloat, CGFloat)], _ color: Color) {
            var path = Path(); path.addLines(points.map { CGPoint(x: $0.0, y: $0.1) }); path.closeSubpath()
            paint(path, color)
        }
        switch outfit {
        case .gat:
            let brim: CGFloat = friend == .usagi ? -0.62 : -0.91
            paint(Path(ellipseIn: CGRect(x: -0.54, y: brim - 0.025, width: 1.08, height: 0.105)), Ink.rgb(0x34333A))
            paint(Path(roundedRect: CGRect(x: -0.24, y: brim - 0.21, width: 0.48, height: 0.24), cornerRadius: 0.035), Ink.rgb(0x29282E))
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: -0.32, y: brim + 0.04))
            ribbon.addQuadCurve(to: CGPoint(x: 0, y: brim + 0.30), control: CGPoint(x: -0.30, y: brim + 0.29))
            ribbon.addQuadCurve(to: CGPoint(x: 0.32, y: brim + 0.04), control: CGPoint(x: 0.30, y: brim + 0.29))
            c.stroke(ribbon, with: .color(Ink.rgb(0x756B65).opacity(0.6)), lineWidth: 0.012)
        case .bowTie:
            let y: CGFloat = friend == .usagi ? -0.27 : -0.33
            let tint = Ink.rgb(friend == .chiikawa || friend == .momonga || friend == .kani ? 0xBB657B : 0x467C97)
            polygon([(0, y), (-0.22, y - 0.065), (-0.22, y + 0.065)], tint)
            polygon([(0, y), (0.22, y - 0.065), (0.22, y + 0.065)], tint)
            paint(Path(ellipseIn: CGRect(x: -0.045, y: y - 0.04, width: 0.09, height: 0.08)), tint)
        case .none: break
        }
    }
}
