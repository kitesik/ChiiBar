import ChiiCore
import SwiftUI

struct FirstFriendWelcome: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 10)
            Text("우리의 첫 만남").font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(2).foregroundStyle(Ink.rgb(0x867254))
            Text("어떤 친구가 기다릴까?")
                .font(.system(size: 22, weight: .heavy, design: .rounded)).tracking(-0.7)
                .padding(.top, 8)
            Text("두근두근… 같이 살 친구를 만나봐요.")
                .font(.system(size: 11)).foregroundStyle(Theme.soft).padding(.top, 8)
            Clock(fixed: model.fixedNow) { date in
                MysteryFriendScene(elapsed: reduceMotion ? 0 : max(0, date.timeIntervalSince(started)))
            }.frame(height: 235).accessibilityLabel("모습이 바뀌는 검은 친구 실루엣")
                .accessibilityHidden(true)
            HStack(spacing: 5) {
                Image(systemName: "ticket.fill")
                Text("첫 뽑기권 1장 도착!")
            }.font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Ink.rgb(0x805E25))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Ink.rgb(0xFFF0CB), in: Capsule())
            Button { model.drawTicket() } label: {
                HStack {
                    Spacer()
                    Text("첫 친구 뽑기")
                    Image(systemName: "sparkles")
                    Spacer()
                }.padding(.vertical, 5)
            }.buttonStyle(UpgradeActionStyle())
                .padding(.top, 14).disabled(model.state.tickets == 0 || model.gacha != nil)
            Text("\(FriendID.allCases.count)명 중 한 친구가 찾아와요")
                .font(.system(size: 10)).foregroundStyle(Theme.soft).padding(.top, 12)
            Button("친구별 뽑기 확률 보기") { model.tab = .friends }
                .font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.actionText)
                .buttonStyle(.plain).padding(.top, 8)
            Spacer(minLength: 18)
        }.padding(.horizontal, 25).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MysteryFriendScene: View {
    let elapsed: Double
    var body: some View {
        Canvas { context, size in
            var c = context
            let k = min(size.width / 290, size.height / 235)
            c.translateBy(x: (size.width - 290 * k) / 2, y: (size.height - 235 * k) / 2)
            c.scaleBy(x: k, y: k)
            let center = CGPoint(x: 145, y: 126)
            c.fill(Path(ellipseIn: CGRect(x: 37, y: 18, width: 216, height: 206)), with: .radialGradient(
                Gradient(colors: [Ink.rgb(0xFFF1BF), Ink.rgb(0xFFF4DA).opacity(0)]),
                center: center, startRadius: 20, endRadius: 110))
            c.stroke(Path(ellipseIn: CGRect(x: 47, y: 30, width: 196, height: 180)),
                     with: .color(Ink.rgb(0xD8CBAA).opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
            c.fill(Path(ellipseIn: CGRect(x: 91, y: 191, width: 108, height: 13)), with: .color(Ink.rgb(0xC9BBA4).opacity(0.3)))
            let sequence: [FriendID] = [.usagi, .momonga, .anoko, .hachiware, .kani, .chiikawa, .shisa, .rakko, .kurimanju]
            let cycle = max(0, elapsed) / 2.4
            let index = Int(cycle) % sequence.count
            let phase = cycle - floor(cycle)
            let blend = max(0, min(1, (phase - 0.65) / 0.35))
            let smooth = blend * blend * (3 - 2 * blend)
            let squash = sin(blend * .pi)
            var mystery = c
            mystery.translateBy(x: 145 + sin(elapsed * 2.4) * 3, y: 187 + sin(elapsed * 3) * 3)
            mystery.scaleBy(x: 1 + squash * 0.25, y: 1 - squash * 0.28)
            mystery.rotate(by: .degrees(sin(elapsed * 2.4) * 3))
            mystery.drawLayer { layer in
                layer.addFilter(.alphaThreshold(min: 0.25, color: .black))
                layer.addFilter(.blur(radius: 1.8 + squash * 3))
                layer.drawLayer { masks in
                    var before = masks
                    before.opacity = 1 - smooth
                    _ = SpriteArt.draw(before, sequence[index], base: .zero, size: 77, pose: Pose(), silhouette: true)
                    var after = masks
                    after.opacity = smooth
                    _ = SpriteArt.draw(after, sequence[(index + 1) % sequence.count], base: .zero, size: 77, pose: Pose(), silhouette: true)
                }
            }
            mystery.draw(Text("?").font(.system(size: 36, weight: .black, design: .rounded)).foregroundColor(.white),
                         at: CGPoint(x: 0, y: -48))
            for i in 0..<6 {
                let a = Double(i) * .pi / 3 + elapsed * 0.13
                let p = CGPoint(x: 145 + cos(a) * 98, y: 120 + sin(a) * 78)
                c.draw(Text(i.isMultiple(of: 2) ? "✦" : "·").font(.system(size: i.isMultiple(of: 2) ? 13 : 22, weight: .bold))
                    .foregroundColor(Ink.rgb(0xC4A768)), at: p)
            }
        }
    }
}
