import ChiiCore
import SwiftUI

/// A collectible daily stamp decorated with the same friends as the game.
struct UpgradeBadge: View {
    let count: Int
    private var gold: Color { Ink.rgb(count > 0 ? 0xD6B883 : 0xBBC9CA) }

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: count > 0 ? [Ink.rgb(0xFFFAEB), Ink.rgb(0xF7EACB)] : [Ink.rgb(0xF5F5EB), Ink.rgb(0xDCE6E7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 84, height: 84)
                .overlay(Circle().strokeBorder(gold, lineWidth: 1.5))
                .shadow(color: gold.opacity(0.2), radius: 0, y: 2)
            Circle().stroke(gold.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
                .frame(width: 73, height: 73)
            HStack(alignment: .bottom, spacing: 1) {
                IllustratedNumber(count: count)
                Text("번")
                    .font(.custom("AppleSDGothicNeo-Heavy", size: 10))
                    .foregroundStyle(Ink.rgb(0x815437))
                    .padding(.bottom, 4)
            }
            .offset(x: -1, y: 2)
            Text("업그레이드")
                .font(.custom("AppleSDGothicNeo-Heavy", size: 9))
                .tracking(0.5)
                .foregroundStyle(Ink.rgb(0x8A6C51))
                .offset(y: 28)
            friend(.chiikawa).rotationEffect(.degrees(8)).offset(x: 24, y: -32)
            GameSymbol(kind: .home).scaleEffect(0.82).rotationEffect(.degrees(-10))
                .offset(x: -34, y: 25)

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
