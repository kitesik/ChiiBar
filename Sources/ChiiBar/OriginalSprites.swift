import AppKit
import ChiiCore
import SwiftUI

/// Original vector masters, rasterized locally. No downloaded or traced artwork.
/// Coordinates are head-width units, with the feet at (0, 0).
enum OriginalSprites {
    static let outline = Ink.rgb(0x49352F)
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
        CharacterMasters.draw(c, friend: f, pose: pose, faceOnly: faceOnly)
    }

    @MainActor static func export(to directory: String) throws {
        let root = URL(fileURLWithPath: directory)
        for f in FriendID.allCases {
            let dir = root.appendingPathComponent(f.rawValue)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("reference-matched.txt").path) { continue }
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
