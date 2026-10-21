import AppKit
import ChiiCore
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private var model: AppModel!
    private var onboardingWindow: NSWindow?
    private var desktopPanel: NSPanel?
    private var desktopTimer: Timer?
    private var desktopTarget: CGPoint?
    private var desktopLastStep = Date()
    private var desktopPauseUntil = Date()
    private var bag: Set<AnyCancellable> = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppIcon.installForRunningApplication()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let url = Store.defaultURL
        let state: GameState
        do { state = try Store.loadOrRecover(url, now: Date()) }
        catch {
            FileHandle.standardError.write(Data("ChiiBar: 저장 파일을 보존할 수 없어 실행을 중단합니다.\n".utf8))
            NSApp.terminate(nil)
            return
        }
        model = AppModel(state: state, stateURL: url)
        model.save()

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 340, height: 710)

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "ChiiBar.MainStatusItem"
        item.behavior = []
        item.isVisible = true
        item.button?.toolTip = "치이카와 키우기"
        item.button?.setAccessibilityLabel("치이카와 키우기")
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        model.$state.map(\.current).removeDuplicates().sink { [weak self] f in
            self?.updateMenuIcon(for: f)
        }.store(in: &bag)

        model.startLive()
        if UserDefaults.standard.bool(forKey: "desktopCompanionVisible") || CommandLine.arguments.contains("--desktop") {
            showDesktop()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.reportMenuStatus() }
        if CommandLine.arguments.contains("--show-draw-demo") {
            DispatchQueue.main.async { [weak self] in self?.showDrawDemo() }
        } else if CommandLine.arguments.contains("--show-onboarding") {
            DispatchQueue.main.async { [weak self] in self?.showOnboarding() }
        } else if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.async { [weak self] in self?.showPopover() }
        }
    }

    @objc private func showOnboarding() {
        showDemo(AppModel(state: GameState(now: Date()), stateURL: nil, isDemo: true), title: "첫 시작 체험 · 실제 진행은 그대로")
    }

    @objc private func showDrawDemo() {
        showDemo(AppModel.drawDemo(), title: "뽑기 체험 · 실제 기록은 그대로")
    }

    private func showDemo(_ preview: AppModel, title: String) {
        popover.performClose(nil)
        if let onboardingWindow { onboardingWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 710),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: PopoverView(model: preview, closeDemo: { [weak self, weak window] in
            window?.close()
            self?.onboardingWindow = nil
        }))
        onboardingWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func reportMenuStatus() {
        guard CommandLine.arguments.contains("--menu-diagnostics"), let button = item?.button else { return }
        let frame = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero
        let intersectsScreen = NSScreen.screens.contains { $0.frame.intersects(frame) }
        let report: [String: Any] = ["visible": item.isVisible, "hasImage": button.image != nil,
                                   "intersectsScreen": intersectsScreen, "frame": NSStringFromRect(frame),
                                   "popoverShown": popover.isShown]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]) {
            FileHandle.standardError.write(data + Data("\n".utf8))
        }
    }

    private func updateMenuIcon(for friend: FriendID?) {
        guard let button = item?.button else { return }
        button.image = MenuIcon.image(for: friend)
        // A missing resource must still leave an obvious, clickable menu item.
        button.title = button.image == nil ? "집" : ""
        item.isVisible = true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func clicked() {
        guard let button = item.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let desktop = NSMenuItem(title: "산책가자!", action: #selector(showDesktop), keyEquivalent: "")
            desktop.target = self
            menu.addItem(desktop)
            if desktopPanel != nil {
                let hide = NSMenuItem(title: "산책 끝내기", action: #selector(hideDesktop), keyEquivalent: "")
                hide.target = self
                menu.addItem(hide)
            }
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            item.menu = menu
            button.performClick(nil)
            item.menu = nil
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        item?.isVisible = true
        updateMenuIcon(for: model.state.current)
        guard let button = item?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        if !popover.isShown {
            popover.contentViewController = NSHostingController(rootView: PopoverView(model: model, showDesktop: { [weak self] in self?.showDesktop() }))
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        popover.contentViewController?.view.window?.makeKey()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return true
    }

    @objc private func showDesktop() {
        popover.performClose(nil)
        if let desktopPanel { desktopPanel.orderFrontRegardless(); return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 224),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentViewController = NSHostingController(rootView: DesktopCompanionView(model: model,
            openApp: { [weak self] in self?.showPopover() }, hide: { [weak self] in self?.hideDesktop() }))
        if let saved = UserDefaults.standard.array(forKey: "desktopPetOrigin") as? [Double], saved.count == 2 {
            panel.setFrameOrigin(CGPoint(x: saved[0], y: saved[1]))
        } else if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 230, y: screen.visibleFrame.minY + 30))
        }
        if !NSScreen.screens.contains(where: { $0.visibleFrame.contains(panel.frame) }) { panel.center() }
        desktopPanel = panel
        desktopLastStep = Date()
        desktopTarget = nil
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stepDesktop() }
        }
        desktopTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        UserDefaults.standard.set(true, forKey: "desktopCompanionVisible")
        panel.orderFrontRegardless()
    }

    @objc private func hideDesktop() {
        saveDesktopPosition()
        desktopTimer?.invalidate()
        desktopTimer = nil
        desktopPanel?.close()
        desktopPanel = nil
        UserDefaults.standard.set(false, forKey: "desktopCompanionVisible")
    }

    private func saveDesktopPosition() {
        guard let panel = desktopPanel else { return }
        UserDefaults.standard.set([panel.frame.minX, panel.frame.minY], forKey: "desktopPetOrigin")
    }

    private func stepDesktop() {
        guard let panel = desktopPanel, let screen = panel.screen ?? NSScreen.main else { return }
        let date = Date(), elapsed = date.timeIntervalSince(desktopLastStep)
        desktopLastStep = date
        // Transparent space passes clicks through to the app underneath.
        let hit = CGRect(x: panel.frame.minX + 20, y: panel.frame.minY + 24, width: 160, height: 150)
        let hovered = hit.contains(NSEvent.mouseLocation)
        panel.ignoresMouseEvents = !hovered
        if hovered || NSEvent.pressedMouseButtons != 0 {
            desktopPauseUntil = date.addingTimeInterval(1.5)
            desktopTarget = nil
            return
        }
        let visible = screen.visibleFrame
        let bounds = CGRect(x: visible.minX, y: visible.minY,
                            width: max(0, visible.width - panel.frame.width), height: max(0, visible.height - panel.frame.height))
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrameOrigin(DesktopRoam.step(from: panel.frame.origin, toward: panel.frame.origin, in: bounds, elapsed: 0, reduced: true))
            return
        }
        let responding = model.pokeStart.map { (0..<2.6).contains(date.timeIntervalSince($0)) } == true
        guard let friend = model.state.current,
              DesktopBehavior.at(date.timeIntervalSinceReferenceDate, friend: friend, responding: responding).walks,
              date >= desktopPauseUntil else { return }
        if desktopTarget == nil {
            desktopTarget = CGPoint(x: Double.random(in: bounds.minX...bounds.maxX), y: Double.random(in: bounds.minY...bounds.maxY))
        }
        guard let target = desktopTarget else { return }
        let next = DesktopRoam.step(from: panel.frame.origin, toward: target, in: bounds, elapsed: elapsed)
        panel.setFrameOrigin(next)
        if hypot(next.x - target.x, next.y - target.y) < 1 {
            desktopTarget = nil
            desktopPauseUntil = date.addingTimeInterval(3)
            saveDesktopPosition()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stopLive()
        saveDesktopPosition()
        desktopTimer?.invalidate()
    }

    func popoverDidClose(_ notification: Notification) {
        // Dispose every TimelineView, rather than relying on hidden-view scheduling.
        popover.contentViewController = nil
        reportMenuStatus()
    }
}

@MainActor
enum MenuIcon {
    /// The current friend's tiny face, or a capsule before the first draw.
    static func image(for friend: FriendID?) -> NSImage? {
        if let friend, let image = SpriteArt.menuImage(for: friend) { return image }
        return NSImage(systemSymbolName: "house.fill", accessibilityDescription: "치이바 열기")
    }
}
