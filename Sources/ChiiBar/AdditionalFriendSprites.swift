import ChiiCore
import SwiftUI

/// Original compact drawings, using the same feet-based coordinates as the other friends.
enum AdditionalFriendSprites {
    static func draw(_ c: GraphicsContext, friend: FriendID, pose: Pose, faceOnly: Bool = false) {
        let anoko = friend == .anoko
        let fur = friend.fur
        let accent = friend.accent
        if !faceOnly {
            if anoko {
                let tail = OriginalSprites.curve([(0.20,-0.10),(0.73,-0.03),(0.70,-0.45),(0.55,-0.48),
                                                   (0.44,-0.51),(0.41,-0.39),(0.49,-0.32)])
                OriginalSprites.line(c, tail, width: 0.14)
                OriginalSprites.line(c, tail, width: 0.095, color: fur)
                for y in [-0.25, -0.34] {
                    OriginalSprites.line(c, OriginalSprites.curve([(0.57,y),(0.60,y),(0.63,y+0.01),(0.65,y+0.02)]), width: 0.025, color: accent)
                }
            }
            OriginalSprites.paint(c, OriginalSprites.oval(0,-0.27,anoko ? 0.65 : 0.53,0.49), fur)
            for side in [-1.0, 1.0] {
                OriginalSprites.paint(c, OriginalSprites.oval(side * 0.17,-0.045,0.20,0.075), fur)
            }
        }
        if anoko {
            for side in [-1.0, 1.0] {
                OriginalSprites.paint(c, OriginalSprites.curve([(side*0.25,-1.04),(side*0.25,-1.25),(side*0.46,-1.31),(side*0.48,-1.23),
                    (side*0.54,-1.04),(side*0.45,-0.94),(side*0.37,-0.94)]), fur)
            }
        }
        let head = OriginalSprites.curve([(-0.49,-0.76),(-0.53,-1.04),(-0.29,-1.15),(0,-1.15),
            (0.29,-1.15),(0.53,-1.04),(0.49,-0.76),
            (0.53,-0.51),(0.27,-0.39),(0,-0.40),(-0.27,-0.39),(-0.53,-0.51),(-0.49,-0.76)])
        OriginalSprites.paint(c, head, fur)
        if anoko {
            OriginalSprites.paint(c, OriginalSprites.curve([(-0.07,-1.12),(-0.06,-1.23),(-0.025,-1.38),(0,-1.38),
                (0.035,-1.34),(0.07,-1.19),(0.07,-1.12)]), accent)
            for side in [-1.0, 1.0] {
                OriginalSprites.line(c, OriginalSprites.curve([(side*0.43,-0.65),(side*0.47,-0.60),(side*0.46,-0.55),(side*0.42,-0.54)]), width: 0.018)
            }
        } else {
            OriginalSprites.line(c, OriginalSprites.curve([(-0.35,-1.03),(-0.20,-1.21),(0.20,-1.21),(0.35,-1.03)]), width: 0.045, color: accent)
            for side in [-1.0, 1.0] {
                var claw = c
                claw.translateBy(x: side * 0.26, y: -1.20)
                claw.rotate(by: .radians(side * 0.25 + pose.earTilt))
                var p = Path()
                p.move(to: CGPoint(x: -0.10, y: 0.07))
                p.addCurve(to: CGPoint(x: -0.09, y: -0.22), control1: CGPoint(x: -0.20, y: -0.02), control2: CGPoint(x: -0.16, y: -0.18))
                p.addLine(to: CGPoint(x: 0, y: -0.08))
                p.addLine(to: CGPoint(x: 0.09, y: -0.22))
                p.addCurve(to: CGPoint(x: 0.10, y: 0.07), control1: CGPoint(x: 0.16, y: -0.18), control2: CGPoint(x: 0.20, y: -0.02))
                p.closeSubpath()
                OriginalSprites.paint(claw, p, accent)
            }
        }
        for side in [-1.0, 1.0] {
            let x = side * 0.18
            if pose.eyes == .closed || pose.eyes == .happy {
                let bend = pose.eyes == .happy ? -0.05 : 0.035
                OriginalSprites.line(c, OriginalSprites.curve([(x-0.05,-0.76),(x-0.02,-0.76+bend),(x+0.02,-0.76+bend),(x+0.05,-0.76)]))
            } else {
                c.fill(OriginalSprites.oval(x,-0.76,0.075,0.095), with: .color(Ink.eye))
                c.fill(OriginalSprites.oval(x-0.012,-0.78,0.026,0.026), with: .color(.white))
            }
            c.fill(OriginalSprites.oval(side*0.31,-0.63,0.13,0.045), with: .color(Ink.cheek.opacity(0.6)))
        }
        if anoko || pose.mouth == .munch || pose.mouth == .open {
            OriginalSprites.paint(c, OriginalSprites.oval(0,-0.59,0.13,0.11), Ink.rgb(0x784536), width: 0.015)
            c.fill(OriginalSprites.oval(0,-0.56,0.08,0.065), with: .color(Ink.tongue))
        } else {
            OriginalSprites.line(c, OriginalSprites.curve([(-0.06,-0.61),(-0.03,-0.56),(0.03,-0.56),(0.06,-0.61)]), width: 0.018)
        }
        if !faceOnly {
            for side in [-1.0, 1.0] {
                var arm = c
                let front = pose.arms == .front
                arm.translateBy(x: side * (front ? 0.15 : 0.29), y: pose.arms == .up ? -0.47 : -0.27)
                arm.rotate(by: .radians(side * (pose.arms == .up ? -2.5 : front ? 1.1 : -0.25)))
                OriginalSprites.paint(arm, OriginalSprites.oval(0,0.03,0.13,0.20), fur)
            }
        }
    }
}
