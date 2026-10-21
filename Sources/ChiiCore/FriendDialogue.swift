import Foundation

/// Original fan dialogue, authored per character and situation, not episode quotations.
public enum DialogueMoment: CaseIterable, Sendable {
    case greeting, poke, building, upgraded, completed, gift
}

private struct DialogueSet {
    let greeting: [String]
    let poke: [String]
    let building: [String]
    let upgraded: [String]
    let completed: [String]
    let gift: [String]

    func lines(for moment: DialogueMoment) -> [String] {
        switch moment {
        case .greeting: greeting
        case .poke: poke
        case .building: building
        case .upgraded: upgraded
        case .completed: completed
        case .gift: gift
        }
    }
}

extension FriendID {
    public func dialogue(for moment: DialogueMoment) -> String {
        if Int.random(in: 0..<4) == 0 { return japaneseLines.randomElement()! }
        return dialogueSet.lines(for: moment).randomElement()!
    }

    private var dialogueSet: DialogueSet {
        switch self {
        case .pajamaGreen, .pajamaPink, .pajamaWhite, .pajamaPurple:
            DialogueSet(greeting: ["♪"], poke: ["…♪!"], building: ["하나, 둘…♪"], upgraded: ["와…!"], completed: ["♪ ♫"], gift: ["함께…♪"])
        case .pochette, .labor:
            DialogueSet(greeting: ["어서 와."], poke: ["무슨 일이야?"], building: ["차근차근 해 보자."], upgraded: ["제법 아늑해졌네."], completed: ["수고했어."], gift: ["여기에 보태면 좋겠네."])
        case .chiikawa:
            DialogueSet(greeting: ["와… 와아…", "…응!"],
                        poke: ["에… 엣!?", "와…!", "으응…"],
                        building: ["읏…!", "응…! 응…!"],
                        upgraded: ["와아…!", "…헤헤"],
                        completed: ["와아아…!", "…우… 와아…!"],
                        gift: ["응…!", "…자아…!"])
        case .hachiware:
            DialogueSet(greeting: ["여기서 같이 사는 거야?", "친구가 생겼네!"],
                        poke: ["앗, 간지러워!", "무슨 좋은 일 있어?", "같이 쉬었다 할까?"],
                        building: ["이렇게 놓으면 되려나?", "조금씩 해 보자!"],
                        upgraded: ["봐 봐, 제법 집 같아!", "우리 힘으로 해냈어!"],
                        completed: ["여기가 우리 집이구나!", "다 같이 놀러 오면 좋겠다!"],
                        gift: ["이거, 집에 쓸 수 있겠지?", "같이 쓰면 좋을 것 같아서!"])
        case .usagi:
            DialogueSet(greeting: ["야하앗!", "우라야하!"],
                        poke: ["하아?", "프루루루!", "야하!"],
                        building: ["우라! 우라!", "훗! 야하!"],
                        upgraded: ["야하아앗!", "우라아!"],
                        completed: ["이야하아아!", "프루루루루!"],
                        gift: ["흣!", "우라!"])
        case .momonga:
            DialogueSet(greeting: ["귀여운 내가 왔다!", "어서 귀여워해 줘!"],
                        poke: ["더 쓰다듬어!", "귀엽다고 해 봐!", "아직 부족해!"],
                        building: ["내 자리, 폭신하게 해!", "더 귀엽게 꾸며 줘!"],
                        upgraded: ["흐흥, 내게 딱이군!", "이제 칭찬해도 좋아!"],
                        completed: ["여기서 잔뜩 뒹굴 테다!", "제일 좋은 자리는 내 거!"],
                        gift: ["받아라! 그리고 칭찬해!", "귀여운 내가 가져왔다!"])
        case .kurimanju:
            DialogueSet(greeting: ["후우…", "음…"],
                        poke: ["…응?", "하아…", "후…"],
                        building: ["흐읍…", "후읍…!"],
                        upgraded: ["…후우", "음…!"],
                        completed: ["하아아…", "크으…"],
                        gift: ["…음", "흠…!"])
        case .rakko:
            DialogueSet(greeting: ["잘 부탁한다.", "꽤 좋은 곳이군."],
                        poke: ["무슨 일이지?", "잠깐 쉬어도 좋겠군.", "흠, 나쁘지 않아."],
                        building: ["기초부터 단단하게.", "서두르지 않아도 된다."],
                        upgraded: ["좋아. 잘해냈군.", "한층 튼튼해졌군."],
                        completed: ["훌륭한 집이 됐군.", "이제 편히 쉬도록 하지."],
                        gift: ["이걸 써 보도록 해.", "네게 도움이 될 거다."])
        case .shisa:
            DialogueSet(greeting: ["잘 부탁드려요!", "저도 함께해도 될까요?"],
                        poke: ["에헤헤, 고마워요!", "오늘도 힘낼게요!", "잠깐 쉬고 있었어요!"],
                        building: ["제가 옮겨 볼게요!", "하나씩 배우고 있어요!"],
                        upgraded: ["조금은 늘었을까요?", "와아, 뿌듯해요!"],
                        completed: ["여기까지 해냈네요!", "열심히 하길 잘했어요!"],
                        gift: ["도움이 되면 좋겠어요!", "이것도 써 주세요!"])
        case .anoko:
            DialogueSet(greeting: ["…아…", "후…"],
                        poke: ["…?", "후우…", "아…!"],
                        building: ["으… 읏", "…흐읍!"],
                        upgraded: ["…아하", "후… 후…"],
                        completed: ["아… 아아…", "…후우…"],
                        gift: ["…응", "…아!"])
        case .kani:
            DialogueSet(greeting: ["…안녕", "이 책, 좋아할까…?"],
                        poke: ["…응?", "잠깐, 책갈피만…", "…헤헤"],
                        building: ["여기에 두면… 되겠지?", "조금만 더…"],
                        upgraded: ["…됐다!", "책 놓을 자리도 생겼어…"],
                        completed: ["…여기서 같이 읽자", "참… 아늑하다…"],
                        gift: ["…이거, 너 주려고", "마음에 들면 좋겠다…"])
        }
    }
}

// Original fan lines for the desktop companion; a line stays stable within its time slot.
extension FriendID {
    public func desktopLine(at time: Double) -> String {
        let lines: [String]
        switch self {
        case .chiikawa: lines = ["…응!", "와… 와아…", "…헤헤", "으응…♪"]
        case .hachiware: lines = ["옆에서 응원할게!", "조금 쉬었다 할까?", "오늘도 같이 있네!", "한 걸음씩 가 보자!"]
        case .usagi: lines = ["야하앗!", "프루루루!", "우라야하!", "야하! 야하!"]
        case .momonga: lines = ["귀여운 내가 지나간다!", "나 좀 봐 줘!", "더 귀여워해 줘!", "여긴 내 자리!"]
        case .kurimanju: lines = ["후우…", "…음", "크으…", "…후우♪"]
        case .rakko: lines = ["서두르지 않아도 된다.", "잠깐 쉬어도 좋겠군.", "잘하고 있군.", "흠, 좋은 산책이군."]
        case .shisa: lines = ["오늘도 힘낼게요!", "같이 산책해요!", "잠깐 쉬어 가요!", "응원하고 있어요!"]
        case .anoko: lines = ["…아…", "후…", "…아하", "후… 후…"]
        case .kani: lines = ["…같이 읽을래?", "잠깐, 책갈피만…", "…헤헤", "…여기 아늑하네"]
        case .pajamaGreen, .pajamaPink, .pajamaWhite, .pajamaPurple: lines = ["♪ ♫", "하나, 둘…♪", "함께…♪", "…♪!"]
        case .pochette, .labor: lines = ["차근차근 해 보자.", "잠깐 쉬어 가자."]
        }
        let slot = Int(max(0, time) / 14)
        if slot % 5 == 4 { return japaneseLines[(slot / 5) % japaneseLines.count] }
        return lines[(slot - slot / 5) % lines.count]
    }
}

// Short fan-authored Japanese variants, not claims of canonical episode quotations.
extension FriendID {
    private var japaneseLines: [String] {
        switch self {
        case .chiikawa: ["…うん!", "わ… わあ…", "…えへへ"]
        case .hachiware: ["いっしょに、ひと休みしよ!", "少しずつ、やってみよう!", "今日はどんな一日かな?"]
        case .usagi: ["ヤハッ!", "プルルル!", "ウラヤハ!"]
        case .momonga: ["もっと、かわいがって!", "こっちも見て!", "ほめてもいいぞ!"]
        case .kurimanju: ["ふぅ…", "…うん", "はぁ…♪"]
        case .rakko: ["少し休むとしよう。", "焦らなくていい。", "いい調子だな。"]
        case .shisa: ["今日もがんばります!", "いっしょに歩きましょう!", "ありがとうございます!"]
        case .anoko: ["…あ…", "ふぅ…", "…あは"]
        case .kani: ["…いっしょに読む?", "しおりを、はさんで…", "…えへへ"]
        case .pajamaGreen, .pajamaPink, .pajamaWhite, .pajamaPurple: ["いっしょに…♪", "いち、に…♪"]
        case .pochette, .labor: ["ひと休みしよう。", "少しずつ、いこう。"]
        }
    }
}
