import Foundation
import Testing
@testable import ChiiCore

// Synthetic fixtures only: no real log text.

private func tempDir() -> URL {
    let d = FileManager.default.temporaryDirectory.appendingPathComponent("chiibar-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}

private func claudeLine(id: String, req: String, input: Int, output: Int, create: Int, read: Int,
                        ts: String = "2026-10-15T03:00:00.000Z") -> String {
    #"{"type":"assistant","requestId":"\#(req)","timestamp":"\#(ts)","message":{"id":"\#(id)","role":"assistant","content":[{"type":"text","text":"x"}],"usage":{"input_tokens":\#(input),"output_tokens":\#(output),"cache_creation_input_tokens":\#(create),"cache_read_input_tokens":\#(read)}}}"#
}

private func codexLine(input: Int, cached: Int, output: Int, ts: String = "2026-10-15T03:00:00.000Z") -> String {
    #"{"timestamp":"\#(ts)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":\#(input),"cached_input_tokens":\#(cached),"output_tokens":\#(output),"reasoning_output_tokens":0,"total_tokens":\#(input + output)},"last_token_usage":{"input_tokens":1,"cached_input_tokens":0,"output_tokens":1,"total_tokens":2}}}}"#
}

private func write(_ lines: [String], to url: URL, append: Bool = false) {
    let text = lines.map { $0 + "\n" }.joined()
    if append, let h = try? FileHandle(forWritingTo: url) {
        h.seekToEndOfFile(); h.write(text.data(using: .utf8)!); try? h.close()
    } else {
        try! text.write(to: url, atomically: false, encoding: .utf8)
    }
}

private func sum(_ e: [TokenEvent]) -> Int64 { e.reduce(0) { $0 + $1.tokens } }

@Suite struct UsageTests {
    @Test func claudeParseAndDedupe() {
        let root = tempDir()
        let line = claudeLine(id: "msg_1", req: "req_1", input: 10, output: 20, create: 30, read: 1000)
        write([line, line, #"{"type":"user","message":{"content":"hi"}}"#, "not json",
               claudeLine(id: "msg_2", req: "req_2", input: 1, output: 2, create: 3, read: 9)],
              to: root.appendingPathComponent("a.jsonl"))
        // same message repeated in another session file
        write([line], to: root.appendingPathComponent("b.jsonl"))
        var state = ScanState()
        let events = UsageScanner.scan(state: &state, claudeRoot: root, codexRoot: nil)
        #expect(sum(events) == (10 + 20 + 30 + 100) + (1 + 2 + 3 + 0))
        #expect(events.count == 2)
        #expect(state.recentKeys.count == 2)
    }

    @Test func codexDeltas() {
        #expect(Effective.codexDelta(previous: nil, current: [100, 40, 10]) == 60 + 4 + 10)
        #expect(Effective.codexDelta(previous: [100, 40, 10], current: [100, 40, 10]) == 0)
        #expect(Effective.codexDelta(previous: [100, 40, 10], current: [300, 140, 30]) == 100 + 10 + 20)
        // counter reset: take current as fresh
        #expect(Effective.codexDelta(previous: [300, 140, 30], current: [50, 0, 5]) == 55)

        let root = tempDir()
        let f = root.appendingPathComponent("rollout.jsonl")
        write([#"{"type":"session_meta","payload":{"id":"s"}}"#,
               codexLine(input: 100, cached: 40, output: 10),
               codexLine(input: 100, cached: 40, output: 10),
               codexLine(input: 300, cached: 140, output: 30)], to: f)
        var state = ScanState()
        #expect(sum(UsageScanner.scan(state: &state, claudeRoot: nil, codexRoot: root)) == 74 + 130)
        write([codexLine(input: 400, cached: 140, output: 40)], to: f, append: true)
        #expect(sum(UsageScanner.scan(state: &state, claudeRoot: nil, codexRoot: root)) == 110)
    }

    @Test func incrementalOffsetsAndTruncation() {
        let root = tempDir()
        let f = root.appendingPathComponent("s.jsonl")
        write([claudeLine(id: "a", req: "1", input: 5, output: 5, create: 0, read: 0)], to: f)
        var state = ScanState()
        #expect(sum(UsageScanner.scan(state: &state, claudeRoot: root, codexRoot: nil)) == 10)
        // half-written line is not consumed
        let partial = claudeLine(id: "b", req: "2", input: 7, output: 0, create: 0, read: 0)
        let h = try! FileHandle(forWritingTo: f)
        h.seekToEndOfFile(); h.write(partial.data(using: .utf8)!); try? h.close()
        #expect(sum(UsageScanner.scan(state: &state, claudeRoot: root, codexRoot: nil)) == 0)
        write([""], to: f, append: true)
        #expect(sum(UsageScanner.scan(state: &state, claudeRoot: root, codexRoot: nil)) == 7)
        // truncation resets the offset; new content is read from the start
        write([claudeLine(id: "c", req: "3", input: 3, output: 0, create: 0, read: 0)], to: f)
        #expect(sum(UsageScanner.scan(state: &state, claudeRoot: root, codexRoot: nil)) == 3)
    }

    @Test func inodeChangeResets() {
        let root = tempDir()
        let f = root.appendingPathComponent("s.jsonl")
        write([codexLine(input: 100, cached: 0, output: 0)], to: f)
        var state = ScanState()
        #expect(sum(UsageScanner.scan(state: &state, claudeRoot: nil, codexRoot: root)) == 100)
        // replace file (new inode) with a longer one whose totals are lower
        let tmp = root.appendingPathComponent("tmp")
        write([codexLine(input: 10, cached: 0, output: 0), codexLine(input: 20, cached: 0, output: 0)], to: tmp)
        _ = try? FileManager.default.replaceItemAt(f, withItemAt: tmp)
        #expect(sum(UsageScanner.scan(state: &state, claudeRoot: nil, codexRoot: root)) == 20)
    }

    @Test func idempotentRescan() {
        let root = tempDir(), croot = tempDir()
        write([claudeLine(id: "a", req: "1", input: 5, output: 5, create: 0, read: 0)], to: root.appendingPathComponent("x.jsonl"))
        write([codexLine(input: 50, cached: 0, output: 0)], to: croot.appendingPathComponent("y.jsonl"))
        var state = ScanState()
        let first = UsageScanner.scan(state: &state, claudeRoot: root, codexRoot: croot)
        #expect(sum(first) == 10 + 50)
        let saved = try! JSONDecoder().decode(ScanState.self, from: JSONEncoder().encode(state))
        var restored = saved
        #expect(UsageScanner.scan(state: &restored, claudeRoot: root, codexRoot: croot).isEmpty)
        #expect(UsageScanner.scan(state: &state, claudeRoot: root, codexRoot: croot).isEmpty)
    }

    @Test func dedupeKeysBounded() {
        let root = tempDir()
        let lines = (0..<(ScanState.maxKeys + 50)).map { claudeLine(id: "m\($0)", req: "r", input: 1, output: 0, create: 0, read: 0) }
        write(lines, to: root.appendingPathComponent("big.jsonl"))
        var state = ScanState()
        _ = UsageScanner.scan(state: &state, claudeRoot: root, codexRoot: nil)
        #expect(state.recentKeys.count == ScanState.maxKeys)
    }

    @Test func missingLogFolders() {
        var state = ScanState()
        let missing = tempDir().appendingPathComponent("absent")
        #expect(UsageScanner.scan(state: &state, claudeRoot: missing, codexRoot: missing).isEmpty)
        #expect(state.files.isEmpty)
    }

    @Test func outOfRangeNumericUsageDoesNotTrap() throws {
        for text in ["1e100", "-1e100", "9223372036854775808.0"] {
            #expect(try JSONDecoder().decode(Num.self, from: Data(text.utf8)).v == 0)
        }
    }
}

@Suite struct GameTests {
    let now = ISO8601DateFormatter().date(from: "2026-10-15T03:00:00Z")!

    func ev(_ t: Int64, at d: Date? = nil) -> TokenEvent { TokenEvent(date: d ?? now, tokens: t, source: .claude) }

    func owned(_ f: FriendID, stage: Int = 1) -> GameState {
        var s = GameState(now: now)
        s.houses[f] = House(stage: stage)
        s.met = [f]
        s.current = f
        return s
    }

    @Test func firstDrawIsStarter() {
        for seed in 0..<200 as Range<UInt64> {
            var s = GameState(now: now)
            var rng = SeededRNG(seed: seed)
            let r = s.draw(using: &rng)!
            #expect(FriendID.starters.contains(r.friend))
            #expect(r.outcome == .newFriend)
            #expect(s.houses[r.friend] == House(stage: 1))
            #expect(s.tickets == 0)
            #expect(s.draw(using: &rng) == nil)
        }
    }

    @Test func rarityWeights() {
        var rng = SeededRNG(seed: 42)
        var tiers = [1: 0, 2: 0, 3: 0]
        var perFriend: [FriendID: Int] = [:]
        let n = 30_000
        for _ in 0..<n {
            var s = owned(.chiikawa, stage: 12)
            s.tickets = 1
            let r = s.draw(using: &rng)!
            tiers[r.friend.rarity, default: 0] += 1
            perFriend[r.friend, default: 0] += 1
        }
        #expect(abs(Double(tiers[1]!) / Double(n) - 0.6) < 0.02)
        #expect(abs(Double(tiers[2]!) / Double(n) - 0.3) < 0.02)
        #expect(abs(Double(tiers[3]!) / Double(n) - 0.1) < 0.02)
        #expect((perFriend[.anoko] ?? 0) > 0)
        #expect((perFriend[.kani] ?? 0) > 0)
        // uniform within the 1-star tier
        for f in [FriendID.momonga, .kurimanju, .shisa] {
            #expect(abs(Double(perFriend[f]!) / Double(n) - 0.2) < 0.02)
        }
        // same seed, same sequence
        var a = SeededRNG(seed: 7), b = SeededRNG(seed: 7)
        var s1 = GameState(now: now), s2 = GameState(now: now)
        #expect(s1.draw(using: &a) == s2.draw(using: &b))
    }

    @Test func newFriendsPreserveProgressAcrossSave() throws {
        var state = owned(.chiikawa, stage: 6)
        state.houses[.anoko] = House(stage: 3, progress: 123_456)
        state.houses[.kani] = House(stage: 8, progress: 789_012)
        state.met = [.chiikawa, .anoko, .kani]
        state.current = .kani
        let restored = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        #expect(restored.houses == state.houses)
        #expect(restored.current == .kani)
        #expect(restored.met == state.met)
    }

    @Test func duplicateAddsMaterialsWithoutBuilding() {
        var rng = SeededRNG(seed: 1)
        // keep drawing until we hit a duplicate of an owned friend
        var s = GameState(now: now)
        for f in FriendID.allCases { s.houses[f] = House(stage: 3, progress: 5) }
        s.tickets = 1
        let r = s.draw(using: &rng)!
        #expect(r.outcome == .gift(stage: 4))
        #expect(s.houses[r.friend] == House(stage: 3, progress: HousePlan.cost(ofStage: 4) + 5))
        #expect(s.tickets == 0)
    }

    @Test func duplicateOnFinishedHouseGivesTicketBack() {
        var rng = SeededRNG(seed: 3)
        var s = GameState(now: now)
        for f in FriendID.allCases { s.houses[f] = House(stage: 12) }
        s.tickets = 1
        let r = s.draw(using: &rng)!
        #expect(r.outcome == .ticketBack)
        #expect(s.tickets == 1)
    }

    @Test func stageCostsMonotonicAndTwelveEnds() {
        var prev: Int64 = 0
        for st in 2...12 {
            #expect(HousePlan.cost(ofStage: st) > prev)
            prev = HousePlan.cost(ofStage: st)
        }
        #expect(HousePlan.pieceNames.count == 12)
        var s = owned(.usagi)
        let credited = s.credit([ev(HousePlan.totalCost)])
        #expect(s.currentHouse?.stage == 1)
        #expect(!credited.contains(.completed(.usagi)))
        var events: [GameEvent] = []
        for expectedStage in 2...12 {
            events += s.build()
            #expect(s.currentHouse?.stage == expectedStage)
        }
        #expect(s.build().isEmpty)
        #expect(s.houses[.usagi]!.stage == 12)
        #expect(s.houses[.usagi]!.isComplete)
        #expect(events.contains(.completed(.usagi)))
        #expect(events.filter { if case .piece = $0 { true } else { false } }.count == 11)
    }

    @Test func partialProgressAndStageByStage() {
        var s = owned(.hachiware)
        s.credit([ev(HousePlan.cost(ofStage: 2) - 1)])
        #expect(s.currentHouse!.stage == 1)
        #expect(s.build().isEmpty)
        s.credit([ev(1)])
        #expect(s.currentHouse?.stage == 1)
        #expect(s.currentHouse?.canBuild == true)
        #expect(s.build() == [.piece(.hachiware, stage: 2)])
        #expect(s.currentHouse == House(stage: 2, progress: 0))
        #expect(s.build().isEmpty)
    }

    @Test func tokensAfterCompletionOnlyEarnTickets() {
        var s = owned(.rakko, stage: 12)
        let events = s.credit([ev(Tuning.ticketCost * 2 + 5)])
        #expect(s.currentHouse == House(stage: 12, progress: 0))
        #expect(s.tickets == 3)
        #expect(s.ticketProgress == 5)
        #expect(events == [.ticket, .ticket])
    }

    @Test func ticketAccrualAndCreditFrom() {
        var s = GameState(now: now)
        #expect(s.tickets == 1)
        s.credit([ev(Tuning.ticketCost - 1), ev(1_000_000_000, at: now.addingTimeInterval(-86_400 * 2))])
        #expect(s.tickets == 1)
        s.credit([ev(1)])
        #expect(s.tickets == 2)
        #expect(s.today(now) == Tuning.ticketCost)
    }

    @Test func switchingKeepsEachHouse() {
        var s = owned(.chiikawa)
        s.houses[.shisa] = House()
        s.credit([ev(HousePlan.cost(ofStage: 2))])
        s.select(.shisa)
        s.select(.momonga) // not owned: ignored
        #expect(s.current == .shisa)
        s.credit([ev(10)])
        #expect(s.houses[.chiikawa] == House(stage: 1, progress: HousePlan.cost(ofStage: 2)))
        #expect(s.houses[.shisa] == House(stage: 1, progress: 10))
    }

    @Test func activitiesUseOnlyBuiltFurniture() {
        let required: [Activity: Int] = [.sweeping: 2, .snack: 6, .napFuton: 7, .window: 8, .cooking: 10, .reading: 11]
        for stage in 1...12 {
            for mood in [Mood.busy, .idle, .sleeping] {
                let opts = Activity.options(mood: mood, stage: stage)
                #expect(!opts.isEmpty)
                for a in opts { #expect(a.requiredStage <= stage); #expect((required[a] ?? 1) <= stage) }
                for minute in stride(from: 0, to: 600, by: 7) {
                    for f in FriendID.allCases {
                        let a = Activity.choose(mood: mood, stage: stage, now: now.addingTimeInterval(Double(minute) * 60), friend: f)
                        #expect(opts.contains(a))
                    }
                }
            }
            #expect(Activity.options(mood: .sleeping, stage: stage) == [stage >= 7 ? .napFuton : .napGround])
        }
    }

    @Test func moodThresholds() {
        #expect(Mood.at(now, lastTokenAt: now.addingTimeInterval(-60)) == .busy)
        #expect(Mood.at(now, lastTokenAt: now.addingTimeInterval(-10 * 60)) == .idle)
        #expect(Mood.at(now, lastTokenAt: now.addingTimeInterval(-31 * 60)) == .sleeping)
    }

    @Test func stateRoundTrip() throws {
        var s = owned(.kurimanju, stage: 5)
        s.credit([ev(123_456)])
        s.scan.files["/x.jsonl"] = FileCheckpoint(offset: 99, inode: 7, codexTotals: [1, 2, 3])
        s.scan.recentKeys = [1, 2, 3]
        let url = tempDir().appendingPathComponent("state.json")
        try Store.save(s, to: url)
        #expect(Store.load(url) == s)
    }

    @Test func corruptStateIsPreservedBeforeRecovery() throws {
        let dir = tempDir(), url = dir.appendingPathComponent("state.json")
        let original = Data("{broken".utf8)
        try original.write(to: url)
        let fresh = try Store.loadOrRecover(url, now: now)
        #expect(fresh.tickets == 1)
        #expect(fresh.houses.isEmpty)
        let backups = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        #expect(backups.count == 1)
        #expect(try Data(contentsOf: backups[0]) == original)
        try Store.save(fresh, to: url)
        #expect(Store.load(url) == fresh)
    }

    @Test func invalidStageDoesNotReachUI() throws {
        let url = tempDir().appendingPathComponent("state.json")
        try Store.save(owned(.chiikawa, stage: 999), to: url)
        #expect(Store.load(url) == nil)
        #expect(try Store.loadOrRecover(url, now: now).houses.isEmpty)
    }

    @Test func firstSessionWithoutLogsStillReachesFirstPiece() throws {
        let url = tempDir().appendingPathComponent("state.json")
        var state = try Store.loadOrRecover(url, now: now)
        var rng = SeededRNG(seed: 10)
        let friend = state.draw(using: &rng)!.friend
        state.credit([ev(Tuning.firstPieceCost - 1)])
        #expect(state.houses[friend]?.stage == 1)
        state.credit([ev(1)])
        #expect(state.houses[friend]?.stage == 1)
        try Store.save(state, to: url)
        state = try Store.loadOrRecover(url, now: now)
        #expect(state.currentHouse?.canBuild == true)
        state.build()
        #expect(state.houses[friend]?.stage == 2)
        try Store.save(state, to: url)
        #expect(try Store.loadOrRecover(url, now: now) == state)
    }

    @Test func pacingRequiresMoreThanOneTypicalDayPerTicket() {
        var s = owned(.hachiware)
        s.tickets = 0
        s.credit([ev(42_000_000)])
        #expect(s.tickets == 0)
        s.credit([ev(21_000_000)])
        #expect(s.tickets == 1)
        #expect(s.ticketProgress == 0)
        #expect(s.currentHouse?.stage == 1)
        #expect(HousePlan.cost(ofStage: 2) == 1_500_000)
        #expect(HousePlan.cost(ofStage: 12) == 84_000_000)
        let costs = (2...12).map { HousePlan.cost(ofStage: $0) }
        let increments = zip(costs.dropFirst(), costs).map { $0 - $1 }
        #expect(zip(increments.dropFirst(), increments).allSatisfy { $0 > $1 })
    }

    @Test func previousPacingBalancesRemainLoadable() throws {
        var s = owned(.usagi, stage: 9)
        s.ticketProgress = 41_999_999
        s.tickets = 3
        s.houses[.usagi]!.progress = 50_000_000
        let url = tempDir().appendingPathComponent("state.json")
        try Store.save(s, to: url)
        #expect(Store.load(url) == s)
        #expect(s.build() == [.piece(.usagi, stage: 10)])
        #expect(s.currentHouse?.progress == 5_000_000)
    }

    @Test func dailyAchievementsTrackClicksAndResetWithoutLosingProgress() throws {
        var s = owned(.hachiware)
        s.houses[.hachiware]!.progress = 500_000
        s.observeProgress(at: now)
        s.credit([ev(3_500_000)])
        let later = now.addingTimeInterval(30 * 60)
        s.build(at: later)
        s.build(at: later)
        let record = s.progressToday(for: .hachiware, at: later)!
        #expect(record.upgrades == 2)
        #expect(record.earned == 3_500_000)
        #expect(record.startProgress == 500_000)
        #expect(record.startStage == 1)
        #expect(record.lastUpgradeAt == later)
        #expect(s.currentHouse?.stage == 3)
        let url = tempDir().appendingPathComponent("state.json")
        try Store.save(s, to: url)
        s = Store.load(url)!
        #expect(s.progressToday(for: .hachiware, at: later) == record)
        let tomorrow = now.addingTimeInterval(86_400)
        #expect(s.progressToday(for: .hachiware, at: tomorrow) == nil)
        s.observeProgress(at: tomorrow)
        #expect(s.progressToday(for: .hachiware, at: tomorrow)?.upgrades == 0)
        #expect(s.progressToday(for: .hachiware, at: tomorrow)?.startStage == 3)
        #expect(s.currentHouse?.stage == 3)
    }

    @Test func oldSavesDoNotInventAchievements() throws {
        let original = owned(.chiikawa, stage: 8)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as! [String: Any]
        object.removeValue(forKey: "dailyProgress")
        var loaded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: object))
        loaded.observeProgress(at: now)
        #expect(loaded.progressToday(for: .chiikawa, at: now)?.upgrades == 0)
        #expect(loaded.progressToday(for: .chiikawa, at: now)?.startStage == 8)
        loaded.houses[.usagi] = House()
        loaded.select(.usagi)
        loaded.observeProgress(at: now)
        loaded.credit([ev(Tuning.firstPieceCost)])
        loaded.build(at: now)
        #expect(loaded.progressToday(for: .usagi, at: now)?.upgrades == 1)
        #expect(loaded.progressToday(for: .chiikawa, at: now)?.upgrades == 0)
    }

    @Test func tokenFormat() {
        #expect(TokenFormat.short(1_234_567) == "1.2M")
        #expect(TokenFormat.short(12_345) == "12K")
        #expect(TokenFormat.short(999) == "999")
    }
}
