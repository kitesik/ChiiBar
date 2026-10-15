import AppKit

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
