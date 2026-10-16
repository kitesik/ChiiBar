import ChiiCore
import SwiftUI

/// A collectible daily stamp decorated with the same friends as the game.
struct UpgradeBadge: View {
    let count: Int
    private var gold: Color { Ink.rgb(count > 0 ? 0xC89543 : 0xA6B6BD) }

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: count > 0 ? [Ink.rgb(0xFFF6D8), Ink.rgb(0xF6D98B)] : [Ink.rgb(0xF5F5EB), Ink.rgb(0xDCE6E7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 84, height: 84)
                .overlay(Circle().strokeBorder(gold, lineWidth: 2.5))
                .shadow(color: gold.opacity(0.4), radius: 0, y: 3)
            Circle().stroke(gold.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
                .frame(width: 73, height: 73)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                StampNumber(text: "\(count)", size: count > 999 ? 24 : count > 99 ? 30 : 40,
                            colors: [Ink.rgb(0xFFFDF0), Ink.rgb(0xFFDF89)], ink: Ink.rgb(0x815437))
                    .rotationEffect(.degrees(-7))
                Text("번")
                    .font(.custom("AppleSDGothicNeo-Heavy", size: 11))
                    .foregroundStyle(Ink.rgb(0x815437))
                    .rotationEffect(.degrees(7))
                    .offset(y: -1)
            }
            .frame(maxWidth: 82).minimumScaleFactor(0.6).lineLimit(1)
            .offset(y: 2)
            Text("업그레이드")
                .font(.custom("AppleSDGothicNeo-Heavy", size: 10))
                .tracking(0.3)
                .foregroundStyle(Ink.rgb(0xFFF9E9))
                .shadow(color: Ink.rgb(0x9A514D), radius: 0, y: 1)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(LinearGradient(colors: [Ink.rgb(0xD5847C), Ink.rgb(0xBB6D68)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Ink.rgb(0x945E53), lineWidth: 1.3))
                .rotationEffect(.degrees(-3)).offset(y: 35)
            friend(.chiikawa).rotationEffect(.degrees(-13)).offset(x: -35, y: -23)
            friend(.hachiware).rotationEffect(.degrees(12)).offset(x: 35, y: -23)
            friend(.usagi).offset(y: -40)
        }
        .frame(width: 112, height: 108)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 업그레이드 \(count)번")
    }

    private func friend(_ id: FriendID) -> some View {
        Canvas { context, size in
            _ = SpriteArt.drawFace(context, id, in: CGRect(origin: .zero, size: size))
        }
        .frame(width: 28, height: 28)
        .shadow(color: .white.opacity(0.9), radius: 1)
        .accessibilityHidden(true)
    }
}

/// Rounded, outlined print with a short offset base, like embossed sticker lettering.
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
            .shadow(color: ink, radius: 0, x: -0.8)
            .shadow(color: ink, radius: 0, x: 0.8)
            .shadow(color: ink, radius: 0, y: -0.8)
            .shadow(color: ink, radius: 0, y: 0.8)
            .shadow(color: ink.opacity(0.8), radius: 0, y: 2)
            .lineLimit(1)
    }
}
