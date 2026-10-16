import Foundation

/// Presentation only. The balance is saved immediately; this never awards experience.
public struct UpgradeCarryover {
    public let friend: FriendID
    public let stage: Int
    public let amount: Int64
    public let startsAt: Date
    public init(friend: FriendID, stage: Int, amount: Int64, startsAt: Date) {
        self.friend = friend; self.stage = stage; self.amount = amount; self.startsAt = startsAt
    }
    public static let duration: TimeInterval = 1.65

    public func displayedFraction(target: Double, at date: Date, reduceMotion: Bool) -> Double {
        let elapsed = date.timeIntervalSince(startsAt)
        guard elapsed >= 0 else { return 0 }
        guard !reduceMotion, elapsed < Self.duration else { return target }
        let t = elapsed / Self.duration
        // Small anticipation, confident fill, then a long soft landing; no numeric overshoot.
        let travel = max(0, (t - 0.07) / 0.93)
        return target * (1 - pow(1 - travel, 4))
    }

    public func isAnimating(at date: Date) -> Bool {
        date.timeIntervalSince(startsAt) < Self.duration
    }

    public var explanation: String {
        "이전 업그레이드에서 남은 경험치 \(TokenFormat.short(amount))가 다음 단계로 이어졌어요."
    }
}
