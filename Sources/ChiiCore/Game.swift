import Foundation

// MARK: - Tuning (measured from this user's logs, see README.md)

public enum Tuning {
    /// Cost of the first new piece (stage 1 -> 2). About 20 minutes of normal use.
    public static let firstPieceCost: Int64 = 1_500_000
    /// Authored accelerating curve: quick early wins, longer late-stage goals.
    public static let pieceCosts: [Int64] = [
        1_500_000, 2_500_000, 4_000_000, 6_500_000, 10_000_000, 15_000_000,
        22_000_000, 32_000_000, 45_000_000, 62_000_000, 84_000_000
    ]
    /// One draw ticket per this many effective tokens (about 1.5 active days).
    public static let ticketCost: Int64 = 63_000_000
}

// MARK: - Friends

public enum FriendID: String, Codable, CaseIterable, Sendable {
    case chiikawa, hachiware, usagi, momonga, kurimanju, rakko, shisa, anoko, kani

    public var name: String {
        switch self {
        case .chiikawa: "치이카와"
        case .hachiware: "하치와레"
        case .usagi: "우사기"
        case .momonga: "모몽가"
        case .kurimanju: "쿠리만쥬"
        case .rakko: "랏코"
        case .shisa: "시사"
        case .anoko: "아노코"
        case .kani: "카니"
        }
    }

    public var rarity: Int {
        switch self {
        case .chiikawa, .rakko, .anoko: 3
        case .hachiware, .usagi, .kani: 2
        case .momonga, .kurimanju, .shisa: 1
        }
    }

    public var lines: [String] {
        switch self {
        case .chiikawa: ["와…", "흐에…", "에엣!"]
        case .hachiware: ["괜찮아 괜찮아~", "와아~!", "해볼까!"]
        case .usagi: ["우라!", "야하!", "프르르르…", "하?"]
        case .momonga: ["뀨우~", "흥!"]
        case .kurimanju: ["캬~", "하아~"]
        case .rakko: ["훗.", "음."]
        case .shisa: ["에헤헤~", "사!"]
        case .anoko: ["와아…", "후후…"]
        case .kani: ["좋은 책이 있어요", "같이 읽을래요?"]
        }
    }

    public static let starters: [FriendID] = [.chiikawa, .hachiware, .usagi]
}

extension FriendID: CodingKeyRepresentable {}

// MARK: - House

public enum HousePlan {
    public static let lastStage = 12
    /// Name of each stage's piece, index = stage - 1.
    public static let pieceNames = [
        "빈 풀밭", "나무 마루", "벽", "지붕", "방석", "작은 밥상",
        "이불", "창문과 커튼", "스탠드 조명", "작은 부엌", "화분과 책", "액자와 가랜드",
    ]

    /// Tokens needed to add piece `stage` (2...12) once stage - 1 is reached.
    public static func cost(ofStage stage: Int) -> Int64 {
        precondition(stage >= 2 && stage <= lastStage)
        return Tuning.pieceCosts[stage - 2]
    }

    public static var totalCost: Int64 { (2...lastStage).reduce(0) { $0 + cost(ofStage: $1) } }
}

public struct House: Codable, Sendable, Equatable {
    public var stage: Int = 1
    public var progress: Int64 = 0
    public var isComplete: Bool { stage >= HousePlan.lastStage }
    public var canBuild: Bool { nextCost.map { progress >= $0 } ?? false }
    public var nextCost: Int64? { isComplete ? nil : HousePlan.cost(ofStage: stage + 1) }
    public init(stage: Int = 1, progress: Int64 = 0) { self.stage = stage; self.progress = progress }
}

// MARK: - State

public enum GameEvent: Equatable, Sendable {
    case piece(FriendID, stage: Int)
    case completed(FriendID)
    case ticket
}

public enum DrawOutcome: Equatable, Sendable {
    case newFriend
    case gift(stage: Int)     // duplicate: materials for this next stage
    case ticketBack           // duplicate on a finished house
}

public struct DrawResult: Equatable, Sendable {
    public var friend: FriendID
    public var outcome: DrawOutcome
    public init(friend: FriendID, outcome: DrawOutcome) { self.friend = friend; self.outcome = outcome }
}

/// Observed progress, never inferred from historical stage totals.
public struct DailyProgress: Codable, Sendable, Equatable {
    public var day: String
    public var observedAt: Date
    public var startStage: Int
    public var startProgress: Int64
    public var earned: Int64 = 0
    public var upgrades: Int = 0
    public var lastUpgradeAt: Date?
    public init(day: String, observedAt: Date, house: House) {
        self.day = day
        self.observedAt = observedAt
        startStage = house.stage
        startProgress = house.progress
    }
}

public struct GameState: Codable, Sendable, Equatable {
    public var creditFrom: Date
    public var tickets: Int = 1
    public var ticketProgress: Int64 = 0
    public var houses: [FriendID: House] = [:]
    public var met: [FriendID] = []
    public var current: FriendID?
    public var dayTotals: [String: Int64] = [:]
    public var lastTokenAt: Date?
    public var scan = ScanState()
    public var dailyProgress: [FriendID: DailyProgress]?

    /// A new state credits tokens from local midnight of `now` and holds one free ticket.
    public init(now: Date, calendar: Calendar = .current) {
        creditFrom = calendar.startOfDay(for: now)
    }

    public var currentHouse: House? { current.flatMap { houses[$0] } }

    /// Start each friend's daily baseline at the first actual observation.
    public mutating func observeProgress(at date: Date) {
        let day = DayKey.of(date)
        var records = dailyProgress ?? [:]
        for (friend, house) in houses where records[friend]?.day != day {
            records[friend] = DailyProgress(day: day, observedAt: date, house: house)
        }
        dailyProgress = records
    }

    public func progressToday(for friend: FriendID, at date: Date) -> DailyProgress? {
        guard let record = dailyProgress?[friend], record.day == DayKey.of(date) else { return nil }
        return record
    }

    /// Adds tokens. They go to the current friend's house (if not complete) and always to tickets.
    @discardableResult
    public mutating func credit(_ events: [TokenEvent]) -> [GameEvent] {
        var out: [GameEvent] = []
        for e in events where e.date >= creditFrom && e.tokens > 0 {
            dayTotals[DayKey.of(e.date), default: 0] += e.tokens
            if lastTokenAt.map({ e.date > $0 }) ?? true { lastTokenAt = e.date }
            ticketProgress += e.tokens
            while ticketProgress >= Tuning.ticketCost {
                ticketProgress -= Tuning.ticketCost
                tickets += 1
                out.append(.ticket)
            }
            guard let id = current, var h = houses[id], !h.isComplete else { continue }
            h.progress += e.tokens
            if var record = dailyProgress?[id], record.day == DayKey.of(e.date) {
                record.earned += e.tokens
                dailyProgress?[id] = record
            }
            houses[id] = h
        }
        if dayTotals.count > 60 {
            for k in dayTotals.keys.sorted().dropLast(60) { dayTotals[k] = nil }
        }
        return out
    }

    /// A click spends stored experience on exactly one piece. Surplus is retained.
    @discardableResult
    public mutating func build(at date: Date = Date()) -> [GameEvent] {
        guard let id = current, var h = houses[id], let cost = h.nextCost,
              h.progress >= cost else { return [] }
        observeProgress(at: date)
        if var record = dailyProgress?[id] {
            record.upgrades += 1
            record.lastUpgradeAt = date
            dailyProgress?[id] = record
        }
        h.progress -= cost
        h.stage += 1
        var events: [GameEvent] = [.piece(id, stage: h.stage)]
        if h.isComplete { h.progress = 0; events.append(.completed(id)) }
        houses[id] = h
        return events
    }

    /// Spends one ticket. Weights: 1-star 60%, 2-star 30%, 3-star 10%; uniform in a tier.
    /// The first draw is always one of the three starters.
    public mutating func draw<R: RandomNumberGenerator>(using rng: inout R) -> DrawResult? {
        guard tickets > 0 else { return nil }
        tickets -= 1
        let friend: FriendID
        if houses.isEmpty {
            friend = FriendID.starters.randomElement(using: &rng)!
        } else {
            let roll = Int.random(in: 0..<100, using: &rng)
            let tier = roll < 60 ? 1 : (roll < 90 ? 2 : 3)
            friend = FriendID.allCases.filter { $0.rarity == tier }.randomElement(using: &rng)!
        }
        guard var h = houses[friend] else {
            houses[friend] = House()
            met.append(friend)
            current = friend
            return DrawResult(friend: friend, outcome: .newFriend)
        }
        if h.isComplete {
            tickets += 1
            return DrawResult(friend: friend, outcome: .ticketBack)
        }
        h.progress += h.nextCost!
        houses[friend] = h
        return DrawResult(friend: friend, outcome: .gift(stage: h.stage + 1))
    }

    public mutating func select(_ id: FriendID) {
        if houses[id] != nil { current = id }
    }

    public func today(_ now: Date) -> Int64 { dayTotals[DayKey.of(now)] ?? 0 }
}

/// SplitMix64: small seedable generator for tests and fixtures.
public struct SeededRNG: RandomNumberGenerator {
    private var x: UInt64
    public init(seed: UInt64) { x = seed }
    public mutating func next() -> UInt64 {
        x &+= 0x9E37_79B9_7F4A_7C15
        var z = x
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Activities

public enum Mood: Sendable {
    case busy, idle, sleeping

    /// busy: tokens in the last 5 minutes; sleeping: none for 30 minutes.
    public static func at(_ now: Date, lastTokenAt: Date?) -> Mood {
        guard let last = lastTokenAt else { return .sleeping }
        let gap = now.timeIntervalSince(last)
        if gap < 5 * 60 { return .busy }
        if gap >= 30 * 60 { return .sleeping }
        return .idle
    }
}

public enum Activity: String, CaseIterable, Sendable {
    case weeding, cooking, sweeping, reading, rolling, snack, tea, window, napFuton, napGround

    public var label: String {
        switch self {
        case .weeding: "풀 뽑기"
        case .cooking: "요리"
        case .sweeping: "청소"
        case .reading: "독서"
        case .rolling: "뒹굴뒹굴"
        case .snack: "간식 먹기"
        case .tea: "차 마시기"
        case .window: "창밖 보기"
        case .napFuton, .napGround: "낮잠"
        }
    }

    /// Lowest house stage that has every piece this activity uses.
    public var requiredStage: Int {
        switch self {
        case .weeding, .rolling, .tea, .napGround: 1
        case .sweeping: 2          // floor
        case .snack: 6             // table
        case .napFuton: 7          // futon
        case .window: 8            // window
        case .cooking: 10          // stove
        case .reading: 11          // lamp (9) and books (11)
        }
    }

    public static func options(mood: Mood, stage: Int) -> [Activity] {
        let list: [Activity]
        switch mood {
        case .busy:
            list = (stage <= 4 ? [.weeding, .weeding] : [.weeding]) + [.sweeping, .cooking, .reading]
        case .idle:
            list = [.rolling, .snack, .tea, .window]
        case .sleeping:
            list = [stage >= Activity.napFuton.requiredStage ? .napFuton : .napGround]
        }
        return list.filter { $0.requiredStage <= stage }
    }

    /// Picks one activity per two-minute slot, stable within the slot.
    public static func choose(mood: Mood, stage: Int, now: Date, friend: FriendID) -> Activity {
        let opts = options(mood: mood, stage: stage)
        let slot = UInt64(max(0, now.timeIntervalSince1970 / 120))
        var rng = SeededRNG(seed: slot &+ UInt64(FriendID.allCases.firstIndex(of: friend) ?? 0) &* 7919)
        return opts[Int(rng.next() % UInt64(opts.count))]
    }
}

// MARK: - Persistence

public enum Store {
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ChiiBar/state.json")
    }

    public static func load(_ url: URL) -> GameState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let state = try? JSONDecoder().decode(GameState.self, from: data), isValid(state) else { return nil }
        return state
    }

    private static func isValid(_ s: GameState) -> Bool {
        s.tickets >= 0 && s.ticketProgress >= 0 && s.ticketProgress < Tuning.ticketCost
        && s.dayTotals.values.allSatisfy { $0 >= 0 }
        && Set(s.met).count == s.met.count && Set(s.met) == Set(s.houses.keys)
        && (s.current.map { s.houses[$0] != nil } ?? s.houses.isEmpty)
        && s.houses.values.allSatisfy {
            (1...HousePlan.lastStage).contains($0.stage) && $0.progress >= 0
            && ($0.stage != HousePlan.lastStage || $0.progress == 0)
        }
    }

    /// Preserve damaged data before starting fresh. A read or backup failure must
    /// propagate so the caller never silently overwrites the only saved copy.
    public static func loadOrRecover(_ url: URL, now: Date) throws -> GameState {
        guard FileManager.default.fileExists(atPath: url.path) else { return GameState(now: now) }
        _ = try Data(contentsOf: url)
        if let state = load(url) { return state }
        let backup = url.deletingLastPathComponent().appendingPathComponent("state.corrupt-\(UUID().uuidString).json")
        try FileManager.default.moveItem(at: url, to: backup)
        return GameState(now: now)
    }

    public static func save(_ state: GameState, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }
}

// MARK: - Formatting

public enum TokenFormat {
    /// 1234 -> "1,234", 1_234_567 -> "1.2M", 12_345 -> "12K"
    public static func short(_ n: Int64) -> String {
        if n >= 1_000_000 {
            let tenths = n / 100_000
            return "\(tenths / 10).\(tenths % 10)M"
        }
        if n >= 10_000 { return "\(n / 1000)K" }
        return "\(n)"
    }
}
