import ChiiCore
import SwiftUI

/// Weather stays outside the cutaway room. Clear weather adds no sunshine overlay.
enum WeatherArt {
    static func draw(_ context: GraphicsContext, moment: HomeWeather.Moment, time: Double,
                     reduced: Bool, foreground: Bool = false) {
        guard moment.kind != .clear, moment.intensity > 0 else { return }
        var c = context
        c.opacity = moment.intensity
        let t = reduced ? 0 : time
        c.clip(to: Path(CGRect(x: 8, y: 48, width: 304, height: HouseArt.size.height - 69)))
        let count = foreground ? 12 : 32
        for i in 0..<count {
            let seed = Double(i)
            let x0 = (seed * 73.17 + (foreground ? 49 : 0)).truncatingRemainder(dividingBy: 300) + 10
            let speed = moment.kind == .rain ? 88.0 : 16.0
            let phase = (t * speed + seed * 31.7).truncatingRemainder(dividingBy: Double(HouseArt.size.height - 55))
            let y = 43 + phase
            let x = x0 + (moment.kind == .snow ? sin(t * 0.8 + seed * 2) * 5 : -phase * 0.035)
            if moment.kind == .rain {
                var drop = Path()
                drop.move(to: CGPoint(x: x, y: y))
                drop.addLine(to: CGPoint(x: x - 1.8, y: y + 7))
                c.stroke(drop, with: .color(Ink.rgb(0x87ACBE).opacity(foreground ? 0.45 : 0.65)),
                         style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            } else {
                let r = 1.6 + Double(i % 3) * 0.4
                let dot = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                c.fill(dot, with: .color(.white.opacity(0.95)))
                c.stroke(dot, with: .color(Ink.rgb(0xB8D3DC).opacity(0.8)), lineWidth: 0.65)
            }
        }
    }
}
