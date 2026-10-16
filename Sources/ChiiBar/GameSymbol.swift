import SwiftUI

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
                c.fill(Path(ellipseIn: CGRect(x: 12.8, y: 17.5, width: 1, height: 1)), with: .color(ink))
            case .friends:
                for (x, y, color) in [(1.5, 8.0, 0xFFF5DD), (10.0, 10.0, 0xE3EFF6)] {
                    var face = Path()
                    face.move(to: CGPoint(x: x + 2, y: y + 2))
                    face.addCurve(to: CGPoint(x: x + 5, y: y), control1: CGPoint(x: x, y: y - 5), control2: CGPoint(x: x + 5, y: y - 5))
                    face.addQuadCurve(to: CGPoint(x: x + 8, y: y), control: CGPoint(x: x + 6.5, y: y - 1))
                    face.addCurve(to: CGPoint(x: x + 11, y: y + 2), control1: CGPoint(x: x + 9, y: y - 5), control2: CGPoint(x: x + 13, y: y - 3))
                    face.addCurve(to: CGPoint(x: x + 6, y: y + 11), control1: CGPoint(x: x + 16, y: y + 10), control2: CGPoint(x: x + 10, y: y + 12))
                    face.addCurve(to: CGPoint(x: x + 2, y: y + 2), control1: CGPoint(x: x - 2, y: y + 12), control2: CGPoint(x: x - 2, y: y + 6))
                    paint(face, Ink.rgb(UInt32(color)))
                    for eye in [4.0, 8.0] {
                        c.fill(Path(ellipseIn: CGRect(x: x + eye, y: y + 4.5, width: 1.4, height: 1.8)), with: .color(ink))
                    }
                    for cheek in [1.7, 9.3] {
                        c.fill(Path(ellipseIn: CGRect(x: x + cheek, y: y + 6.3, width: 2.4, height: 1.5)), with: .color(Ink.rgb(0xEDA4A5)))
                    }
                    var smile = Path()
                    smile.move(to: CGPoint(x: x + 5.3, y: y + 7.5))
                    smile.addQuadCurve(to: CGPoint(x: x + 7.3, y: y + 7.5), control: CGPoint(x: x + 6.3, y: y + 9))
                    c.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                }
            }
        }
        .frame(width: 21, height: 21)
        .accessibilityHidden(true)
    }
}
