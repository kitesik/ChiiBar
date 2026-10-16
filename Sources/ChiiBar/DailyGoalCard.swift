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
            Text(ratio >= 1 ? "오늘 목표 달성!" : "오늘의 목표")
                .font(.custom("AppleSDGothicNeo-Heavy", size: 10))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
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
        .foregroundStyle(Ink.rgb(0x66594E))
        .padding(.horizontal, 15).padding(.top, 4).padding(.bottom, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            QuestCardBackdrop()
        }
        .help("하루 25만 토큰까지 경험치 100%, 100만까지 추가분 20%, 이후 추가분 1%가 쌓여요. 뽑기권은 50만 경험치마다 충전돼요.")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 경험치 목표 \(percent)퍼센트 달성, \(earned) 경험치, 목표 \(Self.target) 경험치")
    }
}

/// Crisp hand-inked quest stationery, matching the pastel medal at every display scale.
private struct QuestCardBackdrop: View {
    var body: some View {
        Canvas { c, size in
            let w = size.width, h = size.height
            let ink = Ink.rgb(0x776454)
            func paint(_ path: Path, _ color: UInt32) {
                c.fill(path, with: .color(Ink.rgb(color)))
                c.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            }
            paint(Path(roundedRect: CGRect(x: 3, y: 13, width: w - 5, height: h - 14), cornerRadius: 13), 0xCCE4D4)
            var paper = Path()
            paper.move(to: CGPoint(x: 15, y: 9))
            paper.addQuadCurve(to: CGPoint(x: w - 15, y: 10), control: CGPoint(x: w * 0.5, y: 13))
            paper.addQuadCurve(to: CGPoint(x: w - 5, y: 22), control: CGPoint(x: w - 3, y: 9))
            paper.addLine(to: CGPoint(x: w - 5, y: h - 17))
            paper.addQuadCurve(to: CGPoint(x: w - 18, y: h - 6), control: CGPoint(x: w - 3, y: h - 4))
            paper.addQuadCurve(to: CGPoint(x: 15, y: h - 7), control: CGPoint(x: w * 0.5, y: h - 10))
            paper.addQuadCurve(to: CGPoint(x: 2, y: h - 20), control: CGPoint(x: 1, y: h - 4))
            paper.addLine(to: CGPoint(x: 3, y: 22))
            paper.addQuadCurve(to: CGPoint(x: 15, y: 9), control: CGPoint(x: 1, y: 8))
            paper.closeSubpath()
            paint(paper, 0xFFF9E9)
            let ribbonWidth = min(108, w - 24), left = (w - ribbonWidth) / 2
            paint(Path(roundedRect: CGRect(x: left - 7, y: 8, width: ribbonWidth + 14, height: 11), cornerRadius: 3), 0xE9D69C)
            paint(Path(roundedRect: CGRect(x: left, y: 0, width: ribbonWidth, height: 19), cornerRadius: 4), 0xFFF0BD)
            for x in [CGFloat(10), w - 10] {
                let y = h - 10
                for i in 0..<5 {
                    let angle = Double(i) * .pi * 2 / 5
                    let petal = CGRect(x: x + cos(angle) * 3 - 2.5, y: y + sin(angle) * 3 - 2.5, width: 5, height: 5)
                    paint(Path(ellipseIn: petal), 0xFFFEF6)
                }
                c.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(Ink.rgb(0xE6C974)))
            }
        }.accessibilityHidden(true)
    }
}
