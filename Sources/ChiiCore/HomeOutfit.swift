/// Only homes with a clear visual theme add an accessory. Other homes keep the original look.
public enum HomeOutfit: String, Sendable {
    case none = "기본 모습", gat = "한옥의 갓", bowTie = "도시의 나비넥타이"
    public var isVisible: Bool { self != .none }
    public static func at(stage: Int) -> HomeOutfit {
        switch stage {
        case 8: .gat
        case 11...13: .bowTie
        default: .none
        }
    }
}
