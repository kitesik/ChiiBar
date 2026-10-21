import CoreGraphics
import Foundation
import Testing

@Test func batchDrawMatches149SingleDrawsAndPreservesRefunds() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    var batch = GameState(now: now)
    batch.tickets = 149
    var singles = batch
    var a = SeededRNG(seed: 149), b = SeededRNG(seed: 149)
    let results = batch.drawAll(using: &a, at: now)
    let expected = (0..<149).compactMap { _ in singles.draw(using: &b, at: now) }
    #expect(results == expected)
    #expect(batch == singles)
    #expect(results.count == 149 && batch.tickets == 0)
    #expect(batch.houses.values.allSatisfy { $0.stage == 1 })
    #expect(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(batch)) == batch)

    batch.houses = Dictionary(uniqueKeysWithValues: FriendID.visible.map { ($0, House(stage: 13)) })
    batch.met = FriendID.visible
    batch.tickets = 149
    let finished = batch.houses
    let refunds = batch.drawAll(using: &a, at: now)
    #expect(refunds.count == 149)
    #expect(refunds.allSatisfy { $0.outcome == .ticketBack })
    #expect(batch.tickets == 149 && batch.houses == finished)
    batch.tickets = 0
    #expect(batch.drawAll(using: &a, at: now).isEmpty)
}

@Test func homeClothingFollowsOnlyClearThemes() {
    for stage in [1, 2, 3, 4, 5, 6, 7, 9, 10] {
        #expect(HomeOutfit.at(stage: stage) == .none)
    }
    #expect(HomeOutfit.at(stage: 8) == .gat)
    for stage in [11, 12, 13] { #expect(HomeOutfit.at(stage: stage) == .bowTie) }
}

@Test func desktopWalkStaysOnScreenAndDoesNotJumpAfterSleep() {
    let bounds = CGRect(x: -1440, y: 24, width: 1240, height: 700)
    var point = CGPoint(x: -800, y: 100)
    for _ in 0..<10000 {
        let next = DesktopRoam.step(from: point, toward: CGPoint(x: 5000, y: -5000), in: bounds, elapsed: 1.0 / 30)
        #expect(next.x >= bounds.minX && next.x <= bounds.maxX)
        #expect(next.y >= bounds.minY && next.y <= bounds.maxY)
        #expect(hypot(next.x - point.x, next.y - point.y) <= 0.801)
        point = next
    }
    let start = CGPoint(x: -800, y: 100)
    let afterSleep = DesktopRoam.step(from: start, toward: .zero, in: bounds, elapsed: 3600)
    #expect(hypot(afterSleep.x - start.x, afterSleep.y - start.y) <= 2.401)
    #expect(DesktopRoam.step(from: start, toward: .zero, in: bounds, elapsed: 10, reduced: true) == start)
    for friend in FriendID.visible {
        #expect(!friend.desktopLine(at: 0).isEmpty)
        #expect(friend.desktopLine(at: 0) == friend.desktopLine(at: 13))
    }
}

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

    @Test func firstDrawUsesFullRosterAndOneFreeTicket() {
        var seen: Set<FriendID> = []
        for seed in 0..<1000 as Range<UInt64> {
            var s = GameState(now: now)
            var rng = SeededRNG(seed: seed)
            let r = s.draw(using: &rng)!
            seen.insert(r.friend)
            #expect(r.outcome == .newFriend)
            #expect(s.houses[r.friend] == House(stage: 1))
            #expect(s.tickets == 0)
            #expect(s.draw(using: &rng) == nil)
        }
        #expect(seen == Set(FriendID.visible))
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
        for friend in FriendID.allCases {
            #expect(abs(Double(perFriend[friend] ?? 0) / Double(n) - DrawOdds.probability(of: friend)) < 0.015)
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

    @Test func duplicateBanksExperienceUntilManualUpgrade() {
        var rng = SeededRNG(seed: 1)
        // keep drawing until we hit a duplicate of an owned friend
        var s = GameState(now: now)
        for f in FriendID.allCases { s.houses[f] = House(stage: 3, progress: 5) }
        s.tickets = 1
        let r = s.draw(using: &rng)!
        #expect(r.outcome == .gift(stage: 4))
        #expect(s.houses[r.friend] == House(stage: 3, progress: Tuning.duplicateGift(forStage: 4) + 5))
        #expect(s.tickets == 0)
    }

    @Test func duplicateOnFinishedHouseGivesTicketBack() {
        var rng = SeededRNG(seed: 3)
        var s = GameState(now: now)
        for f in FriendID.allCases { s.houses[f] = House(stage: 13) }
        s.tickets = 1
        let r = s.draw(using: &rng)!
        #expect(r.outcome == .ticketBack)
        #expect(s.tickets == 1)
    }

    @Test func allThirteenHomesRequireTwelveExplicitUpgrades() {
        let names = ["비박", "움막집", "벽돌집", "굴뚝집", "울타리집", "마당집", "초가집", "양반집", "현대식집", "빌라", "아파트", "초고층 빌딩", "펜트하우스"]
        #expect(HousePlan.pieceNames == names)
        var prev: Int64 = 0
        for st in 2...13 {
            #expect(HousePlan.cost(ofStage: st) > prev)
            prev = HousePlan.cost(ofStage: st)
        }
        var s = owned(.usagi)
        s.observeProgress(at: now)
        let events = s.credit([ev(1_000_000 + (HousePlan.totalCost + 123 - 400_000) * 100)])
        #expect(s.currentHouse?.stage == 1)
        #expect(!events.contains(.completed(.usagi)))
        for stage in 2...13 {
            let built = s.build(at: now)
            #expect(s.currentHouse?.stage == stage)
            #expect(built.filter { if case .piece = $0 { true } else { false } }.count == 1)
        }
        #expect(s.currentHouse == House(stage: 13))
        #expect(s.progressToday(for: .usagi, at: now)?.upgrades == 12)
        #expect(s.build().isEmpty)
    }

    @Test func exactBoundaryAndSurplusWaitForClick() {
        var s = owned(.hachiware)
        s.credit([ev(HousePlan.cost(ofStage: 2) - 1)])
        #expect(s.currentHouse!.stage == 1)
        #expect(s.currentHouse!.fraction < 1)
        #expect(s.credit([ev(1)]) == [.ticket])
        #expect(s.currentHouse?.stage == 1)
        #expect(s.currentHouse?.canBuild == true)
        #expect(s.build(at: now) == [.piece(.hachiware, stage: 2)])
        #expect(s.currentHouse == House(stage: 2))
        let activeSeconds = Double(HousePlan.cost(ofStage: 3)) * 60 / Double(WorkActivity.energyPerMinute) + 3
        s.creditActivity([DateInterval(start: now, duration: activeSeconds)])
        #expect(s.currentHouse?.stage == 2)
        #expect(s.build(at: now) == [.piece(.hachiware, stage: 3)])
        #expect(s.currentHouse == House(stage: 3, progress: 100))
        #expect(s.build().isEmpty)
    }

    @Test func tokensAfterCompletionOnlyEarnTickets() {
        var s = owned(.rakko, stage: 13)
        let events = s.credit([ev(61_000_500)])
        #expect(s.currentHouse == House(stage: 13, progress: 0))
        #expect(s.tickets == 9)
        #expect(s.ticketProgress == 40_005)
        #expect(events == Array(repeating: .ticket, count: 8))
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
        try #require(backups.count == 1)
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

    @Test func dailyExperienceIsBatchIndependentAndResetsTomorrow() {
        var one = owned(.chiikawa), split = one
        one.credit([ev(17_000_000)])
        for _ in 0..<170 { split.credit([ev(100_000)]) }
        #expect(one == split)
        #expect(one.currentHouse?.progress == 560_000)
        #expect(one.tickets == 5)
        #expect(one.ticketProgress == 80_000)
        let tomorrow = now.addingTimeInterval(86_400)
        split.credit([ev(250_000, at: tomorrow)])
        #expect(split.currentHouse?.progress == 810_000)
        #expect(split.today(tomorrow) == 250_000)
    }

    @Test func economyV2KeepsOwnedRewardsAndMigratesTicketFraction() throws {
        var old = owned(.chiikawa, stage: 8)
        old.economyVersion = 2
        old.tickets = 100
        old.ticketProgress = 75_000
        old.houses[.chiikawa]?.progress = 2_900_000
        let url = tempDir().appendingPathComponent("state.json")
        try Store.save(old, to: url)
        let updated = try Store.loadOrRecover(url, now: now)
        #expect(updated.tickets == 100)
        #expect(updated.ticketProgress == Tuning.ticketCost / 2)
        #expect(updated.currentHouse?.stage == old.currentHouse?.stage)
        #expect(updated.currentHouse?.progress == 2_900_000 * HousePlan.cost(ofStage: 9) / 900_000)
        #expect(updated.scan == old.scan)
        try Store.save(updated, to: url)
        #expect(try Store.loadOrRecover(url, now: now) == updated)
    }

    @Test func nonDeveloperPacingAndDuplicateGift() {
        var s = owned(.hachiware)
        s.tickets = 0
        s.credit([ev(Tuning.ticketCost - 1)])
        #expect(s.tickets == 0)
        s.credit([ev(1)])
        #expect(s.tickets == 1)
        #expect(s.ticketProgress == 0)
        #expect(s.currentHouse?.stage == 1)
        #expect(s.currentHouse?.progress == Tuning.ticketCost)
        #expect(HousePlan.cost(ofStage: 2) == 120_000)
        #expect(HousePlan.totalCost == 12_180_000)
        #expect(Tuning.duplicateGift(forStage: 2) == 12_000)
        #expect(Tuning.duplicateGift(forStage: 13) == 30_000)
    }

    @Test func legacyEconomyMigratesOnceAndBacksUpExactOriginal() throws {
        var s = owned(.usagi, stage: 9)
        s.economyVersion = nil
        s.ticketProgress = 31_500_000
        s.tickets = 3
        s.houses[.usagi]!.progress = 67_500_000 // 150% of next cost
        let url = tempDir().appendingPathComponent("state.json")
        try Store.save(s, to: url)
        let original = try Data(contentsOf: url)
        var migrated = try Store.loadOrRecover(url, now: now)
        #expect(migrated.currentHouse?.stage == 9)
        #expect(migrated.currentHouse?.progress == HousePlan.cost(ofStage: 10) * 3 / 2)
        #expect(migrated.ticketProgress == Tuning.ticketCost / 2)
        #expect(migrated.tickets == 3)
        #expect(migrated.scan == s.scan)
        #expect(migrated.dayTotals == s.dayTotals)
        let backups = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("state.before-migration-") }
        try #require(backups.count == 1)
        #expect(try Data(contentsOf: backups[0]) == original)
        try Store.save(migrated, to: url)
        #expect(try Store.loadOrRecover(url, now: now) == migrated)
        #expect(migrated.build() == [.piece(.usagi, stage: 10)])
        #expect(migrated.currentHouse?.progress == HousePlan.cost(ofStage: 10) / 2)
    }

    @Test func dailyAchievementsTrackManualMovesAndResetWithoutLosingProgress() throws {
        var s = owned(.hachiware)
        s.houses[.hachiware]!.progress = 500_000
        s.observeProgress(at: now)
        s.credit([ev(3_500_000)])
        let later = now.addingTimeInterval(30 * 60)
        s.build(at: later)
        s.build(at: later)
        let record = s.progressToday(for: .hachiware, at: later)!
        #expect(record.upgrades == 2)
        #expect(record.earned == 425_000)
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

    @Test func legacyCompletedHouseCanReachPenthouseWithoutReset() throws {
        var s = owned(.chiikawa, stage: 12)
        s.tickets = 4
        let url = tempDir().appendingPathComponent("state.json")
        try Store.save(s, to: url)
        s = try #require(Store.load(url))
        #expect(s.currentHouse?.stage == 12)
        #expect(s.currentHouse?.isComplete == false)
        s.credit([ev(1_000_000 + (HousePlan.cost(ofStage: 13) - 400_000) * 100)])
        #expect(s.currentHouse?.stage == 12)
        s.build(at: now)
        #expect(s.currentHouse == House(stage: 13))
        #expect(s.tickets >= 4)
        try Store.save(s, to: url)
        #expect(Store.load(url) == s)
    }

    @Test func nonPositiveOrOldEventsCannotConstructHomes() {
        var s = owned(.chiikawa)
        let before = s
        let result = s.credit([ev(0), ev(-100), ev(HousePlan.totalCost, at: now.addingTimeInterval(-172800))])
        #expect(result.isEmpty)
        #expect(s == before)
    }

    @Test func randomArrivalIsStableBoundedAndActuallyOccurs() {
        for friend in FriendID.allCases {
            let values = (0..<12000).map { ArrivalMotion.scale(at: Double($0) / 100, friend: friend) }
            #expect(values.allSatisfy { $0 >= 0.86 && $0 <= 1.08 })
            #expect(values.contains { $0 < 0.9 })
            #expect(values.contains { $0 > 1.06 })
            #expect(values.filter { $0 == 1 }.count > 11000)
            #expect(ArrivalMotion.scale(at: 25.123, friend: friend) == ArrivalMotion.scale(at: 25.123, friend: friend))
        }
        #expect(ArrivalMotion.spring(elapsed: -1) == 1)
        #expect(ArrivalMotion.spring(elapsed: 1.1) == 1)
    }

    @Test func motionHasNoPopsOrTeleportingAtBoundaries() {
        for friend in FriendID.allCases {
            let values = (0...60000).map { ArrivalMotion.scale(at: Double($0) / 1000, friend: friend) }
            for pair in zip(values, values.dropFirst()) { #expect(abs(pair.1 - pair.0) < 0.003) }
        }
        #expect(ArrivalMotion.lift(elapsed: 0) == 0)
        #expect(ArrivalMotion.lift(elapsed: 0.45) > 11.9)
        #expect(ArrivalMotion.lift(elapsed: 0.72) == 0)
        #expect(ArrivalMotion.ease(-1) == 0)
        #expect(ArrivalMotion.ease(2) == 1)
    }

    @Test func tokenFormat() {
        #expect(TokenFormat.short(1_234_567) == "1.2M")
        #expect(TokenFormat.short(12_345) == "12K")
        #expect(TokenFormat.short(999) == "999")
    }
}

@Suite struct HomeWanderTests {
    @Test func remainsOnClearFloorWithoutTeleporting() {
        for friend in FriendID.allCases {
            var previous = HomeWander.position(at: 0, friend: friend)
            for tick in 1...7200 {
                let point = HomeWander.position(at: Double(tick) / 100, friend: friend)
                #expect((0.359...0.641).contains(point.x))
                #expect((0.714...0.741).contains(point.y))
                #expect(abs(point.x - previous.x) < 0.001)
                #expect(abs(point.y - previous.y) < 0.001)
                #expect(abs(point.bounce - previous.bounce) < 0.15)
                previous = point
            }
        }
    }
    @Test func reducedMotionKeepsFriendStill() {
        let start = HomeWander.position(at: 0, friend: .chiikawa, reduced: true)
        let later = HomeWander.position(at: 1000, friend: .chiikawa, reduced: true)
        #expect(start.x == later.x && start.y == later.y)
        #expect(later.bounce == 0 && later.lean == 0)
    }
}

@Test func mangaExpressionsStayWithinCharacterEvidence() {
    for friend in FriendID.allCases {
        for stage in 1...13 {
            for time in stride(from: 0.0, through: 48, by: 0.5) {
                for responding in [false, true] {
                    let selected = MangaExpression.select(friend: friend, stage: stage, time: time, responding: responding)
                    #expect(MangaExpression.allowed(for: friend).contains(selected))
                    if friend != .chiikawa { #expect(selected != .cry) }
                    if stage > 2 || responding { #expect(selected != .cry) }
                }
            }
        }
    }
    #expect(MangaExpression.select(friend: .chiikawa, stage: 1, time: 1, responding: false) == .cry)
    #expect(MangaExpression.select(friend: .chiikawa, stage: 1, time: 1, responding: true) == .relief)
    #expect(MangaExpression.select(friend: .usagi, stage: 13, time: 1, responding: true) == .base)
    #expect(MangaExpression.greeting.asset(for: .usagi) == "usagi")
}

@Test func continuousHouseRevealFinishesWithoutSeamsOrOvershoot() {
    var previous = 0.0
    for time in stride(from: -1.0, through: HomeAssembly.duration, by: 0.01) {
        let progress = HomeAssembly.reveal(elapsed: time)
        #expect(progress >= previous && progress >= 0 && progress <= 1)
        #expect(HomeAssembly.scale(elapsed: time) > 0.9 && HomeAssembly.scale(elapsed: time) < 1.04)
        previous = progress
    }
    #expect(HomeAssembly.reveal(elapsed: HomeAssembly.duration) == 1)
    #expect(HomeAssembly.scale(elapsed: HomeAssembly.duration) == 1)
    #expect(HomeAssembly.settle(elapsed: HomeAssembly.duration) == 0)
    #expect(HomeAssembly.settle(elapsed: 2.6, reduced: true) == 0)
}

@Test func everyAllowedExpressionHasPackagedArtworkAndAuthorReference() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Art/Sprites/Manga")
    let data = try Data(contentsOf: root.appendingPathComponent("catalog.json"))
    let entries = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    let ids = entries.compactMap { $0["id"] as? String }
    #expect(Set(ids).count == ids.count)
    for friend in FriendID.allCases {
        for expression in MangaExpression.allowed(for: friend) {
            let id = expression.asset(for: friend)
            let entry = try #require(entries.first { $0["id"] as? String == id })
            let source = try #require(entry["source"] as? String)
            #expect(source.hasPrefix("https://x.com/ngnchiikawa/status/") || source == "https://www.anime-chiikawa.jp/chara.html")
            let asset = try #require(entry["asset"] as? String)
            let png = try Data(contentsOf: root.appendingPathComponent(asset))
            #expect(Array(png.prefix(8)) == [137,80,78,71,13,10,26,10])
            let crop = try #require(entry["crop"] as? [Double])
            #expect(crop.count == 4 && crop[2] > crop[0] && crop[3] > crop[1])
        }
    }
}

@Test func surplusRefillWaitsForMoveThenSettlesAtExactTarget() {
    let start = Date(timeIntervalSince1970: 100)
    let event = UpgradeCarryover(friend: .chiikawa, stage: 3, amount: 2_000_000, startsAt: start)
    #expect(event.displayedFraction(target: 0.5, at: start.addingTimeInterval(-1), reduceMotion: false) == 0)
    var previous = 0.0
    for elapsed in stride(from: 0.0, through: 2, by: 0.02) {
        let value = event.displayedFraction(target: 0.5, at: start.addingTimeInterval(elapsed), reduceMotion: false)
        #expect(value >= previous && value <= 0.5)
        previous = value
    }
    #expect(previous == 0.5)
    #expect(event.displayedFraction(target: 0.5, at: start, reduceMotion: true) == 0.5)
    #expect(!event.isAnimating(at: start.addingTimeInterval(2)))
}


@Test func displayedDrawOddsMatchEveryRollBucket() {
    let buckets = (0..<DrawOdds.totalWeight).map { DrawOdds.friend(for: $0) }
    #expect(DrawOdds.totalWeight == 100)
    #expect(buckets.filter { $0 == .chiikawa }.count == 2)
    #expect(FriendID.chiikawa.rarity == 3)
    #expect(FriendID.visible.filter { $0 != .chiikawa }.allSatisfy {
        DrawOdds.probability(of: $0) > DrawOdds.probability(of: .chiikawa)
    })
    #expect(Set(DrawOdds.ranked) == Set(FriendID.visible))
    for (index, friend) in DrawOdds.ranked.enumerated() {
        #expect(buckets.filter { $0 == friend }.count == DrawOdds.weights[index])
        #expect(DrawOdds.probability(of: friend, firstDraw: true) == DrawOdds.probability(of: friend))
        if index > 0 { #expect(DrawOdds.weights[index] >= DrawOdds.weights[index - 1]) }
    }
}

@Test func ambientWeatherAndShelter() {
    #expect(HomeWeather.moment(at: 0).kind == .clear)
    #expect(HomeWeather.moment(at: 239.99).kind == .clear)
    #expect(HomeWeather.moment(at: 240).intensity == 0)
    #expect(HomeWeather.moment(at: 250).kind == .rain)
    #expect(HomeWeather.moment(at: 315).kind == .clear)
    #expect(HomeWeather.moment(at: 850).kind == .snow)
    #expect(HomeWeather.moment(at: 930).kind == .clear)
    #expect(HomeWeather.moment(at: 1450).kind == .rain)
    for friend in FriendID.allCases {
        for stage in 3...13 {
            #expect(HomeWeather.rain.reaction(friend: friend, stage: stage) == .calm)
        }
    }
    #expect(HomeWeather.rain.reaction(friend: .chiikawa, stage: 1) == .tearful)
    #expect(HomeWeather.snow.reaction(friend: .usagi, stage: 1) == .play)
    #expect(HomeWeather.snow.reaction(friend: .kurimanju, stage: 1) == .shiver)
    #expect(HomeWeather.snow.reaction(friend: .rakko, stage: 1) == .calm)
}

@Test func expandedRosterProfilesAndSaveRoundTrip() throws {
    #expect(FriendID.allCases.count == 15)
    for friend in FriendID.allCases {
        #expect(!friend.profile.isEmpty)
        #expect(!friend.profileTags.isEmpty)
        #expect(friend.profileSource.host == "www.anime-chiikawa.jp")
    }
    var state = GameState(now: Date(timeIntervalSince1970: 0))
    for friend in FriendID.allCases { state.houses[friend] = House(stage: 4, progress: 12345) }
    state.current = .pochette
    let restored = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
    #expect(restored == state)
    #expect(restored.houses[.chiikawa]?.progress == 12345)
    #expect(restored.houses[.pajamaGreen]?.stage == 4)
}

@Test func partyMigrationPreservesRecordsAndHidesArmor() throws {
    var state = GameState(now: Date())
    state.rosterVersion = nil
    state.houses = [.pajamaGreen: House(stage: 2, progress: 100), .pajamaPink: House(stage: 5, progress: 200), .labor: House(stage: 7)]
    state.met = [.pajamaGreen, .pajamaPink, .labor]
    state.current = .pajamaPink
    state.reconcileRoster()
    #expect(state.current == .pajamaGreen)
    #expect(state.houses[.pajamaGreen] == House(stage: 5, progress: 200))
    #expect(state.archivedPajamaHouses?[.pajamaGreen] == House(stage: 2, progress: 100))
    #expect(state.houses[.labor]?.stage == 7)
    #expect(state.visibleOwnedCount == 1)
    let once = state
    state.reconcileRoster()
    #expect(state == once)
    #expect(FriendID.visible.count == 10)
    for hidden in [FriendID.labor, .pochette, .pajamaPink, .pajamaWhite, .pajamaPurple] {
        #expect(DrawOdds.probability(of: hidden) == 0)
        #expect(!(0..<100).map { DrawOdds.friend(for: $0) }.contains(hidden))
    }
    var armorOnly = GameState(now: Date())
    armorOnly.rosterVersion = nil
    armorOnly.houses = [.labor: House(stage: 4)]
    armorOnly.met = [.labor]
    armorOnly.current = .labor
    armorOnly.tickets = 0
    armorOnly.reconcileRoster()
    #expect(armorOnly.current == nil && armorOnly.tickets == 1)
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("state.json")
    try Store.save(armorOnly, to: url)
    #expect(Store.load(url) == armorOnly)
}

@Test func localLogBonusIsNotReplayedAfterRestart() throws {
    let now = ISO8601DateFormatter().date(from: "2026-10-15T03:00:00Z")!
    let folder = tempDir()
    defer { try? FileManager.default.removeItem(at: folder) }
    let logs = folder.appendingPathComponent("logs")
    try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
    write([claudeLine(id: "bonus", req: "one", input: 100_000, output: 0, create: 0, read: 0)], to: logs.appendingPathComponent("usage.jsonl"))
    var s = GameState(now: now)
    s.met = [.chiikawa]; s.current = .chiikawa; s.houses[.chiikawa] = House()
    s.tokenBonus = TokenBonus(at: now.addingTimeInterval(-3600))
    s.creditActivity([DateInterval(start: now.addingTimeInterval(-3600), end: now)])
    let events = UsageScanner.scan(state: &s.scan, claudeRoot: logs, codexRoot: nil)
    #expect(s.creditTokenBonus(events, at: now) == 1_000)
    let url = folder.appendingPathComponent("state.json")
    try Store.save(s, to: url)
    var restored = try Store.loadOrRecover(url, now: now)
    let replay = UsageScanner.scan(state: &restored.scan, claudeRoot: logs, codexRoot: nil)
    #expect(replay.isEmpty)
    #expect(restored.creditTokenBonus(replay, at: now) == 0)
    #expect(restored == s)
}
