import SwiftUI
import ChiiCore

/// A fixed daily reference, not a cap on earned experience or a new reward rule.
struct DailyGoalCard: View {
    static let target: Int64 = Tuning.dailyTarget
    let earned: Int64
    private var ratio: Double { Double(max(0, earned)) / Double(Self.target) }
    private var percent: String { floor(ratio * 100).formatted(.number.precision(.fractionLength(0))) }
    private var amount: String {
        let value = max(0, earned)
        return value >= 10_000 ? "\((value / 10_000).formatted())만" : value.formatted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(ratio >= 1 ? "오늘 목표 달성!" : "오늘의 경험치 목표", systemImage: ratio >= 1 ? "checkmark.seal.fill" : "sparkles")
                .font(.custom("AppleSDGothicNeo-Heavy", size: 10))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                StampNumber(text: percent, size: 24,
                            colors: [Ink.rgb(0x3C6178), Ink.rgb(0x315469)], ink: .white)
                    .minimumScaleFactor(0.25)
                Text("%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Ink.rgb(0x52788E))
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)
            ProgressTrack(fraction: min(1, ratio), sweepFrom: nil, fixedNow: .distantPast)
                .accessibilityHidden(true)
            Text("\(amount) / \(Self.target / 10_000)만")
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(Theme.actionText)
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Ink.rgb(0xEDF5F7), Ink.rgb(0xDFEDF1)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.85), lineWidth: 1).padding(4))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.45), lineWidth: 1))
        .compositingGroup()
        .shadow(color: Theme.accent.opacity(0.18), radius: 0, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 경험치 목표 \(percent)퍼센트 달성, \(earned) 경험치, 목표 \(Self.target) 경험치")
    }
}
