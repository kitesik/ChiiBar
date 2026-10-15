import ChiiCore
import Foundation

/// Presentation only. The balance is saved immediately; this never awards experience.
struct UpgradeCarryover {
    let friend: FriendID
    let stage: Int
    let amount: Int64
    let startsAt: Date
    static let duration: TimeInterval = 1.2

    func displayedFraction(target: Double, at date: Date, reduceMotion: Bool) -> Double {
        let elapsed = date.timeIntervalSince(startsAt)
        guard elapsed >= 0 else { return 0 }
        guard !reduceMotion, elapsed < Self.duration else { return target }
        let t = elapsed / Self.duration
        return target * (1 - pow(1 - t, 3))
    }

    func isAnimating(at date: Date) -> Bool {
        date.timeIntervalSince(startsAt) < Self.duration
    }

    var explanation: String {
        "이전 업그레이드에서 남은 경험치 \(TokenFormat.short(amount))가 다음 단계로 이어졌어요."
    }
}
