import Foundation
import Testing
@testable import NotchBoxCore

struct FortiTrayItemTests {
    @Test func readsWhatTheVPNItemWouldDo() {
        #expect(FortiTrayItem.kind(ofLabel: "Connect to Office VPN") == .connect)
        #expect(FortiTrayItem.kind(ofLabel: "Disconnect Office VPN") == .disconnect)
    }

    /// After hurried presses FortiTray shows "Disconnect " with no VPN name and ignores every press.
    @Test func aLabelWithoutAVPNNameIsStuck() {
        #expect(FortiTrayItem.kind(ofLabel: "Disconnect ") == .stuck)
        #expect(FortiTrayItem.kind(ofLabel: "Connect to ") == .stuck)
    }

    @Test func aLabelInAnotherLanguageIsUnknown() {
        #expect(FortiTrayItem.kind(ofLabel: "Verbinden mit Büro") == .unknown)
        #expect(FortiTrayItem.kind(ofLabel: "") == .unknown)
    }

    @Test func pressesToConnectOnlyWhenTheItemConnects() {
        #expect(FortiTrayItem.connectStep(label: "Connect to Office VPN") == .press)
        // FortiClient is already bringing the VPN up; another press would cancel it.
        #expect(FortiTrayItem.connectStep(label: "Disconnect Office VPN") == .nothing)
    }

    @Test func repairsAStuckTrayAndPressesAnUnknownLabel() {
        #expect(FortiTrayItem.connectStep(label: "Disconnect ") == .repair)
        #expect(FortiTrayItem.connectStep(label: "Verbinden mit Büro") == .press)
    }
}

struct VPNPendingActionTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    @Test func showsTheRealStatusWhenNothingWasAsked() {
        var pending = VPNPendingAction()
        #expect(pending.displayStatus(real: .disconnected, at: t0) == .disconnected)
        #expect(pending.displayStatus(real: .connected, at: t0) == .connected)
    }

    /// macOS keeps saying "disconnected" while FortiClient signs in, so the notch says "connecting" itself.
    @Test func showsConnectingUntilTheVPNIsUp() {
        var pending = VPNPendingAction()
        pending.pressed(toward: .connected, at: t0)
        #expect(pending.displayStatus(real: .disconnected, at: at(1)) == .connecting)
        #expect(pending.displayStatus(real: .unavailable, at: at(2)) == .connecting)
        #expect(pending.displayStatus(real: .connecting, at: at(3)) == .connecting)
        #expect(pending.displayStatus(real: .connected, at: at(50)) == .connected)
        // Reached: a later drop is shown as it is.
        #expect(pending.displayStatus(real: .disconnected, at: at(51)) == .disconnected)
    }

    @Test func givesUpOnAConnectionThatNeverComesUp() {
        var pending = VPNPendingAction()
        pending.pressed(toward: .connected, at: t0)
        #expect(pending.displayStatus(real: .disconnected, at: at(VPNPendingAction.connectTimeout - 1)) == .connecting)
        #expect(pending.displayStatus(real: .disconnected, at: at(VPNPendingAction.connectTimeout + 1)) == .disconnected)
        #expect(pending.displayStatus(real: .disconnected, at: at(VPNPendingAction.connectTimeout + 2)) == .disconnected)
    }

    /// "Disconnecting" stays for a few seconds after the VPN is down, so Connect is not offered while
    /// FortiClient is still tidying up.
    @Test func showsDisconnectingUntilTheVPNIsDownAndSettled() {
        var pending = VPNPendingAction()
        pending.pressed(toward: .disconnected, at: t0)
        #expect(pending.displayStatus(real: .connected, at: at(1)) == .disconnecting)
        #expect(pending.displayStatus(real: .disconnected, at: at(2)) == .disconnecting)
        #expect(pending.displayStatus(real: .disconnected, at: at(VPNPendingAction.disconnectSettle + 0.1)) == .disconnected)
        #expect(pending.displayStatus(real: .connected, at: at(VPNPendingAction.disconnectSettle + 1)) == .connected)
    }

    @Test func givesUpOnADisconnectThatDoesNotHappen() {
        var pending = VPNPendingAction()
        pending.pressed(toward: .disconnected, at: t0)
        #expect(pending.displayStatus(real: .connected, at: at(VPNPendingAction.disconnectTimeout - 1)) == .disconnecting)
        #expect(pending.displayStatus(real: .connected, at: at(VPNPendingAction.disconnectTimeout + 1)) == .connected)
    }

    /// While the notch is only waiting (macOS has not caught up), no button is offered.
    @Test func isWaitingWhileTheShownStatusIsAhead() {
        var pending = VPNPendingAction()
        let idle = pending.isWaiting(real: .disconnected, at: t0)
        pending.pressed(toward: .connected, at: t0)
        let signingIn = pending.isWaiting(real: .disconnected, at: at(1))
        // macOS reports the connection coming up: it can be stopped again.
        let comingUp = pending.isWaiting(real: .connecting, at: at(2))
        let up = pending.isWaiting(real: .connected, at: at(3))
        #expect([idle, signingIn, comingUp, up] == [false, true, false, false])
    }

    /// Presses a couple of seconds apart are what cancelled connections and left FortiTray stuck.
    @Test func ignoresAPressRightAfterAnother() {
        var pending = VPNPendingAction()
        #expect(pending.canPress(at: t0))
        pending.pressed(toward: .connected, at: t0)
        #expect(!pending.canPress(at: at(VPNPendingAction.pressCooldown - 0.5)))
        #expect(pending.canPress(at: at(VPNPendingAction.pressCooldown + 0.1)))
    }

    /// OpenVPN connects in a couple of seconds, so its wait is much shorter than FortiClient's.
    @Test func theConnectionWaitCanBeShorter() {
        var pending = VPNPendingAction(connectTimeout: 30)
        pending.pressed(toward: .connected, at: t0)
        #expect(pending.displayStatus(real: .disconnected, at: at(29)) == .connecting)
        #expect(pending.displayStatus(real: .disconnected, at: at(31)) == .disconnected)
    }

    @Test func timeoutsAndCooldown() {
        #expect(VPNPendingAction.connectTimeout == 90)
        #expect(VPNPendingAction.disconnectTimeout == 15)
        #expect(VPNPendingAction.disconnectSettle == 6)
        #expect(VPNPendingAction.pressCooldown == 4)
    }
}

struct VPNAppHidingTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }
    let forti = "com.fortinet.FortiClient"

    @Test func hidesNothingUntilAConnectionWasAsked() {
        let hiding = VPNAppHiding()
        #expect(!hiding.shouldHide(forti, at: t0))
    }

    /// FortiClient brings its window forward the moment the VPN comes up, seconds after the press.
    @Test func hidesTheAppWhileItsConnectionIsComingUp() {
        var hiding = VPNAppHiding()
        hiding.expect(forti, until: at(90))
        #expect(hiding.shouldHide(forti, at: at(3)))
        #expect(!hiding.shouldHide("org.openvpn.client.app", at: at(3)))
        #expect(!hiding.shouldHide(forti, at: at(91)))
    }

    @Test func stopsSoonAfterTheVPNIsUp() {
        var hiding = VPNAppHiding()
        hiding.expect(forti, until: at(90))
        hiding.connected(forti, at: at(4))
        #expect(hiding.shouldHide(forti, at: at(4 + VPNAppHiding.graceAfterConnected - 0.5)))
        // Later the user opens FortiClient themselves: leave it alone.
        #expect(!hiding.shouldHide(forti, at: at(4 + VPNAppHiding.graceAfterConnected + 0.5)))
    }

    @Test func connectedNeverExtendsTheWindow() {
        var hiding = VPNAppHiding()
        hiding.expect(forti, until: at(2))
        hiding.connected(forti, at: at(1))
        #expect(!hiding.shouldHide(forti, at: at(2.5)))
        hiding.connected("org.openvpn.client.app", at: at(1))
        #expect(!hiding.shouldHide("org.openvpn.client.app", at: at(1.5)))
    }

    /// The user asked NotchBox to open the app: do not hide it.
    @Test func stopsWhenTheUserOpensTheApp() {
        var hiding = VPNAppHiding()
        hiding.expect(forti, until: at(90))
        hiding.stop(forti)
        #expect(!hiding.shouldHide(forti, at: at(3)))
    }

    @Test func graceIsFiveSeconds() {
        #expect(VPNAppHiding.graceAfterConnected == 5)
    }
}
