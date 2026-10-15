import ChiiCore
import SwiftUI

// Every friend is drawn in code: big head, small body, dot eyes with a highlight,
// pink cheeks, tiny mouth, soft dark-grey outline. Local origin = feet, y grows down.

enum Ink {
    static let outline = Color(red: 0.30, green: 0.29, blue: 0.33)
    static let eye = Color(red: 0.16, green: 0.15, blue: 0.18)
    static let cheek = Color(red: 1.0, green: 0.62, blue: 0.70)
    static let tongue = Color(red: 0.98, green: 0.55, blue: 0.60)
    static let earInner = Color(red: 1.0, green: 0.78, blue: 0.82)
    static let tear = Color(red: 0.62, green: 0.82, blue: 1.0)

    static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255)
    }
}

extension FriendID {
    var fur: Color {
        switch self {
        case .chiikawa: Ink.rgb(0xFFFDF8)
        case .hachiware: Ink.rgb(0xFFFFFF)
        case .usagi: Ink.rgb(0xFFF0BE)
        case .momonga: Ink.rgb(0xFFFFFF)
        case .kurimanju: Ink.rgb(0xE0A85E)
        case .rakko: Ink.rgb(0xC99B72)
        case .shisa: Ink.rgb(0xF7B84A)
        case .anoko: Ink.rgb(0xFFFCED)
        case .kani: Ink.rgb(0xF4B9C6)
        }
    }

    /// Second colour: cap, mane or face patch.
    var accent: Color {
        switch self {
        case .chiikawa: Ink.rgb(0xF4ECE0)
        case .hachiware: Ink.rgb(0x6B7C98)
        case .usagi: Ink.rgb(0xF5DE96)
        case .momonga: Ink.rgb(0xC3D2E4)
        case .kurimanju: Ink.rgb(0x8C5A2E)
        case .rakko: Ink.rgb(0xF4E3CD)
        case .shisa: Ink.rgb(0xE07A2C)
        case .anoko: Ink.rgb(0xDCCFA3)
        case .kani: Ink.rgb(0xDA6D80)
        }
    }

    var chipTint: Color {
        switch self {
        case .chiikawa: Ink.rgb(0xFFE3EA)
        case .hachiware: Ink.rgb(0xDDE6F5)
        case .usagi: Ink.rgb(0xFFF2C4)
        case .momonga: Ink.rgb(0xE3ECF7)
        case .kurimanju: Ink.rgb(0xF6E0C0)
        case .rakko: Ink.rgb(0xEEDCC8)
        case .shisa: Ink.rgb(0xFFE0B8)
        case .anoko: Ink.rgb(0xF5EFD9)
        case .kani: Ink.rgb(0xF9E9ED)
        }
    }
}

struct Pose {
    enum Eyes { case open, closed, happy, up }
    enum Mouth { case smile, open, munch, flat, grin }
    enum Arms { case down, front, up }
    var eyes: Eyes = .open
    var mouth: Mouth?
    var arms: Arms = .down
    var tilt: Double = 0        // radians, around the feet
    var squish: Double = 1      // vertical scale
    var lying = false
    var blush: Double = 1
    var earTilt: Double = 0
    var blinking = false
}

enum FriendArt {
    static func ell(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
    }

    static func paint(_ c: GraphicsContext, _ p: Path, _ fill: Color, _ lw: CGFloat) {
        c.fill(p, with: .color(fill))
        c.stroke(p, with: .color(Ink.outline), style: StrokeStyle(lineWidth: lw, lineJoin: .round))
    }

    /// Draws the whole friend with its feet at `base`. `s` is the head width.
    static func draw(_ ctx: GraphicsContext, _ f: FriendID, base: CGPoint, size s: CGFloat, pose: Pose) {
        if SpriteArt.draw(ctx, f, base: base, size: s, pose: pose) { return }
        var c = ctx
        c.translateBy(x: base.x, y: base.y)
        if pose.lying {
            c.translateBy(x: 0, y: -0.42 * s)
            c.rotate(by: .radians(-Double.pi / 2 + 0.12))
        }
        c.rotate(by: .radians(pose.tilt))
        c.scaleBy(x: 1 + (1 - pose.squish) * 0.6, y: pose.squish)
        if f == .anoko || f == .kani {
            c.scaleBy(x: s, y: s)
            AdditionalFriendSprites.draw(c, friend: f, pose: pose)
            return
        }
        let lw = max(1, s * 0.035)
        tail(c, f, s, lw)
        backOfHead(c, f, s, lw)
        bodyAndFeet(c, f, s, lw)
        head(c, f, s, lw)
        face(c, f, s, lw, pose)
        arms(c, f, s, lw, pose.arms)
    }

    /// Head only, centred in `rect` (menu bar icon and friend chips).
    static func drawFace(_ ctx: GraphicsContext, _ f: FriendID, in rect: CGRect) {
        if SpriteArt.drawFace(ctx, f, in: rect) { return }
        let s = min(rect.width, rect.height) * (f == .usagi ? 0.62 : 0.86)
        var c = ctx
        let headCenterY = f == .usagi ? rect.maxY - s * 0.48 : rect.midY + s * 0.06
        c.translateBy(x: rect.midX, y: headCenterY + 0.72 * s)
        if f == .anoko || f == .kani {
            c.scaleBy(x: s, y: s)
            AdditionalFriendSprites.draw(c, friend: f, pose: Pose(), faceOnly: true)
            return
        }
        let lw = max(1, s * 0.05)
        backOfHead(c, f, s, lw)
        head(c, f, s, lw)
        face(c, f, s, lw, Pose())
    }

    // MARK: parts

    private static func tail(_ c: GraphicsContext, _ f: FriendID, _ s: CGFloat, _ lw: CGFloat) {
        switch f {
        case .momonga:
            var t = c
            t.translateBy(x: 0.36 * s, y: -0.42 * s)
            t.rotate(by: .degrees(18))
            paint(t, ell(0, 0, 0.36 * s, 0.6 * s), f.accent, lw)
            t.fill(ell(-0.03 * s, 0.05 * s, 0.16 * s, 0.34 * s), with: .color(.white.opacity(0.55)))
        case .shisa:
            var p = Path()
            p.move(to: CGPoint(x: 0.22 * s, y: -0.18 * s))
            p.addCurve(to: CGPoint(x: 0.5 * s, y: -0.55 * s), control1: CGPoint(x: 0.5 * s, y: -0.12 * s),
                       control2: CGPoint(x: 0.62 * s, y: -0.4 * s))
            p.addCurve(to: CGPoint(x: 0.38 * s, y: -0.5 * s), control1: CGPoint(x: 0.42 * s, y: -0.66 * s),
                       control2: CGPoint(x: 0.3 * s, y: -0.58 * s))
            c.stroke(p, with: .color(Ink.outline), style: StrokeStyle(lineWidth: 0.13 * s + 2 * lw, lineCap: .round))
            c.stroke(p, with: .color(f.accent), style: StrokeStyle(lineWidth: 0.13 * s, lineCap: .round))
        case .rakko:
            paint(c, ell(0.3 * s, -0.08 * s, 0.28 * s, 0.12 * s), Ink.rgb(0xA97E58), lw)
        default:
            break
        }
    }

    private static func backOfHead(_ c: GraphicsContext, _ f: FriendID, _ s: CGFloat, _ lw: CGFloat) {
        switch f {
        case .anoko, .kani: break // Drawn by AdditionalFriendSprites before this fallback.
        case .chiikawa:
            for sx in [-1.0, 1.0] { paint(c, ell(sx * 0.29 * s, -1.06 * s, 0.24 * s, 0.24 * s), f.fur, lw) }
        case .hachiware:
            for sx in [-1.0, 1.0] {
                var p = Path()
                p.move(to: CGPoint(x: sx * 0.46 * s, y: -0.9 * s))
                p.addLine(to: CGPoint(x: sx * 0.38 * s, y: -1.27 * s))
                p.addLine(to: CGPoint(x: sx * 0.1 * s, y: -1.1 * s))
                p.closeSubpath()
                paint(c, p, f.accent, lw)
                var q = Path()
                q.move(to: CGPoint(x: sx * 0.38 * s, y: -1.0 * s))
                q.addLine(to: CGPoint(x: sx * 0.36 * s, y: -1.18 * s))
                q.addLine(to: CGPoint(x: sx * 0.22 * s, y: -1.08 * s))
                q.closeSubpath()
                c.fill(q, with: .color(Ink.earInner))
            }
        case .usagi:
            for sx in [-1.0, 1.0] {
                var e = c
                e.translateBy(x: sx * 0.15 * s, y: -1.42 * s)
                e.rotate(by: .degrees(sx * 6))
                paint(e, ell(0, 0, 0.17 * s, 0.66 * s), f.fur, lw)
                e.fill(ell(0, 0.04 * s, 0.07 * s, 0.44 * s), with: .color(Ink.earInner))
            }
        case .momonga:
            for sx in [-1.0, 1.0] { paint(c, ell(sx * 0.32 * s, -1.05 * s, 0.2 * s, 0.22 * s), f.accent, lw) }
        case .rakko:
            for sx in [-1.0, 1.0] { paint(c, ell(sx * 0.38 * s, -0.98 * s, 0.16 * s, 0.16 * s), f.fur, lw) }
        case .shisa:
            let n = 15
            for i in 0..<n {
                let a = Double(i) / Double(n) * 2 * .pi
                let x = cos(a) * 0.54 * s, y = -0.72 * s + sin(a) * 0.47 * s
                paint(c, ell(x, y, 0.27 * s, 0.27 * s), f.accent, lw)
            }
        case .kurimanju:
            var p = Path()
            p.move(to: CGPoint(x: -0.12 * s, y: -1.08 * s))
            p.addQuadCurve(to: CGPoint(x: 0.02 * s, y: -1.3 * s), control: CGPoint(x: -0.06 * s, y: -1.24 * s))
            p.addQuadCurve(to: CGPoint(x: 0.12 * s, y: -1.08 * s), control: CGPoint(x: 0.1 * s, y: -1.2 * s))
            p.closeSubpath()
            paint(c, p, f.accent, lw)
        }
    }

    private static func bodyAndFeet(_ c: GraphicsContext, _ f: FriendID, _ s: CGFloat, _ lw: CGFloat) {
        for sx in [-1.0, 1.0] { paint(c, ell(sx * 0.14 * s, -0.05 * s, 0.22 * s, 0.11 * s), f.fur, lw) }
        let body = ell(0, -0.27 * s, 0.64 * s, 0.5 * s)
        paint(c, body, f.fur, lw)
        if f == .rakko || f == .shisa {
            c.fill(ell(0, -0.22 * s, 0.38 * s, 0.3 * s), with: .color(f == .rakko ? f.accent : Ink.rgb(0xFFE3A6)))
        }
    }

    private static func headPath(_ f: FriendID, _ s: CGFloat) -> Path {
        f == .kurimanju ? ell(0, -0.7 * s, 1.02 * s, 0.9 * s) : ell(0, -0.72 * s, s, 0.86 * s)
    }

    private static func head(_ c: GraphicsContext, _ f: FriendID, _ s: CGFloat, _ lw: CGFloat) {
        let hp = headPath(f, s)
        c.fill(hp, with: .color(f.fur))
        var h = c
        h.clip(to: hp)
        switch f {
        case .hachiware:
            // Blue-grey cap split down the middle by a white upside-down V.
            for sx in [-1.0, 1.0] {
                var p = Path()
                p.move(to: CGPoint(x: sx * 0.62 * s, y: -0.8 * s))
                p.addLine(to: CGPoint(x: sx * 0.2 * s, y: -0.83 * s))
                p.addLine(to: CGPoint(x: sx * 0.015 * s, y: -1.2 * s))
                p.addLine(to: CGPoint(x: sx * 0.62 * s, y: -1.2 * s))
                p.closeSubpath()
                h.fill(p, with: .color(f.accent))
            }
        case .momonga:
            var p = Path()
            p.move(to: CGPoint(x: -0.6 * s, y: -0.82 * s))
            p.addQuadCurve(to: CGPoint(x: 0.6 * s, y: -0.82 * s), control: CGPoint(x: 0, y: -1.0 * s))
            p.addLine(to: CGPoint(x: 0.6 * s, y: -1.3 * s))
            p.addLine(to: CGPoint(x: -0.6 * s, y: -1.3 * s))
            p.closeSubpath()
            h.fill(p, with: .color(f.accent))
        case .kurimanju:
            var p = Path()
            p.move(to: CGPoint(x: -0.6 * s, y: -0.9 * s))
            for i in 0..<6 {
                let x0 = -0.6 + Double(i) * 0.2
                p.addQuadCurve(to: CGPoint(x: (x0 + 0.2) * s, y: -0.9 * s), control: CGPoint(x: (x0 + 0.1) * s, y: -0.83 * s))
            }
            p.addLine(to: CGPoint(x: 0.6 * s, y: -1.3 * s))
            p.addLine(to: CGPoint(x: -0.6 * s, y: -1.3 * s))
            p.closeSubpath()
            h.fill(p, with: .color(f.accent))
            h.fill(ell(0, -0.6 * s, 0.62 * s, 0.44 * s), with: .color(Ink.rgb(0xF8E6C6)))
        case .rakko:
            h.fill(ell(0, -0.58 * s, 0.8 * s, 0.5 * s), with: .color(f.accent))
        case .usagi:
            h.fill(ell(0, -0.52 * s, 0.6 * s, 0.32 * s), with: .color(Ink.rgb(0xFFF8DD)))
        default:
            break
        }
        c.stroke(hp, with: .color(Ink.outline), lineWidth: lw)
    }

    private static func face(_ c: GraphicsContext, _ f: FriendID, _ s: CGFloat, _ lw: CGFloat, _ pose: Pose) {
        let big = f == .momonga
        let ew = (big ? 0.15 : 0.085) * s, eh = (big ? 0.17 : 0.105) * s
        let ex = (big ? 0.19 : 0.17) * s, ey = (f == .rakko ? -0.78 : -0.7) * s
        for sx in [-1.0, 1.0] {
            let x = sx * ex
            switch pose.eyes {
            case .open, .up:
                let dy = pose.eyes == .up ? -0.03 * s : 0
                c.fill(ell(x, ey + dy, ew, eh), with: .color(Ink.eye))
                c.fill(ell(x - ew * 0.2, ey + dy - eh * 0.22, ew * 0.42, ew * 0.42), with: .color(.white))
                if big { c.fill(ell(x + ew * 0.22, ey + dy + eh * 0.22, ew * 0.2, ew * 0.2), with: .color(.white)) }
                if f == .chiikawa {
                    c.fill(ell(x, ey + eh * 0.3, ew * 0.7, eh * 0.28), with: .color(Ink.tear.opacity(0.9)))
                }
            case .closed:
                var p = Path()
                p.move(to: CGPoint(x: x - ew * 0.7, y: ey))
                p.addQuadCurve(to: CGPoint(x: x + ew * 0.7, y: ey), control: CGPoint(x: x, y: ey + eh * 0.6))
                c.stroke(p, with: .color(Ink.eye), style: StrokeStyle(lineWidth: lw * 1.1, lineCap: .round))
            case .happy:
                var p = Path()
                p.move(to: CGPoint(x: x - ew * 0.7, y: ey + eh * 0.2))
                p.addQuadCurve(to: CGPoint(x: x + ew * 0.7, y: ey + eh * 0.2), control: CGPoint(x: x, y: ey - eh * 0.6))
                c.stroke(p, with: .color(Ink.eye), style: StrokeStyle(lineWidth: lw * 1.1, lineCap: .round))
            }
            c.fill(ell(sx * 0.3 * s, -0.55 * s, 0.15 * s, 0.075 * s), with: .color(Ink.cheek.opacity(0.65 * pose.blush)))
        }
        if f == .rakko { c.fill(ell(0, -0.64 * s, 0.09 * s, 0.06 * s), with: .color(Ink.eye)) }
        if f == .kurimanju || f == .shisa { c.fill(ell(0, -0.62 * s, 0.05 * s, 0.035 * s), with: .color(Ink.eye.opacity(0.8))) }
        mouth(c, pose.mouth ?? defaultMouth(f), s, lw, y: (f == .rakko ? -0.56 : -0.57) * s)
    }

    static func defaultMouth(_ f: FriendID) -> Pose.Mouth {
        switch f {
        case .usagi: .grin
        case .rakko: .flat
        default: .smile
        }
    }

    private static func mouth(_ c: GraphicsContext, _ m: Pose.Mouth, _ s: CGFloat, _ lw: CGFloat, y: CGFloat) {
        let stroke = StrokeStyle(lineWidth: lw, lineCap: .round)
        switch m {
        case .smile:
            var p = Path()
            p.move(to: CGPoint(x: -0.05 * s, y: y - 0.01 * s))
            p.addQuadCurve(to: CGPoint(x: 0, y: y), control: CGPoint(x: -0.03 * s, y: y + 0.03 * s))
            p.addQuadCurve(to: CGPoint(x: 0.05 * s, y: y - 0.01 * s), control: CGPoint(x: 0.03 * s, y: y + 0.03 * s))
            c.stroke(p, with: .color(Ink.outline), style: stroke)
        case .flat:
            var p = Path()
            p.move(to: CGPoint(x: -0.04 * s, y: y))
            p.addLine(to: CGPoint(x: 0.04 * s, y: y))
            c.stroke(p, with: .color(Ink.outline), style: stroke)
        case .open, .munch:
            let o = ell(0, y + 0.01 * s, 0.09 * s, (m == .munch ? 0.05 : 0.08) * s)
            c.fill(o, with: .color(Ink.rgb(0x5A3A40)))
            c.fill(ell(0, y + 0.03 * s, 0.05 * s, 0.025 * s), with: .color(Ink.tongue))
        case .grin:
            var p = Path()
            p.move(to: CGPoint(x: -0.13 * s, y: y - 0.02 * s))
            p.addLine(to: CGPoint(x: 0.13 * s, y: y - 0.02 * s))
            p.addQuadCurve(to: CGPoint(x: -0.13 * s, y: y - 0.02 * s), control: CGPoint(x: 0, y: y + 0.17 * s))
            p.closeSubpath()
            c.fill(p, with: .color(Ink.rgb(0x5A3A40)))
            c.fill(ell(0, y + 0.045 * s, 0.1 * s, 0.05 * s), with: .color(Ink.tongue))
            c.stroke(p, with: .color(Ink.outline), style: StrokeStyle(lineWidth: lw * 0.8, lineJoin: .round))
        }
    }

    private static func arms(_ c: GraphicsContext, _ f: FriendID, _ s: CGFloat, _ lw: CGFloat, _ arms: Pose.Arms) {
        for sx in [-1.0, 1.0] {
            var a = c
            switch arms {
            case .down:
                a.translateBy(x: sx * 0.3 * s, y: -0.28 * s)
                a.rotate(by: .degrees(sx * -25))
            case .front:
                a.translateBy(x: sx * 0.2 * s, y: -0.3 * s)
                a.rotate(by: .degrees(sx * 60))
            case .up:
                a.translateBy(x: sx * 0.34 * s, y: -0.42 * s)
                a.rotate(by: .degrees(sx * -150))
            }
            paint(a, ell(0, 0.06 * s, 0.14 * s, 0.2 * s), f.fur, lw)
        }
    }
}

/// Rarity as filled stars.
func stars(_ n: Int) -> String { String(repeating: "★", count: n) }
