import Foundation

/// One continuous house reveal behind irregular dust puffs, with three hammer beats.
public enum HomeAssembly {
    public static let duration = 3.0
    public static func reveal(elapsed: Double) -> Double {
        ArrivalMotion.ease((elapsed - 0.2) / 1.9)
    }
    public static func settle(elapsed: Double, reduced: Bool = false) -> Double {
        guard !reduced, elapsed > 2.1, elapsed < duration else { return 0 }
        let t = (elapsed - 2.1) / 0.9
        return sin(t * .pi * 3) * pow(1 - t, 2) * 2.8
    }
    public static func scale(elapsed: Double) -> Double {
        0.96 + reveal(elapsed: elapsed) * 0.04 + settle(elapsed: elapsed) * 0.007
    }
}
