import AppKit
import ChiiCore
import CoreGraphics

/// Queries elapsed times only. Never installs a key logger or reads event contents.
@MainActor
final class InputActivityMonitor {
    private var clock = WorkClock(start: Date())
    private var timer: Timer?
    private var paused: Set<String> = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private let receive: ([DateInterval], Date?, Bool, Bool) -> Void
    init(receive: @escaping ([DateInterval], Date?, Bool, Bool) -> Void) { self.receive = receive }

    static func latestInput(at now: Date) -> Date? {
        let types: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        let ages = types.map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }
            .filter { $0.isFinite && $0 >= 0 && $0 < 100_000_000 }
        guard let age = ages.min() else { return nil }
        return now.addingTimeInterval(-age)
    }

    func start() {
        clock.reset(at: Date())
        let workspace = NSWorkspace.shared.notificationCenter
        for (notification, reason, suspend) in [
            (NSWorkspace.willSleepNotification, "sleep", true), (NSWorkspace.didWakeNotification, "sleep", false),
            (NSWorkspace.screensDidSleepNotification, "display", true), (NSWorkspace.screensDidWakeNotification, "display", false),
            (NSWorkspace.sessionDidResignActiveNotification, "session", true), (NSWorkspace.sessionDidBecomeActiveNotification, "session", false)
        ] {
            workspaceObservers.append(workspace.addObserver(forName: notification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.setPaused(reason, suspend) }
            })
        }
        let distributed = DistributedNotificationCenter.default()
        for (name, locked) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            distributedObservers.append(distributed.addObserver(forName: NSNotification.Name(name), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.setPaused("lock", locked) }
            })
        }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.sample() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        sample()
    }

    private func setPaused(_ reason: String, _ value: Bool) {
        if value { sample(); paused.insert(reason) } else { paused.remove(reason) }
        clock.reset(at: Date())
        receive([], nil, !paused.isEmpty, true)
    }

    func sample() {
        let now = Date()
        guard paused.isEmpty else { clock.reset(at: now); receive([], nil, true, true); return }
        let latest = Self.latestInput(at: now)
        let intervals = clock.tick(at: now, latestInput: latest)
        let keyboardAge = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
        let readable = latest != nil && keyboardAge.isFinite && keyboardAge >= 0 && keyboardAge < 100_000_000
        receive(intervals, clock.lastInputAt, false, readable)
    }

    func stop() {
        sample(); timer?.invalidate(); timer = nil
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        distributedObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        workspaceObservers.removeAll(); distributedObservers.removeAll()
    }
}
