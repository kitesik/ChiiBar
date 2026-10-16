import ChiiCore
import SwiftUI

/// Capsule machine, drawn in a 320 x 300 space.
/// Discovery: question mark, forming silhouette, light, then a spring landing.
/// Timing reference: kitesik/EvoBar HatchCeremonyView (1.3, 2.4, 2.75, 5 seconds).
enum GachaArt {
    static let size = CGSize(width: 320, height: 300)
    static let revealAt = 2.75
    static let finishAt = 5.0
    typealias C = GraphicsContext
    static let ell = FriendArt.ell
    static let paint = HouseArt.paint

    static func capsuleColor(_ rarity: Int) -> Color {
        rarity == 3 ? Ink.rgb(0xFFCF4A) : (rarity == 2 ? Ink.rgb(0x8FC8F0) : Ink.rgb(0xFF9FB2))
    }

    /// `t == nil`: idle machine waiting for a draw.
    static func draw(_ ctx: C, canvas: CGSize, t: Double?, idleTime: Double, result: DrawResult?) {
        var c = ctx
        let k = min(canvas.width / size.width, canvas.height / size.height)
        c.translateBy(x: (canvas.width - size.width * k) / 2, y: (canvas.height - size.height * k) / 2)
        c.scaleBy(x: k, y: k)
        guard let t, let result else {
            machine(c, handle: 0, jiggle: idleTime, shaking: false)
            return
        }
        let glow = Ink.rgb(0xFFD779) // Before reveal, neither shape nor color depends on the winner.
        c.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Ink.rgb(0x312B40)))
        if t < revealAt {
            let progress = min(1, max(0, (t - 1.3) / 1.1))
            let center = CGPoint(x: 160, y: 155)
            c.fill(ell(160, 155, 150 + progress * 70, 150 + progress * 70), with: .radialGradient(
                Gradient(colors: [glow.opacity(0.3 + progress * 0.5), glow.opacity(0)]),
                center: center, startRadius: 5, endRadius: 110))
            var mystery = c
            mystery.translateBy(x: 160 + sin(t * 7) * (1.5 + progress * 1.5), y: 211 + sin(t * 5) * 2)
            mystery.rotate(by: .degrees(sin(t * 7) * (2 + progress * 3)))
            MysteryDrawShape.draw(mystery, elapsed: t)
            mystery.draw(Text("?").font(.system(size: 42, weight: .heavy, design: .rounded)).foregroundColor(.white),
                         at: CGPoint(x: 0, y: -56))
            c.draw(Text(t < 1.3 ? "어떤 친구가 찾아올까요?" : "두근두근… 곧 만나요!")
                .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.9)),
                at: CGPoint(x: 160, y: 270))
            for i in 0..<10 {
                let a = Double(i) / 10 * .pi * 2 + t
                let radius = 100 - progress * 45
                Effects.sparkle(c, at: CGPoint(x: 160 + cos(a) * radius, y: 155 + sin(a) * radius),
                                size: 2 + progress * 3, opacity: 0.3 + progress * 0.7)
            }
        } else {
            reveal(c, result: result, elapsed: t - revealAt)
        }
        let flash: Double
        if t >= 2.4 && t < revealAt { flash = (t - 2.4) / 0.35 }
        else if t >= revealAt && t < 3.25 { flash = 1 - (t - revealAt) / 0.5 }
        else { flash = 0 }
        if flash > 0 { c.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(flash))) }
    }

    static func machine(_ c: C, handle: Double, jiggle: Double, shaking: Bool) {
        var c = c
        if shaking { c.translateBy(x: sin(handle * 6) * 1.5, y: 0) }
        paint(c, Path(roundedRect: CGRect(x: 92, y: 150, width: 136, height: 104), cornerRadius: 14), Ink.rgb(0xFF9FB2))
        paint(c, Path(roundedRect: CGRect(x: 104, y: 138, width: 112, height: 16), cornerRadius: 6), Ink.rgb(0xFFC2CF))
        // glass dome with capsules
        let dome = ell(160, 86, 136, 128)
        c.fill(dome, with: .color(Ink.rgb(0xE6F5FF)))
        var inside = c
        inside.clip(to: dome)
        let spots: [(CGFloat, CGFloat, Int)] = [(118, 118, 1), (146, 124, 2), (176, 120, 1), (204, 116, 3), (130, 96, 2),
                                                 (160, 100, 1), (190, 94, 1), (110, 80, 1), (146, 74, 3), (178, 70, 2), (206, 84, 1)]
        for (i, (x, y, r)) in spots.enumerated() {
            let j = CGFloat(sin(jiggle * 2 + Double(i) + handle * 2) * (handle > 0 ? 3 : 0.8))
            capsule(inside, at: CGPoint(x: x + j, y: y - j * 0.5), scale: 0.62, angle: Double(i) * 0.7, open: 0, color: capsuleColor(r))
        }
        c.fill(ell(130, 56, 30, 18), with: .color(.white.opacity(0.7)))
        c.stroke(dome, with: .color(Ink.outline), lineWidth: 1.6)
        paint(c, Path(roundedRect: CGRect(x: 150, y: 16, width: 20, height: 12), cornerRadius: 4), Ink.rgb(0xFF9FB2))
        // label, chute and handle
        c.draw(Text("뽑기").font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundColor(.white),
               at: CGPoint(x: 160, y: 172))
        paint(c, Path(roundedRect: CGRect(x: 176, y: 210, width: 40, height: 30), cornerRadius: 8), Ink.rgb(0x6E5560))
        paint(c, ell(126, 214, 40, 40), .white)
        var h = c
        h.translateBy(x: 126, y: 214)
        h.rotate(by: .radians(handle))
        paint(h, Path(roundedRect: CGRect(x: -17, y: -4.5, width: 34, height: 9), cornerRadius: 4.5), Ink.rgb(0xFFD66B))
        h.fill(ell(0, 0, 7, 7), with: .color(Ink.outline))
        if shaking {
            // motion arc around the turning handle
            var arc = Path()
            arc.addArc(center: CGPoint(x: 126, y: 214), radius: 28, startAngle: .radians(handle - 1.6),
                       endAngle: .radians(handle), clockwise: false)
            c.stroke(arc, with: .color(Ink.rgb(0xFF6F91)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [5, 4]))
        }
    }

    static func capsule(_ c: C, at p: CGPoint, scale: Double, angle: Double, open: Double, color: Color) {
        var c = c
        c.translateBy(x: p.x, y: p.y)
        c.rotate(by: .radians(angle))
        c.scaleBy(x: scale, y: scale)
        let r: CGFloat = 22
        var bottom = Path()
        bottom.addArc(center: .zero, radius: r, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        bottom.closeSubpath()
        paint(c, bottom, .white)
        var top = c
        top.translateBy(x: -r, y: 0)
        top.rotate(by: .radians(-open * 1.6))
        top.translateBy(x: r, y: -open * 10)
        var tp = Path()
        tp.addArc(center: .zero, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        tp.closeSubpath()
        paint(top, tp, color)
        top.fill(ell(-8, -11, 10, 6), with: .color(.white.opacity(0.6)))
    }

    static func burst(_ c: C, at p: CGPoint, amount a: Double) {
        c.fill(ell(p.x, p.y, 40 + a * 80, 40 + a * 80), with: .radialGradient(
            Gradient(colors: [Ink.rgb(0xFFF6CF).opacity(0.9 * a), Ink.rgb(0xFFF6CF).opacity(0)]),
            center: p, startRadius: 0, endRadius: 20 + a * 40))
    }

    static func reveal(_ c: C, result: DrawResult, elapsed e: Double) {
        let pop = 1 + 0.22 * exp(-e * 4) * cos(e * 11)
        c.fill(ell(160, 170, 220, 220), with: .radialGradient(
            Gradient(colors: [Ink.rgb(0xFFF6CF), Ink.rgb(0xFFF6CF).opacity(0)]),
            center: CGPoint(x: 160, y: 170), startRadius: 10, endRadius: 110))
        var f = c
        f.translateBy(x: 160, y: 232)
        f.scaleBy(x: pop, y: pop)
        var pose = Pose()
        pose.arms = .up
        pose.mouth = .open
        pose.eyes = result.outcome == .newFriend ? .open : .happy
        FriendArt.draw(f, result.friend, base: .zero, size: 76, pose: pose)
        for i in 0..<6 {
            let ang = Double(i) / 6 * 2 * .pi + e
            Effects.sparkle(c, at: CGPoint(x: 160 + cos(ang) * 92, y: 170 + sin(ang) * 70), size: 7, opacity: 0.9)
        }
        c.draw(Text(stars(result.friend.rarity)).font(.system(size: 20, weight: .bold)).foregroundColor(Ink.rgb(0xFFB800)),
               at: CGPoint(x: 160, y: 46))
        c.draw(Text(result.friend.name).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundColor(.white),
               at: CGPoint(x: 160, y: 72))
        let line: String
        let detail: String
        switch result.outcome {
        case .newFriend:
            line = "새로운 친구가 찾아왔어요"; detail = "이제 이 친구의 집도 지을 수 있어요"
        case .gift(let stage):
            line = "앗, 이미 만난 친구네요!"
            detail = "대신 \(result.friend.name)의 집 경험치 +\(TokenFormat.short(Tuning.duplicateGift(forStage: stage)))를 드릴게요."
        case .ticketBack:
            line = "이 친구의 집은 이미 완성됐어요"; detail = "사용한 뽑기권 1장을 돌려드렸어요"
        }
        c.draw(Text(line).font(.system(size: 12, weight: .bold)).foregroundColor(.white), at: CGPoint(x: 160, y: 260))
        c.draw(Text(detail).font(.system(size: 11, weight: .medium)).foregroundColor(Ink.rgb(0xFFE5A9)),
               at: CGPoint(x: 160, y: 281))
    }
}
