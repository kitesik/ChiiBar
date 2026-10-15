import ChiiCore
import Foundation

struct GachaSession {
    var start: Date
    var result: DrawResult
}

enum AppTab: String, CaseIterable { case home = "집", friends = "친구" }

@MainActor
final class AppModel: ObservableObject {
    @Published var tab: AppTab
    @Published var state: GameState
    @Published var reveal: (stage: Int, start: Date)?
    @Published var endingStart: Date?
    @Published var bubble: (text: String, start: Date)?
    @Published var pokeStart: Date?
    @Published var gacha: GachaSession?
    @Published var lastCredit: Date?
    @Published var upgradeNotice: (text: String, start: Date)?
    @Published var building = false

    /// Previews pin the clock; the live app leaves it nil and follows real time.
    let fixedNow: Date?
    var activityOverride: Activity?
    private let stateURL: URL?
    private var scanning = false
    private var timer: Timer?

    init(state: GameState, stateURL: URL?, fixedNow: Date? = nil) {
        self.tab = state.houses.isEmpty ? .friends : .home
        self.state = state
        self.stateURL = stateURL
        self.fixedNow = fixedNow
        self.state.observeProgress(at: fixedNow ?? Date())
    }

    var now: Date { fixedNow ?? Date() }

    func startLive() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func refresh() {
        guard !scanning else { return }
        scanning = true
        let scan = state.scan, cutoff = state.creditFrom
        Task.detached(priority: .utility) {
            var s = scan
            let events = UsageScanner.scan(state: &s, claudeRoot: UsageScanner.defaultClaudeRoot,
                                           codexRoot: UsageScanner.defaultCodexRoot, fastForwardClaudeBefore: cutoff)
            let done = s
            await MainActor.run { self.apply(scan: done, events: events) }
        }
    }

    func apply(scan: ScanState, events: [TokenEvent]) {
        scanning = false
        let previousProgress = state.dailyProgress
        state.observeProgress(at: now)
        guard scan != state.scan || !events.isEmpty else {
            if previousProgress != state.dailyProgress { save() }
            return
        }
        state.scan = scan
        let gained = state.credit(events)
        if events.contains(where: { $0.date >= state.creditFrom }) { lastCredit = now }
        handle(gained)
        save()
    }

    func handle(_ events: [GameEvent]) {
        for e in events {
            switch e {
            case .piece(let f, let stage) where f == state.current:
                reveal = (stage, now)
                say(f.lines.randomElement()!)
            case .completed(let f) where f == state.current:
                endingStart = now
                say("행복해…")
            default:
                break
            }
        }
    }

    func say(_ text: String) { bubble = (text, now) }

    func poke() {
        guard let f = state.current else { return }
        pokeStart = now
        say(f.lines.randomElement()!)
    }

    func buildHouse() {
        guard !building, gacha == nil, state.currentHouse?.canBuild == true else { return }
        let events = state.build(at: now)
        guard let f = state.current, let h = state.currentHouse else { return }
        // Commit once at the click, so closing the popover never loses or repeats it.
        building = true
        upgradeNotice = nil
        reveal = (h.stage, now)
        endingStart = nil
        say("뚝딱뚝딱!")
        save()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard let self else { return }
            self.building = false
            self.upgradeNotice = (UpgradeCopy.completion[h.stage]!, self.now)
            if events.contains(.completed(f)) {
                self.endingStart = self.now
                self.say("행복해…")
            } else { self.say("다 지었다!") }
        }
    }

    func select(_ f: FriendID) {
        guard !building else { return }
        reveal = nil
        upgradeNotice = nil
        endingStart = nil
        state.select(f)
        state.observeProgress(at: now)
        tab = .home
        save()
    }

    func drawTicket() {
        guard gacha == nil, !building else { return }
        state.observeProgress(at: now)
        var rng = SystemRandomNumberGenerator()
        guard let r = state.draw(using: &rng) else { return }
        state.observeProgress(at: now)
        upgradeNotice = nil
        gacha = GachaSession(start: now, result: r)
        save()
    }

    func finishGacha(reducedMotion: Bool = false) {
        guard let g = gacha, reducedMotion || now.timeIntervalSince(g.start) >= GachaArt.finishAt else { return }
        gacha = nil
        tab = .home
        state.select(g.result.friend)
        switch g.result.outcome {
        case .newFriend: say(g.result.friend.lines.first!)
        case .gift:
            say("집 지을 재료를 가져왔어!")
        case .ticketBack: say(g.result.friend.lines.randomElement()!)
        }
        save()
    }

    func save() {
        guard let stateURL else { return }
        try? Store.save(state, to: stateURL)
    }

    // MARK: scene

    func sceneParams(at date: Date) -> SceneParams? {
        guard let f = state.current, let h = state.houses[f] else { return nil }
        let mood = Mood.at(date, lastTokenAt: state.lastTokenAt)
        let activity = activityOverride ?? Activity.choose(mood: mood, stage: h.stage, now: date, friend: f)
        func since(_ d: Date?, _ limit: Double) -> Double? {
            guard let d else { return nil }
            let e = date.timeIntervalSince(d)
            return e >= 0 && e < limit ? e : nil
        }
        var p = SceneParams(friend: f, stage: h.stage, activity: activity, t: date.timeIntervalSinceReferenceDate)
        if let r = reveal, let e = since(r.start, 4) { p.reveal = (r.stage, e) }
        p.endingElapsed = since(endingStart, 7)
        p.pokeElapsed = since(pokeStart, 1.5)
        if let b = bubble, since(b.start, 2.6) != nil { p.bubble = b.text }
        p.snackIsPudding = Int(date.timeIntervalSince1970 / 120) % 2 == 1
        return p
    }
}

/// Authored per item: Korean particles and completion verbs are intentional.
enum UpgradeCopy {
    static let completion: [Int: String] = [
        2: "나무 마루가 놓였어요!",
        3: "벽이 세워졌어요!",
        4: "지붕이 올라갔어요!",
        5: "방석이 놓였어요!",
        6: "작은 밥상이 놓였어요!",
        7: "포근한 이불이 준비됐어요!",
        8: "창문과 커튼이 설치됐어요!",
        9: "스탠드 조명이 켜졌어요!",
        10: "작은 부엌이 만들어졌어요!",
        11: "화분과 책이 놓였어요!",
        12: "액자와 가랜드로 꾸민 우리 집, 완성!"
    ]
}
