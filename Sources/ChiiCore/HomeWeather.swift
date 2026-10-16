import Foundation

/// A fictional ambient cycle; no location, network, or real-world forecast is used.
public enum HomeWeather: String, CaseIterable, Sendable {
    case clear, rain, snow

    public struct Moment: Sendable {
        public let kind: HomeWeather
        public let intensity: Double
        public init(kind: HomeWeather, intensity: Double = 1) {
            self.kind = kind
            self.intensity = min(1, max(0, intensity))
        }
    }
    public enum Reaction: Sendable { case calm, tearful, shiver, curious, play, fuss }

    public static func moment(at time: Double) -> Moment {
        let phase = max(0, time).truncatingRemainder(dividingBy: 1_200)
        let kind: HomeWeather
        let elapsed: Double
        let duration: Double
        switch phase {
        case 240..<315: kind = .rain; elapsed = phase - 240; duration = 75
        case 840..<930: kind = .snow; elapsed = phase - 840; duration = 90
        default: return Moment(kind: .clear, intensity: 0)
        }
        return Moment(kind: kind, intensity: min(ArrivalMotion.ease(elapsed / 6), ArrivalMotion.ease((duration - elapsed) / 6)))
    }

    public static func sheltered(stage: Int) -> Bool { stage >= 3 }

    /// Character-inspired game direction, not assertions about events in the manga.
    public func reaction(friend: FriendID, stage: Int) -> Reaction {
        if self == .clear { return .calm }
        if self == .rain {
            if Self.sheltered(stage: stage) { return .calm }
            switch friend {
            case .chiikawa: return .tearful
            case .usagi, .anoko: return .play
            case .hachiware, .rakko: return .calm
            case .momonga: return .fuss
            case .kurimanju, .shisa, .kani: return .shiver
            }
        }
        switch friend {
        case .usagi, .hachiware, .kani, .anoko: return .play
        case .chiikawa, .shisa: return .curious
        case .momonga: return .fuss
        case .kurimanju: return Self.sheltered(stage: stage) ? .calm : .shiver
        case .rakko: return .calm
        }
    }
}
