import Foundation
import Testing
@testable import NotchBoxCore

struct OpenVPNLogTests {
    let istanbul = TimeZone(identifier: "Europe/Istanbul")!

    func date(_ hour: Int, _ minute: Int, _ second: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = istanbul
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: hour, minute: minute, second: second))!
    }

    // Shaped like OpenVPN Connect 3.8's ovpn.log: entries start with "⏎[date]" and may span lines.
    let connected = """
    ⏎[Nov 9, 2026, 17:15:54] EVENT: CONNECTING ⏎[Nov 9, 2026, 17:15:54] EVENT: ASSIGN_IP ⏎[Nov 9, 2026, 17:15:54] Capture
    ⏎[Nov 9, 2026, 17:15:54] EVENT: CONNECTED 203.0.113.10:1194 (203.0.113.10) via /UDP on utun6/10.8.0.2/ gw=[10.8.0.1/] mtu=1500⏎[Nov 9, 2026, 17:15:54] EVENT: COMPRESSION_ENABLED ⏎[Nov 9, 2026, 17:15:55] Session stats
     BYTES_IN : 1032279
    """

    @Test func readsTheLastConnection() throws {
        let state = try #require(OpenVPNLog.lastState(in: connected, timeZone: istanbul))
        #expect(state.event == "CONNECTED")
        #expect(state.date == date(17, 15, 54))
        #expect(state.server == "203.0.113.10")
        #expect(state.interface == "utun6")
    }

    @Test func aLaterDisconnectWins() throws {
        let text = connected + "\n⏎[Nov 9, 2026, 17:16:52] EVENT: DISCONNECTED ⏎"
        let state = try #require(OpenVPNLog.lastState(in: text, timeZone: istanbul))
        #expect(state.event == "DISCONNECTED")
        #expect(state.server == nil)
    }

    @Test func eventsThatSayNothingAboutTheStateAreSkipped() throws {
        let text = connected + "⏎[Nov 9, 2026, 17:20:00] EVENT: INFO something ⏎[Nov 9, 2026, 17:20:01] EVENT: COMPRESSION_ENABLED ⏎"
        #expect(try #require(OpenVPNLog.lastState(in: text, timeZone: istanbul)).event == "CONNECTED")
        #expect(OpenVPNLog.lastState(in: "nothing here", timeZone: istanbul) == nil)
    }

    @Test func statusNeedsTheAppAndTheTunnel() throws {
        let state = try #require(OpenVPNLog.lastState(in: connected, timeZone: istanbul))
        #expect(OpenVPNLog.status(of: state, appRunning: true, interfaceUp: { $0 == "utun6" }) == .connected)
        // The app quit without writing DISCONNECTED, or the tunnel is gone.
        #expect(OpenVPNLog.status(of: state, appRunning: false, interfaceUp: { _ in true }) == .disconnected)
        #expect(OpenVPNLog.status(of: state, appRunning: true, interfaceUp: { _ in false }) == .disconnected)
        #expect(OpenVPNLog.status(of: nil, appRunning: true, interfaceUp: { _ in true }) == .disconnected)
    }

    @Test func inBetweenEventsMeanConnecting() {
        for event in ["CONNECTING", "WAIT", "RESOLVE", "GET_CONFIG", "ASSIGN_IP", "RECONNECTING", "RESUME"] {
            let state = OpenVPNLogState(event: event, date: nil, server: nil, interface: nil)
            #expect(OpenVPNLog.status(of: state, appRunning: true, interfaceUp: { _ in false }) == .connecting)
        }
        for event in ["DISCONNECTED", "PAUSE", "AUTH_FAILED", "CONNECTION_TIMEOUT"] {
            let state = OpenVPNLogState(event: event, date: nil, server: nil, interface: nil)
            #expect(OpenVPNLog.status(of: state, appRunning: true, interfaceUp: { _ in true }) == .disconnected)
        }
    }
}

struct OpenVPNProfileTests {
    // OpenVPN Connect keeps its state as JSON strings inside JSON (redux-persist).
    var config: Data {
        let profiles: [String: Any] = [
            "1700000000003": ["id": "1700000000003", "name": "203.0.113.10 [office]", "hostname": "203.0.113.10", "lastConnected": 1_794_233_754_658, "savedPassword": "secret"],
            "1700000000002": ["id": "1700000000002", "name": "198.51.100.20 [home]", "hostname": "198.51.100.20", "lastConnected": 1_790_807_893_631],
            "1700000000001": ["id": "1700000000001", "name": "Lab", "hostname": "198.51.100.20"],
        ]
        let status = String(decoding: try! JSONSerialization.data(withJSONObject: ["profiles": profiles]), as: UTF8.self)
        let root = String(decoding: try! JSONSerialization.data(withJSONObject: ["status": status]), as: UTF8.self)
        return try! JSONSerialization.data(withJSONObject: ["persist:root": root])
    }

    @Test func readsTheProfilesNewestFirst() {
        let profiles = OpenVPNProfiles.parse(config)
        #expect(profiles.map(\.id) == ["1700000000003", "1700000000002", "1700000000001"])
        #expect(profiles[0].host == "203.0.113.10")
        #expect(profiles[0].lastConnected == Date(timeIntervalSince1970: 1_794_233_754.658))
    }

    @Test func showsTheNameInBrackets() {
        let profiles = OpenVPNProfiles.parse(config)
        #expect(profiles.map(\.shortName) == ["office", "home", "Lab"])
    }

    @Test func findsTheProfileOfAConnection() {
        let profiles = OpenVPNProfiles.parse(config)
        #expect(OpenVPNProfiles.profile(forServer: "203.0.113.10", in: profiles, preferring: nil)?.shortName == "office")
        // Two profiles share a server: the one NotchBox connected, otherwise the one used last.
        #expect(OpenVPNProfiles.profile(forServer: "198.51.100.20", in: profiles, preferring: "1700000000001")?.shortName == "Lab")
        #expect(OpenVPNProfiles.profile(forServer: "198.51.100.20", in: profiles, preferring: nil)?.shortName == "home")
        #expect(OpenVPNProfiles.profile(forServer: "1.2.3.4", in: profiles, preferring: nil) == nil)
    }

    @Test func junkReadsAsNoProfiles() {
        #expect(OpenVPNProfiles.parse(Data("{}".utf8)).isEmpty)
        #expect(OpenVPNProfiles.parse(Data("junk".utf8)).isEmpty)
    }
}
