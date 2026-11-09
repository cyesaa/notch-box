import CoreGraphics
import Foundation
import Testing
@testable import NotchBoxCore

struct SideWidgetsTests {
    @Test func clipboardLeftAndCalendarRightByDefault() {
        #expect(SideWidgets.default == SideWidgets(left: .clipboard, right: .calendar))
        #expect(NotchWidget.allCases == [.clipboard, .calendar, .vpn])
    }

    @Test func choosingAWidgetForASide() {
        var sides = SideWidgets(left: nil, right: nil)
        sides.set(.calendar, on: .left)
        #expect(sides == SideWidgets(left: .calendar, right: nil))
        sides.set(nil, on: .left)
        #expect(sides == SideWidgets(left: nil, right: nil))
    }

    @Test func aWidgetAlreadyOnTheOtherSideSwapsPlaces() {
        var sides = SideWidgets.default
        sides.set(.calendar, on: .left)
        #expect(sides == SideWidgets(left: .calendar, right: .clipboard))
    }

    @Test func aWidgetMovedToAnEmptySideLeavesItsOldSideEmpty() {
        var sides = SideWidgets(left: .clipboard, right: nil)
        sides.set(.clipboard, on: .right)
        #expect(sides == SideWidgets(left: nil, right: .clipboard))
    }

    @Test func tellsWhetherAWidgetIsShown() {
        let sides = SideWidgets(left: .calendar, right: nil)
        #expect(sides.shows(.calendar))
        #expect(!sides.shows(.clipboard))
        #expect(sides[.left] == .calendar)
        #expect(sides[.right] == nil)
    }

    @Test func savesAndRestores() throws {
        let sides = SideWidgets(left: nil, right: .clipboard)
        let data = try JSONEncoder().encode(sides)
        #expect(SideWidgets.decode(data) == sides)
    }

    @Test func aWidgetFromANewerVersionIsDroppedNotFatal() {
        let data = Data(#"{"left":"weather","right":"calendar"}"#.utf8)
        #expect(SideWidgets.decode(data) == SideWidgets(left: nil, right: .calendar))
        #expect(SideWidgets.decode(Data("junk".utf8)) == nil)
    }
}

struct SideWidgetLayoutTests {
    let notch = CGSize(width: 185, height: 32)

    @Test func eachChosenSideAddsAColumn() {
        let both = SideWidgets.default
        let leftOnly = SideWidgets(left: .clipboard, right: nil)
        let none = SideWidgets(left: nil, right: nil)
        let expectedBoth: CGFloat = 240 + 400 + 240
        let expectedOne: CGFloat = 240 + 400
        let expectedNone: CGFloat = 400
        #expect(NotchLayout.size(for: .expanded, notch: notch, sides: both).width == expectedBoth)
        #expect(NotchLayout.size(for: .expanded, notch: notch, sides: leftOnly).width == expectedOne)
        #expect(NotchLayout.size(for: .expanded, notch: notch, sides: none).width == expectedNone)
        // Only the open player has side columns.
        #expect(NotchLayout.size(for: .video, notch: notch, sides: both) == NotchLayout.size(for: .video, notch: notch, sides: none))
    }

    @Test func thePlayerStaysUnderTheNotchWithOneSide() {
        #expect(NotchLayout.horizontalOffset(for: .expanded, sides: SideWidgets(left: .clipboard, right: nil)) == -120)
        #expect(NotchLayout.horizontalOffset(for: .expanded, sides: SideWidgets(left: nil, right: .calendar)) == 120)
        #expect(NotchLayout.horizontalOffset(for: .expanded, sides: .default) == 0)
    }

    @Test func theWindowFitsTheWidestChoice() {
        // The window never resizes when the choice changes: it always fits both columns.
        #expect(NotchLayout.contentReach(notch: notch).width == 440)
    }
}
