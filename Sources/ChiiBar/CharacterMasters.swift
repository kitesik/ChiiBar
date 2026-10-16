import ChiiCore
import SwiftUI

/// Redrawn character-specific silhouettes. Coordinates are head widths from the feet.
enum CharacterMasters {
    typealias C = GraphicsContext
    static let oval = OriginalSprites.oval
    static let curve = OriginalSprites.curve
    static let paint = OriginalSprites.paint
    static let line = OriginalSprites.line
    static let dark = Ink.rgb(0x49352F)
    static func draw(_ ctx: C, friend f: FriendID, pose: Pose, faceOnly: Bool) {
        var c = ctx
        if faceOnly { c.translateBy(x: 0, y: -0.04) }
        let fur = f.fur
        let a = f == .hachiware ? Ink.rgb(0x8EBAD7) : f.accent
        // Character-specific tails, ears and mane sit behind the single round silhouette.
        if !faceOnly && f == .momonga {
            paint(c, curve([(0.25,-0.10),(0.94,-0.01),(0.89,-1.04),(0.54,-0.96),
                            (0.31,-0.89),(0.44,-0.54),(0.30,-0.44)]), .white, 0.025)
            for i in 0..<6 {
                let y = -0.84 + Double(i)*0.11
                line(c, curve([(0.67,y),(0.75,y+0.02),(0.79,y+0.07),(0.78,y+0.1)]), 0.035, a)
            }
        }
        if !faceOnly && f == .anoko {
            let tail = curve([(0.25,-0.15),(0.93,-0.01),(0.77,-0.85),(0.53,-0.60)])
            line(c, tail, 0.21, dark); line(c, tail, 0.16, Ink.rgb(0xA5BC85))
        }
        if f == .shisa {
            for side in [-1.0,1.0] {
                for i in 0..<5 {
                    paint(c, oval(side * (0.46 + sin(Double(i))*0.04), -0.94+Double(i)*0.13, 0.23, 0.25), a, 0.024)
                }
            }
        }
        for side in [-1.0,1.0] {
            var e = c
            switch f {
            case .usagi:
                e.translateBy(x: side*0.19, y: -1.06)
                e.rotate(by: .radians(side*0.035+pose.earTilt))
                paint(e, oval(0,-0.29,0.145,0.69), fur, 0.028)
                line(e, curve([(0,-0.52),(0,-0.4),(0,-0.22),(0,-0.12)]), 0.045, Ink.rgb(0xE8B3A0))
            case .hachiware:
                paint(e, curve([(side*0.46,-0.94),(side*0.48,-1.12),(side*0.43,-1.28),(side*0.38,-1.26),
                                (side*0.31,-1.21),(side*0.25,-1.13),(side*0.20,-1.09)]), a, 0.029)
            case .chiikawa:
                paint(e, oval(side*0.29,-1.13,0.18,0.20), fur, 0.029)
            case .momonga:
                paint(e, curve([(side*0.35,-1.03),(side*0.56,-1.09),(side*0.49,-1.32),(side*0.39,-1.21),
                                (side*0.32,-1.25),(side*0.29,-1.12),(side*0.35,-1.03)]), .white, 0.026)
                line(e, curve([(side*0.39,-1.11),(side*0.45,-1.12),(side*0.44,-1.18),(side*0.41,-1.18)]), 0.015, a)
            case .shisa:
                paint(e, curve([(side*0.24,-1.08),(side*0.30,-1.28),(side*0.53,-1.29),(side*0.47,-1.07)]), fur, 0.025)
            case .anoko:
                paint(e, oval(side*0.36,-1.07,0.19,0.20), fur, 0.026)
            default: break
            }
        }
        let head = curve([(-0.49,-0.75),(-0.52,-1.01),(-0.31,-1.15),(0,-1.15),
                          (0.31,-1.15),(0.52,-1.01),(0.49,-0.75),
                          (0.50,-0.53),(0.39,-0.46),(0.35,-0.34),
                          (0.32,-0.12),(0.24,-0.07),(0,-0.07),
                          (-0.24,-0.07),(-0.32,-0.12),(-0.35,-0.34),
                          (-0.39,-0.46),(-0.50,-0.53),(-0.49,-0.75)])
        let face = curve([(-0.49,-0.75),(-0.52,-1.01),(-0.31,-1.15),(0,-1.15),
                          (0.31,-1.15),(0.52,-1.01),(0.49,-0.75),
                          (0.49,-0.47),(0.26,-0.35),(0,-0.35),
                          (-0.26,-0.35),(-0.49,-0.47),(-0.49,-0.75)])
        if !faceOnly {
            for side in [-1.0,1.0] { paint(c, oval(side*0.19,-0.06,0.10,0.12), fur, 0.026) }
        }
        let silhouette = faceOnly ? face : head
        paint(c, silhouette, fur, 0.028)
        var mask = c; mask.clip(to: silhouette)
        if f == .hachiware {
            mask.fill(curve([(-0.55,-1.3),(-0.2,-1.27),(0.2,-1.27),(0.55,-1.3),
                            (0.56,-0.74),(0.21,-0.76),(0,-1.0),
                            (-0.21,-0.76),(-0.56,-0.74),(-0.55,-1.3)]), with: .color(a))
        }
        if f == .kurimanju {
            mask.fill(oval(0,-1.14,0.91,0.39), with: .color(a))
            line(c, curve([(-0.43,-1.01),(-0.18,-0.91),(0.18,-0.91),(0.43,-1.01)]), 0.025, dark)
        }
        if f == .momonga {
            mask.fill(curve([(-0.51,-1.22),(-0.20,-1.3),(0.20,-1.3),(0.51,-1.22),
                            (0.50,-0.85),(0.22,-0.99),(0,-1.05),
                            (-0.22,-0.99),(-0.50,-0.85),(-0.51,-1.22)]), with: .color(a.opacity(0.65)))
        }
        if f == .anoko {
            paint(c, curve([(-0.065,-1.12),(-0.05,-1.27),(-0.015,-1.38),(0.01,-1.37),
                            (0.05,-1.30),(0.065,-1.19),(0.065,-1.12)]), Ink.rgb(0xDFC58C), 0.024)
            for side in [-1.0, 1.0] {
                for i in 0..<4 {
                    let y = -0.9 + Double(i)*0.14
                    line(c, curve([(side*0.48,y),(side*0.53,y+0.04),(side*0.54,y+0.08),(side*0.48,y+0.1)]), 0.021, dark)
                }
            }
        }
        if f == .kani {
            for side in [-1.0,1.0] {
                var claw = c; claw.translateBy(x: side*0.30, y: -1.18)
                claw.rotate(by: .radians(side*0.2+pose.earTilt))
                paint(claw, curve([(-0.10,0.06),(-0.20,-0.08),(-0.10,-0.29),(-0.055,-0.17),
                                  (-0.01,-0.32),(0.06,-0.28),(0.06,-0.16),
                                  (0.16,-0.23),(0.20,-0.03),(0.10,0.06)]), Ink.rgb(0xECA7BB), 0.026)
            }
        }
        if f == .rakko {
            // Ragged cream fur, forehead star, white cape and tied collar.
            for i in 0..<9 {
                let x = -0.36+Double(i)*0.09
                line(c, curve([(x,-1.14),(x-0.01,-1.20),(x+0.01,-1.19),(x+0.02,-1.15)]), 0.015, dark)
            }
            var star = Path()
            for i in 0..<10 {
                let angle = Double(i)*Double.pi/5-Double.pi/2
                let r = i % 2 == 0 ? 0.085 : 0.036
                let pt = CGPoint(x: -0.22+cos(angle)*r,y: -0.96+sin(angle)*r)
                if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
            }
            star.closeSubpath(); paint(c, star, Ink.rgb(0xDDC27A), 0.018)
            if !faceOnly {
                paint(c, curve([(-0.35,-0.36),(-0.44,-0.25),(-0.45,-0.15),(-0.48,-0.07),
                                (-0.19,-0.15),(0.19,-0.15),(0.48,-0.07),
                                (0.45,-0.15),(0.44,-0.25),(0.35,-0.36)]), .white, 0.018)
                paint(c, oval(0,-0.32,0.72,0.12), .white, 0.018)
                line(c, curve([(-0.33,-0.31),(-0.1,-0.26),(0.1,-0.26),(0.33,-0.31)]), 0.012, a)
            }
        }
        for side in [-1.0,1.0] {
            let x = side * 0.16, y = -0.77
            if pose.eyes == .closed || pose.eyes == .happy {
                let bend = pose.eyes == .happy ? -0.045 : 0.035
                line(c, curve([(x-0.055,y),(x-0.025,y+bend),(x+0.025,y+bend),(x+0.055,y)]), 0.025, dark)
            } else if f == .shisa {
                paint(c, oval(x,-0.80,0.10,0.08), a, 0.016)
                line(c, curve([(x-0.06,-0.84),(x-0.03,-0.94),(x+0.06,-0.94),(x+0.045,-0.85)]), 0.037, a)
                c.fill(oval(x,-0.76,0.035,0.035), with: .color(dark))
            } else {
                let w: CGFloat = f == .momonga ? 0.14 : f == .anoko ? 0.125 : f == .chiikawa ? 0.108 : f == .kurimanju ? 0.06 : 0.073
                c.fill(oval(x,y,w,w*1.05), with: .color(dark))
                c.fill(oval(x-0.006,y-w*0.20,w*0.48,w*0.40), with: .color(.white))
                if f == .chiikawa || f == .momonga {
                    line(c, curve([(x-w*0.27,y+w*0.26),(x,y+w*0.38),(x+w*0.15,y+w*0.31),(x+w*0.25,y+w*0.23)]), 0.012, .white)
                }
            }
            if f == .chiikawa || f == .usagi || f == .kani {
                line(c, curve([(x-0.035,-0.91),(x-0.01,-0.94),(x+0.02,-0.94),(x+0.045,-0.91)]), 0.014, dark)
            }
            c.fill(oval(side*0.29,-0.66,0.17,0.095), with: .color(Ink.rgb(0xF1ACBA).opacity(0.8)))
            for i in 0..<3 {
                let xx = side*0.29 + Double(i-1)*0.035
                line(c, curve([(xx-0.005,-0.68),(xx-0.01,-0.66),(xx-0.012,-0.65),(xx-0.015,-0.64)]), 0.012, dark)
            }
        }
        let hungry = pose.mouth == .munch || pose.mouth == .open
        if hungry || f == .usagi || f == .anoko {
            paint(c, oval(0,-0.64, f == .anoko ? 0.18 : 0.09, 0.09), Ink.rgb(0xA75F58), 0.018)
            c.fill(oval(0,f == .anoko ? -0.585 : -0.615,f == .anoko ? 0.08 : 0.055,f == .anoko ? 0.09 : 0.035), with: .color(Ink.tongue))
        } else {
            line(c, curve([(-0.065,-0.66),(-0.04,-0.61),(-0.01,-0.62),(0,-0.65),
                            (0.01,-0.62),(0.04,-0.61),(0.065,-0.66)]), 0.021, dark)
            if f == .chiikawa { line(c, curve([(-0.02,-0.59),(-0.01,-0.58),(0.01,-0.58),(0.02,-0.59)]), 0.013, dark) }
        }
        if !faceOnly {
            for side in [-1.0,1.0] {
                var arm = c
                arm.translateBy(x: side * (pose.arms == .front ? 0.16 : 0.36), y: pose.arms == .up ? -0.57 : -0.37)
                arm.rotate(by: .radians(side * (pose.arms == .up ? -2.2 : pose.arms == .front ? 1.1 : -0.15)))
                paint(arm, oval(0,0.02,0.10,0.17), fur, 0.024)
            }
        }
    }
}
