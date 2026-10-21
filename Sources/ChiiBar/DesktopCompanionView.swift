import ChiiCore
import SwiftUI

/// Only the sprite and its speech bubble are drawn; the rest of the native panel is clear.
struct DesktopCompanionView: View {
    @ObservedObject var model: AppModel
    var openApp: () -> Void
    var hide: () -> Void
    var previewBehavior: DesktopBehavior? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Clock(fixed: model.fixedNow) { date in
            let friend = model.state.current
            let time = date.timeIntervalSinceReferenceDate
            let responding = model.pokeStart.map { (0..<2.6).contains(date.timeIntervalSince($0)) } == true
            let behavior = previewBehavior ?? DesktopBehavior.at(time, friend: friend ?? .chiikawa, reduced: reduceMotion, responding: responding)
            let phase = max(0, time).truncatingRemainder(dividingBy: 14)
            ZStack(alignment: .top) {
                if let friend {
                    if phase < 6 || !behavior.walks || responding {
                        Text(responding ? model.bubble?.text ?? behavior.line(for: friend, time: time)
                             : behavior.line(for: friend, time: time))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.text).multilineTextAlignment(.center)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Ink.rgb(0xFFF9ED), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(alignment: .bottom) {
                                Triangle().fill(Ink.rgb(0xFFF9ED)).frame(width: 12, height: 8).offset(y: 7)
                            }.padding(.top, 5).allowsHitTesting(false)
                    }
                    Canvas { ctx, _ in
                        SpriteArt.drawDesktop(ctx, friend, behavior: behavior,
                            stage: model.state.currentHouse?.stage ?? 1, reduced: reduceMotion)
                        let name = ctx.resolve(Text(friend.japaneseName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Ink.rgb(0x5E514A)))
                        let width = name.measure(in: CGSize(width: 190, height: 24)).width + 16
                        ctx.fill(Path(roundedRect: CGRect(x: 100 - width / 2, y: 200, width: width, height: 22),
                            cornerRadius: 11), with: .color(Ink.rgb(0xFFF9ED).opacity(0.92)))
                        ctx.draw(name, at: CGPoint(x: 100, y: 211))
                    }.frame(width: 200, height: 224)
                    .allowsHitTesting(false)
                    Color.clear.frame(width: 160, height: 150).contentShape(Rectangle())
                        .offset(y: 50).onTapGesture { model.poke() }
                        .accessibilityLabel("\(friend.name), \(behavior.action.label)")
                        .accessibilityAddTraits(.isButton).accessibilityAction { model.poke() }
                        .contextMenu {
                            Button("치이바 열기", action: openApp)
                            Button("산책 끝내기", action: hide)
                        }
                } else {
                    Button("첫 친구 만나기", action: openApp).buttonStyle(PrimaryActionStyle()).padding(.top, 90)
                }
            }.frame(width: 200, height: 224)

        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: .zero); p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)); p.closeSubpath(); return p
    }
}
