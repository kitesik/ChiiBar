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
    @State private var demoModel: AppModel?
    var closeDemo: (() -> Void)?
    var body: some View {
        ZStack {
            Theme.background
            if demoModel == nil {
            VStack(spacing: 10) {
                HStack {
                    Text(model.isDemo ? "친구와 집 둘러보기" : "신분상승 토큰 치이카와").font(.system(size: 13, weight: .heavy))
                    Spacer()
                    Button(model.isDemo ? "체험 끝내기" : "둘러보기") {
                        if model.isDemo { closeDemo?() } else { demoModel = AppModel.demo() }
                    }.buttonStyle(.plain).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.actionText)
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
                } else if model.state.houses.isEmpty {
                    FirstFriendWelcome(model: model)
                } else { HomeView(model: model) }
            }
            .allowsHitTesting(model.gacha == nil)
            .accessibilityHidden(model.gacha != nil)
            if let g = model.gacha { GachaOverlay(model: model, session: g) }
            }
            if let demoModel {
                AnyView(PopoverView(model: demoModel, closeDemo: { self.demoModel = nil }))
            }
        }
        .frame(width: 340, height: 640)
        .foregroundStyle(Theme.text)
        .onAppear { model.welcome() }
    }
}

struct HomeView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 5) {
            HouseSceneView(model: model)
            FriendHeader(model: model)
            StageProgress(model: model)
            if model.isDemo {
                VStack(spacing: 8) {
                    HStack {
                        Button("다음 친구") { model.nextDemoFriend() }.disabled(model.building)
                        Button("경험치 받기") { model.demoGrow() }.disabled(model.building)
                        Button("쓰다듬기") { model.poke() }
                    }.buttonStyle(PrimaryActionStyle())
                    Text("9명과 13단계 집을 자유롭게 체험해요. 실제 기록은 그대로예요.")
                        .font(.system(size: 10)).foregroundStyle(Theme.soft)
                }.padding(.top, 12)
            } else { TodayDashboardView(model: model) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
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
        .frame(width: 320, height: 210)
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
            if hypot(loc.x - center.x, loc.y - center.y) < 42 { model.poke() }
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

struct StageProgress: View {
    @ObservedObject var model: AppModel
    @State private var hintStartedAt = Date()
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
    var baseline: Double? {
        guard carryover == nil, let f = model.state.current, let record = model.state.progressToday(for: f, at: model.now),
              record.startStage == house.stage, let cost = house.nextCost else { return nil }
        return min(1, Double(record.startProgress) / Double(cost))
    }
    private func guidance(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
                .foregroundStyle(Ink.rgb(0xE9A825))
            Text(text).font(.system(size: 10, weight: .semibold, design: .rounded)).lineLimit(2)
        }
        .foregroundStyle(Theme.hint)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func idleHint(index: Int) -> String {
        if model.building { return "뚝딱뚝딱… 새 집을 준비하고 있어요!" }
        if house.canBuild { return "재료 다 모았다! 업그레이드 눌러 이사하자!" }
        let name = model.state.current?.name ?? "친구"
        let hints = house.isComplete ? [
            "드디어 꼭대기 집! \(name)와 잠깐 쉬어 가요.",
            "친구를 톡 눌러 보세요. 쓰다듬어 줄 수 있어요.",
            "다른 친구는 어떤 집에 살까요? 친구 모음에 가 봐요."
        ] : [
            "Codex·Claude Code에서 쓴 토큰이 집 재료가 돼요.",
            "친구를 톡 눌러 보세요. 쓰다듬어 줄 수 있어요.",
            "하던 일 마치고 오면, \(name) 집도 한 걸음!",
            "게이지가 꽉 차면, 내 손으로 새 집을 지어요.",
            "열심히 했으니까… 잠깐 친구 보고 갈까요?"
        ]
        return hints[index % hints.count]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Clock(fixed: model.fixedNow) { date in
                let displayed = carryover?.displayedFraction(target: fraction, at: date, reduceMotion: reduceMotion) ?? fraction
                let carrying = carryover?.isAnimating(at: date) ?? false
                let landed = carryover.map { date.timeIntervalSince($0.startsAt) - UpgradeCarryover.duration } ?? -1
                VStack(spacing: 4) {
                    Group {
                        if let event = carryover, date >= event.startsAt, date.timeIntervalSince(event.startsAt) < UpgradeCarryover.duration + 5 {
                            guidance(carrying ? "남은 경험치 +\(TokenFormat.short(event.amount)) 이어 담는 중…" : "남은 경험치 덕분에 \(Int(fraction * 100))%부터 시작해요!", icon: "sparkles")
                                .scaleEffect(!reduceMotion && landed >= 0 && landed < 0.4 ? 1 + 0.035 * sin(landed / 0.4 * .pi) : 1, anchor: .leading)
                                .accessibilityLabel(event.explanation)
                        } else {
                            let elapsed = max(0, date.timeIntervalSince(model.fixedNow?.addingTimeInterval(-5) ?? hintStartedAt) - 3)
                            let phase = elapsed.truncatingRemainder(dividingBy: 12)
                            let visible = date.timeIntervalSince(hintStartedAt) >= 3 || model.fixedNow != nil
                            let opacity = visible && phase < 9 ? (reduceMotion ? 1 : min(1, phase / 0.4, (9 - phase) / 0.4)) : 0
                            guidance(idleHint(index: Int(elapsed / 12)), icon: "lightbulb.fill")
                                .opacity(opacity)
                                .accessibilityHidden(opacity < 0.5)
                        }
                    }
                    .frame(height: 28, alignment: .leading)
                    ProgressTrack(fraction: displayed, sweepFrom: carryover == nil ? model.lastCredit : nil,
                                  fixedNow: model.fixedNow, baseline: baseline,
                                  animatesChanges: !reduceMotion && !(carryover?.isAnimating(at: date) ?? false),
                                  endpointElapsed: carryover.map { date.timeIntervalSince($0.startsAt) - UpgradeCarryover.duration })
                        .scaleEffect(x: 1, y: !reduceMotion && landed >= 0 && landed < 0.4 ? 1 + 0.12 * sin(landed / 0.4 * .pi) : 1)
                        .contentShape(Rectangle())
                        .help(carryover?.explanation ?? "사용한 토큰이 경험치로 쌓여요. 가득 차면 업그레이드 버튼을 눌러 이사할 수 있어요.")
                    HStack {
                        Text(baseline == nil ? "\(HousePlan.name(of: house.stage))" : "오늘 첫 확인 \(Int((baseline ?? 0) * 100))% → 지금 \(Int(displayed * 100))%")
                        Spacer()
                        if !house.isComplete {
                            Text("\(Int(displayed * 100))%")
                                .font(.system(size: 12, weight: .heavy, design: .rounded)).monospacedDigit()
                                .foregroundStyle(Ink.rgb(0x493747))
                        }
                    }.font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.text)
                }
            }
            if let cost = house.nextCost {
                HStack(spacing: 4) {
                    Text("경험치 \(TokenFormat.short(house.progress)) / \(TokenFormat.short(cost))")
                    if let carryover {
                        Image(systemName: "info.circle")
                            .help(carryover.explanation)
                            .accessibilityLabel(carryover.explanation)
                    }
                }.font(.system(size: 10)).foregroundStyle(Theme.soft)
            }
            if house.canBuild || model.building { UpgradeButton(model: model).padding(.top, 5) }
        }
        .padding(.horizontal, 4)
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
    var animatesChanges = true
    var endpointElapsed: Double? = nil
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
        .frame(height: 13)
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
                        Text(model.state.houses.isEmpty ? "첫 뽑기권 1장을 선물로 드려요" : "토큰을 쓰면 뽑기권이 충전돼요")
                            .foregroundStyle(Theme.soft)
                    }
                    .font(.system(size: 10, weight: .regular))
                    .fixedSize(horizontal: false, vertical: true)
                    ProgressTrack(fraction: Double(model.state.ticketProgress) / Double(Tuning.ticketCost), sweepFrom: model.lastCredit, fixedNow: model.fixedNow)
                    Text("다음 뽑기권 \(TokenFormat.short(model.state.ticketProgress)) / \(TokenFormat.short(Tuning.ticketCost)) 토큰")
                        .font(.system(size: 10)).foregroundStyle(Theme.soft)
                }
                .padding(12).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
                DrawOddsCard(firstDraw: model.state.houses.isEmpty)
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
}

struct CollectionCard: View {
    @ObservedObject var model: AppModel
    let friend: FriendID
    var house: House? { model.state.houses[friend] }
    private var finish: CardFinish { CardFinish(tier: friend.rarity) }
    var body: some View {
        Button { model.select(friend) } label: {
            VStack(spacing: 0) {
                Canvas { ctx, size in
                    if house != nil {
                        FriendArt.draw(ctx, friend, base: CGPoint(x: size.width / 2, y: size.height - 3), size: 28, pose: Pose())
                    } else {
                        ctx.draw(Text("?").font(.system(size: 30, weight: .bold)).foregroundColor(finish.ink.opacity(0.5)),
                                 at: CGPoint(x: size.width / 2, y: size.height / 2))
                    }
                }
                .frame(height: 56)
                .background(CardFoilBackground(finish: finish))
                VStack(spacing: 3) {
                    Text(friend.name).font(.system(size: 12, weight: .bold))
                        .foregroundStyle(finish.ink)
                    Text(house.map { HousePlan.name(of: $0.stage) } ?? "미보유")
                        .font(.system(size: 9)).foregroundStyle(Theme.soft)
                        .lineLimit(2).multilineTextAlignment(.center)
                        .frame(height: 24)
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
        .buttonStyle(.plain).disabled(house == nil || model.building)
        .accessibilityLabel("\(friend.name), \(finish.name), \(house.map { HousePlan.name(of: $0.stage) } ?? "미보유"), \(house == nil ? "아직 만나지 않은 친구" : "집으로 이동")")
        .accessibilityAddTraits(model.state.current == friend ? .isSelected : [])
    }
}

struct DrawButton: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Button("뽑기") { model.drawTicket() }
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
        ZStack(alignment: .bottom) {
            Clock(fixed: model.fixedNow) { date in
                Canvas { ctx, size in
                    GachaArt.draw(ctx, canvas: size, t: reduceMotion ? GachaArt.finishAt : date.timeIntervalSince(session.start),
                                  idleTime: reduceMotion ? 0 : date.timeIntervalSinceReferenceDate, result: session.result)
                }
                .accessibilityLabel(date.timeIntervalSince(session.start) >= GachaArt.revealAt || reduceMotion
                    ? "\(session.result.friend.name), \(session.result.friend.japaneseName)" : "친구 뽑기")
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
