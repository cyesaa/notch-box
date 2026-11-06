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
        #expect(NotchLayout.size(for: .expanded, notch: notch) == CGSize(width: 400, height: 32 + 154))
        #expect(NotchLayout.size(for: .expandedEmpty, notch: notch) == CGSize(width: 300, height: 80))
    }

    @Test func wideNotchGrowsExpandedWidth() {
        let wide = CGSize(width: 350, height: 40)
        #expect(NotchLayout.size(for: .expanded, notch: wide) == CGSize(width: 430, height: 40 + 154))
        #expect(NotchLayout.size(for: .expandedEmpty, notch: wide) == CGSize(width: 430, height: 80))
    }

    @Test func tallNotchLeavesRoomForThePlayerBelowIt() {
        let tall = CGSize(width: 200, height: 50)
        let expected: CGFloat = 50 + 154
        #expect(NotchLayout.size(for: .expanded, notch: tall).height == expected)
    }

    @Test func maxSizeCoversAllStates() {
        // The video panel is the largest state.
        #expect(NotchLayout.maxSize(notch: notch) == NotchLayout.size(for: .video, notch: notch))
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
        #expect(NotchLayout.windowSize(notch: notch) == CGSize(width: 464 + 2 * (12 + margin), height: 299 + margin))
    }

    @Test func cornerRadiusGrowsWhenOpen() {
        #expect(NotchLayout.bottomCornerRadius(for: .idle) == 8)
        #expect(NotchLayout.bottomCornerRadius(for: .mini) == 8)
        #expect(NotchLayout.bottomCornerRadius(for: .expanded) == 20)
        #expect(NotchLayout.bottomCornerRadius(for: .expandedEmpty) == 20)
    }
}
