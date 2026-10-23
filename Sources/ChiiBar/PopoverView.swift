import ChiiCore
import SwiftUI

enum Theme {
    static let background = LinearGradient(colors: [Ink.rgb(0xFFFBF0), Ink.rgb(0xF0F6FA)], startPoint: .top, endPoint: .bottom)
    static let text = Ink.rgb(0x4A4048)
    static let hint = Ink.rgb(0xCF4455)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let fixed: Date?
    @ViewBuilder let content: (Date) -> Content
    var body: some View {
        if let fixed { content(fixed) } else {
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1 / 30)) { ctx in content(ctx.date) }
        }
    }
}

struct PopoverView: View {
    @ObservedObject var model: AppModel
    var closeDemo: (() -> Void)?
    var showDesktop: (() -> Void)?
    var body: some View {
        ZStack {
            Theme.background
            VStack(spacing: 10) {
                HStack {
                    Text("치이카와 키우기").font(.system(size: 13, weight: .heavy))
                    Spacer()
                    if model.isDemo {
                        Button("체험 끝내기") { closeDemo?() }
                            .buttonStyle(.plain).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.actionText)
                    }
                }.padding(.horizontal, 14).padding(.top, 8)
                HStack(spacing: 4) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        Button { model.tab = tab } label: {
                            HStack(spacing: 5) {
                                GameSymbol(kind: tab == .home ? .home : .friends)
                                Text(tab.rawValue)
                            }.font(.system(size: 13, weight: .bold))
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
                } else if model.state.visibleOwnedCount == 0 {
                    FirstFriendWelcome(model: model)
                } else { HomeView(model: model, showDesktop: showDesktop) }
            }
            .allowsHitTesting(model.gacha == nil && model.batchResults == nil && model.inspectedFriend == nil)
            .accessibilityHidden(model.gacha != nil || model.batchResults != nil || model.inspectedFriend != nil)
            if let g = model.gacha { GachaOverlay(model: model, session: g) }
            if let results = model.batchResults { BatchDrawOverlay(model: model, results: results) }
            if let friend = model.inspectedFriend { FriendDetailView(model: model, friend: friend) }
        }
        .frame(width: 340, height: 710)
        .foregroundStyle(Theme.text)
        .onAppear { model.welcome() }
    }
}

struct HomeView: View {
    @ObservedObject var model: AppModel
    var showDesktop: (() -> Void)?
    var body: some View {
        ScrollView {
        VStack(spacing: 5) {
            HouseSceneView(model: model)
                .overlay(alignment: .bottomTrailing) {
                    if let showDesktop {
                        Button("산책가자!", action: showDesktop)
                            .buttonStyle(WalkActionStyle())
                            .help("친구와 바탕화면에서 산책해요")
                            .padding(.trailing, 10).padding(.bottom, 9)
                    }
                }
            FriendHeader(model: model)
            StageProgress(model: model)
            if model.isDemo {
                VStack(spacing: 8) {
                    HStack {
                        Button("다음 친구") { model.nextDemoFriend() }.disabled(model.building)
                        Button("경험치 받기") { model.demoGrow() }.disabled(model.building)
                        Button("쓰다듬기") { model.poke() }
                    }.buttonStyle(PrimaryActionStyle())
                    Text("\(FriendID.visible.count)종과 13단계 집을 자유롭게 체험해요. 실제 기록은 그대로예요.")
                        .font(.system(size: 10)).foregroundStyle(Theme.soft)
                }.padding(.top, 12)
            } else { TodayDashboardView(model: model) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        }
        // With "always show scroll bars" (or a mouse attached) the legacy scroller takes ~15pt on the right
        // and pushes the content off-center. The popover scrolls by wheel or trackpad, so no bar is needed.
        .scrollIndicators(.never)
    }
}

struct HouseSceneView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Clock(fixed: model.fixedNow) { date in
            Canvas { ctx, size in
                if var p = model.sceneParams(at: date) {
                    p.reduceMotion = reduceMotion
                    if reduceMotion { p.constructionProgress = model.state.currentHouse?.fraction ?? 0 }
                    HouseArt.draw(ctx, canvas: size, p)
                }
            }
        }
        .frame(width: HouseArt.size.width, height: HouseArt.size.height)
        .overlay(alignment: .topLeading) {
            Clock(fixed: model.fixedNow) { date in
                if let notice = model.upgradeNotice,
                   (0..<5).contains(date.timeIntervalSince(notice.start)) {
                    let e = date.timeIntervalSince(notice.start)
                    VStack(spacing: 2) {
                        Text("✦ 새 집 완성! ✦").font(.system(size: 10, weight: .bold))
                        Text(notice.text).font(.system(size: 13, weight: .heavy, design: .rounded))
                    }
                        .foregroundStyle(Ink.rgb(0x674018))
                        .frame(width: 172).padding(.vertical, 7)
                        .background(LinearGradient(colors: [Ink.rgb(0xFFF1BB), Ink.rgb(0xFFD88C)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Ink.rgb(0xDAA453), lineWidth: 1.5))
                        .shadow(color: Ink.rgb(0xD8B66E).opacity(0.3), radius: 6, y: 3)
                        .scaleEffect(reduceMotion ? 1 : 1 + 0.08 * sin(min(1, e / 0.5) * .pi) * max(0, 1 - e / 0.5))
                        .padding(.leading, 10).padding(.top, 8)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.state.current?.name ?? "친구")의 집")
        .accessibilityHint("친구를 쓰다듬으려면 활성화하세요")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.poke() }
        .help("친구를 눌러 쓰다듬어 보세요")
        .onTapGesture(coordinateSpace: .local) { loc in
            guard var params = model.sceneParams(at: model.now) else { return }
            params.reduceMotion = reduceMotion
            let center = DioramaArt.hitCenter(params)
            if hypot(loc.x - center.x, loc.y - center.y) < 42 * 1.3 { model.poke() }
        }
    }
}

struct FriendHeader: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(model.state.current?.name ?? "친구")
                .font(.custom("AppleSDGothicNeo-Heavy", size: 19))
                .tracking(-0.5)
                .foregroundStyle(Ink.rgb(0x51404E))
                .shadow(color: .white, radius: 0, y: 1)
            Text(model.state.current?.japaneseName ?? "")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Ink.rgb(0x857789))
            Spacer(minLength: 0)

        }.padding(.horizontal, 4)

    }
}

/// A quiet scene action with a small tactile press.
struct WalkActionStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Ink.rgb(0x715D50))
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Ink.rgb(configuration.isPressed ? 0xF1E7D5 : 0xFFF9EC), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Ink.rgb(0xB8A592), lineWidth: 0.8))
            .offset(y: configuration.isPressed ? 1 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct StageProgress: View {
    @ObservedObject var model: AppModel
    @State private var showBonusInfo = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var carryover: UpgradeCarryover? {
        guard let event = model.carryover,
              event.friend == model.state.current, event.stage == house.stage else { return nil }
        return event
    }
    var house: House { model.state.currentHouse ?? House() }
    var fraction: Double {
        guard let cost = house.nextCost else { return 1 }
        return min(1, Double(house.progress) / Double(cost))
    }
    private var todayXP: Int64 {
        guard let friend = model.state.current else { return 0 }
        return model.state.progressToday(for: friend, at: model.now)?.earned ?? 0
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LV. \(house.stage)")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.actionText)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Theme.action.opacity(0.5), in: Capsule())
                Text(HousePlan.name(of: house.stage)).font(.system(size: 12, weight: .bold))
                Spacer()
                Text(house.isComplete ? "최고 레벨" : "")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.soft)
            }
            Clock(fixed: model.fixedNow) { date in
                let displayed = carryover?.displayedFraction(target: fraction, at: date, reduceMotion: reduceMotion) ?? fraction
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(house.isComplete ? "꿈의 집 완성!" : "다음 집까지")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                        Text("\(Int(displayed * 100))%")
                            .font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit()
                            .foregroundStyle(Theme.actionText)
                    }
                    ProgressTrack(fraction: displayed, sweepFrom: nil, fixedNow: model.fixedNow,
                                  animatesChanges: !reduceMotion && !(carryover?.isAnimating(at: date) ?? false), height: 10)
                        .accessibilityLabel("집 성장 \(Int(displayed * 100))퍼센트")
                    if let cost = house.nextCost {
                        HStack {
                            Text("\(house.progress.formatted()) / \(cost.formatted()) XP")
                                .font(.system(size: 10, weight: .medium)).monospacedDigit()
                            Spacer(minLength: 4)
                            Text(house.canBuild ? "이사 준비 완료!" : "활동 약 \(WorkTimeFormat.energy(cost - house.progress)) 남음")
                                .font(.system(size: 10, weight: .semibold))
                        }.foregroundStyle(Theme.soft)
                    }
                }
            }
            HStack(spacing: 5) {
                Text("오늘 얻은 경험치")
                Spacer()
                Text("+\(todayXP.formatted()) XP")
                    .fontWeight(.bold).monospacedDigit()
            }
            .font(.system(size: 11))
            .foregroundStyle(Ink.rgb(0x39705B))
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(Ink.rgb(0xEDF5ED), in: RoundedRectangle(cornerRadius: 8))
            Button { showBonusInfo = true } label: {
                let extra = model.state.current.flatMap { model.state.progressToday(for: $0, at: model.now)?.extraXP } ?? 0
                HStack(spacing: 4) {
                    Text(extra > 0 ? "Extra +\(extra.formatted()) XP 포함" : "로컬 AI를 쓰면 작은 보너스 XP")
                    Image(systemName: "info.circle")
                }.font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.soft)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showBonusInfo) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("작은 도움, Extra XP").font(.system(size: 13, weight: .bold))
                    Text("Claude Code·Codex의 로컬 사용 기록에서 토큰을 확인해 집 성장에 보너스를 더해요.")
                    Text("환산 토큰 100개당 1 XP\n활동 경험치의 최대 5%\n하루 최대 12,000 XP · 활동 6분 분량")
                    Text("오늘 얻은 경험치에 포함돼요. 활동 시간과 뽑기권 충전량은 그대로예요. 캐시 토큰은 일부만 반영하며, 기록이 없는 사용은 포함되지 않아요.")
                        .foregroundStyle(Theme.soft)
                }.font(.system(size: 11)).padding(16).frame(width: 270)
                    .foregroundStyle(Theme.text).background(Theme.background)
            }
            if let carryover {
                Text("집 업그레이드 −\(HousePlan.cost(ofStage: house.stage).formatted()) XP · 남은 +\(carryover.amount.formatted()) XP를 이어받았어요.")
                    .font(.system(size: 10)).foregroundStyle(Theme.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if house.canBuild || model.building { UpgradeButton(model: model).padding(.bottom, 3) }
        }
        .foregroundStyle(Theme.text)
        .padding(12)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.22), lineWidth: 1))
    }
}

struct UpgradeButton: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var ready: Bool { model.state.currentHouse?.canBuild == true && !model.building && !(model.carryover?.isAnimating(at: model.now) ?? false) }
    var body: some View {
        Clock(fixed: model.fixedNow) { date in
            let ready = model.state.currentHouse?.canBuild == true && !model.building && !(model.carryover?.isAnimating(at: date) ?? false)
            let pulse = reduceMotion ? 0.5 : (sin(date.timeIntervalSinceReferenceDate * 2.4) + 1) / 2
            Button { model.buildHouse() } label: {
                HStack(spacing: 4) {
                    if ready {
                        GameSymbol(kind: .home)
                    }
                    Text(model.building ? "새 집을 짓고 있어요…" : ready ? "새 집으로 업그레이드" : "경험치 반영 중…")
                    if ready { Image(systemName: "sparkles").opacity(0.7 + pulse * 0.3) }
                }.frame(maxWidth: .infinity)
            }
            .buttonStyle(UpgradeActionStyle())
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Ink.rgb(0xD69B45).opacity(ready ? 0.2 + pulse * 0.25 : 0), lineWidth: 1.5)
                .allowsHitTesting(false))
            .compositingGroup()
            .shadow(color: Ink.rgb(0xFFC76D).opacity(ready ? 0.16 + pulse * 0.15 : 0), radius: 3 + pulse * 4)
            .disabled(!ready)
            .accessibilityLabel(ready ? "업그레이드 가능" : "업그레이드")
        }
    }
}

/// A warm raised game button; its base remains visible until the face is pressed down.
struct UpgradeActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(enabled ? Ink.rgb(0x674018) : Theme.soft)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(LinearGradient(colors: enabled ? [Ink.rgb(0xFFF0B5), Ink.rgb(0xFFD37A)] : [Ink.rgb(0xEAE6E2), Ink.rgb(0xE1DDD8)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(enabled ? Ink.rgb(0xD59A48) : Ink.rgb(0xC8BFB5), lineWidth: 1.5))
            .overlay(alignment: .top) { Capsule().fill(.white.opacity(0.65)).frame(height: 2).padding(.horizontal, 12).padding(.top, 3) }
            .compositingGroup()
            .shadow(color: enabled ? Ink.rgb(0xBC833B) : .clear, radius: 0, y: configuration.isPressed ? 1 : 4)
            .offset(y: configuration.isPressed ? 3 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.58), value: configuration.isPressed)
    }
}

struct TodayDashboardView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Clock(fixed: model.fixedNow) { date in
            let records = (model.state.dailyProgress ?? [:]).values.filter { $0.day == DayKey.of(date) }
            let earned = WorkActivity.energy(for: model.state.workActivity?.seconds(on: date) ?? 0)
            let upgrades = records.reduce(0) { $0 + $1.upgrades }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("오늘의 활동").font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text(model.activityPaused ? "잠시 멈춤" : model.isWorkActive ? "기록 중" : "쉬는 중")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(model.isWorkActive ? Ink.rgb(0x39705B) : Theme.soft)
                }
                DailyGoalCard(earned: earned)
                HStack {
                    Text("오늘 집 업그레이드")
                    Spacer()
                    Text("\(upgrades)회").fontWeight(.bold)
                }.font(.system(size: 11)).foregroundStyle(Theme.soft)
                if !model.activityReadable {
                    Button("활동 감지 권한 확인") { model.openActivityPermission() }
                }
            }
            .padding(12)
            .background(Ink.rgb(0xFFF9EB), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Ink.rgb(0xD7C79C).opacity(0.5), lineWidth: 1))
            .help("키보드·클릭·스크롤 후 5분까지 기록해요. 활동 1분마다 2,000 XP가 쌓여요.")

        }
    }
}

struct ProgressTrack: View {
    let fraction: Double
    let sweepFrom: Date?
    let fixedNow: Date?
    var baseline: Double? = nil
    var animatesChanges = true
    var endpointElapsed: Double? = nil
    var height: CGFloat = 13
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.rgb(0xE5EBED))
                Capsule().fill(LinearGradient(colors: [Ink.rgb(0xB8D8EB), Theme.accent], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, g.size.width * fraction))
                    .animation(animatesChanges ? .timingCurve(0.16, 0.85, 0.25, 1, duration: 1.15) : nil, value: fraction)
                Sweep(from: sweepFrom, fixedNow: fixedNow, width: g.size.width * fraction)
                if let baseline {
                    Rectangle().fill(Theme.actionText).frame(width: 2, height: 10)
                        .offset(x: min(g.size.width - 2, max(0, g.size.width * baseline)))
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.accent.opacity(0.6), lineWidth: 1.5))
        .overlay(alignment: .top) { Capsule().fill(.white.opacity(0.6)).frame(height: 2).padding(.horizontal, 5).padding(.top, 2).allowsHitTesting(false) }
        .overlay {
            GeometryReader { geometry in
                if let e = endpointElapsed, e >= 0, e < 1.1, fraction > 0 {
                    EndpointSparkle(elapsed: e)
                        .position(x: min(geometry.size.width - 3, max(3, geometry.size.width * fraction)), y: 6.5)
                }
            }.allowsHitTesting(false)
        }
    }
}

/// Completion glint is anchored to the fill tip, including partial (e.g. 50%) bars.
struct EndpointSparkle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let elapsed: Double
    var body: some View {
        Canvas { context, _ in
            guard !reduceMotion else { return }
            var ctx = context; ctx.translateBy(x: 32, y: 32)
            let fade = max(0, 1 - elapsed / 1.1)
            let pulse = sin(min(1, elapsed / 0.25) * .pi / 2)
            ctx.fill(Path(ellipseIn: CGRect(x: -10, y: -10, width: 20, height: 20)), with: .color(Ink.rgb(0xFFDE82).opacity(fade * 0.3)))
            for i in 0..<5 {
                let angle = Double(i) * .pi * 2 / 5 - .pi / 2
                let radius = i == 0 ? 0 : (5 + elapsed * 13)
                let x = cos(angle) * radius, y = sin(angle) * radius
                let r = (i == 0 ? 6.0 : 3.0) * pulse * fade
                var star = Path(); star.move(to: CGPoint(x: x, y: y-r))
                star.addLine(to: CGPoint(x: x+r*0.3, y: y-r*0.3)); star.addLine(to: CGPoint(x: x+r, y: y))
                star.addLine(to: CGPoint(x: x+r*0.3, y: y+r*0.3)); star.addLine(to: CGPoint(x: x, y: y+r))
                star.addLine(to: CGPoint(x: x-r*0.3, y: y+r*0.3)); star.addLine(to: CGPoint(x: x-r, y: y))
                star.addLine(to: CGPoint(x: x-r*0.3, y: y-r*0.3)); star.closeSubpath()
                ctx.fill(star, with: .color(i == 0 ? .white.opacity(fade) : Ink.rgb(0xE9B84F).opacity(fade)))
            }
        }.frame(width: 64, height: 64)
    }
}

/// A white shine that runs along the filled part right after tokens arrive.
struct Sweep: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let from: Date?
    let fixedNow: Date?
    let width: CGFloat
    var body: some View {
        Clock(fixed: fixedNow) { date in
            let e = from.map { date.timeIntervalSince($0) } ?? 99
            if !reduceMotion && e >= 0 && e < 1.2 {
                Capsule().fill(.white.opacity(0.7)).frame(width: 24)
                    .offset(x: -24 + (width + 24) * e / 1.2)
            }
        }
    }
}

struct FriendsView: View {
    @ObservedObject var model: AppModel
    @State private var showingOdds = false
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("친구 뽑기").font(.system(size: 16, weight: .bold))
                        Spacer()
                        Text("뽑기권 \(model.state.tickets)장").font(.system(size: 12, weight: .semibold))
                        DrawButton(model: model)
                    }
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "ticket").foregroundStyle(Theme.soft)
                        Text(model.isDemo ? "체험용 뽑기권이에요. 실제 기록은 그대로예요." : model.state.visibleOwnedCount == 0 ? "첫 뽑기권 1장을 선물로 드려요" : "활동 1시간마다 뽑기권 1장이 생겨요")
                            .foregroundStyle(Theme.soft)
                    }
                    .font(.system(size: 10, weight: .regular))
                    .fixedSize(horizontal: false, vertical: true)
                    ProgressTrack(fraction: Double(model.state.ticketProgress) / Double(Tuning.ticketCost), sweepFrom: model.lastCredit, fixedNow: model.fixedNow)
                    Text("다음 뽑기권 \(WorkTimeFormat.energy(model.state.ticketProgress)) / \(WorkTimeFormat.energy(Tuning.ticketCost))")
                        .font(.system(size: 10)).foregroundStyle(Theme.soft)
                }
                .padding(12).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
                HStack(spacing: 4) {
                    ForEach([false, true], id: \.self) { odds in
                        Button { showingOdds = odds } label: {
                            Text(odds ? "뽑기 확률" : "친구 모음")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(showingOdds == odds ? Theme.actionText : Theme.text)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(showingOdds == odds ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                        .accessibilityAddTraits(showingOdds == odds ? .isSelected : [])
                    }
                }.padding(3).background(Ink.rgb(0xE5EDF1), in: RoundedRectangle(cornerRadius: 10))
                if showingOdds {
                    DrawOddsCard(firstDraw: model.state.visibleOwnedCount == 0)
                } else {
                HStack {
                    Text("친구 모음").font(.system(size: 14, weight: .bold))
                    Spacer()
                    Text("\(model.state.visibleOwnedCount) / \(FriendID.visible.count)")
                        .font(.system(size: 12)).foregroundStyle(Theme.soft)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(DrawOdds.displayOrder, id: \.self) { f in
                        CollectionCard(model: model, friend: f)
                    }
                }
                Text("카드를 누르면 소개와 친구의 집을 볼 수 있어요.")
                    .font(.system(size: 10)).foregroundStyle(Theme.soft)
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 12).padding(.bottom, 12)
        }
        .scrollIndicators(.never)   // same as HomeView: keep both margins equal when scroll bars are always shown
    }
}

struct CollectionCard: View {
    @ObservedObject var model: AppModel
    let friend: FriendID
    var house: House? { model.state.houses[friend] }
    private var finish: CardFinish { CardFinish(tier: friend.rarity) }
    var body: some View {
        Button { model.inspectedFriend = friend } label: {
            VStack(spacing: 0) {
                Canvas { ctx, size in
                    if house != nil {
                        FriendArt.draw(ctx, friend, base: CGPoint(x: size.width / 2, y: size.height - 3), size: 23, pose: Pose())
                    } else {
                        ctx.draw(Text("?").font(.system(size: 30, weight: .bold)).foregroundColor(finish.ink.opacity(0.5)),
                                 at: CGPoint(x: size.width / 2, y: size.height / 2))
                    }
                }
                .frame(height: 44)
                .background(CardFoilBackground(finish: finish))
                .overlay(alignment: .topLeading) {
                    Text(finish.code).font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundStyle(finish.ink).padding(.horizontal, 5).padding(.vertical, 3)
                        .background(.white.opacity(0.85), in: Capsule()).padding(4)
                }
                .overlay(alignment: .topTrailing) {
                    if model.state.current == friend {
                        Image(systemName: "heart.fill").font(.system(size: 10))
                            .foregroundStyle(Ink.rgb(0xBD6379)).padding(5)
                    }
                }
                VStack(spacing: 3) {
                    Text(friend.name).font(.system(size: 12, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(finish.ink)
                    Text(house.map { "Lv. \($0.stage) · \(HousePlan.name(of: $0.stage))" } ?? "아직 만나기 전")
                        .font(.system(size: 9)).foregroundStyle(Theme.soft)
                        .lineLimit(2).multilineTextAlignment(.center)
                        .frame(height: 18)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 5)
                .background(Ink.rgb(0xFFFDF5))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(2)
            .background(finish.gradient, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(model.state.current == friend ? Theme.actionText : .clear, lineWidth: 2))
            .opacity(house == nil ? 0.65 : 1)
        }
        .shadow(color: finish.ink.opacity(0.14), radius: 0, y: 2)
        .buttonStyle(.plain).disabled(model.building)
        .accessibilityLabel("\(friend.name), \(finish.name), \(house.map { HousePlan.name(of: $0.stage) } ?? "미보유"), \(house == nil ? "아직 만나지 않은 친구" : "친구 소개 보기")")
        .accessibilityAddTraits(model.state.current == friend ? .isSelected : [])
    }
}

struct DrawButton: View {
    @ObservedObject var model: AppModel
    @State private var choosing = false
    var body: some View {
        Button("뽑기") { choosing = true }
            .buttonStyle(PrimaryActionStyle())
            .disabled(model.state.tickets == 0 || model.building || model.gacha != nil || model.batchResults != nil)
            .popover(isPresented: $choosing, arrowEdge: .bottom) {
                DrawChoiceView(tickets: model.state.tickets,
                    single: { choosing = false; model.drawTicket() },
                    all: { choosing = false; model.drawAllTickets() })
            }
    }
}

struct DrawChoiceView: View {
    let tickets: Int
    var single: () -> Void
    var all: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Text("어떻게 만날까요?").font(.system(size: 16, weight: .heavy))
            Text("뽑기권 \(tickets)장 보유").font(.system(size: 11)).foregroundStyle(Theme.soft)
            Button(action: single) {
                Text("하나씩 뽑기").font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
            }.buttonStyle(PrimaryActionStyle())
            Button(action: all) {
                Text("한 번에 모두 뽑기").font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
            }.buttonStyle(PrimaryActionStyle())
        }.padding(20).frame(width: 260).foregroundStyle(Theme.text).background(Theme.background)
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
        ZStack(alignment: .bottom) {
            Clock(fixed: model.fixedNow) { date in
                GachaAnimation(result: session.result, elapsed: date.timeIntervalSince(session.start),
                               idleTime: date.timeIntervalSinceReferenceDate, reducedMotion: reduceMotion)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Clock(fixed: model.fixedNow) { date in
                let ready = reduceMotion || date.timeIntervalSince(session.start) >= GachaArt.finishAt
                if ready {
                    Button { model.finishGacha(reducedMotion: reduceMotion) } label: {
                        HStack(spacing: 5) {
                            GameSymbol(kind: .home)
                            Text("집으로")
                        }.frame(width: 200, height: 24)
                    }
                    .buttonStyle(PrimaryActionStyle())
                    .padding(.bottom, 44)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.rgb(0x312B40))
        .contentShape(Rectangle())
    }
}
