import SwiftUI
import ChiiCore

struct DailyGoalCard: View {
    static let target: Int64 = Tuning.dailyTarget
    let earned: Int64
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var ratio: Double { Double(max(0, earned)) / Double(Self.target) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(WorkTimeFormat.energy(earned))
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text("목표 4시간").font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.soft)
            }
            ProgressTrack(fraction: min(1, ratio), sweepFrom: nil, fixedNow: .distantPast,
                          animatesChanges: !reduceMotion, height: 7)
                .accessibilityHidden(true)
            HStack {
                Text(ratio >= 1 ? "오늘 목표 달성! 잘했어요" : "목표까지 \(WorkTimeFormat.energy(Self.target - earned))")
                Spacer()
                Text("\(Int(ratio * 100))%") .monospacedDigit()
            }.font(.system(size: 10, weight: .semibold)).foregroundStyle(Ink.rgb(0x8A6A32))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 활동 \(WorkTimeFormat.energy(earned)), 목표 4시간, \(Int(ratio * 100))퍼센트 달성")
    }
}
