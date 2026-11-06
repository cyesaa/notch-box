import CoreGraphics
import Foundation
import Testing
@testable import NotchBoxCore

struct VolumeHUDTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    @Test func showsForOneAndAHalfSeconds() {
        #expect(VolumeHUD.displayDuration == 1.5)
    }

    @Test func theFirstReportOnlyRecordsTheVolume() {
        var hud = VolumeHUD()
        hud.volumeReported(0.5, at: t0)
        #expect(!hud.isVisible(at: t0))
        #expect(hud.nextDeadline == nil)
    }

    @Test func aChangeShowsItUntilTheDeadline() {
        var hud = VolumeHUD()
        hud.volumeReported(0.5, at: t0)
        hud.volumeReported(0.6, at: at(10))
        #expect(hud.isVisible(at: at(10)))
        #expect(hud.nextDeadline == at(11.5))
        #expect(hud.isVisible(at: at(11.4)))
        #expect(!hud.isVisible(at: at(11.5)))
    }

    @Test func theSameVolumeAgainShowsNothing() {
        var hud = VolumeHUD()
        hud.volumeReported(0.5, at: t0)
        hud.volumeReported(0.5004, at: at(1))
        #expect(!hud.isVisible(at: at(1)))
    }

    @Test func furtherChangesKeepItUp() {
        var hud = VolumeHUD()
        hud.volumeReported(0.5, at: t0)
        hud.volumeReported(0.6, at: at(1))
        hud.volumeReported(0.7, at: at(2))
        #expect(hud.nextDeadline == at(3.5))
    }

    @Test func tickPastTheDeadlineClearsIt() {
        var hud = VolumeHUD()
        hud.volumeReported(0.5, at: t0)
        hud.volumeReported(0.6, at: at(1))
        hud.tick(at: at(2))
        #expect(hud.nextDeadline == at(2.5))
        hud.tick(at: at(2.5))
        #expect(hud.nextDeadline == nil)
        #expect(!hud.isVisible(at: at(2.5)))
    }

    @Test func hideClearsItAtOnce() {
        var hud = VolumeHUD()
        hud.volumeReported(0.5, at: t0)
        hud.volumeReported(0.6, at: at(1))
        hud.hide()
        #expect(!hud.isVisible(at: at(1)))
        #expect(hud.nextDeadline == nil)
    }
}

struct NotchButtonLayoutTests {
    let notch = CGSize(width: 185, height: 32)

    @Test func volumeStateAddsARowUnderTheMiniNotch() {
        #expect(!NotchDisplayState.volume.isOpen)
        #expect(NotchLayout.size(for: .volume, notch: notch) == CGSize(width: 185 + 2 * 44, height: 32 + 34))
        #expect(NotchLayout.topCornerRadius(for: .volume) == 6)
        #expect(NotchLayout.bottomCornerRadius(for: .volume) == 14)
    }

    @Test func miniActionAreaIsTheRightWing() {
        #expect(NotchLayout.miniActionFrame(notch: notch) == CGRect(x: 44 + 185, y: 0, width: 44, height: 32))
    }

    @Test func miniTakesClicksOnlyOverItsButton() {
        #expect(NotchInteraction.acceptsClicks(in: .mini, cursorOverButton: true))
        #expect(!NotchInteraction.acceptsClicks(in: .mini, cursorOverButton: false))
        #expect(!NotchInteraction.acceptsClicks(in: .volume, cursorOverButton: true))
    }

    @Test func onlyTheMiniButtonAreaKeepsThePanelClosed() {
        #expect(NotchInteraction.buttonSuppressesHover(in: .mini))
        #expect(!NotchInteraction.buttonSuppressesHover(in: .video))
    }
}
