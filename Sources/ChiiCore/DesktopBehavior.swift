import Foundation

public enum DesktopAction: String, CaseIterable, Sendable {
    case walk, sit, roll, laugh, cry, stretch
    public var label: String {
        switch self {
        case .walk: "산책 중"
        case .sit: "잠깐 앉아 쉬는 중"
        case .roll: "데굴데굴"
        case .laugh: "기분 좋은 웃음"
        case .cry: "훌쩍훌쩍"
        case .stretch: "기지개"
        }
    }
}

/// The view and native window use the same clock so stationary acts never slide around.
public struct DesktopBehavior: Sendable {
    public let action: DesktopAction
    public let elapsed: Double
    public var walks: Bool { action == .walk }
    public var envelope: Double {
        min(ArrivalMotion.ease(elapsed / 0.8), ArrivalMotion.ease((10 - elapsed) / 0.8))
    }
    public init(action: DesktopAction, elapsed: Double) {
        self.action = action; self.elapsed = elapsed
    }
    public static func actions(for friend: FriendID) -> [DesktopAction] {
        switch friend {
        case .chiikawa: [.sit, .laugh, .roll, .sit, .cry, .stretch]
        case .usagi: [.roll, .stretch, .roll, .laugh, .sit]
        case .kurimanju, .rakko: [.sit, .stretch, .sit, .laugh]
        case .pajamaGreen: [.laugh, .stretch, .sit]
        default: [.sit, .laugh, .roll, .stretch]
        }
    }
    public static func at(_ time: Double, friend: FriendID, reduced: Bool = false, responding: Bool = false) -> Self {
        guard !reduced else { return Self(action: .sit, elapsed: 4) }
        guard !responding else { return Self(action: .laugh, elapsed: 3) }
        let t = max(0, time), slot = Int(t / 28), phase = t.truncatingRemainder(dividingBy: 28)
        guard phase >= 15 && phase < 25 else { return Self(action: .walk, elapsed: phase) }
        let actions = actions(for: friend)
        let offset = FriendID.allCases.firstIndex(of: friend) ?? 0
        return Self(action: actions[(slot + offset) % actions.count], elapsed: phase - 15)
    }
    public func line(for friend: FriendID, time: Double) -> String {
        switch action {
        case .walk: friend.desktopLine(at: time)
        case .sit: "잠깐 쉬어 가자…"
        case .roll: friend == .usagi ? "ヤハッ!" : "데굴… 데굴…"
        case .laugh: friend == .usagi ? "ウララ!" : "헤헤…♪"
        case .cry: "…훌쩍."
        case .stretch: "쭈우욱…!"
        }
    }
}
