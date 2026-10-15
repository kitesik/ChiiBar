import AppKit
import ChiiCore
import SwiftUI

/// The seam between game and artwork. When a PNG exists for a friend and
/// pose it is drawn instead of the code drawing in FriendArt; when it does not,
/// FriendArt draws as before. Nothing else in the app knows which one ran.
///
/// Where the files are looked up, first match wins:
///   1. $CHIIBAR_SPRITES (Scripts/render.sh sets it to Art/Sprites)
///   2. ChiiBar.app/Contents/Resources/Sprites (Scripts/build-app.sh copies Art/Sprites there)
///
/// Layout: Sprites/<friend id>/<name>.png, transparent background, at least
/// 512 px wide. Friend ids are FriendID raw values (chiikawa, hachiware, usagi,
/// momonga, kurimanju, rakko, shisa). Names, each falling back to stand.png:
///   stand.png  whole body standing, feet touching the bottom edge, centered
///   sleep.png  eyes closed (naps, lying down)
///   happy.png  happy closed eyes (pet, piece reveal, ending)
///   munch.png  eating or talking mouth
///   face.png   head only, square, for the menu bar and friend chips (falls back to code)
/// A whole-body image is drawn `bodyWidthPerHead` head-widths wide with its
/// bottom center on the friend's feet, so it lines up with the furniture the
/// code drawing was placed against.
enum SpriteArt {
    static let bodyWidthPerHead: CGFloat = 1.6

    static func draw(_ ctx: GraphicsContext, _ f: FriendID, base: CGPoint, size s: CGFloat, pose: Pose) -> Bool {
        guard let image = body(f, pose) else { return false }
        var c = ctx
        c.translateBy(x: base.x, y: base.y)
        if pose.lying {
            c.translateBy(x: 0, y: -0.42 * s)
            c.rotate(by: .radians(-Double.pi / 2 + 0.12))
        }
        c.rotate(by: .radians(pose.tilt))
        c.scaleBy(x: 1 + (1 - pose.squish) * 0.6, y: pose.squish)
        let w = s * bodyWidthPerHead
        let h = w * image.size.height / max(1, image.size.width)
        c.draw(Image(nsImage: image), in: CGRect(x: -w / 2, y: -h, width: w, height: h))
        return true
    }

    static func drawFace(_ ctx: GraphicsContext, _ f: FriendID, in rect: CGRect) -> Bool {
        guard let image = load(f, "face") else { return false }
        ctx.draw(Image(nsImage: image), in: rect)
        return true
    }

    private static func body(_ f: FriendID, _ pose: Pose) -> NSImage? {
        let names: [String]
        if pose.lying {
            names = ["sleep"]
        } else if pose.blinking {
            names = ["blink"]
        } else if pose.arms == .up {
            names = ["cheer", "happy"]
        } else if pose.eyes == .closed {
            names = ["sleep"]
        } else if pose.eyes == .happy {
            names = pose.arms == .front ? ["happy_front", "happy"] : ["happy"]
        } else if pose.mouth == .munch || pose.mouth == .open {
            names = pose.arms == .front ? ["munch_front", "munch"] : ["munch"]
        } else if pose.arms == .front {
            names = ["front"]
        } else if abs(pose.earTilt) > 0.05 {
            names = [pose.earTilt < 0 ? "ear_left" : "ear_right"]
        } else {
            names = ["stand"]
        }
        return (names + ["stand"]).lazy.compactMap { load(f, $0) }.first
    }

    // A nil dictionary value removes a key. Track misses separately to avoid
    // filesystem lookups on every animation frame when a pose is unavailable.
    nonisolated(unsafe) private static var cache: [String: NSImage] = [:]
    nonisolated(unsafe) private static var missing = Set<String>()

    private static func load(_ f: FriendID, _ name: String) -> NSImage? {
        let key = "\(f.rawValue)/\(name)"
        if let hit = cache[key] { return hit }
        if missing.contains(key) { return nil }
        let image = roots.lazy
            .map { $0.appendingPathComponent("\(key).png") }
            .compactMap { NSImage(contentsOf: $0) }
            .first
        cache[key] = image
        if image == nil { missing.insert(key) }
        return image
    }

    private static let roots: [URL] = {
        var list: [URL] = []
        if let env = ProcessInfo.processInfo.environment["CHIIBAR_SPRITES"], !env.isEmpty {
            list.append(URL(fileURLWithPath: env))
        }
        if let resources = Bundle.main.resourceURL {
            list.append(resources.appendingPathComponent("Sprites"))
        }
        return list
    }()
}
