import SwiftUI
import ChiiCore

/// Small hand-drawn-style UI symbols, shared by navigation and game actions.
struct GameSymbol: View {
    enum Kind { case home, friends }
    let kind: Kind

    var body: some View {
        Canvas { context, size in
            var c = context
            let scale = min(size.width, size.height) / 24
            c.translateBy(x: (size.width - 24 * scale) / 2, y: (size.height - 24 * scale) / 2)
            c.scaleBy(x: scale, y: scale)
            let ink = Ink.rgb(0x624C43)
            func paint(_ path: Path, _ color: Color) {
                c.fill(path, with: .color(color))
                c.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
            switch kind {
            case .home:
                paint(Path(roundedRect: CGRect(x: 4.5, y: 9, width: 15, height: 12), cornerRadius: 2.5), Ink.rgb(0xFFF0C4))
                paint(Path(roundedRect: CGRect(x: 15.5, y: 3, width: 3.5, height: 6), cornerRadius: 1), Ink.rgb(0xEDAC82))
                var roof = Path()
                roof.move(to: CGPoint(x: 2, y: 10.5))
                roof.addQuadCurve(to: CGPoint(x: 12, y: 3), control: CGPoint(x: 6, y: 5))
                roof.addQuadCurve(to: CGPoint(x: 22, y: 10.5), control: CGPoint(x: 19, y: 7))
                roof.addQuadCurve(to: CGPoint(x: 19, y: 12), control: CGPoint(x: 22, y: 13))
                roof.addLine(to: CGPoint(x: 12, y: 6.8))
                roof.addLine(to: CGPoint(x: 5, y: 12))
                roof.addQuadCurve(to: CGPoint(x: 2, y: 10.5), control: CGPoint(x: 2, y: 13))
                paint(roof, Ink.rgb(0xED9690))
                paint(Path(roundedRect: CGRect(x: 10, y: 14, width: 5, height: 7), cornerRadius: 2), Ink.rgb(0xA8CBD2))
                SpriteArt.drawPortrait(c, .chiikawa, in: CGRect(x: 8, y: 12, width: 10, height: 10))
            case .friends:
                SpriteArt.drawPortrait(c, .hachiware, in: CGRect(x: 0, y: 2, width: 15, height: 19))
                SpriteArt.drawPortrait(c, .chiikawa, in: CGRect(x: 9, y: 5, width: 15, height: 19))
            }
        }
        .frame(width: 25, height: 24)
        .accessibilityHidden(true)
    }
}
