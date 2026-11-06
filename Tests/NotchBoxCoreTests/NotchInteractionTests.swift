import CoreGraphics
import Testing
@testable import NotchBoxCore

struct NotchInteractionTests {
    let notch = CGSize(width: 185, height: 32)

    @Test func closedStatesNeverTakeClicks() {
        #expect(!NotchInteraction.acceptsClicks(in: .idle, cursorOverButton: false, entry: nil))
        #expect(!NotchInteraction.acceptsClicks(in: .idle, cursorOverButton: true, entry: nil))
    }

    @Test func openPlayerPanelsTakeClicks() {
        #expect(NotchInteraction.acceptsClicks(in: .expanded, cursorOverButton: false, entry: nil))
        #expect(NotchInteraction.acceptsClicks(in: .expandedEmpty, cursorOverButton: false, entry: nil))
    }

    @Test func videoEnteredFromTheSideTakesClicksOnlyOverItsCloseButton() {
        #expect(NotchInteraction.acceptsClicks(in: .video, cursorOverButton: true, entry: .fromSide))
        #expect(!NotchInteraction.acceptsClicks(in: .video, cursorOverButton: false, entry: .fromSide))
        #expect(!NotchInteraction.acceptsClicks(in: .video, cursorOverButton: false, entry: nil))
    }

    @Test func videoEnteredFromTheTopTakesEveryClick() {
        #expect(NotchInteraction.acceptsClicks(in: .video, cursorOverButton: false, entry: .fromTop))
        #expect(NotchInteraction.acceptsClicks(in: .video, cursorOverButton: true, entry: .fromTop))
    }

    @Test func entryDoesNotChangeOtherStates() {
        #expect(NotchInteraction.acceptsClicks(in: .expanded, cursorOverButton: false, entry: .fromSide))
        #expect(!NotchInteraction.acceptsClicks(in: .mini, cursorOverButton: false, entry: .fromTop))
        #expect(!NotchInteraction.acceptsClicks(in: .idle, cursorOverButton: false, entry: .fromTop))
    }

    @Test func onlyAVideoHoveredFromTheSideIsSeeThrough() {
        #expect(NotchInteraction.isSeeThrough(.video, hovering: true, entry: .fromSide))
        #expect(!NotchInteraction.isSeeThrough(.video, hovering: true, entry: .fromTop))
        #expect(!NotchInteraction.isSeeThrough(.video, hovering: false, entry: nil))
        #expect(!NotchInteraction.isSeeThrough(.expanded, hovering: true, entry: .fromSide))
    }

    @Test func enteringWithinTheNotchBandCountsAsFromTheTop() {
        // The band beside the notch, plus a little slack for a fast cursor.
        #expect(NotchInteraction.entry(atDepth: 0, notchHeight: 32) == .fromTop)
        #expect(NotchInteraction.entry(atDepth: 40, notchHeight: 32) == .fromTop)
        #expect(NotchInteraction.entry(atDepth: 41, notchHeight: 32) == .fromSide)
        #expect(NotchInteraction.entry(atDepth: 200, notchHeight: 32) == .fromSide)
    }

    @Test func closeButtonSitsInTheNotchBandAtTheRightEnd() {
        let frame = NotchLayout.videoCloseButtonFrame(notch: notch)
        let side = NotchLayout.videoCloseButtonSide
        #expect(side == 24)
        #expect(frame == CGRect(x: 464 - 16 - side, y: (32 - side) / 2, width: side, height: side))
    }

    @Test func videoPlayerStartsJustBelowTheNotch() {
        // Notch, gap, 16:9 player (432 × 243), bottom padding.
        #expect(NotchLayout.size(for: .video, notch: notch) == CGSize(width: 464, height: 32 + 8 + 243 + 16))
    }

    @Test func contentRectsConvertToScreenCoordinates() throws {
        // 14" MacBook Pro: 1512 × 982 points with a 185 × 32 notch in the middle.
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let geometry = try #require(NotchGeometry(
            screenFrame: screen,
            safeAreaTop: 32,
            auxiliaryTopLeft: CGRect(x: 0, y: 950, width: 663.5, height: 32),
            auxiliaryTopRight: CGRect(x: 848.5, y: 950, width: 663.5, height: 32)
        ))
        let content = CGSize(width: 400, height: 200)
        // The content is centred on the notch (x 556) and hangs from the top (y 982 down to 782).
        let rect = geometry.screenRect(for: CGRect(x: 10, y: 20, width: 30, height: 40), inContentOf: content)
        #expect(rect == CGRect(x: 556 + 10, y: 982 - 20 - 40, width: 30, height: 40))
    }
}
