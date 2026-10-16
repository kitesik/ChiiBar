import ChiiCore
import SwiftUI

/// Places the friend for its activity and adds the small in-place motion and props.
enum ActivityArt {
    typealias C = GraphicsContext
    static let ell = FriendArt.ell
    static let paint = HouseArt.paint

    struct Placement { var base: CGPoint; var size: CGFloat; var lying = false }

    static func placement(_ p: SceneParams) -> Placement {
        let seat = p.stage >= 5 ? CGPoint(x: 160, y: 151) : (p.stage >= 2 ? CGPoint(x: 160, y: 153) : CGPoint(x: 160, y: 196))
        switch p.activity {
        case .weeding: return Placement(base: CGPoint(x: 160, y: 202), size: 40)
        case .cooking: return Placement(base: CGPoint(x: 230, y: 158), size: 38)
        case .sweeping: return Placement(base: CGPoint(x: 124, y: 155), size: 38)
        case .reading: return Placement(base: CGPoint(x: 112, y: 152), size: 38)
        case .rolling, .tea: return Placement(base: seat, size: 40)
        case .snack: return Placement(base: CGPoint(x: 194, y: 153), size: 38)
        case .window: return Placement(base: CGPoint(x: 135, y: 147), size: 34)
        case .napFuton: return Placement(base: CGPoint(x: 98, y: 151), size: 32, lying: true)
        case .napGround:
            return Placement(base: p.stage >= 2 ? CGPoint(x: 176, y: 156) : CGPoint(x: 176, y: 198), size: 38, lying: true)
        }
    }

    static func headPoint(_ p: SceneParams) -> CGPoint {
        let pl = placement(p)
        if pl.lying { return CGPoint(x: pl.base.x - 0.72 * pl.size, y: pl.base.y - 0.9 * pl.size) }
        return CGPoint(x: pl.base.x, y: pl.base.y - 1.15 * pl.size)
    }

    static func draw(_ c: C, _ p: SceneParams) {
        var pl = placement(p)
        let t = p.t, s = pl.size
        var pose = Pose()
        pose.lying = pl.lying
        if p.stage >= HousePlan.lastStage { pose.blush = 1.45 }

        switch p.activity {
        case .weeding:
            pose.arms = .front
            pose.tilt = sin(t * 3) * 0.06
            pose.squish = 1 - 0.04 * max(0, sin(t * 5))
            weedPile(c, at: CGPoint(x: pl.base.x + 34, y: pl.base.y - 1))
        case .cooking:
            pose.arms = .front
            pose.tilt = 0.08 + sin(t * 3) * 0.03
        case .sweeping:
            pose.arms = .front
            pose.tilt = sin(t * 2.5) * 0.06
            pl.base.x += CGFloat(sin(t * 1.25) * 4)
        case .reading:
            pose.arms = .front
            pose.tilt = sin(t * 1.2) * 0.04
            pose.squish = 1 - 0.02 * sin(t * 1.2)
        case .rolling:
            pose.eyes = .happy
            pose.mouth = .open
            pose.tilt = sin(t * 1.8) * 0.55
            pl.base.x += CGFloat(sin(t * 1.8) * 6)
        case .snack:
            pose.arms = .front
            pose.mouth = sin(t * 7) > 0 ? .munch : .smile
            pose.squish = 1 - 0.025 * max(0, sin(t * 7))
        case .tea:
            pose.arms = .front
            let sip = sin(t * 0.9) > 0.55
            pose.eyes = sip ? .happy : .open
            pose.squish = 1 - 0.02 * sin(t * 0.9)
        case .window:
            pose.eyes = .up
            pose.tilt = sin(t * 0.8) * 0.05
            bird(c, t: t)
        case .napFuton, .napGround:
            pose.eyes = .closed
            pose.mouth = .smile
            pose.squish = 1 + 0.03 * sin(t * 1.5)
        }

        personality(p.friend, activity: p.activity, t: t, placement: &pl, pose: &pose)

        if let e = p.pokeElapsed, e < 0.45 {
            pose.squish *= 1 - 0.2 * sin(.pi * e / 0.45)
            pose.eyes = pose.lying ? .closed : .happy
            if !pose.lying { pose.mouth = .open }
        } else if let e = p.pokeElapsed, e < 1.2, !pose.lying {
            pose.eyes = .happy
        }

        if p.activity == .cooking { ladle(c, pl, t: t) }  // held behind the head, reaching the pot
        FriendArt.draw(c, p.friend, base: pl.base, size: s, pose: pose)
        props(c, p, pl)
        if let e = p.pokeElapsed { Effects.hearts(c, from: headPoint(p), elapsed: e) }
    }

    /// Bounded in-place gestures. Sleep and held props stay anchored to furniture.
    static func personality(_ f: FriendID, activity: Activity, t: Double,
                            placement pl: inout Placement, pose: inout Pose) {
        let phase = t + Double(FriendID.allCases.firstIndex(of: f)!) * 0.71
        if pl.lying {
            pose.squish = 1 + 0.022 * sin(phase * (f == .usagi ? 1.8 : 1.2))
            return
        }
        let free = activity == .rolling || activity == .weeding || activity == .window
        let blink = phase.truncatingRemainder(dividingBy: 4.3) < 0.13
        if pose.eyes == .open || pose.eyes == .up {
            pose.blinking = blink
            if blink { pose.eyes = .closed }
        }
        switch f {
        case .pajamaGreen, .pajamaPink, .pajamaWhite, .pajamaPurple:
            pose.tilt += sin(phase * 2.2) * 0.04
            if free { pl.base.y -= max(0, sin(phase * 2.2)) * 2 }
        case .pochette, .labor:
            pose.tilt *= 0.4
            pose.squish = 1 + (pose.squish - 1) * 0.3
        case .chiikawa:
            pose.tilt += sin(phase * 25) * (free ? 0.017 : 0.005)
            if free {
                let hop = max(0, sin(phase * 4.2))
                pl.base.y -= hop * hop * 2.6
                pose.squish *= 1 - 0.035 * cos(phase * 4.2)
            }
        case .hachiware:
            pose.tilt += sin(phase * 1.5) * 0.035
            pose.earTilt = sin(phase * 1.5 - 0.45) * 0.10
        case .usagi:
            pose.earTilt = sin(phase * 5.4 - 0.65) * 0.16
            if free {
                let beat = phase.truncatingRemainder(dividingBy: 3.1)
                let jump = beat < 0.7 ? sin(.pi * beat / 0.7) : 0
                pl.base.y -= jump * 12
                pose.tilt += sin(phase * 10) * jump * 0.11
                pose.squish *= 1 + jump * 0.12 - max(0, 1 - abs(beat - 0.78) / 0.12) * 0.12
                if jump > 0.25 { pose.arms = .up }
            }
        case .momonga:
            pose.tilt += sin(phase * 2) * 0.045
            if free && sin(phase * 1.3) > 0.8 { pose.arms = .up; pose.eyes = .happy }
        case .kurimanju:
            pose.squish *= 1 + sin(phase * 1.1) * 0.018
            pose.tilt += sin(phase * 0.8) * 0.012
        case .rakko:
            pose.tilt *= 0.5
            pose.squish = 1 + (pose.squish - 1) * 0.5
        case .anoko:
            pose.tilt += sin(phase * 1.8) * 0.03
            if free { pose.squish *= 1 + sin(phase * 3.6) * 0.03 }
        case .kani:
            pose.tilt += sin(phase * 2.2) * 0.02
            if free { pl.base.x += sin(phase * 2.2) * 2 }
        case .shisa:
            pose.tilt += sin(phase * 2.8) * 0.04
            if free { pl.base.y -= max(0, sin(phase * 3.4)) * 3 }
        }
    }

    static func props(_ c: C, _ p: SceneParams, _ pl: Placement) {
        let t = p.t, s = pl.size, b = pl.base
        let hands = CGPoint(x: b.x, y: b.y - 0.3 * s)
        switch p.activity {
        case .weeding:
            let ph = (t * 0.8).truncatingRemainder(dividingBy: 1)
            weed(c, at: CGPoint(x: hands.x, y: hands.y - CGFloat(ph) * 6), size: 1)
        case .sweeping:
            var b2 = c
            b2.translateBy(x: hands.x + 4, y: hands.y)
            b2.rotate(by: .radians(-0.35 + sin(t * 2.5) * 0.4))
            paint(b2, Path(roundedRect: CGRect(x: -1.4, y: -18, width: 2.8, height: 26), cornerRadius: 1.4), Ink.rgb(0xC48A5C))
            paint(b2, HouseArt.poly([(-3.5, 6), (3.5, 6), (7, 14), (-7, 14)]), Ink.rgb(0xF2D27A))
            let ph = (t * 1.2).truncatingRemainder(dividingBy: 1)
            for i in 0..<3 {
                let x = hands.x + 14 + CGFloat(i) * 6 + CGFloat(ph) * 6, y = b.y - 2 - CGFloat(ph) * 6
                c.fill(ell(x, y, 5 * (1 - ph) + 2, 5 * (1 - ph) + 2), with: .color(Ink.rgb(0xD9CBB8).opacity(1 - ph)))
            }
        case .reading:
            book(c, at: CGPoint(x: hands.x, y: hands.y + 1), flip: sin(t * 0.5) > 0.9)
        case .snack where !p.snackIsPudding:
            onigiri(c, at: CGPoint(x: b.x + 0.06 * s, y: b.y - 0.4 * s))
        case .snack:
            var sp = Path()
            sp.move(to: CGPoint(x: hands.x + 4, y: hands.y))
            sp.addLine(to: CGPoint(x: hands.x + 10, y: hands.y - 10))
            c.stroke(sp, with: .color(Ink.rgb(0xB0B5C0)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            c.fill(ell(hands.x + 10.5, hands.y - 11, 4, 3), with: .color(Ink.rgb(0xFFD66B)))
        case .tea:
            let sip = sin(t * 0.9) > 0.55
            let cup = CGPoint(x: hands.x + 2, y: hands.y - (sip ? 8 : 1))
            paint(c, Path(roundedRect: CGRect(x: cup.x - 6, y: cup.y - 6, width: 12, height: 10), cornerRadius: 2), .white)
            c.stroke(Path(ellipseIn: CGRect(x: cup.x + 5, y: cup.y - 4, width: 5, height: 5)), with: .color(Ink.outline), lineWidth: 1.2)
            c.fill(ell(cup.x, cup.y - 5, 9, 2.4), with: .color(Ink.rgb(0xA8D58A)))
            Effects.steam(c, at: CGPoint(x: cup.x, y: cup.y - 8), t: t)
        case .napFuton:
            // blanket over the sleeping friend
            paint(c, Path(roundedRect: CGRect(x: 70, y: 139, width: 56, height: 16), cornerRadius: 4), Ink.rgb(0xA8C8F0))
            for i in 0..<4 { c.fill(ell(78 + CGFloat(i) * 12, 146 + CGFloat(i % 2) * 2, 3.5, 3.5), with: .color(.white.opacity(0.9))) }
            Effects.zzz(c, from: CGPoint(x: headPoint(p).x + 10, y: headPoint(p).y), t: t)
        case .napGround:
            Effects.zzz(c, from: CGPoint(x: headPoint(p).x + 10, y: headPoint(p).y), t: t)
        default:
            break
        }
    }

    static func ladle(_ c: C, _ pl: Placement, t: Double) {
        var p = Path()
        let tip = CGPoint(x: 250 + cos(t * 3) * 3, y: 93 + sin(t * 3) * 1.5)
        p.move(to: CGPoint(x: pl.base.x + 0.2 * pl.size, y: pl.base.y - 0.6 * pl.size))
        p.addLine(to: tip)
        c.stroke(p, with: .color(Ink.outline), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
        c.stroke(p, with: .color(Ink.rgb(0xC48A5C)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
    }

    static func weed(_ c: C, at p: CGPoint, size k: CGFloat) {
        var w = Path()
        for dx in [-3.0, 0.0, 3.0] as [CGFloat] {
            w.move(to: CGPoint(x: p.x + dx * 0.4, y: p.y))
            w.addQuadCurve(to: CGPoint(x: p.x + dx * 1.6, y: p.y - 10 * k), control: CGPoint(x: p.x + dx, y: p.y - 5 * k))
        }
        c.stroke(w, with: .color(Ink.rgb(0x5FA84A)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        c.fill(ell(p.x, p.y + 1.5, 6, 3), with: .color(Ink.rgb(0xA67C52)))
    }

    static func weedPile(_ c: C, at p: CGPoint) {
        for (i, dx) in ([-6.0, 0.0, 6.0] as [CGFloat]).enumerated() {
            var w = c
            w.translateBy(x: p.x + dx, y: p.y)
            w.rotate(by: .degrees(Double(i - 1) * 30 + 80))
            weed(w, at: .zero, size: 0.8)
        }
    }

    static func book(_ c: C, at p: CGPoint, flip: Bool) {
        let l = HouseArt.poly([(p.x - 13, p.y - 8), (p.x, p.y - 6), (p.x, p.y + 4), (p.x - 13, p.y + 2)])
        let r = HouseArt.poly([(p.x + 13, p.y - 8), (p.x, p.y - 6), (p.x, p.y + 4), (p.x + 13, p.y + 2)])
        paint(c, l, Ink.rgb(0xFFFDF5))
        paint(c, r, Ink.rgb(0xFFFDF5))
        for i in 0..<3 {
            let y = p.y - 4 + CGFloat(i) * 2.5
            var ln = Path()
            ln.move(to: CGPoint(x: p.x - 10, y: y - 1)); ln.addLine(to: CGPoint(x: p.x - 3, y: y))
            ln.move(to: CGPoint(x: p.x + 3, y: y)); ln.addLine(to: CGPoint(x: p.x + 10, y: y - 1))
            c.stroke(ln, with: .color(Ink.outline.opacity(0.35)), lineWidth: 0.7)
        }
        c.fill(Path(CGRect(x: p.x - 1, y: p.y - 7, width: 2, height: 11)), with: .color(Ink.rgb(0xF58FA4)))
        if flip { paint(c, HouseArt.poly([(p.x, p.y - 6), (p.x + 7, p.y - 12), (p.x + 7, p.y - 2), (p.x, p.y + 4)]), Ink.rgb(0xFFFDF5)) }
    }

    static func onigiri(_ c: C, at p: CGPoint) {
        var tri = Path()
        tri.move(to: CGPoint(x: p.x, y: p.y - 8))
        tri.addQuadCurve(to: CGPoint(x: p.x + 8, y: p.y + 5), control: CGPoint(x: p.x + 7, y: p.y - 3))
        tri.addQuadCurve(to: CGPoint(x: p.x - 8, y: p.y + 5), control: CGPoint(x: p.x, y: p.y + 7))
        tri.addQuadCurve(to: CGPoint(x: p.x, y: p.y - 8), control: CGPoint(x: p.x - 7, y: p.y - 3))
        paint(c, tri, .white)
        c.fill(Path(CGRect(x: p.x - 4, y: p.y, width: 8, height: 6)), with: .color(Ink.rgb(0x2F3B33)))
    }

    static func bird(_ c: C, t: Double) {
        let x = 124 + CGFloat(sin(t * 0.7) * 8), hop = CGFloat(max(0, sin(t * 4)) * 2)
        let y = 101 - hop
        c.fill(ell(x, y, 9, 7), with: .color(Ink.rgb(0xFFE08A)))
        c.fill(ell(x + 4, y - 3, 6, 6), with: .color(Ink.rgb(0xFFE08A)))
        c.fill(ell(x + 5, y - 3.5, 1.3, 1.3), with: .color(Ink.eye))
        c.fill(HouseArt.poly([(x + 7, y - 3), (x + 10, y - 2), (x + 7, y - 1.5)]), with: .color(Ink.rgb(0xF59A4A)))
    }
}
