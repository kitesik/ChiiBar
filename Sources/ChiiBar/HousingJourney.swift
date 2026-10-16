import ChiiCore
import SwiftUI

/// All thirteen homes share one ground line, making construction fill legible.
enum HousingJourney {
    typealias C = GraphicsContext
    static let rect = HouseArt.rect
    static let poly = HouseArt.poly
    static let ink = Ink.rgb(0x605249)
    static func box(_ c: C, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: UInt32, r: CGFloat = 2) {
        let p = rect(x, y, w, h, r)
        c.fill(p, with: .color(Ink.rgb(color)))
        c.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
    }
    static func shape(_ c: C, _ points: [(CGFloat, CGFloat)], _ color: UInt32) {
        let p = poly(points)
        c.fill(p, with: .color(Ink.rgb(color)))
        c.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
    }
    static func line(_ c: C, _ x: CGFloat, _ y: CGFloat, _ xx: CGFloat, _ yy: CGFloat, color: UInt32 = 0x605249) {
        var p = Path(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: xx, y: yy))
        c.stroke(p, with: .color(Ink.rgb(color)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
    }
    static func draw(_ c: C, _ p: SceneParams) {
        if DioramaArt.draw(c, p) { return }
        var environment = p
        if p.reduceMotion { environment.t = 0 }
        HouseArt.sky(c, environment)
        HouseArt.grass(c, environment.t)
        // Distant skyline appears when the journey reaches the city.
        if p.stage >= 9 {
            var distant = c; distant.opacity = 0.15
            for i in 0..<9 {
                box(distant, CGFloat(i * 39), CGFloat(96 - i % 3 * 16), 28, CGFloat(65 + i % 3 * 16), 0x657F9C)
            }
        }
        var home = c
        home.translateBy(x: 25, y: 3)
        let reveal = p.reduceMotion ? 1 : ArrivalMotion.ease((p.reveal?.elapsed ?? 1) / 0.85)
        if let previous = p.previousStage, reveal < 1 {
            var old = home; old.opacity = 1 - reveal
            building(old, stage: previous)
        }
        var settled = home
        settled.opacity = reveal
        settled.translateBy(x: 0, y: (1 - reveal) * 7)
        building(settled, stage: p.stage)
        if p.stage < HousePlan.lastStage && p.constructionProgress > 0 {
            // The next residence is constructed from the foundation upwards.
            var blueprint = home; blueprint.opacity = 0.13
            building(blueprint, stage: p.stage + 1)
            var next = home
            let h = CGFloat(p.constructionProgress) * 156
            next.clip(to: rect(78, 170 - h, 194, h, 0))
            building(next, stage: p.stage + 1)
            if p.constructionProgress < 0.98 {
                let y = 170 - h
                line(home, 89, y, 252, y, color: 0xE3A545)
                for x in stride(from: 95, through: 245, by: 25) {
                    home.fill(FriendArt.ell(CGFloat(x), y, 3, 3), with: .color(Ink.rgb(0xFFE7A4)))
                }
            }
        }
        let asleep = p.activity == .napGround || p.activity == .napFuton
        let celebrating = p.pokeElapsed != nil || p.endingElapsed != nil
        var pose = Pose()
        pose.blinking = !p.reduceMotion && !asleep && !celebrating && ArrivalMotion.blinking(at: p.t, friend: p.friend)
        pose.eyes = asleep ? .closed : .open
        let elapsed = p.pokeElapsed ?? p.arrivalElapsed ?? ArrivalMotion.elapsed(at: p.t, friend: p.friend)
        let moves = !p.reduceMotion && (!asleep || celebrating)
        let pop = moves ? ArrivalMotion.spring(elapsed: elapsed) : 1
        let lift = moves ? ArrivalMotion.lift(elapsed: elapsed) : 0
        pose.squish = moves ? pop * (1 + sin(p.t * 1.8) * 0.008) : 1
        pose.tilt = moves ? sin(p.t * 1.35) * 0.012 : 0
        if celebrating { pose.eyes = .happy; pose.arms = .up }
        c.fill(FriendArt.ell(60, 196, 33 - lift * 0.5, 5), with: .color(.black.opacity(0.09 - lift * 0.003)))
        FriendArt.draw(c, p.friend, base: CGPoint(x: 60, y: 195 - lift), size: 57, pose: pose)
        if !p.reduceMotion {
            if let e = p.pokeElapsed { Effects.hearts(c, from: CGPoint(x: 60, y: 122), elapsed: e) }
            if asleep && !celebrating { Effects.zzz(c, from: CGPoint(x: 83, y: 105), t: p.t) }
        }
        let caption = p.stage == 13 ? "하늘 위 우리 집" : HousePlan.name(of: p.stage)
        c.draw(Text(caption).font(.system(size: 10, weight: .bold)).foregroundColor(ink), at: CGPoint(x: 210, y: 194))
        if !p.reduceMotion, let e = p.endingElapsed { Effects.confetti(c, elapsed: e) }
        if !p.reduceMotion, let r = p.reveal { HouseArt.sparkles(c, around: CGPoint(x: 205, y: 90), elapsed: r.elapsed) }
        if let b = p.bubble { Effects.bubble(c, text: b, near: CGPoint(x: 60, y: 112)) }
    }

    static func windows(_ c: C, x: CGFloat, y: CGFloat, columns: Int, rows: Int, spacing: CGFloat = 23) {
        for row in 0..<rows { for col in 0..<columns {
            let xx = x + CGFloat(col) * spacing, yy = y + CGFloat(row) * 22
            box(c, xx, yy, 13, 15, (row + col) % 3 == 0 ? 0xFFE6AC : 0xC1E9F2, r: 1)
            line(c, xx + 6.5, yy, xx + 6.5, yy + 15, color: 0x8AABBC)
        } }
    }
    static func building(_ c: C, stage: Int) {
        // Grounds and approach, increasingly cared for.
        c.fill(FriendArt.ell(171, 170, 183, 15), with: .color(.black.opacity(0.09)))
        if stage == 1 {
            shape(c, [(117,163),(213,163),(229,173),(105,173)], 0xD1B491)
            box(c, 144, 153, 52, 15, 0xC6D8A8, r: 7)
            box(c, 143, 153, 16, 15, 0xF7EAD6, r: 6)
            line(c, 221, 167, 228, 154); line(c, 223, 154, 232, 167)
            return
        }
        if stage <= 8 {
            if stage >= 6 {
                box(c, 93, 151, 164, 21, 0xA6C889, r: 8)
                shape(c, [(169,149),(187,149),(198,172),(157,172)], 0xE8D8B8)
                for x in [105.0, 233.0] {
                    box(c, x, 148, 10, 13, 0xBD805E)
                    c.fill(FriendArt.ell(x+5, 145, 19, 17), with: .color(Ink.rgb(0x648D57)))
                }
            }
            let traditional = stage == 7 || stage == 8
            box(c, 112, 105, 125, 56, stage == 2 ? 0xB8936A : traditional ? 0xF6E7CC : 0xE8AD8D)
            if stage == 2 {
                for x in stride(from: 117, through: 233, by: 12) { line(c, CGFloat(x), 107, CGFloat(x), 160, color: 0x866446) }
                shape(c, [(101,111),(173,62),(249,111)], 0xB4A375)
                for x in stride(from: 112, through: 242, by: 10) { line(c, 173, 67, CGFloat(x), 110, color: 0x8F7D52) }
            } else if traditional {
                shape(c, [(94,108),(113,99),(130,76),(219,76),(238,99),(256,108)], stage == 7 ? 0xC8AB62 : 0x617380)
                if stage == 7 {
                    for x in stride(from: 104, through: 245, by: 7) { line(c, CGFloat(x), 101, CGFloat(x+3), 108, color: 0x8E743E) }
                } else {
                    for x in stride(from: 124, through: 226, by: 9) { line(c, CGFloat(x), 79, CGFloat(x-6), 103, color: 0xB4C3C5) }
                    box(c, 104, 157, 142, 6, 0xB3ADA1)
                }
                for x in [115.0, 152.0, 195.0, 231.0] { box(c, x, 111, 4, 46, 0x926B4D, r: 0) }
            } else {
                for y in stride(from: 113, through: 153, by: 10) {
                    line(c, 113, CGFloat(y), 236, CGFloat(y), color: 0xC3836B)
                    for x in stride(from: 117 + (y % 20 == 3 ? 0 : 9), through: 230, by: 20) {
                        line(c, CGFloat(x), CGFloat(y-9), CGFloat(x), CGFloat(y), color: 0xC3836B)
                    }
                }
                if stage >= 4 { box(c, 210, 72, 14, 31, 0xBF7D6A); box(c, 207, 70, 20, 6, 0xDFC1A8) }
                shape(c, [(102,108),(173,66),(247,108)], 0xA86F62)
                line(c, 117, 99, 233, 99, color: 0xD6A697)
            }
            box(c, 164, 124, 22, 37, traditional ? 0xEEE1C4 : 0x987154)
            windows(c, x: 125, y: 121, columns: 1, rows: 1)
            windows(c, x: 207, y: 121, columns: 1, rows: 1)
            if stage >= 5 {
                for x in stride(from: 96, through: 251, by: 12) where x < 153 || x > 194 {
                    box(c, CGFloat(x), 150, 5, 22, stage == 8 ? 0xAE9A7A : 0xF6EADD)
                }
                box(c, 94, 157, 58, 4, 0xE2CCAC); box(c, 196, 157, 62, 4, 0xE2CCAC)
            }
            return
        }
        if stage == 9 {
            box(c, 111, 106, 135, 58, 0xF5F1E6)
            box(c, 126, 80, 99, 40, 0xDAE4E6)
            box(c, 121, 77, 109, 7, 0x6B7C83)
            box(c, 143, 88, 68, 23, 0xB3DCE4)
            box(c, 124, 127, 53, 29, 0xB3DCE4)
            box(c, 204, 125, 21, 39, 0x957A62)
            return
        }
        let floors = stage == 10 ? 3 : stage == 11 ? 4 : 6
        let top: CGFloat = stage == 10 ? 91 : stage == 11 ? 67 : 23
        box(c, 124, top, 111, 164-top, stage >= 12 ? 0x8DB1C7 : 0xE3DED3)
        box(c, 118, top-5, 123, 6, stage >= 12 ? 0x526B84 : 0x9C887C)
        windows(c, x: 136, y: top+8, columns: 4, rows: floors, spacing: 24)
        box(c, 166, 144, 25, 20, 0x687F90)
        if stage == 10 {
            for y in [119.0,141.0] { box(c, 119, y, 121, 4, 0xB6AAA0) }
        }
        if stage >= 12 {
            box(c, 240, 61, 16, 103, 0xB7CEDB)
            for y in stride(from: 69, through: 153, by: 12) { line(c, 241, CGFloat(y), 255, CGFloat(y), color: 0xE2EFF4) }
        }
        if stage == 13 {
            box(c, 136, 7, 86, 17, 0xF6E9C9)
            box(c, 148, 10, 38, 12, 0xB0DDE6)
            box(c, 192, 15, 25, 6, 0x8EC3CB)
            box(c, 130, 24, 99, 4, 0xD5B667)
            for x in [134.0,222.0] {
                box(c, x, 16, 6, 8, 0xB89062)
                c.fill(FriendArt.ell(x+3,13,12,12), with: .color(Ink.rgb(0x638966)))
            }
        }
    }
}
