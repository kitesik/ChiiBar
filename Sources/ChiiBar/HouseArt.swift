import ChiiCore
import SwiftUI

/// Everything the house scene needs for one frame. Pure data, so previews can pin any moment.
struct SceneParams {
    var friend: FriendID
    var stage: Int
    var activity: Activity
    var t: Double
    var reveal: (stage: Int, elapsed: Double)?
    var endingElapsed: Double?
    var pokeElapsed: Double?
    var bubble: String?
    var snackIsPudding = false
    var constructionProgress: Double = 0
    var reduceMotion = false
    var arrivalElapsed: Double?
    var previousStage: Int?
    var previousFraction: Double?
    var progressElapsed: Double?
}

/// Doll-house cross-section drawn in a 320 x 210 space, scaled to fit.
enum HouseArt {
    static let size = CGSize(width: 320, height: 210)
    typealias C = GraphicsContext
    static let ell = FriendArt.ell
    static let lw: CGFloat = 1.3
    static func paint(_ c: C, _ p: Path, _ fill: Color) { FriendArt.paint(c, p, fill, lw) }
    static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, r: CGFloat = 0) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }
    static func poly(_ pts: [(CGFloat, CGFloat)]) -> Path {
        var p = Path()
        p.addLines(pts.map { CGPoint(x: $0.0, y: $0.1) })
        p.closeSubpath()
        return p
    }

    static func draw(_ ctx: C, canvas: CGSize, _ p: SceneParams) {
        var c = ctx
        let k = min(canvas.width / size.width, canvas.height / size.height)
        c.translateBy(x: (canvas.width - size.width * k) / 2, y: (canvas.height - size.height * k) / 2)
        c.scaleBy(x: k, y: k)
        c.clip(to: rect(0, 0, size.width, size.height, r: 14))

        HousingJourney.draw(c, p)
    }

    static func anchor(of stage: Int) -> CGPoint {
        let a: [Int: (CGFloat, CGFloat)] = [1: (160, 190), 2: (160, 155), 3: (160, 100), 4: (160, 40), 5: (160, 151),
                                             6: (226, 144), 7: (84, 150), 8: (135, 88), 9: (66, 112),
                                             10: (252, 120), 11: (150, 130), 12: (200, 80)]
        let v = a[stage] ?? (160, 100)
        return CGPoint(x: v.0, y: v.1)
    }

    /// Draws one piece; if it is the one being revealed it pops in from small with overshoot.
    static func piece(_ c: C, _ p: SceneParams, _ stage: Int, anchor: (CGFloat, CGFloat)? = nil, _ body: (C) -> Void) {
        guard let r = p.reveal, r.stage == stage else { body(c); return }
        let e = r.elapsed - 2.4
        if e < 0 {
            var draft = c
            draft.opacity = 0.12 + 0.1 * (r.elapsed / 0.6).rounded(.down)
            body(draft)
            return
        }
        let scale: Double = e < 0.25 ? 0.2 + e / 0.25 * 0.95 : (e < 0.5 ? 1.15 - (e - 0.25) / 0.25 * 0.15 : 1)
        let a = anchor.map { CGPoint(x: $0.0, y: $0.1) } ?? self.anchor(of: stage)
        var d = c
        d.opacity = min(1, e / 0.15)
        d.translateBy(x: a.x, y: a.y)
        d.scaleBy(x: scale, y: scale)
        d.translateBy(x: -a.x, y: -a.y)
        body(d)
    }

    static func construction(_ c: C, _ p: SceneParams, elapsed e: Double) {
        let beat = e.truncatingRemainder(dividingBy: 0.6) / 0.6
        let impact = max(0, 1 - abs(beat - 0.65) * 8)
        var pose = Pose()
        pose.tilt = sin(e * 10) * 0.045
        pose.squish = 1 - impact * 0.06
        FriendArt.draw(c, p.friend, base: CGPoint(x: 146, y: 192), size: 40, pose: pose)
        // A hammer beside the friend's paw swings four times before completion.
        var hammer = c
        hammer.translateBy(x: 172, y: 162)
        hammer.rotate(by: .degrees(-55 + 95 * sin(beat * .pi)))
        paint(hammer, rect(-2, -24, 5, 27, r: 2), Ink.rgb(0xB9835A))
        paint(hammer, rect(-11, -30, 23, 11, r: 3), Ink.rgb(0x8394A8))
        paint(c, rect(180, 183, 35, 6, r: 2), Ink.rgb(0xE7BF8E))
        paint(c, rect(186, 177, 28, 6, r: 2), Ink.rgb(0xD7A774))
        for i in 0..<5 {
            let a = Double(i) * 0.7 + 3.4
            let distance = 8 + beat * 20
            var dust = c
            dust.opacity = impact * 0.8
            dust.fill(ell(193 + cos(a) * distance, 174 + sin(a) * distance, 5, 4),
                      with: .color(Ink.rgb(0xFFF0CF)))
        }
        c.draw(Text(impact > 0.4 ? "뚝딱!" : "뚝딱뚝딱…")
            .font(.system(size: 13, weight: .heavy)).foregroundColor(Ink.rgb(0x9A6A45)),
            at: CGPoint(x: 235, y: 193))
    }

    // MARK: pieces

    static func sky(_ c: C, _ p: SceneParams) {
        let top = Ink.rgb(0xDDEFFF), bottom = Ink.rgb(0xFFF4F6)
        c.fill(rect(0, 0, size.width, size.height), with: .linearGradient(
            Gradient(colors: [top, bottom]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        // two soft clouds
        for (x, y, w) in [(40.0, 26.0, 46.0), (262.0, 34.0, 38.0)] {
            let dx = sin(p.t / 9 + x) * 4
            c.fill(ell(x + dx, y, w, w * 0.36), with: .color(.white.opacity(0.9)))
            c.fill(ell(x + dx - w * 0.18, y - 5, w * 0.5, w * 0.36), with: .color(.white.opacity(0.9)))
        }
        c.fill(ell(296, 18, 18, 18), with: .color(Ink.rgb(0xFFE6A0)))
    }

    static func grass(_ c: C, _ t: Double) {
        let g = rect(-10, 160, size.width + 20, 60)
        c.fill(g, with: .linearGradient(Gradient(colors: [Ink.rgb(0xBFE6A6), Ink.rgb(0xA6D98C)]),
                                        startPoint: CGPoint(x: 0, y: 160), endPoint: CGPoint(x: 0, y: 210)))
        let tufts: [(CGFloat, CGFloat)] = [(18, 178), (52, 196), (92, 186), (128, 204), (196, 200), (232, 184),
                                            (270, 198), (302, 180), (150, 176), (10, 204), (310, 204)]
        for (i, (x, y)) in tufts.enumerated() {
            let sway = CGFloat(sin(t * 1.3 + Double(i)) * 1.2)
            var p = Path()
            p.move(to: CGPoint(x: x - 4, y: y)); p.addLine(to: CGPoint(x: x - 2 + sway, y: y - 7))
            p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + sway, y: y - 9))
            p.move(to: CGPoint(x: x + 4, y: y)); p.addLine(to: CGPoint(x: x + 2 + sway, y: y - 6))
            c.stroke(p, with: .color(Ink.rgb(0x6FB85A)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        for (x, y, col) in [(70.0, 200.0, 0xFFFFFF), (250.0, 190.0, 0xFFD6E2), (300.0, 196.0, 0xFFF2A8)] as [(CGFloat, CGFloat, UInt32)] {
            for i in 0..<5 {
                let a = Double(i) / 5 * 2 * .pi
                c.fill(ell(x + cos(a) * 2.6, y + sin(a) * 2.6, 3.4, 3.4), with: .color(Ink.rgb(col)))
            }
            c.fill(ell(x, y, 2.4, 2.4), with: .color(Ink.rgb(0xF7C948)))
        }
    }

    static func floor(_ c: C) {
        paint(c, rect(34, 158, 252, 10, r: 2), Ink.rgb(0xB9835A))
        let top = poly([(46, 140), (274, 140), (286, 158), (34, 158)])
        paint(c, top, Ink.rgb(0xE7BF8E))
        for i in 1..<9 {
            let f = CGFloat(i) / 9
            var p = Path()
            p.move(to: CGPoint(x: 46 + 228 * f, y: 140))
            p.addLine(to: CGPoint(x: 34 + 252 * f, y: 158))
            c.stroke(p, with: .color(Ink.rgb(0xC99A6A)), lineWidth: 0.8)
        }
    }

    static func walls(_ c: C, roofed: Bool) {
        paint(c, rect(50, 58, 220, 82), Ink.rgb(0xFFF3E0))
        for i in 0..<11 {
            let x = 60 + CGFloat(i) * 20
            c.fill(ell(x, 66 + CGFloat(i % 2) * 14, 3, 3), with: .color(Ink.rgb(0xF6D9C8)))
            c.fill(ell(x + 10, 102 + CGFloat(i % 2) * 14, 3, 3), with: .color(Ink.rgb(0xF6D9C8)))
        }
        c.fill(rect(50, 132, 220, 8), with: .color(Ink.rgb(0xE9D2B4)))
        paint(c, poly([(34, 50), (50, 58), (50, 140), (34, 158)]), Ink.rgb(0xF4E0C4))
        paint(c, poly([(286, 50), (270, 58), (270, 140), (286, 158)]), Ink.rgb(0xF4E0C4))
        if !roofed { c.stroke(rect(50, 58, 220, 82), with: .color(Ink.outline), lineWidth: lw) }
    }

    static func roof(_ c: C) {
        paint(c, poly([(20, 58), (160, 8), (300, 58), (288, 64), (160, 20), (32, 64)]), Ink.rgb(0xE07C6E))
        paint(c, poly([(32, 64), (160, 20), (288, 64), (270, 58), (50, 58)]), Ink.rgb(0xF2A094))
        for i in 1..<6 {
            let f = CGFloat(i) / 6
            var p = Path()
            p.move(to: CGPoint(x: 20 + 140 * f, y: 58 - 50 * f))
            p.addLine(to: CGPoint(x: 32 + 128 * f, y: 64 - 44 * f))
            p.move(to: CGPoint(x: 300 - 140 * f, y: 58 - 50 * f))
            p.addLine(to: CGPoint(x: 288 - 128 * f, y: 64 - 44 * f))
            c.stroke(p, with: .color(Ink.rgb(0xC4655A)), lineWidth: 0.9)
        }
        paint(c, rect(226, 14, 14, 22, r: 2), Ink.rgb(0xC8A27E))
        c.fill(ell(160, 40, 14, 14), with: .color(Ink.rgb(0xFFF3E0)))
        c.stroke(ell(160, 40, 14, 14), with: .color(Ink.outline), lineWidth: lw)
    }

    static func cushion(_ c: C) {
        paint(c, ell(160, 152, 50, 13), Ink.rgb(0xF59AA8))
        c.fill(ell(160, 150, 40, 8), with: .color(Ink.rgb(0xFFC2CB)))
        c.fill(ell(160, 150, 4, 3), with: .color(Ink.rgb(0xD9707F)))
    }

    static func table(_ c: C, pudding: Bool) {
        for x in [212.0, 240.0] as [CGFloat] { paint(c, rect(x - 2.5, 140, 5, 12, r: 1.5), Ink.rgb(0x9A6A45)) }
        paint(c, ell(226, 142, 46, 9), Ink.rgb(0x9A6A45))
        paint(c, ell(226, 139, 46, 9), Ink.rgb(0xC48A5C))
        // a teapot-less cup always sits on the table
        paint(c, rect(238, 129, 7, 7, r: 1.5), Ink.rgb(0xFFFFFF))
        if pudding {
            paint(c, ell(218, 138, 14, 3.5), .white)
            paint(c, poly([(213, 137), (223, 137), (221, 129), (215, 129)]), Ink.rgb(0xFFD66B))
            c.fill(ell(218, 129, 6, 2.4), with: .color(Ink.rgb(0x9A5A2A)))
        }
    }

    static func futon(_ c: C) {
        paint(c, rect(44, 144, 80, 12, r: 3), Ink.rgb(0xFFFFFF))
        paint(c, rect(46, 140, 18, 8, r: 3.5), Ink.rgb(0xF7F2FF))
        paint(c, rect(66, 141, 58, 13, r: 3), Ink.rgb(0xA8C8F0))
        for i in 0..<5 { c.fill(ell(74 + CGFloat(i) * 11, 147 + CGFloat(i % 2) * 2, 3.5, 3.5), with: .color(.white.opacity(0.9))) }
    }

    static func window(_ c: C, t: Double) {
        paint(c, rect(112, 70, 46, 36, r: 2), Ink.rgb(0xCFEBFF))
        c.fill(ell(126 + sin(t / 4) * 6, 82, 14, 6), with: .color(.white))
        var bar = Path()
        bar.move(to: CGPoint(x: 135, y: 70)); bar.addLine(to: CGPoint(x: 135, y: 106))
        bar.move(to: CGPoint(x: 112, y: 88)); bar.addLine(to: CGPoint(x: 158, y: 88))
        c.stroke(bar, with: .color(Ink.rgb(0xFFFFFF)), lineWidth: 2.4)
        c.stroke(rect(112, 70, 46, 36, r: 2), with: .color(Ink.outline), lineWidth: lw)
        paint(c, rect(106, 66, 58, 3, r: 1.5), Ink.rgb(0xB9835A))
        for (x0, dir) in [(108.0, 1.0), (162.0, -1.0)] as [(CGFloat, CGFloat)] {
            var p = Path()
            p.move(to: CGPoint(x: x0, y: 68))
            p.addLine(to: CGPoint(x: x0 + dir * 14, y: 68))
            p.addQuadCurve(to: CGPoint(x: x0 + dir * 8, y: 110), control: CGPoint(x: x0 + dir * 6, y: 90))
            p.addLine(to: CGPoint(x: x0, y: 110))
            p.closeSubpath()
            paint(c, p, Ink.rgb(0xFFB7C5))
            c.fill(ell(x0 + dir * 7, 92, 9, 3), with: .color(Ink.rgb(0xF58FA4)))
        }
    }

    static func lampGlow(_ ctx: C) {
        var c = ctx
        c.clip(to: poly([(34, 50), (286, 50), (286, 158), (34, 158)]))
        c.fill(ell(66, 108, 150, 110), with: .radialGradient(
            Gradient(colors: [Ink.rgb(0xFFE7A0).opacity(0.75), Ink.rgb(0xFFE7A0).opacity(0)]),
            center: CGPoint(x: 66, y: 100), startRadius: 4, endRadius: 72))
    }

    static func lamp(_ c: C) {
        paint(c, ell(66, 140, 18, 5), Ink.rgb(0x9A6A45))
        paint(c, rect(64.5, 96, 3, 44), Ink.rgb(0x9A6A45))
        paint(c, poly([(56, 82), (76, 82), (84, 98), (48, 98)]), Ink.rgb(0xFFE08A))
        c.fill(ell(66, 99, 26, 4), with: .color(Ink.rgb(0xFFF6CF)))
    }

    static func kitchen(_ c: C, steaming: Bool, t: Double) {
        paint(c, rect(236, 104, 32, 36, r: 2), Ink.rgb(0xF4F4F6))
        paint(c, rect(240, 116, 24, 18, r: 2), Ink.rgb(0xDADDE4))
        c.fill(rect(245, 119, 14, 2, r: 1), with: .color(Ink.rgb(0x9FA5B0)))
        for x in [242.0, 250.0, 258.0] as [CGFloat] { c.fill(ell(x, 110, 3.5, 3.5), with: .color(Ink.rgb(0xF07A6A))) }
        paint(c, rect(234, 101, 36, 4, r: 1.5), Ink.rgb(0xC9CDD6))
        // pot
        paint(c, rect(243, 90, 20, 12, r: 3), Ink.rgb(0xF7A6A6))
        paint(c, ell(253, 90, 22, 4), Ink.rgb(0xE88A8A))
        c.fill(ell(253, 87.5, 4, 2.5), with: .color(Ink.outline))
        for x in [240.0, 266.0] as [CGFloat] { paint(c, rect(x - 2, 93, 4, 3, r: 1), Ink.rgb(0xE88A8A)) }
        if steaming { Effects.steam(c, at: CGPoint(x: 253, y: 85), t: t) }
    }

    static func plantAndBooks(_ c: C) {
        // books stacked by the lamp
        let books: [(CGFloat, CGFloat, UInt32)] = [(86, 134, 0x8FB8E8), (88, 129, 0xF5A3B5), (85, 124, 0xA8D58A)]
        for (x, y, col) in books { paint(c, rect(x, y, 22, 5, r: 1), Ink.rgb(col)) }
        // potted plant by the back wall
        for (dx, h) in [(-5.0, 18.0), (0.0, 24.0), (5.0, 17.0)] as [(CGFloat, CGFloat)] {
            var p = c
            p.translateBy(x: 196 + dx, y: 128)
            p.rotate(by: .degrees(Double(dx) * 5))
            paint(p, ell(0, -h / 2, 8, h), Ink.rgb(0x7CC46A))
        }
        paint(c, poly([(189, 127), (203, 127), (201, 140), (191, 140)]), Ink.rgb(0xE59A6B))
    }

    static func frameAndGarland(_ c: C) {
        paint(c, rect(186, 72, 28, 22, r: 1.5), Ink.rgb(0xC48A5C))
        c.fill(rect(189, 75, 22, 16), with: .color(Ink.rgb(0xFFF8EC)))
        Effects.heart(c, at: CGPoint(x: 200, y: 83), size: 9, color: Ink.rgb(0xF58FA4))
        var line = Path()
        line.move(to: CGPoint(x: 52, y: 62))
        line.addQuadCurve(to: CGPoint(x: 268, y: 62), control: CGPoint(x: 160, y: 80))
        c.stroke(line, with: .color(Ink.outline.opacity(0.7)), lineWidth: 0.8)
        let colors: [UInt32] = [0xF58FA4, 0xFFD66B, 0x8FC8F0, 0xA8D58A]
        for i in 0..<11 {
            let f = (CGFloat(i) + 0.5) / 11
            let x = 52 + 216 * f
            let y = 62 + 36 * f * (1 - f)
            paint(c, poly([(x - 5, y), (x + 5, y), (x, y + 9)]), Ink.rgb(colors[i % colors.count]))
        }
    }

    static func badge(_ c: C) {
        paint(c, rect(268, 186, 44, 18, r: 9), Ink.rgb(0xFF8FA8))
        c.draw(Text("완성").font(.system(size: 10, weight: .bold)).foregroundColor(.white), at: CGPoint(x: 290, y: 195))
    }

    static func sparkles(_ c: C, around a: CGPoint, elapsed e: Double) {
        guard e >= 0 && e < 1.6 else { return }
        let fade = 1 - e / 1.6
        for i in 0..<8 {
            let ang = Double(i) / 8 * 2 * .pi + 0.3
            let r = 14 + e * 34
            Effects.sparkle(c, at: CGPoint(x: a.x + cos(ang) * r, y: a.y + sin(ang) * r * 0.75),
                            size: 7 * (1 - e / 2), opacity: fade)
        }
        c.draw(Text("짠!").font(.system(size: 16, weight: .heavy)).foregroundColor(Ink.rgb(0xFF6F91).opacity(fade)),
               at: CGPoint(x: a.x, y: a.y - 24 - e * 10))
    }
}

enum Effects {
    typealias C = GraphicsContext

    static func heart(_ c: C, at p: CGPoint, size s: CGFloat, color: Color) {
        var h = Path()
        h.move(to: CGPoint(x: p.x, y: p.y + s * 0.35))
        h.addCurve(to: CGPoint(x: p.x - s * 0.5, y: p.y - s * 0.1), control1: CGPoint(x: p.x - s * 0.15, y: p.y + s * 0.15),
                   control2: CGPoint(x: p.x - s * 0.5, y: p.y + s * 0.1))
        h.addArc(center: CGPoint(x: p.x - s * 0.25, y: p.y - s * 0.12), radius: s * 0.25, startAngle: .degrees(180),
                 endAngle: .degrees(0), clockwise: false)
        h.addArc(center: CGPoint(x: p.x + s * 0.25, y: p.y - s * 0.12), radius: s * 0.25, startAngle: .degrees(180),
                 endAngle: .degrees(0), clockwise: false)
        h.addCurve(to: CGPoint(x: p.x, y: p.y + s * 0.35), control1: CGPoint(x: p.x + s * 0.5, y: p.y + s * 0.1),
                   control2: CGPoint(x: p.x + s * 0.15, y: p.y + s * 0.15))
        c.fill(h, with: .color(color))
    }

    static func sparkle(_ c: C, at p: CGPoint, size s: CGFloat, opacity: Double) {
        var d = Path()
        d.move(to: CGPoint(x: p.x, y: p.y - s))
        d.addQuadCurve(to: CGPoint(x: p.x + s, y: p.y), control: CGPoint(x: p.x, y: p.y))
        d.addQuadCurve(to: CGPoint(x: p.x, y: p.y + s), control: CGPoint(x: p.x, y: p.y))
        d.addQuadCurve(to: CGPoint(x: p.x - s, y: p.y), control: CGPoint(x: p.x, y: p.y))
        d.addQuadCurve(to: CGPoint(x: p.x, y: p.y - s), control: CGPoint(x: p.x, y: p.y))
        c.fill(d, with: .color(Ink.rgb(0xFFD24A).opacity(opacity)))
    }

    static func steam(_ c: C, at p: CGPoint, t: Double) {
        for i in 0..<3 {
            let ph = (t * 0.6 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            var s = Path()
            let x = p.x + CGFloat(i - 1) * 5, y = p.y - CGFloat(ph) * 16
            s.move(to: CGPoint(x: x, y: y))
            s.addQuadCurve(to: CGPoint(x: x, y: y - 7), control: CGPoint(x: x + 3, y: y - 3.5))
            c.stroke(s, with: .color(.white.opacity(0.95 * (1 - ph))), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            c.stroke(s, with: .color(Ink.outline.opacity(0.25 * (1 - ph))), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        }
    }

    static func hearts(_ c: C, from p: CGPoint, elapsed e: Double) {
        guard e < 1.4 else { return }
        for i in 0..<4 {
            let d = e - Double(i) * 0.12
            guard d > 0 else { continue }
            let x = p.x + CGFloat(i - 2) * 9 + CGFloat(sin(d * 6 + Double(i)) * 3)
            heart(c, at: CGPoint(x: x, y: p.y - CGFloat(d) * 40), size: 9, color: Ink.rgb(0xFF7F9E).opacity(max(0, 1 - d / 1.3)))
        }
    }

    static func zzz(_ c: C, from p: CGPoint, t: Double) {
        for i in 0..<3 {
            let ph = (t * 0.35 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            let size = 8 + ph * 6
            c.draw(Text("z").font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundColor(Ink.rgb(0x7F8FB8).opacity(1 - ph * 0.8)),
                   at: CGPoint(x: p.x + CGFloat(ph) * 18, y: p.y - CGFloat(ph) * 22))
        }
    }

    static func confetti(_ c: C, elapsed e: Double) {
        guard e < 7 else { return }
        let colors: [UInt32] = [0xFF8FA8, 0xFFD66B, 0x8FC8F0, 0xA8D58A, 0xC9A8F0]
        var rng = SeededRNG(seed: 99)
        for i in 0..<46 {
            let x0 = Double(rng.next() % 320), speed = 40 + Double(rng.next() % 50), delay = Double(rng.next() % 100) / 100
            let d = e - delay
            guard d > 0 else { continue }
            let y = -10 + d * speed
            guard y < 215 else { continue }
            var p = c
            p.translateBy(x: x0 + sin(d * 3 + Double(i)) * 8, y: y)
            p.rotate(by: .radians(d * 4 + Double(i)))
            if i % 6 == 0 {
                heart(p, at: .zero, size: 10, color: Ink.rgb(0xFF6F91))
            } else {
                p.fill(Path(CGRect(x: -3, y: -1.6, width: 6, height: 3.2)), with: .color(Ink.rgb(colors[i % colors.count])))
            }
        }
    }

    static func bubble(_ c: C, text: String, near head: CGPoint) {
        let label = c.resolve(Text(text).font(.system(size: 11, weight: .semibold)).foregroundColor(Ink.rgb(0x4A4048)))
        let sz = label.measure(in: CGSize(width: 200, height: 40))
        let w = sz.width + 16, h = sz.height + 8
        var x = head.x + 14, y = head.y - h - 6
        if x + w > 314 { x = head.x - 14 - w }
        x = max(6, x); y = max(6, y)
        let box = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: h / 2)
        var tail = Path()
        let tx = min(max(head.x, x + 10), x + w - 10)
        tail.move(to: CGPoint(x: tx - 5, y: y + h - 1))
        tail.addLine(to: CGPoint(x: tx, y: y + h + 6))
        tail.addLine(to: CGPoint(x: tx + 5, y: y + h - 1))
        c.fill(tail, with: .color(.white))
        c.fill(box, with: .color(.white))
        c.stroke(box, with: .color(Ink.outline.opacity(0.5)), lineWidth: 1)
        c.draw(label, at: CGPoint(x: x + w / 2, y: y + h / 2))
    }
}
