import ChiiCore
import SwiftUI

struct FriendDetailView: View {
    @ObservedObject var model: AppModel
    let friend: FriendID
    private var owned: Bool { model.state.houses[friend] != nil }
    private var finish: CardFinish { CardFinish(tier: friend.rarity) }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("친구 도감").font(.system(size: 15, weight: .heavy))
                Spacer()
                Button("닫기") { model.inspectedFriend = nil }
                    .buttonStyle(PrimaryActionStyle())
                    .keyboardShortcut(.cancelAction)
            }.padding(16)
            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24).fill(finish.gradient.opacity(0.3))
                        Canvas { context, size in
                            if owned {
                                FriendArt.draw(context, friend, base: CGPoint(x: size.width / 2, y: size.height - 12), size: 100, pose: Pose())
                            } else {
                                _ = SpriteArt.drawFace(context, friend, in: CGRect(x: 45, y: 20, width: 150, height: 150), silhouette: true)
                                context.draw(Text("?").font(.system(size: 46, weight: .heavy)).foregroundColor(.white), at: CGPoint(x: size.width / 2, y: size.height / 2))
                            }
                        }
                    }.frame(width: 240, height: 205)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(finish.ink.opacity(0.35), lineWidth: 2))
                    VStack(spacing: 5) {
                        Text(friend.name).font(.system(size: 24, weight: .heavy)).foregroundStyle(finish.ink)
                        Text(friend.japaneseName).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.soft)
                        Text("\(finish.name) · 뽑기 확률 \(Int((DrawOdds.probability(of: friend) * 100).rounded()))%")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.actionText)
                    }
                    HStack(spacing: 6) {
                        ForEach(friend.profileTags, id: \.self) { tag in
                            Text(tag).font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                                .background(friend.chipTint, in: Capsule())
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("어떤 친구일까?").font(.system(size: 14, weight: .bold))
                        Text(friend.profile).font(.system(size: 13)).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
                        Link("공식 소개 보기 ↗", destination: friend.profileSource)
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.actionText)
                        Text(friend == .anoko ? "공식 표기와 외형을 바탕으로 정리했어요." : "공식 소개를 짧게 정리했어요.")
                            .font(.system(size: 9)).foregroundStyle(Theme.soft)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                        .background(Ink.rgb(0xFFFDF5), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Ink.rgb(0xD9CBB5), lineWidth: 1.5))
                    if owned {
                        Button("\(friend.name)의 집으로") {
                            model.select(friend)
                            model.inspectedFriend = nil
                        }.buttonStyle(PrimaryActionStyle()).disabled(model.building)
                    } else {
                        Text("아직 만나지 않은 친구예요").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.soft)
                    }
                }.padding(.horizontal, 20).padding(.bottom, 24)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.background)
    }
}
