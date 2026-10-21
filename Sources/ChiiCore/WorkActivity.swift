import Foundation

/// Daily totals only: never keys, typed text, mouse positions or event logs.
public struct WorkActivity: Codable, Sendable, Equatable {
    public static let grace: TimeInterval = 300
    public static let energyPerMinute: Int64 = 2_000
    public static let dailyGoalSeconds: TimeInterval = 4 * 3600
    public var secondsByDay: [String: TimeInterval] = [:]
    public init() {}
    public func seconds(on date: Date) -> TimeInterval { secondsByDay[DayKey.of(date)] ?? 0 }
    public static func energy(for seconds: TimeInterval) -> Int64 {
        Int64((max(0, seconds) * Double(energyPerMinute) / 60).rounded(.down))
    }
}

/// Unions five-minute windows. Restart, suspension and unobserved gaps never earn offline credit.
public struct WorkClock {
    public private(set) var lastInputAt: Date?
    private var cursor: Date
    private var eligibleSince: Date
    public init(start: Date) { cursor = start; eligibleSince = start }
    public mutating func reset(at date: Date) { cursor = date; eligibleSince = date; lastInputAt = nil }
    public mutating func tick(at date: Date, latestInput: Date?) -> [DateInterval] {
        let start = cursor
        cursor = date
        guard date >= start, date.timeIntervalSince(start) <= 30 else { reset(at: date); return [] }
        var windows: [DateInterval] = []
        func appendWindow(_ input: Date) {
            let begin = max(start, input), end = min(date, input.addingTimeInterval(WorkActivity.grace))
            if end > begin { windows.append(DateInterval(start: begin, end: end)) }
        }
        if let lastInputAt { appendWindow(lastInputAt) }
        if let input = latestInput, input >= eligibleSince, input <= date,
           lastInputAt.map({ input > $0 }) ?? true {
            appendWindow(input); lastInputAt = input
        }
        guard windows.count == 2, windows[0].end >= windows[1].start else { return windows }
        return [DateInterval(start: windows[0].start, end: max(windows[0].end, windows[1].end))]
    }
}

public enum WorkTimeFormat {
    public static func duration(_ seconds: TimeInterval) -> String {
        let n = Int(max(0, seconds)), minutes = n / 60
        if minutes == 0 { return "\(n)초" }
        if minutes < 60 { return "\(minutes)분" }
        return minutes % 60 == 0 ? "\(minutes / 60)시간" : "\(minutes / 60)시간 \(minutes % 60)분"
    }
    public static func energy(_ value: Int64) -> String {
        duration(Double(value) * 60 / Double(WorkActivity.energyPerMinute))
    }
}
