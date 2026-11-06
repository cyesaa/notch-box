import CoreGraphics
import Testing
@testable import NotchBoxCore

struct NotchInteractionTests {
    let notch = CGSize(width: 185, height: 32)

    @Test func closedStatesNeverTakeClicks() {
        #expect(!NotchInteraction.acceptsClicks(in: .idle, cursorOverCloseButton: false))
        #expect(!NotchInteraction.acceptsClicks(in: .mini, cursorOverCloseButton: true))
    }

    @Test func openPlayerPanelsTakeClicks() {
        #expect(NotchInteraction.acceptsClicks(in: .expanded, cursorOverCloseButton: false))
        #expect(NotchInteraction.acceptsClicks(in: .expandedEmpty, cursorOverCloseButton: false))
    }

    @Test func videoTakesClicksOnlyOverItsCloseButton() {
        #expect(NotchInteraction.acceptsClicks(in: .video, cursorOverCloseButton: true))
        #expect(!NotchInteraction.acceptsClicks(in: .video, cursorOverCloseButton: false))
    }

    @Test func onlyAHoveredVideoIsSeeThrough() {
        #expect(NotchInteraction.isSeeThrough(.video, hovering: true))
        #expect(!NotchInteraction.isSeeThrough(.video, hovering: false))
        #expect(!NotchInteraction.isSeeThrough(.expanded, hovering: true))
    }

    @Test func closeButtonSitsAtTheRightEndOfTheVideoBar() {
        let frame = NotchLayout.videoCloseButtonFrame(notch: notch)
        let side = NotchLayout.videoCloseButtonSide
        #expect(side == 28)
        #expect(frame == CGRect(x: 464 - 16 - side, y: 32 + 8 + (30 - side) / 2, width: side, height: side))
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
