import AppKit
import ChiiCore
import SwiftUI

/// Sparse cartoon rooms. Keep the centre clear for the separately animated friend.
enum DioramaArt {
    static let sceneScale: CGFloat = 0.74 * 1.3
    static let sceneOrigin = CGPoint(x: 160 * (1 - sceneScale), y: 53)
    private static let images: [Int: CGImage] = {
        let root: URL
        if let sprites = ProcessInfo.processInfo.environment["CHIIBAR_SPRITES"] {
            root = URL(fileURLWithPath: sprites).deletingLastPathComponent().appendingPathComponent("Homes")
        } else {
            root = (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("Homes")
        }
        return Dictionary(uniqueKeysWithValues: (1...13).compactMap { stage in
            let url = root.appendingPathComponent(String(format: "stage-%02d.png", stage))
            guard let image = NSImage(contentsOf: url),
                  let pixels = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
            return (stage, pixels)
        })
    }()
    private static func roomScale(_ stage: Int) -> CGFloat {
        [0.60, 0.70, 0.79, 0.84, 0.89, 0.94, 0.97, 1, 1, 1, 1, 1, 1][min(12, max(0, stage - 1))]
    }
    static func position(_ p: SceneParams) -> CGPoint {
        let current = floorPosition(p)
        guard !p.reduceMotion, let stage = p.previousStage, let reveal = p.reveal else { return current }
        var previous = p; previous.stage = stage
        let start = floorPosition(previous)
        let fraction = ArrivalMotion.ease(reveal.elapsed / HomeAssembly.duration)
        return CGPoint(x: start.x + (current.x - start.x) * fraction, y: start.y + (current.y - start.y) * fraction)
    }
    private static func floorPosition(_ p: SceneParams) -> CGPoint {
        let motion = HomeWander.position(at: p.t, friend: p.friend, reduced: p.reduceMotion)
        let floorOffset = p.stage == 1 ? -0.07 : p.stage == 8 ? -0.05 : p.stage == 12 ? -0.16 : -0.03
        let routeX: Double
        switch p.stage {
        case 12: routeX = 0.48 + (motion.x - 0.36) / 0.28 * 0.20
        case 13: routeX = 0.43 + (motion.x - 0.36) / 0.28 * 0.22
        case 11: routeX = 0.40 + (motion.x - 0.36)
        default: routeX = motion.x
        }
        let scale = roomScale(p.stage)
        return CGPoint(x: 160 + (routeX * 320 - 160) * scale,
                       y: 180 + ((motion.y + floorOffset) * 210 - 180) * scale)
    }
    static func hitCenter(_ p: SceneParams) -> CGPoint {
        guard images[p.stage] != nil else { return CGPoint(x: 60, y: 157) }
        let feet = position(p)
        return CGPoint(x: sceneOrigin.x + feet.x * sceneScale, y: sceneOrigin.y + feet.y * sceneScale - 22 * 1.3)
    }
    static func draw(_ canvas: GraphicsContext, _ p: SceneParams) -> Bool {
        canvas.fill(Path(CGRect(x: 0, y: 0, width: 320, height: HouseArt.size.height)), with: .color(Ink.rgb(0xFFF9EF)))
        WeatherArt.draw(canvas, moment: p.weather, time: p.t, reduced: p.reduceMotion)
        var c = canvas
        // Keep the house centred below the separate next-house header.
        c.translateBy(x: sceneOrigin.x, y: sceneOrigin.y)
        c.scaleBy(x: sceneScale, y: sceneScale)
        guard let image = images[p.stage] else { return false }
        func imageFrame(_ stage: Int) -> CGRect {
            let scale = roomScale(stage)
            return CGRect(x: 160 - 160 * scale, y: 180 - 185 * scale, width: 320 * scale, height: 213.333 * scale)
        }
        let frame = imageFrame(p.stage)
        if let previous = p.previousStage, let reveal = p.reveal, !p.reduceMotion,
           reveal.elapsed < HomeAssembly.duration {
            if let oldImage = images[previous] {
                var old = c; old.opacity = 1 - ArrivalMotion.ease(reveal.elapsed / 0.6)
                old.draw(Image(decorative: oldImage, scale: 1), in: imageFrame(previous))
            }
            assemble(c, image: image, frame: frame, elapsed: reveal.elapsed)
        } else {
            c.draw(Image(decorative: image, scale: 1), in: frame)
        }
        let motion = HomeWander.position(at: p.t, friend: p.friend, reduced: p.reduceMotion)
        let feet = position(p)
        let completion = p.reveal.map { $0.elapsed - HomeAssembly.duration }
        let newHome = completion.map { $0 >= 0 && $0 < 5.0 } ?? false
        let celebrating = p.pokeElapsed != nil || p.endingElapsed != nil || newHome
        let resting = motion.bounce == 0 && motion.lean == 0
        let weather = p.weather
        let reaction = weather.kind.reaction(friend: p.friend, stage: p.stage)
        let reacting = weather.intensity > 0.4 && !celebrating
        var expression = MangaExpression.select(friend: p.friend, stage: p.stage, time: p.t, responding: celebrating)
        if reacting && reaction == .tearful { expression = .cry }
        if reacting && weather.kind == .rain && HomeWeather.sheltered(stage: p.stage) && p.friend == .chiikawa {
            expression = .relief
        }
        let quiet = expression == .cry || resting
        let asleep = false // No sleep expression is admitted without its own original-panel reference.
        let elapsed = p.pokeElapsed ?? (newHome ? completion : nil) ?? p.arrivalElapsed ?? ArrivalMotion.elapsed(at: p.t, friend: p.friend)
        let lift = p.reduceMotion || asleep ? 0 : ArrivalMotion.lift(elapsed: elapsed)
        var pose = Pose()
        pose.mangaExpression = expression
        pose.eyes = asleep ? .closed : celebrating ? .happy : .open
        pose.arms = celebrating ? .up : pose.arms
        pose.blinking = !p.reduceMotion && !asleep && !celebrating && ArrivalMotion.blinking(at: p.t, friend: p.friend)
        pose.squish = p.reduceMotion || asleep ? 1 : ArrivalMotion.spring(elapsed: elapsed)
        pose.tilt = motion.lean
        var bounce = (expression == .cry ? 0 : lift) + (quiet ? 0 : motion.bounce)
        if reacting && !p.reduceMotion {
            switch reaction {
            case .play:
                bounce += pow(max(0, sin(p.t * 3.6)), 2) * 4 * weather.intensity
                pose.tilt += sin(p.t * 1.8) * 0.04 * weather.intensity
            case .shiver, .fuss:
                pose.tilt += sin(p.t * (reaction == .fuss ? 5 : 12)) * 0.025 * weather.intensity
                bounce = min(bounce, 1)
            case .curious:
                pose.tilt += sin(p.t * 0.8) * 0.045 * weather.intensity
            case .tearful: bounce = 0
            case .calm: break
            }
        }
        c.fill(FriendArt.ell(feet.x, feet.y, 21, 3), with: .color(.black.opacity(0.07)))
        let friendSize: CGFloat = p.friend == .rakko || p.friend == .shisa ? 44 :
            (p.friend == .momonga || p.friend == .anoko ? 39 : 35)
        FriendArt.draw(c, p.friend, base: CGPoint(x: feet.x, y: feet.y - bounce), size: friendSize / 0.74, pose: pose)
        if !p.reduceMotion {
            if let e = p.pokeElapsed { Effects.hearts(c, from: CGPoint(x: feet.x, y: feet.y - 46 / 0.74), elapsed: e) }
            if asleep { Effects.zzz(c, from: CGPoint(x: feet.x + 15, y: feet.y - 46 / 0.74), t: p.t) }
            if let e = p.endingElapsed { Effects.confetti(c, elapsed: e) }
            if let e = completion, e >= 0 {
                if p.endingElapsed == nil { Effects.confetti(c, elapsed: e) }
                HouseArt.sparkles(c, around: CGPoint(x: 160, y: 100), elapsed: e)
            }
        }
        if !HomeWeather.sheltered(stage: p.stage) {
            WeatherArt.draw(canvas, moment: weather, time: p.t, reduced: p.reduceMotion, foreground: true)
        }
        c.fill(Path(roundedRect: CGRect(x: 65, y: 190, width: 190, height: 19), cornerRadius: 8), with: .color(Ink.rgb(0xFFF9EF).opacity(0.95)))
        c.draw(Text(HousePlan.name(of: p.stage)).font(.system(size: 10 / sceneScale, weight: .bold)).foregroundColor(HousingJourney.ink), at: CGPoint(x: 160, y: 200))
        if p.bubble == nil && expression == .cry { Effects.bubble(c, text: "우웅…", near: CGPoint(x: feet.x, y: feet.y - 50 / 0.74)) }
        if let b = p.bubble { Effects.bubble(c, text: b, near: CGPoint(x: feet.x, y: feet.y - 50 / 0.74)) }
        // A mystery silhouette, without a separate card or progress fill.
        if p.stage < 13, let next = images[p.stage + 1] {
            let inset = CGRect(x: 268, y: 14, width: 45, height: 30)
            canvas.draw(Text("다음 집").font(.system(size: 9, weight: .bold)).foregroundColor(Ink.rgb(0x736B72)),
                   at: CGPoint(x: inset.midX, y: 5))
            var silhouette = canvas.resolve(Image(decorative: next, scale: 1))
            silhouette.shading = .color(.black)
            canvas.draw(silhouette, in: inset)
            canvas.draw(Text("?").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundColor(.white),
                   at: CGPoint(x: inset.midX, y: inset.midY))
        }
        return true
    }
    private static func assemble(_ c: GraphicsContext, image: CGImage, frame: CGRect, elapsed: Double) {
        let progress = HomeAssembly.reveal(elapsed: elapsed)
        let baseline = frame.maxY - frame.height * 0.10
        let boundary = frame.maxY - frame.height * progress
        let workLine = min(165, boundary)
        var house = c
        house.translateBy(x: frame.midX, y: baseline)
        house.scaleBy(x: HomeAssembly.scale(elapsed: elapsed), y: HomeAssembly.scale(elapsed: elapsed))
        house.translateBy(x: -frame.midX, y: -baseline)
        // Soft mask keeps the artwork intact: no rectangular tiles or seams.
        house.drawLayer { layer in
            layer.draw(Image(decorative: image, scale: 1), in: frame)
            layer.blendMode = .destinationIn
            layer.fill(Path(frame), with: .linearGradient(Gradient(colors: [.clear, .white]),
                startPoint: CGPoint(x: 0, y: boundary - 18), endPoint: CGPoint(x: 0, y: boundary + 8)))
        }
        let cloudFade = ArrivalMotion.ease(elapsed / 0.25) * (1 - ArrivalMotion.ease((elapsed - 1.8) / 0.65))
        if cloudFade > 0 {
            // Uneven overlapping clouds hide the work line; one hammer travels between beats.
            for i in 0..<7 {
                let seed = Double(i)
                let anchors = [0.16, 0.39, 0.73, 0.53, 0.85, 0.28, 0.64]
                let x = frame.minX + frame.width * anchors[i] + sin(elapsed * 2 + seed * 3) * 4
                let y = max(frame.minY + 25, workLine) + sin(seed * 2.4 + elapsed * 7) * 9
                let diameter = 19 + sin(seed * 1.7) * 6 + sin(elapsed * 12 + seed) * 2
                c.fill(FriendArt.ell(x, y, diameter * 1.35, diameter),
                       with: .color(Ink.rgb(i % 2 == 0 ? 0xF5E5C9 : 0xFFF5E1).opacity(cloudFade * 0.94)))
            }
            let beat = elapsed * 2.4
            let x = frame.midX + sin(elapsed * 3.4) * frame.width * 0.22
            let y = max(frame.minY + 35, workLine) - 9
            var hammer = c; hammer.opacity = cloudFade
            hammer.translateBy(x: x, y: y)
            hammer.rotate(by: .radians(-0.5 + sin(beat * .pi * 2) * 0.7))
            hammer.fill(Path(roundedRect: CGRect(x: -2, y: 0, width: 4, height: 17), cornerRadius: 2), with: .color(Ink.rgb(0xC5946A)))
            hammer.fill(Path(roundedRect: CGRect(x: -9, y: -5, width: 18, height: 8), cornerRadius: 3), with: .color(Ink.rgb(0x8C9BA6)))
        }
    }
}
