import Foundation
import Testing
@testable import ChiiCore

@Test func desktopActionsAreBoundedAndMatchMovement() {
    for friend in FriendID.visible {
        var seen = Set<DesktopAction>()
        for second in 0..<1200 {
            let behavior = DesktopBehavior.at(Double(second), friend: friend)
            seen.insert(behavior.action)
            #expect(behavior.walks == (behavior.action == .walk))
            #expect((0...1).contains(behavior.envelope))
            #expect(!behavior.line(for: friend, time: Double(second)).isEmpty)
            if behavior.action == .cry { #expect(friend == .chiikawa) }
        }
        #expect(seen.contains(.walk) && seen.contains(.sit) && seen.contains(.laugh))
        #expect(!friend.japaneseName.isEmpty)
    }
}

@Test func desktopRestNeverMovesAndRespondingSoothesCrying() {
    for friend in FriendID.visible {
        for t in stride(from: 0.0, through: 1000.0, by: 0.5) {
            let rest = DesktopBehavior.at(t, friend: friend, reduced: true)
            #expect(rest.action == .sit && !rest.walks)
            #expect(DesktopBehavior.at(t, friend: friend, responding: true).action == .laugh)
        }
    }
    #expect(DesktopBehavior(action: .sit, elapsed: 0).envelope == 0)
    #expect(DesktopBehavior(action: .sit, elapsed: 10).envelope == 0)
    #expect(DesktopBehavior(action: .sit, elapsed: 5).envelope == 1)
}
