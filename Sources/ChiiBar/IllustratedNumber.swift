import AppKit
import SwiftUI

/// 0...30 are individually illustrated numbers. Larger counts use the same drawn digits.
struct IllustratedNumber: View {
    let count: Int
    var width: CGFloat? = nil
    var height: CGFloat = 38
    var body: some View {
        let images = NumberArtwork.images(for: max(0, count))
        Canvas { context, size in
            guard !images.isEmpty else { return }
            let naturalWidths = images.map { image -> CGFloat in
                guard let image else { return 0.18 }
                return CGFloat(image.width) / CGFloat(image.height)
            }
            let gap: CGFloat = images.count > 1 ? 0.06 : 0
            let total = naturalWidths.reduce(0, +) + gap * CGFloat(images.count - 1)
            let height = min(size.height, size.width / total)
            var x = (size.width - total * height) / 2
            for (index, image) in images.enumerated() {
                let width = naturalWidths[index] * height
                if let image {
                    context.draw(Image(decorative: image, scale: 1),
                        in: CGRect(x: x, y: (size.height - height) / 2, width: width, height: height))
                } else {
                    let y = (size.height - height) / 2
                    var comma = Path()
                    comma.move(to: CGPoint(x: x + width * 0.25, y: y + height * 0.71))
                    comma.addCurve(to: CGPoint(x: x + width * 0.8, y: y + height * 0.91),
                        control1: CGPoint(x: x + width, y: y + height * 0.65),
                        control2: CGPoint(x: x + width * 1.1, y: y + height * 0.81))
                    comma.addQuadCurve(to: CGPoint(x: x + width * 0.15, y: y + height * 0.99),
                        control: CGPoint(x: x + width * 0.5, y: y + height * 1.02))
                    comma.addLine(to: CGPoint(x: x + width * 0.4, y: y + height * 0.84))
                    comma.addQuadCurve(to: CGPoint(x: x + width * 0.25, y: y + height * 0.71),
                        control: CGPoint(x: x - width * 0.1, y: y + height * 0.84))
                    comma.closeSubpath()
                    context.fill(comma, with: .color(Ink.rgb(0xFFE9AA)))
                    context.stroke(comma, with: .color(Ink.rgb(0x695548)),
                        style: StrokeStyle(lineWidth: max(0.65, height * 0.025), lineJoin: .round))
                }
                x += width + gap * height
            }
        }
        .frame(width: width ?? (count < 10 ? 38 : count < 1000 ? 60 : 80), height: height)
        .accessibilityLabel(count.formatted())
    }
}

@MainActor
private enum NumberArtwork {
    static var cache: [Int: CGImage] = [:]
    static let root: URL = {
        if let path = ProcessInfo.processInfo.environment["CHIIBAR_NUMBERS"] {
            return URL(fileURLWithPath: path)
        }
        return (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("StampNumbers")
    }()

    static func images(for count: Int) -> [CGImage?] {
        if count <= 30, let image = image(count) { return [image] }
        var result: [CGImage?] = []
        let digits = Array(String(count))
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index).isMultiple(of: 3) { result.append(nil) }
            if let value = digit.wholeNumberValue, let artwork = image(value) { result.append(artwork) }
        }
        return result
    }

    static func image(_ number: Int) -> CGImage? {
        if let cached = cache[number] { return cached }
        let url = root.appendingPathComponent(String(format: "%02d.png", number))
        guard let source = NSImage(contentsOf: url),
              let image = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        // Generated files retain their original alpha. Ignore transparent padding at draw time.
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let bounds: CGRect? = pixels.withUnsafeMutableBytes { bytes in
            guard let ctx = CGContext(data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                  let data = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            var left = w, top = h, right = -1, bottom = -1
            for y in 0..<h {
                for x in 0..<w where data[(y * w + x) * 4 + 3] > 8 {
                    left = min(left, x); right = max(right, x)
                    top = min(top, y); bottom = max(bottom, y)
                }
            }
            guard right >= left, bottom >= top else { return nil }
            return CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
        }
        guard let bounds, let trimmed = image.cropping(to: bounds) else { return nil }
        // The stamp is tiny; cache a retina-sized draw image rather than 31 full-resolution originals.
        let scale = min(1, 192 / CGFloat(max(trimmed.width, trimmed.height)))
        let width = max(1, Int(CGFloat(trimmed.width) * scale))
        let height = max(1, Int(CGFloat(trimmed.height) * scale))
        guard let small = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return trimmed }
        small.interpolationQuality = .high
        small.draw(trimmed, in: CGRect(x: 0, y: 0, width: width, height: height))
        let result = small.makeImage() ?? trimmed
        cache[number] = result
        return result
    }
}
