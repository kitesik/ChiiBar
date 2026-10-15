import Foundation

// Reads Claude Code and Codex JSONL logs incrementally. Only numbers leave this file:
// no prompt or response text is ever stored, printed or returned.

public enum Source: String, Codable, Sendable { case claude, codex }

public struct TokenEvent: Sendable, Equatable {
    public var date: Date
    public var tokens: Int64
    public var source: Source
    public init(date: Date, tokens: Int64, source: Source) { self.date = date; self.tokens = tokens; self.source = source }
}

public struct FileCheckpoint: Codable, Sendable, Equatable {
    public var offset: UInt64 = 0
    public var inode: UInt64 = 0
    /// Codex only: last seen total_token_usage as [input, cached_input, output].
    public var codexTotals: [Int64]?
}

public struct ScanState: Codable, Sendable, Equatable {
    public var files: [String: FileCheckpoint] = [:]
    /// Hashes of recent Claude message.id + requestId keys, oldest first, bounded.
    public var recentKeys: [UInt64] = []
    public static let maxKeys = 20_000
    public init() {}
}

public enum Effective {
    public static func claude(input: Int64, output: Int64, cacheCreation: Int64, cacheRead: Int64) -> Int64 {
        max(0, input) + max(0, output) + max(0, cacheCreation) + max(0, cacheRead) / 10
    }

    /// Delta of Codex cumulative totals [input, cached_input, output]. Codex input_tokens
    /// includes cached tokens, so uncached = input - cached. A decrease means the counter reset.
    public static func codexDelta(previous: [Int64]?, current: [Int64]) -> Int64 {
        var base: [Int64] = [0, 0, 0]
        if let previous, previous.count == 3, zip(current, previous).allSatisfy({ $0 >= $1 }) {
            base = previous
        }
        let dIn = current[0] - base[0], dCached = current[1] - base[1], dOut = current[2] - base[2]
        return max(0, dIn - dCached) + max(0, dCached) / 10 + max(0, dOut)
    }
}

public enum UsageScanner {
    public static var defaultClaudeRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
    }
    public static var defaultCodexRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
    }

    public static func jsonlFiles(under root: URL) -> [URL] {
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey],
                                                     options: [.skipsPackageDescendants]) else { return [] }
        var out: [URL] = []
        for case let url as URL in e where url.pathExtension == "jsonl" { out.append(url) }
        return out.sorted { $0.path < $1.path }
    }

    /// Scans every JSONL file under the roots from its saved offset.
    /// `fastForwardClaudeBefore`: a Claude file not yet in `state` whose mtime is older than this
    /// date is skipped to its end without reading (it cannot hold newer events).
    public static func scan(state: inout ScanState, claudeRoot: URL?, codexRoot: URL?,
                            fastForwardClaudeBefore: Date? = nil) -> [TokenEvent] {
        var keys = Set(state.recentKeys)
        var order = state.recentKeys
        var events: [TokenEvent] = []
        let iso = TimestampParser()
        for (root, source) in [(claudeRoot, Source.claude), (codexRoot, Source.codex)] {
            guard let root else { continue }
            for url in jsonlFiles(under: root) {
                var cp = state.files[url.path] ?? FileCheckpoint()
                let isNew = state.files[url.path] == nil
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { continue }
                let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
                let inode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
                if size < cp.offset || (cp.inode != 0 && inode != cp.inode) {
                    cp = FileCheckpoint()
                }
                cp.inode = inode
                if isNew, source == .claude, let cutoff = fastForwardClaudeBefore,
                   let mtime = attrs[.modificationDate] as? Date, mtime < cutoff {
                    cp.offset = size
                    state.files[url.path] = cp
                    continue
                }
                if size > cp.offset {
                    var totals = cp.codexTotals
                    readLines(url: url, offset: &cp.offset) { line in
                        switch source {
                        case .claude:
                            if let ev = parseClaude(line, iso: iso, keys: &keys, order: &order) { events.append(ev) }
                        case .codex:
                            if let ev = parseCodex(line, iso: iso, totals: &totals) { events.append(ev) }
                        }
                    }
                    cp.codexTotals = totals
                }
                state.files[url.path] = cp
            }
        }
        if order.count > ScanState.maxKeys { order.removeFirst(order.count - ScanState.maxKeys) }
        state.recentKeys = order
        return events
    }

    /// Calls `body` with each complete line after the checkpoint offset; advances the offset
    /// past complete lines only, so a half-written last line is read again next time.
    static func readLines(url: URL, offset: inout UInt64, body: (Data) -> Void) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        guard (try? handle.seek(toOffset: offset)) != nil else { return }
        var carry = Data()
        while let chunk = try? handle.read(upToCount: 4 << 20), !chunk.isEmpty {
            carry.append(chunk)
            var consumed = 0
            carry.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                guard let base = raw.baseAddress else { return }
                let count = raw.count
                var start = 0
                while start < count, let nl = memchr(base + start, 0x0A, count - start) {
                    let end = base.distance(to: nl)
                    if end > start { body(Data(bytes: base + start, count: end - start)) }
                    start = end + 1
                }
                consumed = start
            }
            if consumed > 0 {
                offset += UInt64(consumed)
                carry.removeSubrange(0..<consumed)
            }
        }
    }

    static func contains(_ line: Data, _ needle: StaticString) -> Bool {
        line.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return false }
            return memmem(base, raw.count, needle.utf8Start, needle.utf8CodeUnitCount) != nil
        }
    }

    static func parseClaude(_ line: Data, iso: TimestampParser, keys: inout Set<UInt64>, order: inout [UInt64]) -> TokenEvent? {
        guard contains(line, "\"usage\""), let r = try? JSONDecoder().decode(ClaudeRecord.self, from: line),
              r.type == "assistant", let u = r.message?.usage, let date = iso.parse(r.timestamp) else { return nil }
        if r.message?.id != nil || r.requestId != nil {
            let key = fnv1a("\(r.message?.id ?? "")|\(r.requestId ?? "")")
            guard keys.insert(key).inserted else { return nil }
            order.append(key)
        }
        let t = Effective.claude(input: u.input, output: u.output, cacheCreation: u.cacheCreation, cacheRead: u.cacheRead)
        return t > 0 ? TokenEvent(date: date, tokens: t, source: .claude) : nil
    }

    static func parseCodex(_ line: Data, iso: TimestampParser, totals: inout [Int64]?) -> TokenEvent? {
        guard contains(line, "token_count"), let r = try? JSONDecoder().decode(CodexRecord.self, from: line),
              r.type == "event_msg", r.payload?.type == "token_count",
              let total = r.payload?.info?.totalTokenUsage else { return nil }
        let current = [total.input, total.cached, total.output]
        let t = Effective.codexDelta(previous: totals, current: current)
        totals = current
        guard t > 0, let date = iso.parse(r.timestamp) else { return nil }
        return TokenEvent(date: date, tokens: t, source: .codex)
    }

    static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100_0000_01b3 }
        return h
    }
}

final class TimestampParser: @unchecked Sendable {
    private let frac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private let plain = ISO8601DateFormatter()
    func parse(_ s: String?) -> Date? {
        guard let s else { return nil }
        return frac.date(from: s) ?? plain.date(from: s)
    }
}

/// Decodes an integer that may arrive as a number, a float or a string; missing = 0.
struct Num: Decodable {
    let v: Int64
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int64.self) { v = i }
        else if let d = try? c.decode(Double.self), d.isFinite,
                d >= Double(Int64.min), d < Double(Int64.max) { v = Int64(d) }
        else if let s = try? c.decode(String.self) { v = Int64(s) ?? 0 }
        else { v = 0 }
    }
}

private struct ClaudeRecord: Decodable {
    let type: String?
    let requestId: String?
    let timestamp: String?
    let message: Message?
    struct Message: Decodable { let id: String?; let usage: Usage? }
    struct Usage: Decodable {
        let input, output, cacheCreation, cacheRead: Int64
        enum K: String, CodingKey {
            case input = "input_tokens", output = "output_tokens"
            case cacheCreation = "cache_creation_input_tokens", cacheRead = "cache_read_input_tokens"
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: K.self)
            input = (try? c.decodeIfPresent(Num.self, forKey: .input))??.v ?? 0
            output = (try? c.decodeIfPresent(Num.self, forKey: .output))??.v ?? 0
            cacheCreation = (try? c.decodeIfPresent(Num.self, forKey: .cacheCreation))??.v ?? 0
            cacheRead = (try? c.decodeIfPresent(Num.self, forKey: .cacheRead))??.v ?? 0
        }
    }
}

private struct CodexRecord: Decodable {
    let type: String?
    let timestamp: String?
    let payload: Payload?
    struct Payload: Decodable { let type: String?; let info: Info? }
    struct Info: Decodable {
        let totalTokenUsage: Usage?
        enum CodingKeys: String, CodingKey { case totalTokenUsage = "total_token_usage" }
    }
    struct Usage: Decodable {
        let input, cached, output: Int64
        enum K: String, CodingKey { case input = "input_tokens", cached = "cached_input_tokens", output = "output_tokens" }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: K.self)
            input = (try? c.decodeIfPresent(Num.self, forKey: .input))??.v ?? 0
            cached = (try? c.decodeIfPresent(Num.self, forKey: .cached))??.v ?? 0
            output = (try? c.decodeIfPresent(Num.self, forKey: .output))??.v ?? 0
        }
    }
}

public enum DayKey {
    public static func of(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
