import AppKit
import ChiiCore
import SwiftUI

@MainActor
enum AppIcon {
    @discardableResult
    static func installForRunningApplication() -> Bool {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: url), image.isValid else { return false }
        NSApp.applicationIconImage = image
        return true
    }

    static func export(to path: String) throws {
        let renderer = ImageRenderer(content: Canvas { ctx, _ in
            let tile = Path(roundedRect: CGRect(x: 64, y: 64, width: 896, height: 896), cornerRadius: 200)
            ctx.fill(tile, with: .linearGradient(Gradient(colors: [Ink.rgb(0xFFF5DA), Ink.rgb(0xD5EAF4)]),
                startPoint: .zero, endPoint: CGPoint(x: 1024, y: 1024)))
            ctx.stroke(tile, with: .color(Ink.rgb(0x91B1BC)), lineWidth: 10)
            var home = Path()
            home.move(to: CGPoint(x: 220, y: 430)); home.addLine(to: CGPoint(x: 512, y: 200))
            home.addLine(to: CGPoint(x: 804, y: 430))
            ctx.stroke(home, with: .color(Ink.rgb(0x8D6C62)), style: StrokeStyle(lineWidth: 48, lineCap: .round, lineJoin: .round))
            FriendArt.draw(ctx, .chiikawa, base: CGPoint(x: 512, y: 870), size: 440, pose: Pose())
        }.frame(width: 1024, height: 1024))
        renderer.scale = 1
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: URL(fileURLWithPath: path))
    }
}
