import SwiftUI

/// A daily achievement seal. Its ornaments do not imply a target or percentage.
struct UpgradeBadge: View {
    let count: Int
    private var gold: Color { Ink.rgb(count > 0 ? 0xD4AA50 : 0xB9C5CA) }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().fill(Ink.rgb(count > 0 ? 0xF8E8B9 : 0xEDF2F4))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(gold, lineWidth: 2))
                    .compositingGroup()
            .shadow(color: gold.opacity(0.35), radius: 0, y: 3)
                Circle().stroke(gold.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .frame(width: 68, height: 68)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(count)").font(.system(size: count > 99 ? 27 : 34, weight: .heavy, design: .rounded))
                    Text("번").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Theme.actionText)
                .offset(y: -3)
                decorations
                Text("업그레이드")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.actionText)
                    .padding(.horizontal, 12).padding(.vertical, 3)
                    .background(Ink.rgb(0xDCECF5), in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.accent, lineWidth: 1))
                    .offset(y: 31)
            }
            .frame(width: 112, height: 86)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 업그레이드 \(count)번")
    }

    private var decorations: some View {
        ZStack {
            Image(systemName: "star.fill").font(.system(size: 15)).rotationEffect(.degrees(-15)).offset(x: -39, y: -23)
            Image(systemName: "sparkle").font(.system(size: 17)).offset(x: 42, y: 7)
            Image(systemName: "star.fill").font(.system(size: 9)).rotationEffect(.degrees(15)).offset(x: 32, y: -33)
            Circle().frame(width: 4, height: 4).offset(x: -45, y: 13)
        }
        .foregroundStyle(gold)
        .accessibilityHidden(true)
    }
}
