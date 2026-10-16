import Foundation

/// Only expressions with a reviewed author-panel reference may enter this set.
/// Artwork and panel descriptions live in Art/Sprites/Manga/catalog.json.
public enum MangaExpression: String, CaseIterable, Sendable {
    case base, cry, relief, greeting

    public static func allowed(for friend: FriendID) -> [Self] {
        switch friend {
        case .chiikawa: [.base, .cry, .relief]
        case .hachiware: [.base, .greeting]
        default: [.base]
        }
    }

    public static func select(friend: FriendID, stage: Int, time: Double, responding: Bool) -> Self {
        if responding {
            switch friend {
            case .chiikawa: return .relief
            case .hachiware: return .greeting
            default: return .base
            }
        }
        // Early-house sadness is a game scenario, not a claim about a comic plot.
        // Use the actual tearful expression only for Chiikawa, in short quiet bouts.
        if friend == .chiikawa, stage <= 2,
           time.truncatingRemainder(dividingBy: 24) < 4 { return .cry }
        if friend == .chiikawa, stage >= 3 { return .relief }
        return .base
    }

    public func asset(for friend: FriendID) -> String {
        let safe = Self.allowed(for: friend).contains(self) ? self : .base
        return friend.rawValue + (safe == .base ? "" : "-" + safe.rawValue)
    }
}
