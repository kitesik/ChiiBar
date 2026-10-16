import Foundation

// MARK: - Tuning (initial non-developer work pacing; validate with real cohorts)

public enum Tuning {
    public static let economyVersion = 2
    public static let firstPieceCost: Int64 = 20_000
    public static let pieceCosts: [Int64] = [
        20_000, 40_000, 80_000, 150_000, 250_000, 400_000,
        600_000, 900_000, 1_300_000, 1_800_000, 2_500_000, 3_500_000
    ]
    public static let ticketCost: Int64 = 150_000
    public static let dailyTarget: Int64 = 300_000
    public static func duplicateGift(forStage stage: Int) -> Int64 {
        min(150_000, HousePlan.cost(ofStage: stage) / 10)
    }
    static let legacyPieceCosts: [Int64] = [
        1_500_000, 2_500_000, 4_000_000, 6_500_000, 10_000_000, 15_000_000,
        22_000_000, 32_000_000, 45_000_000, 62_000_000, 84_000_000, 112_000_000
    ]
    static let legacyTicketCost: Int64 = 63_000_000
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
        case .usagi, .hachiware, .momonga: 3
        case .chiikawa, .kurimanju, .shisa: 2
        case .kani, .rakko, .anoko: 1
        }
    }

    public static let starters: [FriendID] = [.chiikawa, .hachiware, .usagi]
}

extension FriendID: CodingKeyRepresentable {}

/// Shared by the actual draw and the probability display.
public enum DrawOdds {
    // Dengeki Online's March 2026 reader poll order; weights are game design, not poll shares.
    public static let ranked: [FriendID] = [.usagi, .hachiware, .momonga, .chiikawa, .kurimanju, .shisa, .kani, .rakko, .anoko]
    public static let weights = [2, 3, 5, 7, 10, 13, 16, 20, 24]
    public static var totalWeight: Int { weights.reduce(0, +) }
    public static func friend(for roll: Int) -> FriendID {
        precondition((0..<totalWeight).contains(roll))
        var ceiling = 0
        for (index, weight) in weights.enumerated() {
            ceiling += weight
            if roll < ceiling { return ranked[index] }
        }
        preconditionFailure("Invalid draw weights")
    }
    public static func probability(of friend: FriendID, firstDraw: Bool = false) -> Double {
        Double(weights[ranked.firstIndex(of: friend)!]) / Double(totalWeight)
    }
}


// MARK: - House

public enum HousePlan {
    public static let lastStage = 13
    /// Name of each stage's piece, index = stage - 1.
    public static let pieceNames = [
        "비박", "움막집", "벽돌집", "굴뚝집", "울타리집", "마당집", "초가집",
        "양반집", "현대식집", "빌라", "아파트", "초고층 빌딩", "초고층 빌딩 펜트하우스",
    ]

    public static func name(of stage: Int) -> String {
        pieceNames[max(0, min(lastStage - 1, stage - 1))]
    }

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
    public var fraction: Double { nextCost.map { min(1, Double(progress) / Double($0)) } ?? 1 }
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
    public var economyVersion: Int? = Tuning.economyVersion
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

    /// One explicit upgrade consumes one threshold; surplus remains banked.
    @discardableResult
    public mutating func advanceHouse(for id: FriendID, at date: Date) -> [GameEvent] {
        guard var house = houses[id] else { return [] }
        var events: [GameEvent] = []
        if let cost = house.nextCost, house.progress >= cost {
            house.progress -= cost
            house.stage += 1
            events.append(.piece(id, stage: house.stage))
            if var record = dailyProgress?[id], record.day == DayKey.of(date) {
                record.upgrades += 1
                record.lastUpgradeAt = date
                dailyProgress?[id] = record
            }
        }
        if house.isComplete && !events.isEmpty {
            house.progress = 0
            events.append(.completed(id))
        }
        houses[id] = house
        return events
    }

    /// Explicit user action; never called by credit, loading or duplicate gifts.
    @discardableResult
    public mutating func build(at date: Date = Date()) -> [GameEvent] {
        guard let id = current else { return [] }
        observeProgress(at: date)
        return advanceHouse(for: id, at: date)
    }

    /// Every ticket, including the free first ticket, uses the same full roster.
    public mutating func draw<R: RandomNumberGenerator>(using rng: inout R, at date: Date = Date()) -> DrawResult? {
        guard tickets > 0 else { return nil }
        tickets -= 1
        let friend = DrawOdds.friend(for: Int.random(in: 0..<DrawOdds.totalWeight, using: &rng))
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
        let giftedStage = h.stage + 1
        h.progress += Tuning.duplicateGift(forStage: giftedStage)
        houses[friend] = h
        return DrawResult(friend: friend, outcome: .gift(stage: giftedStage))
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
        return migrate(state)
    }

    private static func isValid(_ s: GameState) -> Bool {
        (s.economyVersion == nil || s.economyVersion == Tuning.economyVersion)
        && s.tickets >= 0 && s.ticketProgress >= 0
        && s.ticketProgress < (s.economyVersion == nil ? Tuning.legacyTicketCost : Tuning.ticketCost)
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
        let original = try Data(contentsOf: url)
        if let state = load(url) {
            let old = try JSONDecoder().decode(GameState.self, from: original)
            if old.economyVersion == nil {
                let backup = url.deletingLastPathComponent().appendingPathComponent("state.before-economy-v2-\(UUID().uuidString).json")
                try original.write(to: backup, options: .atomic)
            }
            return state
        }
        let backup = url.deletingLastPathComponent().appendingPathComponent("state.corrupt-\(UUID().uuidString).json")
        try FileManager.default.moveItem(at: url, to: backup)
        return GameState(now: now)
    }

    /// Preserve fractional progress AND any surplus, without auto-building or minting tickets.
    private static func migrate(_ original: GameState) -> GameState {
        guard original.economyVersion == nil else { return original }
        var state = original
        func scaled(_ value: Int64, old: Int64, new: Int64) -> Int64 {
            // All new costs are lower. Quotient/remainder avoids overflow and float rounding.
            (value / old) * new + (value % old) * new / old
        }
        for (friend, house) in state.houses where !house.isComplete {
            state.houses[friend]?.progress = scaled(house.progress,
                old: Tuning.legacyPieceCosts[house.stage - 1], new: house.nextCost!)
        }
        state.ticketProgress = scaled(state.ticketProgress, old: Tuning.legacyTicketCost, new: Tuning.ticketCost)
        for (friend, record) in state.dailyProgress ?? [:] where (1..<HousePlan.lastStage).contains(record.startStage) {
            state.dailyProgress?[friend]?.startProgress = scaled(record.startProgress,
                old: Tuning.legacyPieceCosts[record.startStage - 1], new: Tuning.pieceCosts[record.startStage - 1])
        }
        state.economyVersion = Tuning.economyVersion
        return state
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
