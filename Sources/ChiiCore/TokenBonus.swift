import Foundation

/// Optional, additive save data. Usage counts are capped; conversation text is never retained.
public struct TokenBonus: Codable, Sendable, Equatable {
    public static let dailyLimit: Int64 = 12_000
    public static let tokensPerXP: Int64 = 100
    public var startedAt: Date
    public var day: String
    public var tokens: Int64 = 0
    public var awarded: Int64 = 0

    public init(at date: Date) {
        startedAt = date
        day = DayKey.of(date)
    }

    public static func allowance(activitySeconds: TimeInterval) -> Int64 {
        min(dailyLimit, WorkActivity.energy(for: activitySeconds) / 20)
    }
}

extension GameState {
    /// Checkpoints are advanced by the caller even when an event is ineligible.
    @discardableResult
    public mutating func creditTokenBonus(_ events: [TokenEvent], at date: Date) -> Int64 {
        guard var bonus = tokenBonus else { return 0 }
        let today = DayKey.of(date)
        if bonus.day != today { bonus.day = today; bonus.tokens = 0; bonus.awarded = 0 }
        let tokenLimit = TokenBonus.dailyLimit * TokenBonus.tokensPerXP
        for event in events where event.date >= bonus.startedAt && event.date <= date && DayKey.of(event.date) == today && event.tokens > 0 {
            bonus.tokens += min(event.tokens, tokenLimit - bonus.tokens)
        }
        tokenBonus = bonus
        guard let friend = current, var house = houses[friend], !house.isComplete else { return 0 }
        let target = min(bonus.tokens / TokenBonus.tokensPerXP,
                         TokenBonus.allowance(activitySeconds: workActivity?.seconds(on: date) ?? 0))
        let gain = max(0, target - bonus.awarded)
        guard gain > 0 else { return 0 }
        observeProgress(at: date)
        house.progress = min(house.progress, Int64.max - gain) + gain
        houses[friend] = house
        if var record = dailyProgress?[friend] {
            record.earned = min(record.earned, Int64.max - gain) + gain
            record.extraXP = min(record.extraXP ?? 0, Int64.max - gain) + gain
            dailyProgress?[friend] = record
        }
        bonus.awarded += gain
        tokenBonus = bonus
        return gain
    }
}
