import Foundation
import Testing
@testable import ChiiCore

private let activityStart = Date(timeIntervalSince1970: 1_800_000_000)
private func stateForActivity(stage: Int = 1) -> GameState {
    var s = GameState(now: activityStart)
    s.met = [.chiikawa]; s.current = .chiikawa; s.houses[.chiikawa] = House(stage: stage); s.tickets = 0
    return s
}

@Test func fiveMinuteWindowExtendsWithoutDoubleCounting() {
    for (secondInput, expected) in [(0, 300.0), (240, 540.0)] {
        var clock = WorkClock(start: activityStart), state = stateForActivity()
        for second in 0...900 {
            let now = activityStart.addingTimeInterval(Double(second))
            let input = activityStart.addingTimeInterval(second >= secondInput ? Double(secondInput) : 0)
            state.creditActivity(clock.tick(at: now, latestInput: input))
        }
        #expect(abs((state.workActivity?.seconds(on: activityStart) ?? 0) - expected) < 0.001)
        #expect(state.currentHouse?.progress == WorkActivity.energy(for: expected))
        #expect(state.currentHouse?.stage == 1)
    }
}

@Test func activityStopsForLockSleepRestartAndClockChanges() {
    var clock = WorkClock(start: activityStart)
    var seconds = 0.0
    for second in 0...120 {
        seconds += clock.tick(at: activityStart.addingTimeInterval(Double(second)), latestInput: activityStart).reduce(0) { $0 + $1.duration }
    }
    clock.reset(at: activityStart.addingTimeInterval(120))
    #expect(clock.tick(at: activityStart.addingTimeInterval(121), latestInput: activityStart).isEmpty)
    #expect(seconds == 120)
    #expect(clock.tick(at: activityStart.addingTimeInterval(5000), latestInput: activityStart).isEmpty)
    #expect(clock.tick(at: activityStart.addingTimeInterval(4000), latestInput: activityStart).isEmpty)
    var restarted = WorkClock(start: activityStart.addingTimeInterval(60))
    #expect(restarted.tick(at: activityStart.addingTimeInterval(61), latestInput: activityStart).isEmpty)
    #expect(restarted.tick(at: activityStart.addingTimeInterval(62), latestInput: activityStart.addingTimeInterval(999)).isEmpty)
}

@Test func repeatedInputAndTimerTicksCannotMintExtraTime() {
    var clock = WorkClock(start: activityStart), state = stateForActivity()
    for second in 0...120 {
        let now = activityStart.addingTimeInterval(Double(second))
        state.creditActivity(clock.tick(at: now, latestInput: now))
        for _ in 0..<20 { state.creditActivity(clock.tick(at: now, latestInput: now)) }
    }
    #expect(state.workActivity?.seconds(on: activityStart) == 120)
    #expect(state.currentHouse?.progress == 4000)
}

@Test func activityCrossesMidnightAndSurvivesSave() throws {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
    let midnight = calendar.startOfDay(for: activityStart)
    var state = stateForActivity()
    state.creditActivity([DateInterval(start: midnight.addingTimeInterval(-30), end: midnight.addingTimeInterval(90))], calendar: calendar)
    #expect(state.workActivity?.secondsByDay[DayKey.of(midnight.addingTimeInterval(-30), calendar: calendar)] == 30)
    #expect(state.workActivity?.secondsByDay[DayKey.of(midnight, calendar: calendar)] == 90)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    try Store.save(state, to: url)
    #expect(Store.load(url) == state)
}

@Test func sixHourDaysStartWithThreeThenTwoMovesAndFinalMoveTakesFourDays() {
    var state = stateForActivity()
    func interval(_ minutes: Double, from date: Date) -> DateInterval { DateInterval(start: date, duration: minutes * 60) }
    state.creditActivity([interval(360, from: activityStart)])
    var moves = 0
    while state.currentHouse?.canBuild == true { state.build(at: activityStart); moves += 1 }
    #expect(moves == 3)
    state.creditActivity([interval(360, from: activityStart.addingTimeInterval(86400))])
    moves = 0
    while state.currentHouse?.canBuild == true { state.build(at: activityStart.addingTimeInterval(86400)); moves += 1 }
    #expect(moves == 2)
    #expect(HousePlan.cost(ofStage: 13) == WorkActivity.energy(for: 4 * 6 * 3600))
    #expect(Tuning.dailyTarget == WorkActivity.energy(for: WorkActivity.dailyGoalSeconds))
    #expect(WorkActivity.dailyGoalSeconds == 4 * 3600)
    var final = stateForActivity(stage: 12)
    final.creditActivity([interval(1439, from: activityStart)])
    #expect(final.currentHouse?.canBuild == false)
    final.creditActivity([interval(1, from: activityStart.addingTimeInterval(1439 * 60))])
    #expect(final.currentHouse?.canBuild == true)
    #expect(final.currentHouse?.stage == 12)
    final.build(at: activityStart.addingTimeInterval(86400))
    #expect(final.currentHouse == House(stage: 13))
}

@Test func tokenEconomyMigrationKeepsFractionsSurplusFriendsAndTickets() throws {
    var old = stateForActivity(stage: 2)
    old.economyVersion = 3; old.tickets = 149; old.ticketProgress = 375_000
    old.houses[.chiikawa]?.progress = 60_000 // 150% of the old 40k threshold.
    old.observeProgress(at: activityStart)
    old.archivedPajamaHouses = [.pajamaPink: House(stage: 1, progress: 10_000)]
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("state.json")
    try Store.save(old, to: url)
    let original = try Data(contentsOf: url)
    let updated = try Store.loadOrRecover(url, now: activityStart)
    #expect(updated.economyVersion == Tuning.economyVersion)
    #expect(updated.houses[.chiikawa]?.progress == HousePlan.cost(ofStage: 3) * 3 / 2)
    #expect(updated.archivedPajamaHouses?[.pajamaPink]?.progress == HousePlan.cost(ofStage: 2) / 2)
    #expect(updated.tickets == 149 && updated.ticketProgress == Tuning.ticketCost * 3 / 4 && updated.met == old.met)
    #expect(updated.workActivity == nil)
    #expect(updated.dailyProgress?[.chiikawa]?.startProgress == HousePlan.cost(ofStage: 3) * 3 / 2)
    let backups = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("state.before-migration") }
    #expect(backups.count == 1)
    #expect(try Data(contentsOf: backups[0]) == original)
    try Store.save(updated, to: url)
    #expect(try Store.loadOrRecover(url, now: activityStart) == updated)
}

@Test func occasionalJapaneseDesktopLinesAreStableAndCharacterSpecific() {
    for friend in FriendID.visible {
        let japanese = friend.desktopLine(at: 56) // The fifth speech slot.
        #expect(japanese == friend.desktopLine(at: 69))
        #expect(japanese.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) })
    }
    #expect(FriendID.usagi.desktopLine(at: 56) != FriendID.hachiware.desktopLine(at: 56))
}

@Test func activityTicketsArriveEveryHourAndKeepRemainder() {
    var state = stateForActivity()
    state.creditActivity([DateInterval(start: activityStart, duration: 3599)])
    #expect(state.tickets == 0)
    state.creditActivity([DateInterval(start: activityStart.addingTimeInterval(3599), duration: 1)])
    #expect(state.tickets == 1 && state.ticketProgress == 0)
    state.creditActivity([DateInterval(start: activityStart.addingTimeInterval(3600), duration: 9000)])
    #expect(state.tickets == 3 && state.ticketProgress == Tuning.ticketCost / 2)
}

@Test func hourlyTicketsMigrateV4WithoutChangingGrowthOrActivity() throws {
    var old = stateForActivity(stage: 8)
    old.economyVersion = 4
    old.tickets = 149; old.ticketProgress = 375_000
    old.houses[.chiikawa]?.progress = 123_456
    old.observeProgress(at: activityStart)
    old.dailyProgress?[.chiikawa]?.earned = 12_000
    var activity = WorkActivity(); activity.secondsByDay[DayKey.of(activityStart)] = 3600
    old.workActivity = activity
    old.archivedPajamaHouses = [.pajamaPink: House(stage: 3, progress: 12_345)]
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("state.json")
    try Store.save(old, to: url)
    let updated = try Store.loadOrRecover(url, now: activityStart)
    var expected = old
    expected.economyVersion = Tuning.economyVersion
    expected.ticketProgress = 90_000
    #expect(updated == expected)
    try Store.save(updated, to: url)
    #expect(try Store.loadOrRecover(url, now: activityStart) == updated)
}

@Test func tokenBonusStaysSmallAndNeverChargesTickets() throws {
    var s = stateForActivity()
    s.tokenBonus = TokenBonus(at: activityStart)
    let event = TokenEvent(date: activityStart, tokens: Int64.max, source: .codex)
    #expect(s.creditTokenBonus([event], at: activityStart) == 0)
    s.creditActivity([DateInterval(start: activityStart, duration: 3600)])
    #expect(s.currentHouse?.progress == 126_000) // 1 hour + at most 5%.
    #expect(s.tickets == 1 && s.ticketProgress == 0)
    #expect(s.dailyProgress?[.chiikawa]?.extraXP == 6_000)
    s.creditActivity([DateInterval(start: activityStart.addingTimeInterval(3600), duration: 5 * 3600)])
    #expect(s.tokenBonus?.awarded == 12_000)
    #expect(s.currentHouse?.progress == 732_000)
    #expect(s.tickets == 6 && s.ticketProgress == 0)
    let restored = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(s))
    #expect(restored == s)
    #expect(s.creditTokenBonus([], at: activityStart.addingTimeInterval(6 * 3600)) == 0)
}

@Test func tokenBonusFiltersHistoryFutureAndResetsDaily() {
    var s = stateForActivity()
    s.tokenBonus = TokenBonus(at: activityStart)
    s.creditActivity([DateInterval(start: activityStart, duration: 3600)])
    let now = activityStart.addingTimeInterval(3600)
    let events = [TokenEvent(date: activityStart.addingTimeInterval(-1), tokens: 1_000_000, source: .claude),
                  TokenEvent(date: now.addingTimeInterval(1), tokens: 1_000_000, source: .codex),
                  TokenEvent(date: now, tokens: 12_345, source: .claude)]
    #expect(s.creditTokenBonus(events, at: now) == 123)
    #expect(s.tokenBonus?.tokens == 12_345)
    let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
    #expect(s.creditTokenBonus([], at: tomorrow) == 0)
    #expect(s.tokenBonus?.tokens == 0 && s.tokenBonus?.awarded == 0)
}

@Test func bonusAllowanceIsSharedAcrossFriendsAndCompleteHomesCannotFarmTickets() {
    var s = stateForActivity(stage: 13)
    s.tokenBonus = TokenBonus(at: activityStart)
    s.creditActivity([DateInterval(start: activityStart, duration: 3600)])
    let now = activityStart.addingTimeInterval(3600)
    #expect(s.creditTokenBonus([TokenEvent(date: now, tokens: 600_000, source: .codex)], at: now) == 0)
    #expect(s.tickets == 1 && s.ticketProgress == 0)
    s.houses[.hachiware] = House(); s.met.append(.hachiware); s.select(.hachiware)
    #expect(s.creditTokenBonus([], at: now) == 6_000)
    s.houses[.usagi] = House(); s.met.append(.usagi); s.select(.usagi)
    #expect(s.creditTokenBonus([], at: now) == 0)
    #expect(s.currentHouse?.progress == 0)
}
