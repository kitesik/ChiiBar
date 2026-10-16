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
            let heights = images.map { CGFloat($0.height) }
            let naturalWidths = images.enumerated().map { CGFloat($0.element.width) / heights[$0.offset] }
            let gap: CGFloat = images.count > 1 ? 0.06 : 0
            let total = naturalWidths.reduce(0, +) + gap * CGFloat(images.count - 1)
            let height = min(size.height, size.width / total)
            var x = (size.width - total * height) / 2
            for (index, image) in images.enumerated() {
                let width = naturalWidths[index] * height
                context.draw(Image(decorative: image, scale: 1),
                             in: CGRect(x: x, y: (size.height - height) / 2, width: width, height: height))
                x += width + gap * height
            }
        }
        .frame(width: width ?? (count < 10 ? 38 : 60), height: height)
        .accessibilityLabel("\(count)")
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

    static func images(for count: Int) -> [CGImage] {
        if count <= 30, let image = image(count) { return [image] }
        var result: [CGImage] = []
        for digit in String(count) {
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
