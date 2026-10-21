import AppKit
import ChiiCore
import SwiftUI

/// Strict panel-backed catalog. Legacy generic happy/sleep/blink artwork is never loaded.
enum SpriteArt {
    private struct Entry: Decodable {
        let id: String
        let source: String
        let asset: String
        let crop: [Double]
    }
    private static let root: URL = {
        if let env = ProcessInfo.processInfo.environment["CHIIBAR_SPRITES"] {
            return URL(fileURLWithPath: env).appendingPathComponent("Manga")
        }
        return (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("Sprites/Manga")
    }()
    private static let images: [String: CGImage] = {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("catalog.json")),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [:] }
        var result: [String: CGImage] = [:]
        for entry in entries {
            guard (entry.source.hasPrefix("https://x.com/ngnchiikawa/status/") || entry.source == "https://www.anime-chiikawa.jp/chara.html"), entry.crop.count == 4,
                  let original = NSImage(contentsOf: root.appendingPathComponent(entry.asset)),
                  let cg = original.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let trimmed = cg.cropping(to: CGRect(x: entry.crop[0], y: entry.crop[1],
                    width: entry.crop[2] - entry.crop[0], height: entry.crop[3] - entry.crop[1])) else { continue }
            result[entry.id] = strengthenInk(trimmed, character: entry.id)
        }
        // One collectible made from four existing sprites. Keep each member's artwork intact.
        result["pajamaGreen-individual"] = result[FriendID.pajamaGreen.rawValue]
        if let party = pajamaParty(from: result) { result[FriendID.pajamaGreen.rawValue] = party }
        return result
    }()

    private static func pajamaParty(from sprites: [String: CGImage]) -> CGImage? {
        guard let context = CGContext(data: nil, width: 1000, height: 900, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let positions: [(FriendID, CGFloat, CGFloat)] = [(.pajamaWhite, 270, 375), (.pajamaPurple, 700, 375), (.pajamaGreen, 240, 0), (.pajamaPink, 730, 0)]
        for (friend, x, y) in positions {
            guard let image = sprites[friend.rawValue] else { return nil }
            let height: CGFloat = 510
            let width = min(490, height * CGFloat(image.width) / CGFloat(image.height))
            context.draw(image, in: CGRect(x: x - width / 2, y: y, width: width, height: height))
        }
        return context.makeImage()
    }

    /// Draw the bundled pixels directly. A menu icon must not depend on SwiftUI
    /// rendering a Canvas before its view has ever joined a window hierarchy.
    static func menuImage(for friend: FriendID) -> NSImage? {
        guard let cg = portrait(for: friend) else { return nil }
        let source = NSImage(cgImage: cg, size: CGSize(width: cg.width, height: cg.height))
        let icon = NSImage(size: NSSize(width: 22, height: 20), flipped: false) { bounds in
            let ratio = min(bounds.width / CGFloat(cg.width), bounds.height / CGFloat(cg.height))
            let size = CGSize(width: CGFloat(cg.width) * ratio, height: CGFloat(cg.height) * ratio)
            source.draw(in: CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                                   width: size.width, height: size.height))
            return true
        }
        icon.isTemplate = false
        return icon
    }

    /// Head-focused crop from the existing expression; no new facial features.
    static func portrait(for friend: FriendID) -> CGImage? {
        guard let image = images[friend.rawValue] else { return nil }
        let crop: CGRect
        switch friend {
        case .pajamaGreen: crop = CGRect(x: 0, y: 0, width: 1, height: 1)
        case .pochette, .labor: crop = CGRect(x: 0.22, y: 0, width: 0.58, height: 0.27)
        case .usagi: crop = CGRect(x: 0, y: 0.18, width: 1, height: 0.59)
        case .anoko: crop = CGRect(x: 0, y: 0, width: 0.84, height: 0.54)
        case .momonga: crop = CGRect(x: 0, y: 0, width: 0.76, height: 0.72)
        case .rakko: crop = CGRect(x: 0.09, y: 0, width: 0.82, height: 0.62)
        default: crop = CGRect(x: 0, y: 0, width: 1, height: 0.72)
        }
        return image.cropping(to: CGRect(x: CGFloat(image.width) * crop.minX, y: CGFloat(image.height) * crop.minY,
            width: CGFloat(image.width) * crop.width, height: CGFloat(image.height) * crop.height))
    }

    static func drawPortrait(_ ctx: GraphicsContext, _ friend: FriendID, in rect: CGRect) {
        guard let image = portrait(for: friend) else { return }
        let scale = min(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        ctx.draw(Image(decorative: image, scale: 1), in: CGRect(x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2, width: size.width, height: size.height))
    }

    /// Reinforce dark ink consistently, including facial details, once at load.
    /// Keep the original sprite files and expression geometry unchanged.
    private static func strengthenInk(_ image: CGImage, character: String) -> CGImage {
        let w = image.width, h = image.height, count = w * h
        var pixels = [UInt8](repeating: 0, count: count * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w * 4, space: colorSpace,
                bitmapInfo: bitmapInfo), let p = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else { return image }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            var mask = [UInt8](repeating: 0, count: count)
            for i in 0..<count {
                let offset = i * 4, alpha = Int(p[offset + 3])
                guard alpha > 0 else { continue }
                let brightest = Int(max(p[offset], max(p[offset + 1], p[offset + 2]))) * 255 / alpha
                // Only near-black ink; preserve cheek colors and white eye highlights.
                let strength = min(1, max(0, Double(88 - brightest) / 48))
                mask[i] = UInt8(Double(alpha) * strength)
            }
            // Small enclosed light regions are eye glints, not space to thicken into.
            var light = [Bool](repeating: false, count: count)
            var preserve = light
            for i in 0..<count {
                let o = i * 4
                let low = min(p[o], min(p[o + 1], p[o + 2]))
                let high = max(p[o], max(p[o + 1], p[o + 2]))
                light[i] = p[o + 3] > 240 && low > 210 && high - low < 18
            }
            for i in 0..<count where light[i] {
                var region = [i], head = 0
                light[i] = false
                while head < region.count {
                    let current = region[head], x = current % w, y = current / w
                    head += 1
                    for next in [x > 0 ? current - 1 : -1, x + 1 < w ? current + 1 : -1,
                                 y > 0 ? current - w : -1, y + 1 < h ? current + w : -1] {
                        if next >= 0 && light[next] { light[next] = false; region.append(next) }
                    }
                }
                if region.count >= 16 && region.count < count / 1000 {
                    let margin = max(2, Int(Double(h) * 0.01))
                    let left = region.map { $0 % w }.min()! - margin
                    let right = region.map { $0 % w }.max()! + margin
                    let top = region.map { $0 / w }.min()! - margin
                    let bottom = region.map { $0 / w }.max()! + margin
                    if left >= 0 && right < w && top >= 0 && bottom < h {
                        let corners = [top * w + left, top * w + right, bottom * w + left, bottom * w + right]
                        if corners.allSatisfy({ p[$0 * 4 + 3] > 240 }) {
                            for index in region { preserve[index] = true }
                        }
                    }
                }
            }
            let inkRatio: Double
            switch character {
            case "rakko": inkRatio = 0.0065
            case "shisa": inkRatio = 0.006
            case "momonga", "anoko": inkRatio = 0.0055
            default: inkRatio = 0.005
            }
            let radius = max(1, Int((Double(h) * inkRatio).rounded()))
            var horizontal = mask
            for y in 0..<h {
                for x in 0..<w {
                    var value: UInt8 = 0
                    for dx in max(0, x - radius)...min(w - 1, x + radius) {
                        value = max(value, mask[y * w + dx])
                    }
                    horizontal[y * w + x] = value
                }
            }
            for y in 0..<h {
                for x in 0..<w {
                    var value: UInt8 = 0
                    for dy in max(0, y - radius)...min(h - 1, y + radius) {
                        value = max(value, horizontal[dy * w + x])
                    }
                    if preserve[y * w + x] { continue }
                    let offset = (y * w + x) * 4, a = Double(value) / 255
                    for channel in 0..<3 {
                        p[offset + channel] = UInt8(18 * a + Double(p[offset + channel]) * (1 - a))
                    }
                    p[offset + 3] = UInt8(min(255, Double(value) + Double(p[offset + 3]) * (1 - a)))
                }
            }
            return context.makeImage() ?? image
        }
    }

    static func draw(_ ctx: GraphicsContext, _ friend: FriendID, base: CGPoint, size: CGFloat, pose: Pose, silhouette: Bool = false) -> Bool {
        if friend == .pajamaGreen, pose.homeOutfit?.isVisible == true {
            for (member, x, y) in [(FriendID.pajamaWhite, -0.35, -0.72), (.pajamaPurple, 0.35, -0.72), (.pajamaGreen, -0.38, 0.0), (.pajamaPink, 0.38, 0.0)] {
                // Use the individual source image rather than the grouped collectible.
                _ = drawDressed(ctx, member, base: CGPoint(x: base.x + x * size, y: base.y + y * size), size: size * 0.62, pose: pose, silhouette: silhouette)
            }
            return true
        }
        return drawDressed(ctx, friend, base: base, size: size, pose: pose, silhouette: silhouette)
    }

    private static func drawDressed(_ ctx: GraphicsContext, _ friend: FriendID, base: CGPoint, size: CGFloat, pose: Pose, silhouette: Bool) -> Bool {
        // Fail closed: a missing reviewed asset must not revive an invented fallback face.
        let key = friend == .pajamaGreen && pose.homeOutfit?.isVisible == true ? "pajamaGreen-individual" : pose.mangaExpression.asset(for: friend)
        guard let image = images[key] ?? images[friend.rawValue] else { return true }
        var c = ctx
        c.translateBy(x: base.x, y: base.y)
        c.rotate(by: .radians(pose.tilt))
        c.scaleBy(x: 1 + (1 - pose.squish) * 0.6, y: pose.squish)
        let height = size * (friend == .pajamaGreen ? 1.65 : (friend == .pochette || friend == .labor) ? 1.9 : friend == .usagi ? 1.65 : friend == .anoko ? 1.5 : 1.35)
        let width = height * CGFloat(image.width) / CGFloat(image.height)
        var resolved = c.resolve(Image(decorative: image, scale: 1))
        if silhouette { resolved.shading = .color(.black) }
        c.draw(resolved, in: CGRect(x: -width / 2, y: -height, width: width, height: height))
        if !silhouette, let outfit = pose.homeOutfit {
            HomeOutfitArt.draw(c, outfit: outfit, width: width, height: height, friend: friend)
        }
        return true
    }

    /// Repose the existing pixels. The face/ink/palette are never regenerated.
    static func drawDesktop(_ ctx: GraphicsContext, _ friend: FriendID, behavior: DesktopBehavior,
                            stage: Int, reduced: Bool) {
        let action = behavior.action, e = behavior.elapsed
        let blend = reduced ? 1 : behavior.envelope
        let expression: MangaExpression = action == .cry && friend == .chiikawa ? .cry
            : action == .laugh ? MangaExpression.select(friend: friend, stage: stage, time: 0, responding: true) : .base
        guard let image = images[expression.asset(for: friend)] else { return }
        let height: CGFloat = friend == .usagi ? 101 : friend == .pajamaGreen ? 106 : friend == .anoko ? 96 : 86
        let width = min(136, height * CGFloat(image.width) / CGFloat(image.height))
        let rect = CGRect(x: -width / 2, y: -height, width: width, height: height)
        var c = ctx
        let wave = reduced ? 0 : sin(e * 7)
        let bounce = action == .laugh ? abs(wave) * 2.5 * blend : action == .walk ? abs(wave) * 1.5 : 0
        c.translateBy(x: 100, y: 184 - bounce)
        if action == .roll && !reduced {
            // Roll around the body's centre, not around a foot; settle before walking.
            let angle = 2 * Double.pi * ArrivalMotion.ease((e - 1.5) / 6)
            c.translateBy(x: 0, y: -height / 2)
            c.rotate(by: .radians(angle))
            c.translateBy(x: 0, y: height / 2)
        } else if !reduced {
            c.rotate(by: .radians((action == .cry ? sin(e * 18) * 0.015 : wave * 0.018) * blend))
        }
        let seated = action == .sit ? blend : 0
        // Fold the lower body while leaving the entire face at its original scale.
        let split = height * 0.24
        let lowerScale = 1 - 0.45 * seated
        let drop = split * (1 - lowerScale)
        let sprite = Image(decorative: image, scale: 1)
        if seated > 0 {
            var lower = c
            lower.scaleBy(x: 1, y: lowerScale)
            lower.clip(to: Path(CGRect(x: -100, y: -split, width: 200, height: split + 1)))
            lower.draw(sprite, in: rect)
            var upper = c
            upper.translateBy(x: 0, y: drop)
            upper.clip(to: Path(CGRect(x: -100, y: -height - 1, width: 200, height: height - split + 1)))
            upper.draw(sprite, in: rect)
        } else {
            if action == .stretch && !reduced {
                c.scaleBy(x: 1 - 0.025 * blend, y: 1 + 0.035 * blend)
            }
            c.draw(sprite, in: rect)
        }
        // Accessories stay with the original head. The party keeps its grouped sprite intact.
        if friend != .pajamaGreen {
            var dressed = c
            dressed.translateBy(x: 0, y: drop)
            HomeOutfitArt.draw(dressed, outfit: HomeOutfit.at(stage: stage), width: width, height: height, friend: friend)
        }
    }

    static func drawFace(_ ctx: GraphicsContext, _ friend: FriendID, in rect: CGRect, silhouette: Bool = false) -> Bool {
        guard let image = images[friend.rawValue] else { return true }
        let ratio = min(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * ratio, height: CGFloat(image.height) * ratio)
        var resolved = ctx.resolve(Image(decorative: image, scale: 1))
        if silhouette { resolved.shading = .color(.black) }
        ctx.draw(resolved, in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                                      width: size.width, height: size.height))
        return true
    }
}
