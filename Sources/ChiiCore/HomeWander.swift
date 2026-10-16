import Foundation

/// Slow, continuous strolling with a rest at each end of the clear floor.
public enum HomeWander {
    public struct Position {
        public let x: Double
        public let y: Double
        public let bounce: Double
        public let lean: Double
    }
    public static func position(at time: Double, friend: FriendID, reduced: Bool = false) -> Position {
        if reduced { return Position(x: 0.5, y: 0.74, bounce: 0, lean: 0) }
        let index = FriendID.allCases.firstIndex(of: friend) ?? 0
        let phase = (max(0, time) + Double(index) * 2.7).truncatingRemainder(dividingBy: 24)
        let outbound = phase < 12
        let local = phase.truncatingRemainder(dividingBy: 12)
        let travel = min(1, max(0, (local - 3) / 7))
        let eased = ArrivalMotion.ease(travel)
        let x = outbound ? 0.36 + 0.28 * eased : 0.64 - 0.28 * eased
        let envelope = sin(travel * .pi)
        return Position(x: x, y: 0.74 - 0.025 * sin(eased * .pi),
                        bounce: pow(sin(travel * .pi * 12), 2) * envelope * 2.5,
                        lean: (outbound ? 1 : -1) * envelope * 0.035)
    }
}
