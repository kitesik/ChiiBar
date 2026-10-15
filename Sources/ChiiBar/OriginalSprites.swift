import AppKit
import ChiiCore
import SwiftUI

/// Original vector masters, rasterized locally. No downloaded or traced artwork.
/// Coordinates are head-width units, with the feet at (0, 0).
enum OriginalSprites {
    static let outline = Ink.rgb(0x55443E)
    static func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
        FriendArt.ell(x, y, w, h)
    }
    static func paint(_ c: GraphicsContext, _ p: Path, _ color: Color, width: CGFloat = 0.022) {
        c.fill(p, with: .color(color))
        c.stroke(p, with: .color(outline), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
    static func line(_ c: GraphicsContext, _ p: Path, width: CGFloat = 0.023, color: Color = outline) {
        c.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
    static func curve(_ points: [(CGFloat, CGFloat)]) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: points[0].0, y: points[0].1))
        for i in stride(from: 1, to: points.count, by: 3) {
            p.addCurve(to: CGPoint(x: points[i + 2].0, y: points[i + 2].1),
                       control1: CGPoint(x: points[i].0, y: points[i].1),
                       control2: CGPoint(x: points[i + 1].0, y: points[i + 1].1))
        }
        return p
    }

    static func draw(_ c: GraphicsContext, friend f: FriendID, pose: Pose, faceOnly: Bool = false) {
        if f == .anoko || f == .kani {
            AdditionalFriendSprites.draw(c, friend: f, pose: pose, faceOnly: faceOnly)
            return
        }
        let fur = f.fur
        let accent: Color = f == .hachiware ? Ink.rgb(0x96B8D4) : f.accent
        if !faceOnly {
            if f == .momonga {
                paint(c, curve([(0.20,-0.12),(0.82,-0.02),(0.88,-0.90),(0.56,-0.85),
                                (0.34,-0.80),(0.40,-0.49),(0.31,-0.43)]), accent)
                line(c, curve([(0.42,-0.24),(0.68,-0.28),(0.74,-0.58),(0.59,-0.63)]), color: .white)
            } else if f == .shisa {
                let tail = curve([(0.24,-0.16),(0.76,-0.10),(0.72,-0.72),(0.48,-0.57),
                                  (0.33,-0.47),(0.62,-0.33),(0.59,-0.53)])
                line(c, tail, width: 0.115)
                line(c, tail, width: 0.072, color: accent)
            } else if f == .rakko {
                paint(c, oval(0.30,-0.08,0.29,0.12), fur)
            }
            paint(c, oval(0,-0.27,0.53,0.49), fur)
            for side in [-1.0, 1.0] {
                paint(c, oval(side * 0.135,-0.047,0.17,0.072), fur)
            }
            if f == .rakko { c.fill(oval(0,-0.22,0.32,0.28), with: .color(accent)) }
        }

        if f == .shisa {
            for i in 0..<13 {
                let a = Double(i) * 2 * .pi / 13
                paint(c, oval(cos(a)*0.48,-0.76+sin(a)*0.39,0.27,0.25), accent)
            }
        }
        for side in [-1.0, 1.0] {
            var e = c
            let lag = pose.earTilt * (side < 0 ? 1 : 0.75)
            switch f {
            case .usagi:
                e.translateBy(x: side * 0.19, y: -1.06)
                e.rotate(by: .radians(side * 0.07 + lag))
                paint(e, oval(0,-0.29,0.17,0.69), fur)
                e.fill(oval(0,-0.29,0.075,0.48), with: .color(Ink.rgb(0xF6C4AE)))
            case .hachiware:
                paint(e, curve([(side*0.46,-0.91),(side*0.48,-1.04),(side*0.44,-1.29),(side*0.38,-1.27),
                                (side*0.30,-1.25),(side*0.17,-1.11),(side*0.16,-1.04)]), accent)
            case .chiikawa, .momonga, .rakko:
                let x = side * (f == .rakko ? 0.39 : 0.32)
                paint(e, oval(x,-1.105,f == .rakko ? 0.18 : 0.22,0.21), f == .momonga ? accent : fur)
                e.fill(oval(x,-1.11,0.09,0.09), with: .color(f == .momonga ? .white : Ink.rgb(0xF9DDD2)))
            default: break
            }
        }

        // Soft cheeks, flatter crown, and a compact chin instead of a perfect ellipse.
        let head = curve([(-0.49,-0.76),(-0.52,-1.01),(-0.32,-1.155),(0,-1.155),
                          (0.32,-1.155),(0.52,-1.01),(0.49,-0.76),
                          (0.52,-0.51),(0.29,-0.385),(0,-0.40),
                          (-0.29,-0.385),(-0.52,-0.51),(-0.49,-0.76)])
        c.fill(head, with: .color(fur))
        var h = c
        h.clip(to: head)
        switch f {
        case .hachiware:
            for side in [-1.0, 1.0] {
                h.fill(curve([(side*0.57,-1.25),(side*0.35,-1.24),(side*0.15,-1.20),(0,-1.19),
                              (side*0.08,-0.98),(side*0.24,-0.86),(side*0.55,-0.84)]), with: .color(accent))
            }
        case .momonga:
            h.fill(curve([(-0.55,-1.24),(-0.2,-1.34),(0.2,-1.34),(0.55,-1.24),
                          (0.56,-0.77),(0.22,-0.98),(0,-0.95),
                          (-0.22,-0.98),(-0.56,-0.77),(-0.55,-1.24)]), with: .color(accent))
        case .kurimanju:
            h.fill(curve([(-0.6,-1.25),(-0.2,-1.3),(0.2,-1.3),(0.6,-1.25),
                          (0.6,-0.82),(0.12,-0.82),(0,-0.91),
                          (-0.12,-0.82),(-0.6,-0.82),(-0.6,-1.25)]), with: .color(accent))
            h.fill(oval(0,-0.62,0.67,0.37), with: .color(Ink.rgb(0xF8E6C6)))
        case .rakko:
            h.fill(oval(0,-0.69,0.80,0.51), with: .color(accent))
        default: break
        }
        line(c, head)

        let big = f == .momonga
        let eyeY: CGFloat = f == .rakko ? -0.82 : -0.76
        for side in [-1.0, 1.0] {
            let x: CGFloat = side * (big ? 0.195 : 0.18)
            if pose.eyes == .closed || pose.eyes == .happy {
                let bend: CGFloat = pose.eyes == .happy ? -0.055 : 0.035
                line(c, curve([(x-0.052,eyeY),(x-0.02,eyeY+bend),(x+0.02,eyeY+bend),(x+0.052,eyeY)]))
            } else {
                let w: CGFloat = big ? 0.18 : 0.072, ht: CGFloat = big ? 0.205 : 0.094
                c.fill(oval(x,eyeY,w,ht), with: .color(Ink.eye))
                c.fill(oval(x-0.015,eyeY-ht*0.23,w*0.36,w*0.36), with: .color(.white))
                if big { c.fill(oval(x+0.035,eyeY+0.05,0.035,0.035), with: .color(.white)) }
                if f == .chiikawa {
                    c.fill(oval(x,eyeY+0.04,0.067,0.025), with: .color(Ink.tear))
                    line(c, curve([(x-0.055,eyeY-0.11),(x-0.025,eyeY-0.10),(x+0.005,eyeY-0.12),(x+0.025,eyeY-0.14)]), width: 0.013)
                }
            }
            c.fill(oval(side*0.31,-0.63,0.14,0.052), with: .color(Ink.cheek.opacity(0.60)))
            for i in 0..<3 {
                let xx = side*0.31+CGFloat(i-1)*0.034
                line(c, curve([(xx-0.008,-0.647),(xx-0.004,-0.635),(xx+0.004,-0.625),(xx+0.008,-0.615)]), width: 0.008, color: Ink.rgb(0xD88D8F))
            }
        }
        if f == .rakko || f == .shisa || f == .kurimanju {
            paint(c, oval(0,-0.68,f == .rakko ? 0.085 : 0.044,0.037), Ink.eye, width: 0.01)
        }
        if f == .rakko {
            line(c, curve([(-0.29,-0.95),(-0.22,-0.95),(-0.17,-0.92),(-0.13,-0.90)]), width: 0.028)
            line(c, curve([(0.13,-0.90),(0.17,-0.92),(0.22,-0.95),(0.29,-0.95)]), width: 0.028)
            line(c, curve([(-0.40,-0.76),(-0.37,-0.74),(-0.35,-0.72),(-0.32,-0.70)]), width: 0.014)
        }
        let mouth = pose.mouth ?? FriendArt.defaultMouth(f)
        if mouth == .open || mouth == .munch || mouth == .grin {
            let w: CGFloat = mouth == .grin ? 0.21 : 0.085
            paint(c, oval(0,-0.595,w,mouth == .munch ? 0.045 : 0.115), Ink.rgb(0x784536), width: 0.014)
            c.fill(oval(0,-0.565,w*0.56,0.036), with: .color(Ink.tongue))
        } else {
            line(c, curve([(-0.065,-0.61),(-0.035,-0.57),(-0.015,-0.57),(0,-0.61),
                            (0.015,-0.57),(0.035,-0.57),(0.065,-0.61)]), width: 0.017)
        }
        if f == .shisa {
            for side in [-1.0, 1.0] {
                line(c, curve([(side*0.44,-0.95),(side*0.21,-1.18),(side*0.10,-0.86),(side*0.31,-0.94)]), width: 0.043, color: accent)
            }
        }
        if !faceOnly {
            for side in [-1.0, 1.0] {
                var a = c
                switch pose.arms {
                case .down: a.translateBy(x: side*0.255,y: -0.27); a.rotate(by: .radians(side * -0.25))
                case .front: a.translateBy(x: side*0.15,y: -0.31); a.rotate(by: .radians(side * 1.1))
                case .up: a.translateBy(x: side*0.33,y: -0.46); a.rotate(by: .radians(side * -2.5))
                }
                paint(a, oval(0,0.03,0.12,0.19), fur)
            }
        }
    }

    @MainActor static func export(to directory: String) throws {
        let root = URL(fileURLWithPath: directory)
        for f in FriendID.allCases {
            let dir = root.appendingPathComponent(f.rawValue)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let poses: [(String, Pose)] = [
                ("stand", Pose()), ("sleep", Pose(eyes: .closed)),
                ("happy", Pose(eyes: .happy, mouth: .open)), ("munch", Pose(mouth: .munch)),
                ("blink", Pose(eyes: .closed)), ("cheer", Pose(eyes: .happy, mouth: .open, arms: .up)),
                ("front", Pose(arms: .front)), ("munch_front", Pose(mouth: .munch, arms: .front)),
                ("happy_front", Pose(eyes: .happy, mouth: .open, arms: .front)),
                ("ear_left", Pose(earTilt: -0.13)), ("ear_right", Pose(earTilt: 0.13)),
                ("face", Pose())
            ]
            for (name, pose) in poses {
                let faceOnly = name == "face"
                let size = CGSize(width: 160, height: faceOnly ? 160 : 190)
                let canvas = Canvas { ctx, _ in
                    var c = ctx
                    let scale: CGFloat = faceOnly ? (f == .usagi ? 84 : 110) : 100
                    c.translateBy(x: 80, y: faceOnly ? (f == .usagi ? 150 : 169) : 190)
                    c.scaleBy(x: scale,y: scale)
                    draw(c, friend: f, pose: pose, faceOnly: faceOnly)
                }.frame(width: size.width, height: size.height)
                let renderer = ImageRenderer(content: canvas)
                renderer.scale = 4
                guard let image = renderer.cgImage,
                      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                try png.write(to: dir.appendingPathComponent(name + ".png"))
            }
        }
        print("Exported \(FriendID.allCases.count * 12) original sprites")
    }
}
