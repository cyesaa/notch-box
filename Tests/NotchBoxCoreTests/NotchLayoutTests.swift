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
        #expect(NotchLayout.size(for: .expanded, notch: notch) == CGSize(width: 400, height: 200))
        #expect(NotchLayout.size(for: .expandedEmpty, notch: notch) == CGSize(width: 300, height: 80))
    }

    @Test func wideNotchGrowsExpandedWidth() {
        let wide = CGSize(width: 350, height: 40)
        #expect(NotchLayout.size(for: .expanded, notch: wide) == CGSize(width: 430, height: 200))
        #expect(NotchLayout.size(for: .expandedEmpty, notch: wide) == CGSize(width: 430, height: 80))
    }

    @Test func tallNotchLeavesRoomForThePlayerBelowIt() {
        let tall = CGSize(width: 200, height: 50)
        #expect(NotchLayout.size(for: .expanded, notch: tall).height == 210)
    }

    @Test func maxSizeCoversAllStates() {
        #expect(NotchLayout.maxSize(notch: notch) == CGSize(width: 400, height: 200))
    }

    @Test func cornerRadiusGrowsWhenOpen() {
        #expect(NotchLayout.bottomCornerRadius(for: .idle) == 8)
        #expect(NotchLayout.bottomCornerRadius(for: .mini) == 8)
        #expect(NotchLayout.bottomCornerRadius(for: .expanded) == 20)
        #expect(NotchLayout.bottomCornerRadius(for: .expandedEmpty) == 20)
    }
}
