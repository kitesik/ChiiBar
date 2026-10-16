import Foundation

/// Deterministic choreography: anticipation, a small hop, soft landing, then rest.
public enum ArrivalMotion {
    public static func elapsed(at time: Double, friend: FriendID) -> Double {
        let slot = Int(max(0, time) / 20)
        let index = FriendID.allCases.firstIndex(of: friend) ?? 0
        var rng = SeededRNG(seed: UInt64(slot) &* 7919 &+ UInt64(index) &* 104729)
        let delay = 2 + Double(rng.next() % 1400) / 100
        return time - Double(slot) * 20 - delay
    }

    public static func scale(at time: Double, friend: FriendID) -> Double {
        spring(elapsed: elapsed(at: time, friend: friend))
    }

    public static func ease(_ value: Double) -> Double {
        let x = min(1, max(0, value))
        return x * x * (3 - 2 * x)
    }

    public static func spring(elapsed e: Double) -> Double {
        guard e >= 0 && e < 1.1 else { return 1 }
        let keys: [(Double, Double)] = [(0, 1), (0.18, 0.86), (0.36, 1.08), (0.64, 0.96), (1.1, 1)]
        for i in 1..<keys.count where e <= keys[i].0 {
            let (t, v) = keys[i - 1], (end, next) = keys[i]
            return v + (next - v) * ease((e - t) / (end - t))
        }
        return 1
    }

    public static func lift(elapsed e: Double) -> Double {
        guard e > 0.18 && e < 0.72 else { return 0 }
        return 12 * pow(sin((e - 0.18) / 0.54 * .pi), 2)
    }

    public static func blinking(at time: Double, friend: FriendID) -> Bool {
        let index = FriendID.allCases.firstIndex(of: friend) ?? 0
        let phase = (time + Double(index) * 0.53).truncatingRemainder(dividingBy: 4.7)
        return phase >= 0 && phase < 0.12
    }
}
