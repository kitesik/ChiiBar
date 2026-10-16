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
    private var bag: Set<AnyCancellable> = []

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
        item.button?.toolTip = "신분상승 토큰 치이카와"
        item.button?.setAccessibilityLabel("신분상승 토큰 치이카와")
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        model.$state.map(\.current).removeDuplicates().sink { [weak self] f in
            self?.updateMenuIcon(for: f)
        }.store(in: &bag)

        model.startLive()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.reportMenuStatus() }
        if CommandLine.arguments.contains("--show-onboarding") {
            DispatchQueue.main.async { [weak self] in self?.showOnboarding() }
        } else if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.async { [weak self] in self?.showPopover() }
        }
    }

    @objc private func showOnboarding() {
        popover.performClose(nil)
        if let onboardingWindow { onboardingWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let preview = AppModel(state: GameState(now: Date()), stateURL: nil, isDemo: true)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 710),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "첫 시작 체험 · 실제 진행은 그대로"
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
            let firstStart = NSMenuItem(title: "첫 시작 체험", action: #selector(showOnboarding), keyEquivalent: "")
            firstStart.target = self
            menu.addItem(firstStart)
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
            popover.contentViewController = NSHostingController(rootView: PopoverView(model: model))
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        popover.contentViewController?.view.window?.makeKey()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return true
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
