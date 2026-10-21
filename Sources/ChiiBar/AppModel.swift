import ChiiCore
import Foundation
import AppKit
import CoreGraphics

struct GachaSession {
    var start: Date
    var result: DrawResult
}

enum AppTab: String, CaseIterable { case home = "집", friends = "친구" }

@MainActor
final class AppModel: ObservableObject {
    @Published var inspectedFriend: FriendID?
    @Published var arrivalStart: Date?
    private var progressTransition: (friend: FriendID, house: House, start: Date)?
    let isDemo: Bool
    @Published var tab: AppTab
    @Published var state: GameState
    @Published var reveal: (stage: Int, start: Date)?
    @Published var endingStart: Date?
    @Published var bubble: (text: String, start: Date)?
    @Published var pokeStart: Date?
    @Published var gacha: GachaSession?
    @Published var batchResults: [DrawResult]?
    @Published var batchStartedAt: Date?
    @Published var lastCredit: Date?
    @Published var upgradeNotice: (text: String, start: Date)?
    @Published var building = false
    @Published var carryover: UpgradeCarryover?

    /// Previews pin the clock; the live app leaves it nil and follows real time.
    let fixedNow: Date?
    var activityOverride: Activity?
    private let stateURL: URL?
    @Published var latestWorkInput: Date?
    @Published var activityPaused = false
    @Published var activityReadable = true
    private var inputMonitor: InputActivityMonitor?
    private var bonusTimer: Timer?
    private var bonusTask: Task<Void, Never>?
    private var lastActivitySave = Date.distantPast

    init(state: GameState, stateURL: URL?, fixedNow: Date? = nil, isDemo: Bool = false) {
        self.isDemo = isDemo
        self.tab = .home
        self.state = state
        self.stateURL = stateURL
        self.fixedNow = fixedNow
        self.state.reconcileRoster()
        self.state.observeProgress(at: fixedNow ?? Date())
    }

    var now: Date { fixedNow ?? Date() }

    func startLive() {
        guard !isDemo, inputMonitor == nil else { return }
        inputMonitor = InputActivityMonitor { [weak self] intervals, lastInput, paused, readable in
            guard let self else { return }
            self.latestWorkInput = lastInput
            self.activityPaused = paused
            self.activityReadable = readable
            let before = self.state.currentHouse
            self.state.observeProgress(at: self.now)
            let energy = self.state.creditActivity(intervals)
            self.trackProgress(from: before)
            if energy > 0 { self.lastCredit = self.now }
            if self.now.timeIntervalSince(self.lastActivitySave) >= 15 {
                self.save(); self.lastActivitySave = self.now
            }
        }
        inputMonitor?.start()
        if state.tokenBonus == nil { state.tokenBonus = TokenBonus(at: now); save() }
        refreshTokenBonus()
        bonusTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshTokenBonus() }
        }
    }

    func stopLive() {
        bonusTimer?.invalidate(); bonusTimer = nil
        bonusTask?.cancel(); bonusTask = nil
        inputMonitor?.stop(); inputMonitor = nil; save()
    }

    private func refreshTokenBonus() {
        guard bonusTask == nil, !isDemo else { return }
        let checkpoint = state.scan
        let cutoff = state.tokenBonus?.startedAt ?? now
        bonusTask = Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                var scan = checkpoint
                let events = UsageScanner.scan(state: &scan, claudeRoot: UsageScanner.defaultClaudeRoot,
                    codexRoot: UsageScanner.defaultCodexRoot, fastForwardClaudeBefore: cutoff)
                return (scan, events)
            }.value
            guard let self, !Task.isCancelled else { return }
            let before = self.state.currentHouse
            self.state.scan = result.0
            let gained = self.state.creditTokenBonus(result.1, at: self.now)
            if gained > 0 { self.lastCredit = self.now; self.trackProgress(from: before) }
            self.save()
            self.bonusTask = nil
        }
    }

    var isWorkActive: Bool {
        !activityPaused && latestWorkInput.map { now.timeIntervalSince($0) < WorkActivity.grace } == true
    }

    func openActivityPermission() {
        if !CGRequestListenEventAccess(),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func handle(_ events: [GameEvent]) {
        for e in events {
            switch e {
            case .piece(let f, let stage) where f == state.current:
                reveal = (stage, now)
                upgradeNotice = ("\(HousePlan.name(of: stage)) 입주!", now)
                say(f.dialogue(for: .upgraded))
            case .completed(let f) where f == state.current:
                endingStart = now
                say(f.dialogue(for: .completed))
            default:
                break
            }
        }
    }

    func trackProgress(from old: House?) {
        guard !building, let old, let friend = state.current, old != state.currentHouse else { return }
        progressTransition = (friend, old, now)
    }

    func welcome() { arrivalStart = now }

    static func demo() -> AppModel {
        var state = GameState(now: Date())
        state.tickets = 149
        state.met = FriendID.visible
        state.houses = Dictionary(uniqueKeysWithValues: FriendID.visible.map { ($0, House()) })
        state.current = .chiikawa
        let model = AppModel(state: state, stateURL: nil, isDemo: true)
        model.activityOverride = .tea
        return model
    }

    static func drawDemo() -> AppModel {
        var state = GameState(now: Date())
        state.tickets = 149
        let model = AppModel(state: state, stateURL: nil, isDemo: true)
        model.tab = .friends
        return model
    }

    func demoGrow() {
        guard isDemo, !building, let friend = state.current, var house = state.currentHouse, !house.isComplete else { return }
        let old = house
        // Give enough to demonstrate a manual move and a 50% surplus in the next home.
        house.progress += (house.nextCost ?? 0) + (house.stage < 12 ? HousePlan.cost(ofStage: house.stage + 2) / 2 : 0)
        state.houses[friend] = house
        trackProgress(from: old)
    }

    func nextDemoFriend() {
        guard isDemo, let friend = state.current, let index = FriendID.visible.firstIndex(of: friend) else { return }
        select(FriendID.visible[(index + 1) % FriendID.visible.count])
    }

    func say(_ text: String) { bubble = (text, now) }

    func poke() {
        guard let f = state.current else { return }
        pokeStart = now
        say(f.dialogue(for: .poke))
    }

    func buildHouse() {
        guard !building, !(carryover?.isAnimating(at: now) ?? false), gacha == nil, batchResults == nil, state.currentHouse?.canBuild == true else { return }
        let previousHouse = state.currentHouse
        let events = state.build(at: now)
        trackProgress(from: previousHouse)
        guard let f = state.current, let h = state.currentHouse else { return }
        // Commit once at the click, so closing the popover never loses or repeats it.
        building = true
        upgradeNotice = nil
        reveal = (h.stage, now)
        carryover = h.progress > 0 && !h.isComplete
            ? UpgradeCarryover(friend: f, stage: h.stage, amount: h.progress,
                               startsAt: now.addingTimeInterval(HomeAssembly.duration)) : nil
        endingStart = nil
        say(f.dialogue(for: .building))
        save()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(HomeAssembly.duration))
            guard let self else { return }
            self.building = false
            self.upgradeNotice = (UpgradeCopy.completion[h.stage]!, self.now)
            if events.contains(.completed(f)) {
                self.endingStart = self.now
                self.say(f.dialogue(for: .completed))
            } else { self.say(f.dialogue(for: .upgraded)) }
        }
    }

    func select(_ f: FriendID) {
        guard !building, gacha == nil, batchResults == nil else { return }
        reveal = nil
        upgradeNotice = nil
        endingStart = nil
        bubble = nil
        pokeStart = nil
        carryover = nil
        progressTransition = nil
        arrivalStart = now
        state.select(f)
        state.observeProgress(at: now)
        tab = .home
        save()
    }

    func drawTicket() {
        guard gacha == nil, batchResults == nil, !building else { return }
        state.observeProgress(at: now)
        var rng = SystemRandomNumberGenerator()
        guard let r = state.draw(using: &rng, at: now) else { return }
        state.observeProgress(at: now)
        upgradeNotice = nil
        gacha = GachaSession(start: now, result: r)
        save()
    }

    func drawAllTickets() {
        guard gacha == nil, batchResults == nil, !building, state.tickets > 0 else { return }
        state.observeProgress(at: now)
        var rng = SystemRandomNumberGenerator()
        let results = state.drawAll(using: &rng, at: now)
        state.observeProgress(at: now)
        upgradeNotice = nil
        reveal = nil
        carryover = nil
        progressTransition = nil
        batchStartedAt = now
        batchResults = results
        save()
    }

    func finishBatch() {
        batchResults = nil
        batchStartedAt = nil
        arrivalStart = now
        pokeStart = nil
        endingStart = nil
        tab = .friends
    }

    func finishGacha(reducedMotion: Bool = false) {
        guard let g = gacha, reducedMotion || now.timeIntervalSince(g.start) >= GachaArt.finishAt else { return }
        gacha = nil
        arrivalStart = now
        pokeStart = nil
        reveal = nil
        endingStart = nil
        progressTransition = nil
        tab = .home
        state.select(g.result.friend)
        switch g.result.outcome {
        case .newFriend: say(g.result.friend.dialogue(for: .greeting))
        case .gift:
            say(g.result.friend.dialogue(for: .gift))
        case .ticketBack: say(g.result.friend.dialogue(for: .greeting))
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
        let mood = Mood.at(date, lastTokenAt: latestWorkInput)
        let activity = activityOverride ?? Activity.choose(mood: mood, stage: h.stage, now: date, friend: f)
        func since(_ d: Date?, _ limit: Double) -> Double? {
            guard let d else { return nil }
            let e = date.timeIntervalSince(d)
            return e >= 0 && e < limit ? e : nil
        }
        var p = SceneParams(friend: f, stage: h.stage, activity: activity, t: date.timeIntervalSinceReferenceDate)
        if let r = reveal, let e = since(r.start, 8.0) { p.reveal = (r.stage, e) }
        p.endingElapsed = since(endingStart, 7)
        p.pokeElapsed = since(pokeStart, 1.5)
        if let b = bubble, since(b.start, 2.6) != nil { p.bubble = b.text }
        p.arrivalElapsed = since(arrivalStart, 1.1)
        p.constructionProgress = h.fraction
        if let transition = progressTransition, transition.friend == f,
           let e = since(transition.start, HomeAssembly.duration) {
            p.progressElapsed = e
            p.previousFraction = transition.house.fraction
            if transition.house.stage == h.stage {
                p.constructionProgress = transition.house.fraction + (h.fraction - transition.house.fraction) * ArrivalMotion.ease(e)
            } else { p.previousStage = transition.house.stage }
        }
        if let carryover, carryover.friend == f, carryover.stage == h.stage {
            p.constructionProgress = carryover.displayedFraction(target: h.fraction, at: date, reduceMotion: false)
        }
        p.snackIsPudding = Int(date.timeIntervalSince1970 / 120) % 2 == 1
        return p
    }
}

/// Authored per item: Korean particles and completion verbs are intentional.
enum UpgradeCopy {
    static let completion: [Int: String] = Dictionary(uniqueKeysWithValues:
        (2...HousePlan.lastStage).map { ($0, "\(HousePlan.name(of: $0)) 입주!") })
}
