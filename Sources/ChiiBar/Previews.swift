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

        if ProcessInfo.processInfo.environment["CHIIBAR_WEATHER_ONLY"] == "1" {
            for weather in [HomeWeather.rain, .snow] {
                for stage in [1, 3, 9] {
                    for friend in [FriendID.chiikawa, .usagi, .momonga] {
                        var p = SceneParams(friend: friend, stage: stage, activity: .tea, t: t0)
                        p.weatherOverride = weather
                        save("\(weather.rawValue)-\(stage)-\(friend.rawValue)", sz, scene(p))
                    }
                }
            }
            return
        }

        if ProcessInfo.processInfo.environment["CHIIBAR_LAYOUT_ONLY"] == "1" {
            for stage in 1...13 {
                save("stage_\(stage)", sz, scene(SceneParams(friend: .hachiware, stage: stage, activity: .tea, t: t0)))
            }
            save("menu-faces", CGSize(width: 270, height: 40), HStack(spacing: 8) {
                ForEach(FriendID.allCases, id: \.self) { friend in
                    if let icon = SpriteArt.menuImage(for: friend) { Image(nsImage: icon) }
                }
            }.background(Color.gray.opacity(0.15)))
            return
        }

        if ProcessInfo.processInfo.environment["CHIIBAR_NUMBER_SHEET"] == "1" {
            save("number-stamps", CGSize(width: 720, height: 720), VStack(spacing: 0) {
                ForEach(0..<6) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<6) { column in
                            let count = row * 6 + column
                            VStack(spacing: 2) {
                                UpgradeBadge(count: count)
                                Text("\(count)").font(.system(size: 9)).foregroundStyle(.gray)
                            }.frame(width: 120, height: 120)
                        }
                    }
                }
            }.background(Theme.background))
            return
        }

        if ProcessInfo.processInfo.environment["CHIIBAR_STAMP_ONLY"] == "1" {
            for (count, earned) in [(0, Int64(0)), (7, 13_193_379), (77, 243_000), (7777, Int64.max)] {
                save("stamp_\(count)", CGSize(width: 320, height: 154), HStack(spacing: 14) {
                    UpgradeBadge(count: count).frame(width: 112)
                    DailyGoalCard(earned: earned)
                }.padding(12).background(Theme.background))
            }
            return
        }

        if ProcessInfo.processInfo.environment["CHIIBAR_PRESENTATION_ONLY"] == "1" {
            let model = fixtureModel(lastTokenAgo: 60)
            model.state.current = .kurimanju
            model.state.houses[.kurimanju] = House(stage: 1, progress: 5000)
            save("home", CGSize(width: 340, height: 640), PopoverView(model: model))
            save("odds", CGSize(width: 316, height: 510), DrawOddsCard(firstDraw: false).background(Theme.background))
            model.state.houses[.kurimanju] = House(stage: 1, progress: 20000)
            save("ready", CGSize(width: 340, height: 640), PopoverView(model: model))
            for elapsed in [1.0, 3.6, 5.2] {
                let session = GachaSession(start: now.addingTimeInterval(-elapsed), result: DrawResult(friend: .kurimanju, outcome: .newFriend))
                model.gacha = session
                save("draw_\(elapsed)", CGSize(width: 340, height: 640), PopoverView(model: model))
            }
            for (index, friend) in FriendID.allCases.enumerated() {
                model.state.houses[friend] = House(stage: min(13, index + 5))
            }
            model.state.houses.removeValue(forKey: .anoko)
            save("collection", CGSize(width: 316, height: 380), VStack(spacing: 10) {
                ForEach(0..<3) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<3) { column in
                            CollectionCard(model: model, friend: DrawOdds.displayOrder[row * 3 + column])
                        }
                    }
                }
            }.padding(4).background(Theme.background))
            return
        }

        if ProcessInfo.processInfo.environment["CHIIBAR_GACHA_ONLY"] == "1" {
            let collection = fixtureModel(lastTokenAgo: 60)
            collection.tab = .friends
            save("friends_title", CGSize(width: 340, height: 640), PopoverView(model: collection))
            for (index, t) in [0.2, 1.0, 1.8, 3.6].enumerated() {
                save("gacha_refined_\(index)", GachaArt.size,
                     GachaCanvas(t: t, result: DrawResult(friend: .usagi, outcome: .newFriend)))
            }
            for friend in FriendID.allCases {
                save("hidden_result_\(friend.rawValue)", GachaArt.size,
                     GachaCanvas(t: 1.1, result: DrawResult(friend: friend, outcome: .newFriend)))
            }
            save("gacha_duplicate_clear", GachaArt.size,
                 GachaCanvas(t: 4, result: DrawResult(friend: .shisa, outcome: .gift(stage: 5))))
            return
        }

        if ProcessInfo.processInfo.environment["CHIIBAR_UPGRADE_ONLY"] == "1" {
            for elapsed in [0.0, 0.9, 1.2, 2.0, 2.5, 2.8] {
                save("manual_surplus_\(Int(elapsed * 10))", CGSize(width: 320, height: 120),
                    StageProgress(model: carryoverModel(elapsed: elapsed)).padding(8).background(Theme.background))
            }
            let ready = fixtureModel(lastTokenAgo: 60)
            ready.state.houses[.hachiware] = House(stage: 2, progress: HousePlan.cost(ofStage: 3) + HousePlan.cost(ofStage: 4) / 2)
            save("manual_ready", CGSize(width: 340, height: 640), PopoverView(model: ready))
            let celebration = fixtureModel(lastTokenAgo: 60)
            celebration.state.houses[.hachiware] = House(stage: 3, progress: 2_000_000)
            celebration.reveal = (3, now.addingTimeInterval(-3.7))
            celebration.upgradeNotice = ("벽돌집 입주!", now.addingTimeInterval(-0.7))
            save("joyful_complete", CGSize(width: 340, height: 640), PopoverView(model: celebration))
            save("carryover_notice", CGSize(width: 340, height: 640), PopoverView(model: carryoverModel(elapsed: 2.2)))
            renderCarryover(to: out)
            renderAssembly(to: out)
            for e in [0.5, 1.2, 1.8, 2.5, 3.0] {
                var p = SceneParams(friend: .chiikawa, stage: 3, activity: .tea, t: 100 + e)
                p.previousStage = 2; p.reveal = (3, e)
                save("soft_build_\(Int(e * 10))", sz, scene(p))
            }
            return
        }

        if ProcessInfo.processInfo.environment["CHIIBAR_MANGA_ONLY"] == "1" {
            save("manga_expressions", CGSize(width: 720, height: 660), Canvas { ctx, _ in
                let entries = FriendID.allCases.flatMap { f in MangaExpression.allowed(for: f).map { (f, $0) } }
                for (i, item) in entries.enumerated() {
                    let x = CGFloat(i % 4) * 180 + 90, y = CGFloat(i / 4) * 220 + 170
                    var pose = Pose(); pose.mangaExpression = item.1
                    FriendArt.draw(ctx, item.0, base: CGPoint(x: x, y: y), size: 85, pose: pose)
                    ctx.draw(Text(item.0.name + " · " + item.1.rawValue).font(.system(size: 12)).foregroundColor(.black), at: CGPoint(x: x, y: y + 24))
                }
            }.background(Color.white))
            for (i, f) in FriendID.allCases.enumerated() {
                save("manga_room_\(i)", sz, scene(SceneParams(friend: f, stage: 3, activity: .tea, t: 1)))
            }
            for e in [0.0, 0.5, 1.2, 2.1, 2.7, 3.1] {
                var p = SceneParams(friend: .chiikawa, stage: 3, activity: .tea, t: 100 + e)
                p.previousStage = 2; p.reveal = (3, e)
                save("assembly_\(Int(e * 10))", sz, scene(p))
            }
            renderAssembly(to: out)
            return
        }

        for stage in 1...HousePlan.lastStage {
            save(String(format: "stage_%02d", stage), sz,
                 scene(SceneParams(friend: .hachiware, stage: stage, activity: .tea, t: t0)))
        }
        for progress in [0.0, 0.25, 0.5, 0.75, 0.99] {
            var p = SceneParams(friend: .chiikawa, stage: 2, activity: .tea, t: t0)
            p.constructionProgress = progress
            save("building_\(Int(progress * 100))", sz, scene(p))
        }
        save("journey_sheet", CGSize(width: 960, height: 1050),
             VStack(spacing: 0) {
                 ForEach(0..<5) { row in
                     HStack(spacing: 0) {
                         ForEach(0..<3) { col in
                             let stage = row * 3 + col + 1
                             if stage <= HousePlan.lastStage {
                                 scene(SceneParams(friend: .chiikawa, stage: stage, activity: .tea, t: t0))
                                     .frame(width: 320, height: 210)
                             } else { Color.clear.frame(width: 320, height: 210) }
                         }
                     }
                 }
             })
        if ProcessInfo.processInfo.environment["CHIIBAR_HOMES_ONLY"] == "1" {
            renderHomeWalk(to: out)
            return
        }
        save("ending", sz, scene(SceneParams(friend: .hachiware, stage: 12, activity: .tea, t: t0,
                                             endingElapsed: 1.6, bubble: FriendID.hachiware.dialogue(for: .completed))))
        for f in FriendID.allCases {
            save("character_\(f.rawValue)", sz, scene(SceneParams(friend: f, stage: 12, activity: .tea, t: t0)))
        }
        save("chiikawa_corrected", CGSize(width: 420, height: 320),
             Canvas { ctx, _ in
                 ctx.fill(Path(CGRect(x: 0, y: 0, width: 420, height: 320)), with: .color(Ink.rgb(0xFFF9EF)))
                 FriendArt.draw(ctx, .chiikawa, base: CGPoint(x: 210, y: 285), size: 215, pose: Pose())
             })
        var corrected = SceneParams(friend: .chiikawa, stage: 4, activity: .tea, t: t0)
        corrected.constructionProgress = 0.35
        save("chiikawa_home_corrected", sz, scene(corrected))
        save("character_sheet", CGSize(width: CGFloat(FriendID.allCases.count) * 100, height: 150), CharacterSheet())
        save("menu_faces", CGSize(width: CGFloat(FriendID.allCases.count) * 30, height: 30), MenuFaceSheet())
        save("all_friends_corrected", CGSize(width: 720, height: 660), Canvas { ctx, _ in
            ctx.fill(Path(CGRect(x: 0, y: 0, width: 720, height: 660)), with: .color(Ink.rgb(0xFFF9EF)))
            for (i, friend) in FriendID.allCases.enumerated() {
                let x = CGFloat(i % 3) * 240 + 120
                let y = CGFloat(i / 3) * 220
                FriendArt.draw(ctx, friend, base: CGPoint(x: x, y: y + 190), size: 110, pose: Pose())
                ctx.draw(Text(friend.name).font(.system(size: 16)).foregroundColor(Theme.text), at: CGPoint(x: x, y: y + 208))
            }
        })
        save("all_friend_expressions", CGSize(width: 600, height: 1800), Canvas { ctx, _ in
            ctx.fill(Path(CGRect(x: 0, y: 0, width: 600, height: 1800)), with: .color(Ink.rgb(0xFFF9EF)))
            for (i, friend) in FriendID.allCases.enumerated() {
                for col in 0..<3 {
                    var pose = Pose()
                    if col == 1 { pose.eyes = .closed }
                    if col == 2 { pose.eyes = .happy; pose.arms = .up }
                    FriendArt.draw(ctx, friend, base: CGPoint(x: CGFloat(col) * 200 + 100, y: CGFloat(i) * 200 + 170), size: 95, pose: pose)
                }
                ctx.draw(Text(friend.name).font(.system(size: 14)).foregroundColor(Theme.text), at: CGPoint(x: 300, y: CGFloat(i) * 200 + 188))
            }
        })
        let demo = AppModel.demo()
        save("demo_home", CGSize(width: 340, height: 640), PopoverView(model: demo))
        var pet = SceneParams(friend: .hachiware, stage: 6, activity: .tea, t: t0)
        pet.pokeElapsed = 0.45
        pet.bubble = "에헤헤!"
        save("pet_response", sz, scene(pet))
        renderPolishedMotion(to: out)
        renderJourney(to: out)
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

        let popSize = CGSize(width: 340, height: 640)
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
        template.state.houses[.hachiware] = House(stage: 3, progress: HousePlan.cost(ofStage: 4) / 2)
        let model = AppModel(state: template.state, stateURL: nil, fixedNow: now.addingTimeInterval(elapsed))
        model.carryover = UpgradeCarryover(friend: .hachiware, stage: 3, amount: HousePlan.cost(ofStage: 4) / 2,
                                          startsAt: now.addingTimeInterval(0.6))
        return model
    }

    static func renderPolishedMotion(to out: URL) {
        let url = out.appendingPathComponent("polished_motion.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 120, nil) else { return }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<120 {
            let time = Double(frame) / 24
            var p = SceneParams(friend: .hachiware, stage: time < 3.8 ? 3 : 4, activity: .tea, t: t0 + time)
            p.arrivalElapsed = time
            p.constructionProgress = time < 3.8 ? ArrivalMotion.ease(time / 3.8) : 0
            if time >= 2 && time < 3.5 { p.pokeElapsed = time - 2; p.bubble = "에헤헤!" }
            if time >= 3.8 { p.reveal = (4, time - 3.8); p.previousStage = 3 }
            let params = p
            let renderer = ImageRenderer(content: Canvas { ctx, size in HouseArt.draw(ctx, canvas: size, params) }.frame(width: 320, height: 210))
            renderer.scale = 2
            guard let image = renderer.cgImage else { fatalError("motion render failed") }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 24]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }

    static func renderAssembly(to out: URL) {
        let url = out.appendingPathComponent("assembly.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 60, nil) else { return }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<60 {
            let elapsed = Double(frame) / 12
            var params = SceneParams(friend: .chiikawa, stage: 3, activity: .tea, t: 100 + elapsed)
            params.previousStage = 2; params.reveal = (3, elapsed)
            let renderer = ImageRenderer(content: Canvas { ctx, size in HouseArt.draw(ctx, canvas: size, params) }.frame(width: 320, height: 210))
            renderer.scale = 2
            guard let image = renderer.cgImage else { fatalError("assembly frame failed") }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 12]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }

    static func renderHomeWalk(to out: URL) {
        let url = out.appendingPathComponent("home_walk.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 144, nil) else { return }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<144 {
            let params = SceneParams(friend: .chiikawa, stage: 13, activity: .tea, t: Double(frame) / 6)
            let renderer = ImageRenderer(content: Canvas { ctx, size in HouseArt.draw(ctx, canvas: size, params) }.frame(width: 320, height: 210))
            renderer.scale = 2
            guard let image = renderer.cgImage else { fatalError("walk frame failed") }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 6]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }

    static func renderJourney(to out: URL) {
        let url = out.appendingPathComponent("home_pop.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 60, nil) else { return }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let arrival = (0..<2000).map { t0 + Double($0) / 100 }.first { ArrivalMotion.scale(at: $0, friend: .chiikawa) < 0.88 } ?? t0
        for frame in 0..<60 {
            var p = SceneParams(friend: .chiikawa, stage: frame < 48 ? 2 : 3, activity: .tea, t: arrival - 0.3 + Double(frame) / 12)
            p.constructionProgress = frame < 48 ? Double(frame) / 48 : 0
            if frame >= 48 { p.reveal = (3, Double(frame - 48) / 12); p.previousStage = 2 }
            let params = p
            let view = Canvas { ctx, size in HouseArt.draw(ctx, canvas: size, params) }.frame(width: 320, height: 210)
            let renderer = ImageRenderer(content: view); renderer.scale = 2
            guard let image = renderer.cgImage else { fatalError("journey frame failed") }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 12]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
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
