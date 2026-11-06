import CoreGraphics
import Testing
@testable import NotchBoxCore

struct NotchLayoutTests {
    let notch = CGSize(width: 185, height: 32)

    @Test func idleMatchesNotch() {
        #expect(NotchLayout.size(for: .idle, notch: notch) == notch)
    }

    @Test func miniWidensBothSides() {
        #expect(NotchLayout.miniSideWidth(notch: notch) == 44)
        #expect(NotchLayout.size(for: .mini, notch: notch) == CGSize(width: 273, height: 32))
        #expect(NotchLayout.miniArtworkSide(notch: notch) == 24)
    }

    @Test func expandedSizes() {
        // The player body hangs right below the notch; the band beside the notch holds the small icons.
        // The clipboard column (240) sits left of the player.
        #expect(NotchLayout.size(for: .expanded, notch: notch) == CGSize(width: 240 + 400, height: 32 + 154))
        #expect(NotchLayout.size(for: .expandedEmpty, notch: notch) == CGSize(width: 240 + 300, height: 32 + 154))
    }

    @Test func wideNotchGrowsExpandedWidth() {
        let wide = CGSize(width: 350, height: 40)
        #expect(NotchLayout.size(for: .expanded, notch: wide) == CGSize(width: 240 + 430, height: 40 + 154))
        #expect(NotchLayout.size(for: .expandedEmpty, notch: wide) == CGSize(width: 240 + 430, height: 40 + 154))
    }

    @Test func tallNotchLeavesRoomForThePlayerBelowIt() {
        let tall = CGSize(width: 200, height: 50)
        let expected: CGFloat = 50 + 154
        #expect(NotchLayout.size(for: .expanded, notch: tall).height == expected)
    }

    @Test func windowCoversEveryStateAroundTheNotch() {
        // The window stays centred on the notch, so it is twice the widest reach from the notch's centre:
        // the open player reaches 640 / 2 + 120 = 440 to the left. The video panel is the tallest.
        #expect(NotchLayout.contentReach(notch: notch) == CGSize(width: 440, height: 299))
    }

    @Test func topCornersFlareIntoTheScreenEdgeOnlyWhenVisible() {
        #expect(NotchLayout.topCornerRadius(for: .idle) == 0)
        #expect(NotchLayout.topCornerRadius(for: .mini) == 6)
        #expect(NotchLayout.topCornerRadius(for: .expanded) == 12)
        #expect(NotchLayout.topCornerRadius(for: .expandedEmpty) == 12)
    }

    @Test func windowLeavesRoomForTheFlaredCornersAndTheShadow() {
        let margin = NotchLayout.shadowMargin
        #expect(margin == 24)
        #expect(NotchLayout.windowSize(notch: notch) == CGSize(width: 2 * 440 + 2 * (12 + margin), height: 299 + margin))
    }

    @Test func cornerRadiusGrowsWhenOpen() {
        #expect(NotchLayout.bottomCornerRadius(for: .idle) == 8)
        #expect(NotchLayout.bottomCornerRadius(for: .mini) == 8)
        #expect(NotchLayout.bottomCornerRadius(for: .expanded) == 20)
        #expect(NotchLayout.bottomCornerRadius(for: .expandedEmpty) == 20)
    }
}
