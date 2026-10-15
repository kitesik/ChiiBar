import ChiiCore
import SwiftUI

enum Theme {
    static let background = LinearGradient(colors: [Ink.rgb(0xFFFBF0), Ink.rgb(0xF0F6FA)], startPoint: .top, endPoint: .bottom)
    static let text = Ink.rgb(0x4A4048)
    static let soft = Ink.rgb(0x8A7A84)
    static let accent = Ink.rgb(0x6E9CC4)
    static let action = Ink.rgb(0xC5DFF0)
    static let actionText = Ink.rgb(0x315771)
}

/// Explicit colors keep CTA appearance consistent across macOS accent settings.
struct PrimaryActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(enabled ? Theme.actionText : Ink.rgb(0x8D979C))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(enabled ? Theme.action : Ink.rgb(0xE7EAEB), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(enabled ? Theme.accent : Ink.rgb(0xCDD4D7), lineWidth: 1.5))
            .compositingGroup()
            .shadow(color: enabled ? Theme.accent.opacity(0.7) : .clear, radius: 0, y: configuration.isPressed ? 0 : 3)
            .offset(y: configuration.isPressed ? 2 : 0)
    }
}

/// Runs `content` with the live clock, or once with the model's pinned clock (previews).
struct Clock<Content: View>: View {
    let fixed: Date?
    @ViewBuilder let content: (Date) -> Content
    var body: some View {
        if let fixed { content(fixed) } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in content(ctx.date) }
        }
    }
}

struct PopoverView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ZStack {
            Theme.background
            VStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        Button { model.tab = tab } label: {
                            Label(tab.rawValue, systemImage: tab == .home ? "house.fill" : "person.2.fill").font(.system(size: 13, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .foregroundStyle(model.tab == tab ? Theme.text : Theme.soft)
                                .background(model.tab == tab ? Ink.rgb(0xFFFCF2) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9)
                                    .stroke(model.tab == tab ? Theme.accent.opacity(0.6) : .clear, lineWidth: 1)
                                    .allowsHitTesting(false))
                                .compositingGroup()
                                .shadow(color: Theme.accent.opacity(model.tab == tab ? 0.2 : 0), radius: 0, y: 2)
                                // Plain buttons otherwise hit-test only their visible label.
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(model.tab == tab ? .isSelected : [])
                    }
                }
                .padding(3).background(Ink.rgb(0xE7EDF0), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 12).padding(.top, 10)
                .disabled(model.building)
                if model.tab == .friends {
                    FriendsView(model: model)
                } else if model.state.houses.isEmpty {
                    VStack(spacing: 12) {
                        Text("친구와 함께 집을 만들어 보세요").font(.headline)
                        Button("친구 만나러 가기") { model.tab = .friends }.buttonStyle(PrimaryActionStyle())
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else { HomeView(model: model) }
            }
            if let g = model.gacha { GachaOverlay(model: model, session: g) }
        }
        .frame(width: 340, height: 560)
        .foregroundStyle(Theme.text)
    }
}

struct HomeView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 6) {
            HouseSceneView(model: model)
            FriendHeader(model: model)
            StageProgress(model: model)
            TodayDashboardView(model: model)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
    }
}

struct HouseSceneView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Clock(fixed: model.fixedNow) { date in
            Canvas { ctx, size in
                if let p = model.sceneParams(at: date) { HouseArt.draw(ctx, canvas: size, p) }
            }
        }
        .frame(width: 320, height: 210)
        .overlay(alignment: .bottom) {
            Clock(fixed: model.fixedNow) { date in
                if let notice = model.upgradeNotice,
                   (0..<5).contains(date.timeIntervalSince(notice.start)) {
                    Text(notice.text)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 8)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { loc in
            guard let p = model.sceneParams(at: model.now) else { return }
            let head = ActivityArt.headPoint(p)
            let pl = ActivityArt.placement(p)
            let center = CGPoint(x: head.x, y: (head.y + pl.base.y) / 2 + 6)
            if hypot(loc.x - center.x, loc.y - center.y) < 42 { model.poke() }
        }
    }
}

struct FriendHeader: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(spacing: 6) {
            if let f = model.state.current {
                Text(f.name).font(.system(size: 15, weight: .heavy, design: .rounded))
                Text(stars(f.rarity)).font(.system(size: 12)).foregroundStyle(Ink.rgb(0xFFB800))
            }
            Spacer()
            ActivityLabel(model: model)
        }
        .padding(.horizontal, 4)
    }
}

struct ActivityLabel: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Clock(fixed: model.fixedNow) { date in
            Text(model.building ? "업그레이드 중" : (model.sceneParams(at: date)?.activity.label ?? ""))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.soft)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(.white.opacity(0.8)))
        }
    }
}

struct StageProgress: View {
    @ObservedObject var model: AppModel
    var house: House { model.state.currentHouse ?? House() }
    var fraction: Double {
        guard let cost = house.nextCost else { return 1 }
        return min(1, Double(house.progress) / Double(cost))
    }
    var baseline: Double? {
        guard let f = model.state.current, let record = model.state.progressToday(for: f, at: model.now),
              record.startStage == house.stage, let cost = house.nextCost else { return nil }
        return min(1, Double(record.startProgress) / Double(cost))
    }
    var label: String {
        if model.building { return "\(HousePlan.pieceNames[house.stage - 1]) 업그레이드 중" }
        return house.isComplete ? "우리 집 완성 12/12"
            : "다음 단계: \(HousePlan.pieceNames[house.stage])"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 12, weight: .bold))
                Spacer()
                if !house.isComplete {
                    UpgradeButton(model: model)
                }
            }
            ProgressTrack(fraction: fraction, sweepFrom: model.lastCredit, fixedNow: model.fixedNow, baseline: baseline)
            HStack {
                Text(baseline == nil ? "집 \(house.stage)/12단계" : "오늘 첫 확인 \(Int((baseline ?? 0) * 100))% → 지금 \(Int(fraction * 100))%")
                Spacer()
                if !house.isComplete { Text("\(Int(fraction * 100))%") }
            }.font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.actionText)
            if let cost = house.nextCost {
                Text("경험치 \(TokenFormat.short(house.progress)) / \(TokenFormat.short(cost))")
                    .font(.system(size: 10)).foregroundStyle(Theme.soft)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct UpgradeButton: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var ready: Bool { model.state.currentHouse?.canBuild == true && !model.building }
    var body: some View {
        Clock(fixed: model.fixedNow) { date in
            let pulse = reduceMotion ? 0.5 : (sin(date.timeIntervalSinceReferenceDate * 2.4) + 1) / 2
            Button { model.buildHouse() } label: {
                HStack(spacing: 4) {
                    if ready { Image(systemName: "sparkles").opacity(0.65 + pulse * 0.35) }
                    Text(model.building ? "업그레이드 중…" : "업그레이드")
                }
            }
            .buttonStyle(PrimaryActionStyle())
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.accent.opacity(ready ? 0.35 + pulse * 0.45 : 0), lineWidth: 1.5)
                .allowsHitTesting(false))
            .compositingGroup()
            .shadow(color: Theme.accent.opacity(ready ? 0.12 + pulse * 0.2 : 0), radius: 3 + pulse * 4)
            .disabled(!ready)
            .accessibilityLabel(ready ? "업그레이드 가능" : "업그레이드")
        }
    }
}

struct TodayDashboardView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Clock(fixed: model.fixedNow) { date in
            let records = (model.state.dailyProgress ?? [:]).values.filter { $0.day == DayKey.of(date) }
            let earned = records.reduce(Int64(0)) { $0 + $1.earned }
            let upgrades = records.reduce(0) { $0 + $1.upgrades }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("오늘의 대시보드").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.soft)
                    Spacer()
                    Image(systemName: "sun.max.fill").foregroundStyle(Ink.rgb(0xD8AF51))
                }
                HStack(alignment: .center, spacing: 14) {
                    UpgradeBadge(count: upgrades)
                        .frame(width: 112)
                    DailyGoalCard(earned: earned)
                }
            }
            .padding(12)
            .background(LinearGradient(colors: [Ink.rgb(0xFFFCF3), .white], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Ink.rgb(0xD8CCAE), lineWidth: 1.5))
            .accessibilityElement(children: .combine)
        }
    }
}

struct ProgressTrack: View {
    let fraction: Double
    let sweepFrom: Date?
    let fixedNow: Date?
    var baseline: Double? = nil
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.rgb(0xE5EBED))
                Capsule().fill(LinearGradient(colors: [Ink.rgb(0xB8D8EB), Theme.accent], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, g.size.width * fraction))
                    .animation(.easeOut(duration: 0.9), value: fraction)
                Sweep(from: sweepFrom, fixedNow: fixedNow, width: g.size.width * fraction)
                if let baseline {
                    Rectangle().fill(Theme.actionText).frame(width: 2, height: 10)
                        .offset(x: min(g.size.width - 2, max(0, g.size.width * baseline)))
                }
            }
        }
        .frame(height: 13)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.accent.opacity(0.6), lineWidth: 1.5))
        .overlay(alignment: .top) { Capsule().fill(.white.opacity(0.6)).frame(height: 2).padding(.horizontal, 5).padding(.top, 2).allowsHitTesting(false) }
    }
}

/// A white shine that runs along the filled part right after tokens arrive.
struct Sweep: View {
    let from: Date?
    let fixedNow: Date?
    let width: CGFloat
    var body: some View {
        Clock(fixed: fixedNow) { date in
            let e = from.map { date.timeIntervalSince($0) } ?? 99
            if e >= 0 && e < 1.2 {
                Capsule().fill(.white.opacity(0.7)).frame(width: 24)
                    .offset(x: -24 + (width + 24) * e / 1.2)
            }
        }
    }
}

struct FriendsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("친구 뽑기").font(.system(size: 16, weight: .bold))
                        Spacer()
                        Text("뽑기권 \(model.state.tickets)장").font(.system(size: 12, weight: .semibold))
                        DrawButton(model: model)
                    }
                    Text(model.state.houses.isEmpty ? "첫 뽑기는 무료예요. 첫 친구를 만나 보세요." : "토큰을 모아 새로운 친구를 만나 보세요.")
                        .font(.system(size: 11)).foregroundStyle(Theme.soft)
                    ProgressTrack(fraction: Double(model.state.ticketProgress) / Double(Tuning.ticketCost), sweepFrom: model.lastCredit, fixedNow: model.fixedNow)
                    Text("다음 뽑기권 \(TokenFormat.short(model.state.ticketProgress)) / \(TokenFormat.short(Tuning.ticketCost)) 토큰")
                        .font(.system(size: 10)).foregroundStyle(Theme.soft)
                }
                .padding(12).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
                HStack {
                    Text("친구 모음").font(.system(size: 14, weight: .bold))
                    Spacer()
                    Text("\(model.state.houses.count) / \(FriendID.allCases.count)")
                        .font(.system(size: 12)).foregroundStyle(Theme.soft)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(FriendID.allCases, id: \.self) { f in
                        CollectionCard(model: model, friend: f)
                    }
                }
                Text("만난 친구를 선택하면 그 친구의 집으로 이동해요.")
                    .font(.system(size: 10)).foregroundStyle(Theme.soft)
                Spacer(minLength: 0)
            }.padding(.horizontal, 12).padding(.bottom, 12)
    }
}

struct CollectionCard: View {
    @ObservedObject var model: AppModel
    let friend: FriendID
    var house: House? { model.state.houses[friend] }
    var body: some View {
        Button { model.select(friend) } label: {
            VStack(spacing: 4) {
                Canvas { ctx, size in
                    if house != nil {
                        FriendArt.draw(ctx, friend, base: CGPoint(x: size.width / 2, y: size.height - 2), size: 28, pose: Pose())
                    } else {
                        ctx.draw(Text("?").font(.system(size: 30, weight: .bold)).foregroundColor(Theme.soft),
                                 at: CGPoint(x: size.width / 2, y: size.height / 2))
                    }
                }.frame(height: 50)
                Text(friend.name).font(.system(size: 12, weight: .bold))
                Text(house.map { $0.isComplete ? "집 완성" : "집 \($0.stage)/12" } ?? "미보유")
                    .font(.system(size: 9)).foregroundStyle(Theme.soft)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 5)
            .background(house == nil ? Ink.rgb(0xECE8EC) : friend.chipTint, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.state.current == friend ? Theme.accent : Ink.rgb(0xD8CCAE), lineWidth: model.state.current == friend ? 2 : 1))
        }
        .compositingGroup()
            .shadow(color: Ink.rgb(0xD8CCAE).opacity(0.45), radius: 0, y: 3)
        .buttonStyle(.plain).disabled(house == nil || model.building)
        .accessibilityLabel("\(friend.name), \(house == nil ? "미보유" : "집으로 이동")")
    }
}

struct DrawButton: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Button("친구 뽑기") { model.drawTicket() }
            .buttonStyle(PrimaryActionStyle())
            .disabled(model.state.tickets == 0 || model.building)
    }
}

struct ChipFace: View {
    let friend: FriendID
    let owned: Bool
    var body: some View {
        if owned {
            Canvas { ctx, size in FriendArt.drawFace(ctx, friend, in: CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 5)) }
        } else {
            Canvas { ctx, size in
                GachaArt.capsule(ctx, at: CGPoint(x: size.width / 2, y: size.height / 2), scale: 0.72, angle: 0.4, open: 0,
                                 color: Ink.rgb(0xC9C1C6))
                ctx.draw(Text("?").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundColor(Ink.rgb(0x8A7F86)),
                         at: CGPoint(x: size.width / 2, y: size.height / 2 + 7))
            }
        }
    }
}

struct GachaOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var model: AppModel
    let session: GachaSession
    var body: some View {
        ZStack {
            Theme.background
            VStack(spacing: 18) {
                Clock(fixed: model.fixedNow) { date in
                    Canvas { ctx, size in
                        GachaArt.draw(ctx, canvas: size, t: reduceMotion ? GachaArt.finishAt : date.timeIntervalSince(session.start),
                                      idleTime: date.timeIntervalSinceReferenceDate, result: session.result)
                    }
                }
                .frame(width: 320, height: 300)
                Clock(fixed: model.fixedNow) { date in
                    let ready = reduceMotion || date.timeIntervalSince(session.start) >= GachaArt.finishAt
                    Button(ready ? "집으로" : "친구를 만나는 중…") { model.finishGacha(reducedMotion: reduceMotion) }
                        .buttonStyle(PrimaryActionStyle()).disabled(!ready)
                }
            }
            .padding(.top, 20)
        }
    }
}
