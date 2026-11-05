import CoreGraphics
import Testing
@testable import NotchBoxCore

struct NotchGeometryTests {
    // 14" MacBook Pro at default scaling: 1512 x 982 points, 185 x 32 notch.
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let left = CGRect(x: 0, y: 950, width: 663.5, height: 32)
    let right = CGRect(x: 848.5, y: 950, width: 663.5, height: 32)

    @Test func computesNotchRectFromAuxiliaryAreas() throws {
        let geometry = try #require(NotchGeometry(screenFrame: screen, safeAreaTop: 32, auxiliaryTopLeft: left, auxiliaryTopRight: right))
        #expect(geometry.notchRect == CGRect(x: 663.5, y: 950, width: 185, height: 32))
        #expect(geometry.notchSize == CGSize(width: 185, height: 32))
    }

    @Test func returnsNilWithoutNotch() {
        #expect(NotchGeometry(screenFrame: screen, safeAreaTop: 0, auxiliaryTopLeft: left, auxiliaryTopRight: right) == nil)
        #expect(NotchGeometry(screenFrame: screen, safeAreaTop: 32, auxiliaryTopLeft: nil, auxiliaryTopRight: right) == nil)
        #expect(NotchGeometry(screenFrame: screen, safeAreaTop: 32, auxiliaryTopLeft: left, auxiliaryTopRight: nil) == nil)
    }

    @Test func offsetsForScreensNotAtOrigin() throws {
        let shifted = CGRect(x: 1920, y: -100, width: 1512, height: 982)
        let geometry = try #require(NotchGeometry(screenFrame: shifted, safeAreaTop: 32, auxiliaryTopLeft: left, auxiliaryTopRight: right))
        #expect(geometry.notchRect == CGRect(x: 2583.5, y: 850, width: 185, height: 32))
    }

    @Test func panelFrameIsCenteredOnNotchAndPinnedToTop() throws {
        let geometry = try #require(NotchGeometry(screenFrame: screen, safeAreaTop: 32, auxiliaryTopLeft: left, auxiliaryTopRight: right))
        #expect(geometry.panelFrame(for: CGSize(width: 400, height: 200)) == CGRect(x: 556, y: 782, width: 400, height: 200))
    }

    @Test func containsIncludesEdges() {
        let rect = CGRect(x: 663.5, y: 950, width: 185, height: 32)
        #expect(NotchGeometry.contains(rect, CGPoint(x: 756, y: 982)))
        #expect(NotchGeometry.contains(rect, CGPoint(x: 663.5, y: 950)))
        #expect(!NotchGeometry.contains(rect, CGPoint(x: 756, y: 949)))
        #expect(!NotchGeometry.contains(rect, CGPoint(x: 600, y: 970)))
        #expect(!NotchGeometry.contains(.null, CGPoint(x: 0, y: 0)))
    }
}
