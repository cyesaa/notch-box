import CoreGraphics
import Foundation
import Testing
@testable import NotchBoxCore

/// Widgets sit beside the open player and in a second row under it: bottom left, below, bottom right.
struct WidgetPlacesTests {
    @Test func thereAreFivePlacesAndTheBottomRowStartsEmpty() {
        #expect(SideWidgets.Side.allCases == [.left, .right, .bottomLeft, .bottom, .bottomRight])
        #expect(SideWidgets.default.bottomLeft == nil)
        #expect(SideWidgets.default.bottom == nil)
        #expect(SideWidgets.default.bottomRight == nil)
        #expect(!SideWidgets.default.hasBottomRow)
    }

    @Test func aWidgetCanGoBelowThePlayer() {
        var sides = SideWidgets.default
        sides.set(.vpn, on: .bottom)
        #expect(sides == SideWidgets(left: .clipboard, right: .calendar, bottom: .vpn))
        #expect(sides[.bottom] == .vpn)
        #expect(sides.shows(.vpn))
        #expect(sides.hasBottomRow)
    }

    @Test func aWidgetAlreadyPlacedSwapsWithThePlaceItIsMovedTo() {
        var sides = SideWidgets(left: .clipboard, right: .calendar, bottomLeft: .vpn, bottom: .auth)
        sides.set(.clipboard, on: .bottom)
        #expect(sides == SideWidgets(left: .auth, right: .calendar, bottomLeft: .vpn, bottom: .clipboard))
        // Moved to an empty place, it leaves its old place empty.
        sides.set(.calendar, on: .bottomRight)
        #expect(sides == SideWidgets(left: .auth, right: nil, bottomLeft: .vpn, bottom: .clipboard, bottomRight: .calendar))
    }

    @Test func emptyingAPlaceLeavesTheOthersAlone() {
        var sides = SideWidgets(left: .clipboard, right: .calendar, bottom: .vpn)
        sides.set(nil, on: .bottom)
        #expect(sides == .default)
    }

    @Test func aColumnExistsWhenEitherOfItsPlacesIsTaken() {
        #expect(SideWidgets(left: nil, right: nil, bottomLeft: .vpn).hasLeftColumn)
        #expect(!SideWidgets(left: nil, right: nil, bottomLeft: .vpn).hasRightColumn)
        #expect(SideWidgets(left: nil, right: nil, bottomRight: .vpn).hasRightColumn)
        #expect(!SideWidgets(left: nil, right: nil, bottom: .vpn).hasLeftColumn)
        #expect(!SideWidgets(left: nil, right: nil, bottom: .vpn).hasRightColumn)
        #expect(SideWidgets.default.hasLeftColumn && SideWidgets.default.hasRightColumn)
    }

    @Test func savesAndRestoresTheBottomRow() throws {
        let sides = SideWidgets(left: .clipboard, right: nil, bottomLeft: .auth, bottom: .calendar, bottomRight: .vpn)
        let data = try JSONEncoder().encode(sides)
        #expect(SideWidgets.decode(data) == sides)
    }

    @Test func aChoiceSavedBeforeTheBottomRowExistedStillReads() {
        let data = Data(#"{"left":"clipboard","right":"vpn"}"#.utf8)
        #expect(SideWidgets.decode(data) == SideWidgets(left: .clipboard, right: .vpn))
        let newer = Data(#"{"left":"clipboard","bottom":"weather","bottomRight":"auth"}"#.utf8)
        #expect(SideWidgets.decode(newer) == SideWidgets(left: .clipboard, right: nil, bottomRight: .auth))
    }
}

struct WidgetGridLayoutTests {
    let notch = CGSize(width: 185, height: 32)
    let full = SideWidgets(left: .clipboard, right: .calendar, bottomLeft: .vpn, bottom: .auth)

    @Test func theBottomRowIsAsTallAsTheRowAboveIt() {
        // So a widget looks the same in either row: its header's height plus the player's body.
        let rowHeight: CGFloat = 32 + 154
        #expect(NotchLayout.bottomRowHeight(notch: notch) == rowHeight)
        #expect(NotchLayout.size(for: .expanded, notch: notch, sides: full) == CGSize(width: 240 + 400 + 240, height: 2 * (32 + 154)))
        #expect(NotchLayout.size(for: .expandedEmpty, notch: notch, sides: full) == CGSize(width: 240 + 300 + 240, height: 2 * (32 + 154)))
    }

    @Test func withoutABottomWidgetThePanelIsAsBefore() {
        #expect(NotchLayout.size(for: .expanded, notch: notch, sides: .default) == CGSize(width: 880, height: 32 + 154))
        #expect(NotchLayout.bottomExtension(for: .expanded, notch: notch, sides: .default) == 0)
    }

    @Test func aWidgetOnlyBelowKeepsThePanelAsWideAsThePlayer() {
        let below = SideWidgets(left: nil, right: nil, bottom: .clipboard)
        #expect(NotchLayout.size(for: .expanded, notch: notch, sides: below) == CGSize(width: 400, height: 2 * (32 + 154)))
        #expect(NotchLayout.horizontalOffset(for: .expanded, sides: below) == 0)
    }

    @Test func aWidgetOnlyOnADiagonalAddsItsColumn() {
        let diagonal = SideWidgets(left: nil, right: nil, bottomLeft: .calendar)
        #expect(NotchLayout.size(for: .expanded, notch: notch, sides: diagonal) == CGSize(width: 240 + 400, height: 2 * (32 + 154)))
        // The player stays under the notch.
        #expect(NotchLayout.horizontalOffset(for: .expanded, sides: diagonal) == -120)
        #expect(NotchLayout.leadingExtension(for: .expanded, sides: diagonal) == 240)
        #expect(NotchLayout.trailingExtension(for: .expanded, sides: diagonal) == 0)
    }

    @Test func onlyTheOpenPlayerHasABottomRow() {
        for state in [NotchDisplayState.idle, .mini, .video, .volume, .auth] {
            #expect(NotchLayout.size(for: state, notch: notch, sides: full) == NotchLayout.size(for: state, notch: notch, sides: SideWidgets(left: nil, right: nil)))
            #expect(NotchLayout.bottomExtension(for: state, notch: notch, sides: full) == 0)
        }
    }

    @Test func theWindowFitsBothColumnsAndTheBottomRow() {
        // The window never resizes when the choice changes: it is sized for every place taken.
        #expect(NotchLayout.contentReach(notch: notch) == CGSize(width: 440, height: 2 * (32 + 154)))
        #expect(NotchLayout.windowSize(notch: notch) == CGSize(width: 2 * 440 + 2 * (12 + 24), height: 372 + 24))
    }

    @Test func theMiddleOfTheBottomRowIsAsWideAsThePlayer() {
        #expect(NotchLayout.centerWidth(for: .expanded, notch: notch) == 400)
        #expect(NotchLayout.centerWidth(for: .expandedEmpty, notch: notch) == 300)
        #expect(NotchLayout.centerWidth(for: .expanded, notch: CGSize(width: 350, height: 40)) == 430)
    }
}
