import AppKit
import ChiiCore

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--export-sprites") {
    guard i + 1 < args.count else {
        FileHandle.standardError.write(Data("usage: ChiiBar --export-sprites DIR\n".utf8))
        exit(2)
    }
    try MainActor.assumeIsolated {
        _ = NSApplication.shared
        try OriginalSprites.export(to: args[i + 1])
    }
    exit(0)
}
if args.contains("--check-menu-icons") {
    MainActor.assumeIsolated {
        _ = NSApplication.shared
        for friend in FriendID.allCases {
            guard let image = MenuIcon.image(for: friend),
                  let data = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: data) else { exit(1) }
            var visible = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 { visible += 1 }
                }
            }
            guard visible > 10 else { exit(1) }
            print("\(friend.rawValue): visible pixels \(visible)")
        }
    }
    exit(0)
}
if args.contains("--stats") {
    Stats.run()
    exit(0)
}
if let i = args.firstIndex(of: "--render-previews") {
    guard i + 1 < args.count else {
        FileHandle.standardError.write("usage: ChiiBar --render-previews DIR\n".data(using: .utf8)!)
        exit(2)
    }
    MainActor.assumeIsolated {
        _ = NSApplication.shared
        Previews.render(to: args[i + 1])
    }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
