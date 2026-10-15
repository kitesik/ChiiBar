import AppKit
import ChiiCore
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private var model: AppModel!
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
        popover.contentSize = NSSize(width: 340, height: 560)

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.toolTip = "ChiiBar"
        item.button?.setAccessibilityLabel("ChiiBar")
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        model.$state.map(\.current).removeDuplicates().sink { [weak self] f in
            self?.item.button?.image = MenuIcon.image(for: f)
        }.store(in: &bag)

        model.startLive()
    }

    @objc private func clicked() {
        guard let button = item.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            item.menu = menu
            button.performClick(nil)
            item.menu = nil
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.contentViewController = NSHostingController(rootView: PopoverView(model: model))
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        // Dispose every TimelineView, rather than relying on hidden-view scheduling.
        popover.contentViewController = nil
    }
}

@MainActor
enum MenuIcon {
    /// The current friend's tiny face, or a capsule before the first draw.
    static func image(for friend: FriendID?) -> NSImage? {
        let view = Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            if let friend {
                FriendArt.drawFace(ctx, friend, in: r.insetBy(dx: 0.5, dy: 0.5))
            } else {
                GachaArt.capsule(ctx, at: CGPoint(x: size.width / 2, y: size.height / 2), scale: 0.36, angle: 0.5, open: 0,
                                 color: Ink.rgb(0xFF9FB2))
            }
        }
        .frame(width: 18, height: 18)
        let r = ImageRenderer(content: view)
        r.scale = 2
        guard let cg = r.cgImage else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: 18, height: 18))
    }
}
