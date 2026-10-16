import AppKit
import SwiftUI

/// A hand-drawn pastel reward badge, with illustrated counts and a readable ribbon label.
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
            IllustratedNumber(count: count)
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

/// Rounded stamp lettering with a restrained paper highlight.
struct StampNumber: View {
    let text: String
    let size: CGFloat
    let colors: [Color]
    let ink: Color
    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .black, design: .rounded).width(.condensed))
            .tracking(-0.8)
            .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .shadow(color: ink.opacity(0.7), radius: 0, y: 1)
            .lineLimit(1)
    }
}
