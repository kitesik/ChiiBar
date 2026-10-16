import AppKit
import SwiftUI

/// A hand-drawn pastel reward badge; numeral artwork remains available for future use.
struct UpgradeBadge: View {
    let count: Int
    private static let artwork: NSImage? = {
        let root = ProcessInfo.processInfo.environment["CHIIBAR_NUMBERS"].map { URL(fileURLWithPath: $0) }
            ?? (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("StampNumbers")
        return NSImage(contentsOf: root.appendingPathComponent("badge-pastel.png"))
    }()

    var body: some View {
        ZStack {
            if let artwork = Self.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 112, height: 108)
            }
            StampNumber(text: max(0, count).formatted(), size: 52,
                        colors: [Ink.rgb(0x79533E), Ink.rgb(0x684530)], ink: Ink.rgb(0x624534))
                .frame(width: 76, height: 54)
                .offset(y: -5)
            Text("업그레이드")
                .font(.custom("AppleSDGothicNeo-Heavy", size: 9))
                .tracking(0.15)
                .foregroundStyle(Ink.rgb(0x66594E))
                .shadow(color: Ink.rgb(0xFFF2A0), radius: 0, y: 0.5)
                .offset(y: 24)
        }
        .frame(width: 112, height: 108)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 업그레이드 \(count)번")
    }
}

/// Compact, hand-lettered counts with a warm ink edge, rendered as live text.
struct StampNumber: View {
    let text: String
    let size: CGFloat
    let colors: [Color]
    let ink: Color
    var body: some View {
        Text(text)
            .font(.custom("ChalkboardSE-Bold", size: size))
            .tracking(-1.4)
            .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .shadow(color: ink, radius: 0, x: -0.65, y: -0.65)
            .shadow(color: ink, radius: 0, x: 0.65, y: -0.65)
            .shadow(color: ink, radius: 0, x: -0.65, y: 0.65)
            .shadow(color: ink, radius: 0, x: 0.65, y: 0.65)
            .lineLimit(1).minimumScaleFactor(0.25)
    }
}
