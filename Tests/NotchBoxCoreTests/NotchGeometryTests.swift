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

struct VirtualNotchTests {
    // 13" MacBook Air (M1) at default scaling: 1440 x 900 points, a 24 pt menu bar and no notch.
    let air = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test func sitsCentredAtTheTopAsTallAsTheMenuBar() {
        let geometry = NotchGeometry.virtual(screenFrame: air, menuBarHeight: 24)
        #expect(geometry.isVirtual)
        #expect(geometry.notchRect == CGRect(x: 720 - 92.5, y: 900 - 24, width: 185, height: 24))
        #expect(geometry.notchSize == CGSize(width: NotchGeometry.virtualNotchWidth, height: 24))
    }

    @Test func aHiddenMenuBarFallsBackToTheUsualHeight() {
        #expect(NotchGeometry.defaultMenuBarHeight == 24)
        #expect(NotchGeometry.virtual(screenFrame: air, menuBarHeight: 0).notchSize.height == 24)
        // Very tall readings (a display with odd insets) are capped.
        #expect(NotchGeometry.virtual(screenFrame: air, menuBarHeight: 80).notchSize.height == 40)
    }

    @Test func followsScreensNotAtTheOrigin() {
        let external = CGRect(x: -1920, y: 200, width: 1920, height: 1080)
        let geometry = NotchGeometry.virtual(screenFrame: external, menuBarHeight: 25)
        #expect(geometry.notchRect == CGRect(x: -960 - 92.5, y: 1280 - 25, width: 185, height: 25))
    }

    @Test func aRealNotchIsNotVirtual() throws {
        let geometry = try #require(NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryTopLeft: CGRect(x: 0, y: 950, width: 663.5, height: 32),
            auxiliaryTopRight: CGRect(x: 848.5, y: 950, width: 663.5, height: 32)
        ))
        #expect(!geometry.isVirtual)
    }
}

struct ScreenChoiceTests {
    let macBook = NotchGeometry.ScreenInfo(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982), visibleTop: 950, safeAreaTop: 32,
        auxiliaryTopLeft: CGRect(x: 0, y: 950, width: 663.5, height: 32),
        auxiliaryTopRight: CGRect(x: 848.5, y: 950, width: 663.5, height: 32)
    )
    let monitor = NotchGeometry.ScreenInfo(
        frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440), visibleTop: 1415, safeAreaTop: 0,
        auxiliaryTopLeft: nil, auxiliaryTopRight: nil
    )

    @Test func aNotchedScreenWinsWhereverItIs() {
        let geometry = NotchGeometry.choose(from: [monitor, macBook], allowVirtual: true)
        #expect(geometry?.isVirtual == false)
        #expect(geometry?.screenFrame == macBook.frame)
    }

    @Test func withoutANotchTheMenuBarScreenGetsAVirtualOne() {
        // The first screen is the one with the menu bar.
        let geometry = NotchGeometry.choose(from: [monitor], allowVirtual: true)
        #expect(geometry?.isVirtual == true)
        #expect(geometry?.screenFrame == monitor.frame)
        #expect(geometry?.notchSize.height == 25)
    }

    @Test func virtualNotchesCanBeTurnedOff() {
        #expect(NotchGeometry.choose(from: [monitor], allowVirtual: false) == nil)
        #expect(NotchGeometry.choose(from: [], allowVirtual: true) == nil)
    }
}
