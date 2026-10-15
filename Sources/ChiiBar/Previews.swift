import AppKit
import ChiiCore
import ImageIO
import SwiftUI

/// `--render-previews DIR`: PNGs at 2x from fixture state only. Never touches the user's state.
@MainActor
enum Previews {
    static let now = ISO8601DateFormatter().date(from: "2026-10-15T03:00:00Z")!
    static let t0 = 1001.5

    static func render(to dir: String) {
        let out = URL(fileURLWithPath: dir, isDirectory: true)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        var files: [String] = []
        func save<V: View>(_ name: String, _ size: CGSize, _ view: V) {
            let r = ImageRenderer(content: view.frame(width: size.width, height: size.height))
            r.scale = ProcessInfo.processInfo.environment["CHIIBAR_PREVIEW_SCALE"].flatMap(Double.init) ?? 2
            guard let cg = r.cgImage, let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
                FileHandle.standardError.write("failed: \(name)\n".data(using: .utf8)!)
                exit(1)
            }
            try! png.write(to: out.appendingPathComponent(name + ".png"))
            files.append(name + ".png")
        }
        func scene(_ p: SceneParams) -> some View {
            Canvas { ctx, size in HouseArt.draw(ctx, canvas: size, p) }
        }
        let sz = HouseArt.size

        for stage in 1...12 {
            save(String(format: "stage_%02d", stage), sz,
                 scene(SceneParams(friend: .hachiware, stage: stage, activity: .tea, t: t0)))
        }
        save("ending", sz, scene(SceneParams(friend: .hachiware, stage: 12, activity: .tea, t: t0,
                                             endingElapsed: 1.6, bubble: "행복해…")))
        for f in FriendID.allCases {
            save("character_\(f.rawValue)", sz, scene(SceneParams(friend: f, stage: 12, activity: .tea, t: t0)))
        }
        save("character_sheet", CGSize(width: CGFloat(FriendID.allCases.count) * 100, height: 150), CharacterSheet())
        save("menu_faces", CGSize(width: CGFloat(FriendID.allCases.count) * 30, height: 30), MenuFaceSheet())
        renderHero(to: out)
        renderMotion(to: out)
        renderConstruction(to: out)
        renderDiscovery(to: out)
        renderCarryover(to: out)

        let activities: [(String, Activity, Int)] = [
            ("weeding", .weeding, 3), ("cooking", .cooking, 12), ("sweeping", .sweeping, 12), ("reading", .reading, 12),
            ("rolling", .rolling, 12), ("snack", .snack, 12), ("tea", .tea, 12), ("window", .window, 12),
            ("nap_futon", .napFuton, 12), ("nap_grass", .napGround, 1),
        ]
        for (name, a, stage) in activities {
            save("activity_\(name)", sz, scene(SceneParams(friend: .hachiware, stage: stage, activity: a, t: t0 + 0.3)))
        }
        save("activity_snack_pudding", sz,
             scene(SceneParams(friend: .usagi, stage: 12, activity: .snack, t: t0, snackIsPudding: true)))
        save("poke", sz, scene(SceneParams(friend: .chiikawa, stage: 6, activity: .tea, t: t0, pokeElapsed: 0.5, bubble: "에엣!")))
        save("reveal", sz, scene(SceneParams(friend: .momonga, stage: 7, activity: .tea, t: t0, reveal: (7, 0.35), bubble: "뀨우~")))

        let newDraw = DrawResult(friend: .usagi, outcome: .newFriend)
        for (i, t) in [0.45, 1.9, 2.75, 3.6].enumerated() {
            save("gacha_\(i + 1)", GachaArt.size, GachaCanvas(t: t, result: newDraw))
        }
        save("gacha_again", GachaArt.size, GachaCanvas(t: 3.6, result: DrawResult(friend: .shisa, outcome: .gift(stage: 5))))

        let popSize = CGSize(width: 340, height: 560)
        for (name, ago) in [("busy", 60.0), ("idle", 600.0), ("sleeping", 3600.0)] {
            save("popover_\(name)", popSize, PopoverView(model: fixtureModel(lastTokenAgo: ago)))
        }
        let ready = fixtureModel(lastTokenAgo: 60)
        ready.state.houses[.hachiware]!.progress = HousePlan.cost(ofStage: 8) + 12345
        save("popover_build_ready", popSize, PopoverView(model: ready))
        let upgraded = fixtureModel(lastTokenAgo: 60)
        upgraded.state.houses[.hachiware] = House(stage: 10)
        upgraded.upgradeNotice = (UpgradeCopy.completion[10]!, now)
        save("popover_upgrade_complete", popSize, PopoverView(model: upgraded))
        var growing = GameState(now: now)
        growing.current = .chiikawa
        growing.met = [.chiikawa]
        growing.houses = [.chiikawa: House(stage: 3, progress: 1_000_000)]
        growing.observeProgress(at: now.addingTimeInterval(-1800))
        growing.houses[.chiikawa]!.progress = 3_000_000
        growing.dailyProgress?[.chiikawa]?.earned = 2_000_000
        save("popover_today_progress", popSize, PopoverView(model: AppModel(state: growing, stateURL: nil, fixedNow: now)))
        growing.houses[.chiikawa]!.progress = HousePlan.cost(ofStage: 4) + HousePlan.cost(ofStage: 5) + 2_000_000
        growing.build(at: now)
        growing.build(at: now)
        growing.dailyProgress?[.chiikawa]?.earned = 11_500_000
        save("popover_today_achievement", popSize, PopoverView(model: AppModel(state: growing, stateURL: nil, fixedNow: now)))
        growing.dailyProgress?[.chiikawa]?.earned = 50_400_000
        save("popover_today_goal_complete", popSize, PopoverView(model: AppModel(state: growing, stateURL: nil, fixedNow: now)))
        for (name, elapsed) in [("start", 0.0), ("middle", 1.0), ("end", 2.0)] {
            save("carryover_" + name, CGSize(width: 320, height: 110),
                 StageProgress(model: carryoverModel(elapsed: elapsed)).padding(8).background(Theme.background))
        }
        let collection = fixtureModel(lastTokenAgo: 60)
        collection.state.houses = [.chiikawa: House(stage: 6)]
        collection.state.met = [.chiikawa]
        collection.state.current = .chiikawa
        collection.tab = .friends
        save("popover_friends", popSize, PopoverView(model: collection))
        let full = fixtureModel(lastTokenAgo: 60)
        full.state.houses = Dictionary(uniqueKeysWithValues: FriendID.allCases.map { ($0, House(stage: 12)) })
        full.tab = .friends
        save("popover_friends_all", popSize, PopoverView(model: full))
        save("popover_first_draw", popSize, PopoverView(model: AppModel(state: GameState(now: now), stateURL: nil, fixedNow: now)))
        print(files.joined(separator: "\n"))
    }

    static func carryoverModel(elapsed: Double) -> AppModel {
        let template = fixtureModel(lastTokenAgo: 60)
        template.state.houses[.hachiware] = House(stage: 7, progress: 11_000_000)
        let model = AppModel(state: template.state, stateURL: nil, fixedNow: now.addingTimeInterval(elapsed))
        model.carryover = UpgradeCarryover(friend: .hachiware, stage: 7, amount: 11_000_000,
                                          startsAt: now.addingTimeInterval(0.6))
        return model
    }

    static func renderCarryover(to out: URL) {
        let url = out.appendingPathComponent("carryover_refill.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 48, nil) else { return }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<48 {
            let view = StageProgress(model: carryoverModel(elapsed: Double(frame) / 12))
                .padding(8).frame(width: 320, height: 110).background(Theme.background)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.cgImage else { fatalError("carryover frame failed") }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 12]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }

    /// README mascot, rendered from the same original sprite as the app.
    static func renderHero(to out: URL) {
        let url = out.appendingPathComponent("chiikawa.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 48, nil) else { return }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<48 {
            let t = Double(frame) / 24
            let envelope = pow(sin(.pi * t / 2), 2)
            let view = Canvas { ctx, _ in
                var pose = Pose()
                pose.tilt = sin(t * .pi * 16) * 0.035 * envelope
                pose.squish = 1 + sin(t * .pi * 8) * 0.025 * envelope
                let base = CGPoint(x: 120 + sin(t * .pi * 16) * 1.5 * envelope,
                                   y: 170 - max(0, sin(t * .pi * 4)) * 3 * envelope)
                FriendArt.draw(ctx, .chiikawa, base: base, size: 72, pose: pose)
            }.frame(width: 240, height: 200).background(.white)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.cgImage else { fatalError("hero frame failed") }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 24]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }

    static func renderMotion(to out: URL) {
        let url = out.appendingPathComponent("character_motion.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 48, nil) else { return }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<48 {
            let renderer = ImageRenderer(content: MotionSheet(t: Double(frame) / 12).frame(width: CGFloat(FriendID.allCases.count) * 100, height: 170))
            renderer.scale = 1
            guard let image = renderer.cgImage else { fatalError("motion frame failed") }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 12]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }

    static func renderConstruction(to out: URL) {
        let url = out.appendingPathComponent("construction.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 48, nil) else { return }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<48 {
            let elapsed = Double(frame) / 12
            let p = SceneParams(friend: .hachiware, stage: 4, activity: .tea, t: t0 + elapsed,
                                reveal: (4, elapsed))
            let view = Canvas { ctx, size in HouseArt.draw(ctx, canvas: size, p) }
                .frame(width: 320, height: 210)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.cgImage else { fatalError("construction frame failed") }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 12]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }

    static func renderDiscovery(to out: URL) {
        let url = out.appendingPathComponent("friend_discovery.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 72, nil) else { return }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<72 {
            let renderer = ImageRenderer(content: GachaCanvas(t: Double(frame) / 12,
                result: DrawResult(friend: .usagi, outcome: .newFriend)).frame(width: 320, height: 300))
            renderer.scale = 2
            guard let image = renderer.cgImage else { fatalError("discovery frame failed") }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 12]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }

    static func fixtureModel(lastTokenAgo: Double) -> AppModel {
        var s = GameState(now: now)
        s.tickets = 2
        s.houses = [.hachiware: House(stage: 7, progress: HousePlan.cost(ofStage: 8) * 2 / 5),
                    .chiikawa: House(stage: 12), .momonga: House(stage: 3)]
        s.met = [.chiikawa, .hachiware, .momonga]
        s.current = .hachiware
        s.dayTotals[DayKey.of(now)] = 1_234_567
        s.lastTokenAt = now.addingTimeInterval(-lastTokenAgo)
        return AppModel(state: s, stateURL: nil, fixedNow: now)
    }
}

struct MenuFaceSheet: View {
    var body: some View {
        Canvas { ctx, _ in
            for (i, f) in FriendID.allCases.enumerated() {
                FriendArt.drawFace(ctx, f, in: CGRect(x: CGFloat(i) * 30 + 6, y: 6, width: 18, height: 18))
            }
        }.background(.white)
    }
}

struct MotionSheet: View {
    let t: Double
    var body: some View {
        Canvas { ctx, _ in
            for (i, f) in FriendID.allCases.enumerated() {
                var p = ActivityArt.Placement(base: CGPoint(x: 50 + CGFloat(i) * 100, y: 132), size: 58)
                var pose = Pose()
                ActivityArt.personality(f, activity: .window, t: t + 1000, placement: &p, pose: &pose)
                FriendArt.draw(ctx, f, base: p.base, size: p.size, pose: pose)
                ctx.draw(Text(f.name).font(.system(size: 12)).foregroundColor(Theme.text), at: CGPoint(x: 50 + CGFloat(i) * 100, y: 153))
            }
        }.background(.white)
    }
}

struct GachaCanvas: View {
    let t: Double
    let result: DrawResult
    var body: some View {
        ZStack {
            Theme.background
            Canvas { ctx, size in GachaArt.draw(ctx, canvas: size, t: t, idleTime: 0, result: result) }
        }
    }
}

struct CharacterSheet: View {
    var body: some View {
        Canvas { ctx, size in
            for (i, f) in FriendID.allCases.enumerated() {
                FriendArt.draw(ctx, f, base: CGPoint(x: 50 + CGFloat(i) * 100, y: 140), size: 66, pose: Pose())
            }
        }
        .background(Color.white)
    }
}
