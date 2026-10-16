import Foundation

/// Short Korean summaries of the official anime character guide, reviewed 2026-10-16.
/// Game dialogue and weather reactions are separate fan-authored interpretations.
extension FriendID {
    public var profile: String {
        switch self {
        case .chiikawa: "눈물이 조금 많지만 마음씨가 다정해요. 풀 뽑기와 토벌로 생활해요."
        case .hachiware: "밝고 긍정적인 치이카와의 친구예요. 동굴에서 살고 있어요."
        case .usagi: "치이카와의 친구예요. ‘우라’, ‘야하’ 하고 큰 소리로 외치곤 해요."
        case .momonga: "늘 귀여움을 어필하며 이것저것 부탁하는 친구예요."
        case .kurimanju: "맛있는 것을 즐기는 미식가예요. 주변을 잘 챙겨주는 면도 있어요."
        case .rakko: "토벌에 능숙한 강자예요. 치이카와와 친구들이 동경하는 존재예요."
        case .shisa: "라멘집 ‘로’의 조수예요. 라멘 갑옷 씨를 스승님이라고 불러요."
        case .kani: "헌책을 팔아요. 모몽가에게 받은 게 모양 머리띠를 쓰고 있어요."
        case .anoko: "일본어 이름은 ‘아노코(あのこ)’, 우리말로는 ‘그 아이’예요. 커다란 몸집이 눈에 띄는 캐릭터예요."
        case .pajamaGreen:
            "초록·분홍·하양·보라 잠옷을 입은 네 친구가 한 팀이에요. 포셰트 갑옷 씨가 만든 잠옷을 입고 노래와 춤을 선보여요."
        case .pajamaPink, .pajamaWhite, .pajamaPurple:
            "파자마파티즈의 멤버예요. 포셰트 갑옷 씨가 만든 잠옷을 입고 함께 노래와 춤을 선보여요."
        case .pochette: "귀여운 것을 좋아해요. 직접 만든 포셰트와 잠옷을 팔며, 노동 갑옷 씨와 친해요."
        case .labor: "일거리 접수를 맡고 있어요. 포셰트 갑옷 씨와 사이가 좋아요."
        }
    }
    public var profileTags: [String] {
        switch self {
        case .chiikawa: ["다정함", "풀 뽑기"]
        case .hachiware: ["긍정적", "동굴 생활"]
        case .usagi: ["야하!", "치이카와의 친구"]
        case .momonga: ["귀여움 어필", "부탁쟁이"]
        case .kurimanju: ["미식가", "챙겨주는 친구"]
        case .rakko: ["토벌", "동경의 대상"]
        case .shisa: ["라멘집 조수", "스승님"]
        case .kani: ["헌책", "게 머리띠"]
        case .anoko: ["그 아이", "커다란 몸집"]
        case .pajamaGreen: ["네 친구가 한 팀", "노래와 춤"]
        case .pajamaPink: ["파자마파티즈", "분홍 잠옷"]
        case .pajamaWhite: ["파자마파티즈", "하얀 잠옷"]
        case .pajamaPurple: ["파자마파티즈", "보라 잠옷"]
        case .pochette: ["손수 만든 소품", "귀여운 것"]
        case .labor: ["일거리 접수", "갑옷 씨"]
        }
    }
    public var profileSource: URL {
        URL(string: self == .anoko ? "https://www.anime-chiikawa.jp/" : "https://www.anime-chiikawa.jp/chara.html")!
    }
}
