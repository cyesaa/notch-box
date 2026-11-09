import Foundation

/// The latest state change OpenVPN Connect wrote to its log.
public struct OpenVPNLogState: Equatable, Sendable {
    public let event: String
    public let date: Date?
    /// The server of a CONNECTED event.
    public let server: String?
    /// The tunnel interface of a CONNECTED event ("utun6").
    public let interface: String?

    public init(event: String, date: Date?, server: String?, interface: String?) {
        self.event = event
        self.date = date
        self.server = server
        self.interface = interface
    }
}

/// Reads OpenVPN Connect's ovpn.log (~/Library/Application Support/OpenVPN Connect/log). The app has no API
/// for its state; its log records every connection event.
public enum OpenVPNLog {
    static let connectingEvents: Set<String> = ["CONNECTING", "WAIT", "RESOLVE", "GET_CONFIG", "ASSIGN_IP", "RECONNECTING", "RESUME"]
    static let disconnectedEvents: Set<String> = ["DISCONNECTED", "PAUSE", "AUTH_FAILED", "CONNECTION_TIMEOUT", "TUN_ERROR", "CLIENT_HALT"]

    private static let entry = try! NSRegularExpression(
        pattern: #"\[([A-Z][a-z]{2} \d{1,2}, \d{4}, \d{2}:\d{2}:\d{2})\] EVENT: ([A-Z_]+)([^⏎\n]*)"#
    )
    private static let connectedDetails = try! NSRegularExpression(pattern: #"^\s*([^\s:]+)(?::\d+)?.* on (utun\d+)"#)

    public static func lastState(in text: String, timeZone: TimeZone) -> OpenVPNLogState? {
        let matches = entry.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let eventRange = Range(match.range(at: 2), in: text) else { continue }
            let event = String(text[eventRange])
            guard event == "CONNECTED" || connectingEvents.contains(event) || disconnectedEvents.contains(event) else { continue }
            let date = Range(match.range(at: 1), in: text).flatMap { parseDate(String(text[$0]), timeZone: timeZone) }
            var server: String?
            var interface: String?
            if event == "CONNECTED", let restRange = Range(match.range(at: 3), in: text) {
                let rest = String(text[restRange])
                if let details = connectedDetails.firstMatch(in: rest, range: NSRange(rest.startIndex..., in: rest)) {
                    server = Range(details.range(at: 1), in: rest).map { String(rest[$0]) }
                    interface = Range(details.range(at: 2), in: rest).map { String(rest[$0]) }
                } else {
                    server = rest.split(separator: " ").first.map { String($0.split(separator: ":")[0]) }
                }
            }
            return OpenVPNLogState(event: event, date: date, server: server, interface: interface)
        }
        return nil
    }

    /// Connected only while the app runs and the tunnel it named still exists: the app does not always
    /// write DISCONNECTED when it quits.
    public static func status(of state: OpenVPNLogState?, appRunning: Bool, interfaceUp: (String) -> Bool) -> VPNStatus {
        guard let state, appRunning else { return .disconnected }
        if state.event == "CONNECTED" {
            if let interface = state.interface, !interfaceUp(interface) { return .disconnected }
            return .connected
        }
        return connectingEvents.contains(state.event) ? .connecting : .disconnected
    }

    private static func parseDate(_ text: String, timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM d, yyyy, HH:mm:ss"
        return formatter.date(from: text)
    }
}

public struct OpenVPNProfile: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let host: String?
    public let lastConnected: Date?

    public init(id: String, name: String, host: String?, lastConnected: Date?) {
        self.id = id
        self.name = name
        self.host = host
        self.lastConnected = lastConnected
    }

    /// "fatmavpn" for "212.64.199.51 [fatmavpn]"; the whole name otherwise.
    public var shortName: String {
        guard let open = name.lastIndex(of: "["), let close = name.lastIndex(of: "]"), open < close else { return name }
        let inner = name[name.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
        return inner.isEmpty ? name : inner
    }
}

/// Reads the profiles from OpenVPN Connect's config.json (only ids, names, servers and dates: never
/// passwords or keys).
public enum OpenVPNProfiles {
    public static func parse(_ data: Data) -> [OpenVPNProfile] {
        guard let outer = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rootText = outer["persist:root"] as? String,
              let root = json(rootText),
              let statusText = root["status"] as? String,
              let status = json(statusText),
              let profiles = status["profiles"] as? [String: Any]
        else { return [] }
        return profiles.compactMap { key, value -> OpenVPNProfile? in
            guard let fields = value as? [String: Any] else { return nil }
            let name = (fields["name"] as? String) ?? (fields["profileName"] as? String) ?? key
            let last = (fields["lastConnected"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
            return OpenVPNProfile(id: (fields["id"] as? String) ?? key, name: name, host: fields["hostname"] as? String, lastConnected: last)
        }
        .sorted { ($0.lastConnected ?? .distantPast) > ($1.lastConnected ?? .distantPast) }
    }

    /// The profile a connection to `server` belongs to: the one NotchBox asked for if it matches, otherwise
    /// the one used most recently.
    public static func profile(forServer server: String, in profiles: [OpenVPNProfile], preferring preferredID: String?) -> OpenVPNProfile? {
        let matching = profiles.filter { $0.host == server }
        return matching.first { $0.id == preferredID } ?? matching.first
    }

    private static func json(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
