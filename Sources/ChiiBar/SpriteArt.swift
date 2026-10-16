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
            guard entry.source.hasPrefix("https://x.com/ngnchiikawa/status/"), entry.crop.count == 4,
                  let original = NSImage(contentsOf: root.appendingPathComponent(entry.asset)),
                  let cg = original.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let trimmed = cg.cropping(to: CGRect(x: entry.crop[0], y: entry.crop[1],
                    width: entry.crop[2] - entry.crop[0], height: entry.crop[3] - entry.crop[1])) else { continue }
            result[entry.id] = strengthenInk(trimmed)
        }
        return result
    }()

    /// Draw the bundled pixels directly. A menu icon must not depend on SwiftUI
    /// rendering a Canvas before its view has ever joined a window hierarchy.
    static func menuImage(for friend: FriendID) -> NSImage? {
        guard let cg = images[friend.rawValue] else { return nil }
        let source = NSImage(cgImage: cg, size: CGSize(width: cg.width, height: cg.height))
        let icon = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { bounds in
            let ratio = min(bounds.width / CGFloat(cg.width), bounds.height / CGFloat(cg.height))
            let size = CGSize(width: CGFloat(cg.width) * ratio, height: CGFloat(cg.height) * ratio)
            source.draw(in: CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                                   width: size.width, height: size.height))
            return true
        }
        icon.isTemplate = false
        return icon
    }

    /// Reinforce dark ink consistently, including facial details, once at load.
    /// Keep the original sprite files and expression geometry unchanged.
    private static func strengthenInk(_ image: CGImage) -> CGImage {
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
            let radius = max(1, Int((Double(h) * 0.005).rounded()))
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
        // Fail closed: a missing reviewed asset must not revive an invented fallback face.
        guard let image = images[pose.mangaExpression.asset(for: friend)] ?? images[friend.rawValue] else { return true }
        var c = ctx
        c.translateBy(x: base.x, y: base.y)
        c.rotate(by: .radians(pose.tilt))
        c.scaleBy(x: 1 + (1 - pose.squish) * 0.6, y: pose.squish)
        let height = size * (friend == .usagi ? 1.65 : friend == .anoko ? 1.5 : 1.35)
        let width = height * CGFloat(image.width) / CGFloat(image.height)
        var resolved = c.resolve(Image(decorative: image, scale: 1))
        if silhouette { resolved.shading = .color(.black) }
        c.draw(resolved, in: CGRect(x: -width / 2, y: -height, width: width, height: height))
        return true
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
