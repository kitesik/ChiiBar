import AppKit

// Run from the repository root. Reads artwork without modifying it.
for number in 0...30 {
    let path = String(format: "Art/StampNumbers/%02d.png", number)
    guard let source = NSImage(contentsOfFile: path),
          let image = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("Missing or invalid number image: \(path)")
    }
    let w = image.width, h = image.height
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    let valid = pixels.withUnsafeMutableBytes { bytes -> Bool in
        guard let c = CGContext(data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
              let data = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return false }
        c.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var transparent = 0, opaque = 0
        for pixel in 0..<(w * h) {
            if data[pixel * 4 + 3] == 0 { transparent += 1 }
            if data[pixel * 4 + 3] > 240 { opaque += 1 }
        }
        return transparent > w * h / 10 && opaque > w * h / 50
    }
    precondition(valid, "Image lacks usable content or transparency: \(path)")
    print("\(number): \(w)x\(h), transparent content verified")
}
