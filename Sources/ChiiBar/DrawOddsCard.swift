import ChiiCore
import SwiftUI

/// Our three game tiers, using foil/material contrast rather than a rainbow of panel fills.
struct CardFinish {
    let tier: Int
    var code: String { tier == 3 ? "SSR" : tier == 2 ? "SR" : "R" }
    var name: String { tier == 3 ? "슈퍼 레어" : tier == 2 ? "레어" : "일반" }
    var ink: Color { Ink.rgb(0x273241) }
    var edge: [Color] {
        (tier == 3 ? [0xA76A15, 0xFFE7A0, 0xC9912D, 0xFFF2C1, 0xA76A15] :
         tier == 2 ? [0x647B99, 0xDEF4F0, 0xB8A9D6, 0xF7F8FC, 0x7288A2] :
                     [0x8E9AA4, 0xDCE0E1, 0xA3ADB6]).map { Ink.rgb($0) }
    }
    var foil: [Color] {
        (tier == 3 ? [0xFFF2BE, 0xF9D77A, 0xFFF6D4, 0xEED295] :
         tier == 2 ? [0xD5E8F4, 0xE8DAF3, 0xD2EEE7, 0xF4E6D9] :
                     [0xEFF0E9, 0xE4E8E4]).map { Ink.rgb($0) }
    }
    var emblem: Color { tier == 3 ? Ink.rgb(0xFFE7A0) : tier == 2 ? Ink.rgb(0xDCE6F3) : Ink.rgb(0xCBD2D7) }
    var gradient: LinearGradient { LinearGradient(colors: edge, startPoint: .topLeading, endPoint: .bottomTrailing) }
}

/// The same material appears on draw odds and owned-friend cards.
struct CardFoilBackground: View {
    let finish: CardFinish
    var highlighted = false
    var body: some View {
        ZStack {
                LinearGradient(colors: finish.foil, startPoint: .topLeading, endPoint: .bottomTrailing)
                // Stationary foil facets stay legible and use no continuously running animation.
                if finish.tier > 1 {
                    GeometryReader { geo in
                        Path { p in
                            p.move(to: CGPoint(x: geo.size.width * 0.15, y: 0))
                            p.addLine(to: CGPoint(x: geo.size.width * 0.60, y: 0))
                            p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                            p.addLine(to: CGPoint(x: geo.size.width * 0.55, y: geo.size.height))
                            p.closeSubpath()
                        }.fill(.white.opacity(highlighted ? 0.55 : 0.28))
                    }
                    VStack {
                        HStack { Image(systemName: "sparkle"); Spacer() }
                        Spacer()
                        HStack { Spacer(); Image(systemName: "sparkle") }
                    }.font(.system(size: 7)).foregroundStyle(.white.opacity(0.9)).padding(5)
                }
        }
        .accessibilityHidden(true)
    }
}

struct DrawOddsCard: View {
    let firstDraw: Bool
    var ownedFriends: Set<FriendID> = []
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("친구별 뽑기 확률").font(.system(size: 13, weight: .heavy, design: .rounded))
                Spacer()
                Text("전체 \(FriendID.visible.count)종").font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.soft)
            }.padding(.horizontal, 2)
            ForEach([1, 2, 3], id: \.self) { tier in
                RarityPackRow(tier: tier, ownedFriends: ownedFriends)
            }
            Text(firstDraw ? "첫 뽑기도 같은 확률 · \(FriendID.visible.count)종 모두 만날 수 있어요" : "매번 같은 확률 · 이미 만난 친구도 나와요")
                .font(.system(size: 9)).foregroundStyle(Theme.soft)
                .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 2)
        }
        .padding(10)
        .background(Ink.rgb(0xF2EEE5), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Ink.rgb(0xD6D0C3), lineWidth: 1))
    }
}

private struct RarityPackRow: View {
    let tier: Int
    let ownedFriends: Set<FriendID>
    private var finish: CardFinish { CardFinish(tier: tier) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 7) {
                Text(finish.code)
                    .font(.system(size: 19, weight: .black, design: .rounded).width(.condensed))
                    .italic().tracking(-0.8)
                    .foregroundStyle(finish.gradient)
                    .shadow(color: .black.opacity(0.4), radius: 0, y: 1)
                Text(finish.name).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.85))
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<tier, id: \.self) { _ in
                        Image(systemName: "star.fill").font(.system(size: 8, weight: .black))
                    }
                }.foregroundStyle(finish.emblem)
            }.padding(.horizontal, 10).padding(.vertical, 5)
                .background(LinearGradient(colors: [Ink.rgb(0x374351), Ink.rgb(0x202834)], startPoint: .leading, endPoint: .trailing))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                ForEach(DrawOdds.displayOrder.filter { $0.rarity == tier }, id: \.self) { friend in
                    OddsCollectorCard(friend: friend, finish: finish, owned: ownedFriends.contains(friend))
                }
            }.padding(7)
                .background(Ink.rgb(0xF5F1E8))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(finish.gradient, lineWidth: 1.5))
        .shadow(color: finish.ink.opacity(0.14), radius: 0, y: 2)
    }
}

private struct OddsCollectorCard: View {
    let friend: FriendID
    let finish: CardFinish
    let owned: Bool
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                CardFoilBackground(finish: finish, highlighted: hovering)
                Canvas { context, size in
                    _ = SpriteArt.drawFace(context, friend, in: CGRect(origin: .zero, size: size), silhouette: !owned)
                }.frame(width: 38, height: 38)
                    .shadow(color: finish.ink.opacity(0.12), radius: 0, y: 2)
            }.frame(height: 46)
            VStack(spacing: 3) {
                Text(friend.name).font(.system(size: 10, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(Int((DrawOdds.probability(of: friend) * 100).rounded()))")
                        .font(.system(size: 18, weight: .black, design: .rounded).width(.condensed))
                        .monospacedDigit().tracking(-0.6)
                    Text("%").font(.system(size: 9, weight: .heavy, design: .rounded))
                }
            }.foregroundStyle(finish.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 4)
                .background(Ink.rgb(0xFFFDF5))
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(2)
        .background(finish.gradient, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 7).inset(by: 1).stroke(.white.opacity(0.6), lineWidth: 0.5))
        .shadow(color: finish.ink.opacity(0.18), radius: hovering ? 3 : 0, y: 2)
        .offset(y: hovering && !reduceMotion ? -2 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovering)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(finish.name), \(friend.name), 등장 확률 \(Int((DrawOdds.probability(of: friend) * 100).rounded()))퍼센트")
    }
}
