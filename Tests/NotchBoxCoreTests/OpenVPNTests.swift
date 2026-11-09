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
    ⏎[Nov 9, 2026, 17:15:54] EVENT: CONNECTED 212.64.199.51:1194 (212.64.199.51) via /UDP on utun6/10.8.0.2/ gw=[10.8.0.1/] mtu=1500⏎[Nov 9, 2026, 17:15:54] EVENT: COMPRESSION_ENABLED ⏎[Nov 9, 2026, 17:15:55] Session stats
     BYTES_IN : 1032279
    """

    @Test func readsTheLastConnection() throws {
        let state = try #require(OpenVPNLog.lastState(in: connected, timeZone: istanbul))
        #expect(state.event == "CONNECTED")
        #expect(state.date == date(17, 15, 54))
        #expect(state.server == "212.64.199.51")
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
            "1790842090433": ["id": "1790842090433", "name": "212.64.199.51 [fatmavpn]", "hostname": "212.64.199.51", "lastConnected": 1_794_233_754_658, "savedPassword": "secret"],
            "1788900392436": ["id": "1788900392436", "name": "173.212.194.24 [Eren1]", "hostname": "173.212.194.24", "lastConnected": 1_790_807_893_631],
            "1784324441808": ["id": "1784324441808", "name": "Office", "hostname": "173.212.194.24"],
        ]
        let status = String(decoding: try! JSONSerialization.data(withJSONObject: ["profiles": profiles]), as: UTF8.self)
        let root = String(decoding: try! JSONSerialization.data(withJSONObject: ["status": status]), as: UTF8.self)
        return try! JSONSerialization.data(withJSONObject: ["persist:root": root])
    }

    @Test func readsTheProfilesNewestFirst() {
        let profiles = OpenVPNProfiles.parse(config)
        #expect(profiles.map(\.id) == ["1790842090433", "1788900392436", "1784324441808"])
        #expect(profiles[0].host == "212.64.199.51")
        #expect(profiles[0].lastConnected == Date(timeIntervalSince1970: 1_794_233_754.658))
    }

    @Test func showsTheNameInBrackets() {
        let profiles = OpenVPNProfiles.parse(config)
        #expect(profiles.map(\.shortName) == ["fatmavpn", "Eren1", "Office"])
    }

    @Test func findsTheProfileOfAConnection() {
        let profiles = OpenVPNProfiles.parse(config)
        #expect(OpenVPNProfiles.profile(forServer: "212.64.199.51", in: profiles, preferring: nil)?.shortName == "fatmavpn")
        // Two profiles share a server: the one NotchBox connected, otherwise the one used last.
        #expect(OpenVPNProfiles.profile(forServer: "173.212.194.24", in: profiles, preferring: "1784324441808")?.shortName == "Office")
        #expect(OpenVPNProfiles.profile(forServer: "173.212.194.24", in: profiles, preferring: nil)?.shortName == "Eren1")
        #expect(OpenVPNProfiles.profile(forServer: "1.2.3.4", in: profiles, preferring: nil) == nil)
    }

    @Test func junkReadsAsNoProfiles() {
        #expect(OpenVPNProfiles.parse(Data("{}".utf8)).isEmpty)
        #expect(OpenVPNProfiles.parse(Data("junk".utf8)).isEmpty)
    }
}
