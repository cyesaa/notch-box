import Foundation
import Testing
@testable import NotchBoxCore

struct VPNServiceListTests {
    // `scutil --nc list` on a Mac with FortiClient 7.4 and a built-in IKEv2 VPN.
    let output = """
    Available network connection services in the current set (*=enabled):
    * (Disconnected)   689A790A-026F-4E3D-9480-D4AF8362B958 VPN (com.fortinet.forticlient.macos.vpn) "VPN"                            [VPN:com.fortinet.forticlient.macos.vpn]
    * (Connected)      11111111-2222-3333-4444-555555555555 IPSec              "Office IKEv2"                   [IPSec]
      (Disconnected)   AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE VPN (com.wireguard.macos.network-extension) "WireGuard Home" [VPN:com.wireguard.macos.network-extension]
    """

    @Test func readsEveryService() {
        let services = VPNServiceList.parse(output)
        #expect(services.map(\.name) == ["VPN", "Office IKEv2", "WireGuard Home"])
        #expect(services[0] == VPNServiceInfo(
            id: "689A790A-026F-4E3D-9480-D4AF8362B958", name: "VPN",
            providerBundleID: "com.fortinet.forticlient.macos.vpn", isEnabled: true
        ))
        #expect(services[1].providerBundleID == nil)
        #expect(!services[2].isEnabled)
    }

    @Test func ignoresAnEmptyOrOddListing() {
        #expect(VPNServiceList.parse("").isEmpty)
        #expect(VPNServiceList.parse("Available network connection services in the current set (*=enabled):\n").isEmpty)
        #expect(VPNServiceList.parse("garbage line").isEmpty)
    }

    @Test func prefersFortiClientThenAnEnabledService() {
        let services = VPNServiceList.parse(output)
        #expect(VPNServiceList.preferred(in: services)?.name == "VPN")
        let withoutForti = Array(services.dropFirst())
        #expect(VPNServiceList.preferred(in: withoutForti)?.name == "Office IKEv2")
        #expect(VPNServiceList.preferred(in: []) == nil)
    }

    @Test func fortiClientGetsItsOwnName() {
        let forti = VPNServiceList.parse(output)[0]
        #expect(forti.isFortiClient)
        #expect(forti.displayName == "FortiClient VPN")
        #expect(VPNServiceList.parse(output)[2].displayName == "WireGuard Home")
    }
}

struct VPNStatusTests {
    @Test func mapsTheSystemStatusCodes() {
        #expect(VPNStatus(systemStatus: -1) == .unavailable)
        #expect(VPNStatus(systemStatus: 0) == .disconnected)
        #expect(VPNStatus(systemStatus: 1) == .connecting)
        #expect(VPNStatus(systemStatus: 2) == .connected)
        #expect(VPNStatus(systemStatus: 3) == .disconnecting)
        #expect(VPNStatus(systemStatus: 42) == .unavailable)
    }

    @Test func remembersWhenTheConnectionCameUp() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        var clock = VPNConnectionClock()
        clock.update(.disconnected, at: t0)
        #expect(clock.connectedSince == nil)
        clock.update(.connected, at: t0.addingTimeInterval(5))
        clock.update(.connected, at: t0.addingTimeInterval(60))
        #expect(clock.connectedSince == t0.addingTimeInterval(5))
        clock.update(.disconnected, at: t0.addingTimeInterval(90))
        #expect(clock.connectedSince == nil)
    }

    @Test func aConnectionAlreadyUpAtLaunchHasNoKnownStart() {
        // NotchBox did not see it come up, so it does not guess a duration.
        var clock = VPNConnectionClock()
        clock.update(.connected, at: Date(timeIntervalSince1970: 1_000), isFirstReading: true)
        #expect(clock.connectedSince == nil)
        #expect(clock.isConnected)
    }
}
