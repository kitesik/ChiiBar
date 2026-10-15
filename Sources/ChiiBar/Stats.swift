import ChiiCore
import Foundation

/// `--stats`: a fresh in-memory scan of the real logs. Never reads or writes the app's state.
enum Stats {
    static func run() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let from = cal.date(byAdding: .day, value: -13, to: today)!
        var scan = ScanState()
        let events = UsageScanner.scan(state: &scan, claudeRoot: UsageScanner.defaultClaudeRoot,
                                       codexRoot: UsageScanner.defaultCodexRoot, fastForwardClaudeBefore: from)
        var claude: [String: Int64] = [:], codex: [String: Int64] = [:]
        for e in events where e.date >= from {
            let k = DayKey.of(e.date)
            if e.source == .claude { claude[k, default: 0] += e.tokens } else { codex[k, default: 0] += e.tokens }
        }
        let todayKey = DayKey.of(today)
        func total(_ k: String) -> Int64 { (claude[k] ?? 0) + (codex[k] ?? 0) }
        print("today \(todayKey): \(total(todayKey)) effective tokens (claude \(claude[todayKey] ?? 0), codex \(codex[todayKey] ?? 0))")
        print("")
        print("day           claude        codex        total")
        var active: [Int64] = []
        for i in 0..<14 {
            let k = DayKey.of(cal.date(byAdding: .day, value: -i, to: today)!)
            print(k.padding(toLength: 10, withPad: " ", startingAt: 0)
                  + pad(claude[k] ?? 0) + pad(codex[k] ?? 0) + pad(total(k)))
            if k != todayKey, total(k) > 0 { active.append(total(k)) }
        }
        active.sort()
        let median: Int64 = active.isEmpty ? 0
            : (active.count % 2 == 1 ? active[active.count / 2] : (active[active.count / 2 - 1] + active[active.count / 2]) / 2)
        print("")
        print("active days (last 13, excluding today): \(active.count), median per active day: \(median)")
    }

    private static func pad(_ n: Int64) -> String {
        let s = String(n)
        return String(repeating: " ", count: max(1, 13 - s.count)) + s
    }
}
