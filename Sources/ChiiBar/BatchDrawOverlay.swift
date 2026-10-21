import ChiiCore
import SwiftUI

struct BatchDrawOverlay: View {
    @ObservedObject var model: AppModel
    let results: [DrawResult]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Clock(fixed: model.fixedNow) { date in
            let elapsed = model.batchStartedAt.map { date.timeIntervalSince($0) } ?? GachaArt.revealAt
            if !reduceMotion && elapsed < GachaArt.revealAt {
                if let representative = results.first {
                    GachaAnimation(result: representative, elapsed: max(0, elapsed), idleTime: date.timeIntervalSinceReferenceDate)
                        .overlay(alignment: .top) {
                            Text("\(results.count)번 한 번에 뽑기")
                                .font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.85))
                                .padding(.top, 28)
                        }
                        .background(Ink.rgb(0x312B40))
                } else { summary }
            } else { summary }
        }
    }
    private var summary: some View {
        VStack(spacing: 14) {
            Text("\(results.count)번 뽑기 완료!").font(.system(size: 22, weight: .heavy))
            Text("친구와 선물을 한 번에 모았어요.")
                .font(.system(size: 12)).foregroundStyle(Theme.soft)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(DrawOdds.ranked, id: \.self) { friend in
                        let matches = results.filter { $0.friend == friend }
                        if !matches.isEmpty {
                            HStack(spacing: 12) {
                                ChipFace(friend: friend, owned: true).frame(width: 48, height: 52)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(friend.name) × \(matches.count)").font(.system(size: 14, weight: .bold))
                                    let fresh = matches.filter { $0.outcome == .newFriend }.count
                                    let refunds = matches.filter { $0.outcome == .ticketBack }.count
                                    let gifts = matches.count - fresh - refunds
                                    Text([fresh > 0 ? "새 친구!" : nil,
                                          gifts > 0 ? "경험치 선물 \(gifts)회" : nil,
                                          refunds > 0 ? "뽑기권 반환 \(refunds)장" : nil]
                                        .compactMap { $0 }.joined(separator: " · "))
                                        .font(.system(size: 10)).foregroundStyle(Theme.soft)
                                }
                                Spacer(minLength: 0)
                            }.padding(8).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            Text("남은 뽑기권 \(model.state.tickets)장 · 반환된 표는 다음 뽑기에 써요")
                .font(.system(size: 10)).foregroundStyle(Theme.soft)
            Button("친구 모음으로") { model.finishBatch() }.buttonStyle(PrimaryActionStyle())
        }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background).foregroundStyle(Theme.text)
    }
}
