import Foundation

/// A VPN configured in macOS (System Settings → VPN, or by an app such as FortiClient).
public struct VPNServiceInfo: Equatable, Sendable {
    /// The network service ID (a UUID string).
    public let id: String
    public let name: String
    /// The app extension that runs the VPN, for VPNs added by apps (`com.fortinet.forticlient.macos.vpn`).
    public let providerBundleID: String?
    public let isEnabled: Bool

    public init(id: String, name: String, providerBundleID: String?, isEnabled: Bool) {
        self.id = id
        self.name = name
        self.providerBundleID = providerBundleID
        self.isEnabled = isEnabled
    }

    public var isFortiClient: Bool {
        providerBundleID?.hasPrefix("com.fortinet.") == true
    }

    /// FortiClient names its configuration just "VPN".
    public var displayName: String {
        isFortiClient ? "FortiClient VPN" : name
    }
}

/// Reads `scutil --nc list`.
public enum VPNServiceList {
    /// `* (Disconnected)   <UUID> VPN (<bundle id>) "<name>"   [VPN:<bundle id>]`
    private static let line = try! NSRegularExpression(
        pattern: #"^\s*(\*)?\s*\([^)]*\)\s+([0-9A-Fa-f-]{36})\s+(?:\S+)(?:\s+\(([^)]+)\))?\s+"([^"]*)""#
    )

    public static func parse(_ output: String) -> [VPNServiceInfo] {
        output.split(whereSeparator: \.isNewline).compactMap { raw in
            let text = String(raw)
            let range = NSRange(text.startIndex..., in: text)
            guard let match = line.firstMatch(in: text, range: range) else { return nil }
            func group(_ index: Int) -> String? {
                Range(match.range(at: index), in: text).map { String(text[$0]) }
            }
            guard let id = group(2), let name = group(4) else { return nil }
            return VPNServiceInfo(id: id, name: name, providerBundleID: group(3), isEnabled: group(1) != nil)
        }
    }

    /// FortiClient's VPN if there is one, otherwise the first enabled VPN, otherwise the first.
    public static func preferred(in services: [VPNServiceInfo]) -> VPNServiceInfo? {
        services.first(where: \.isFortiClient) ?? services.first(where: \.isEnabled) ?? services.first
    }
}

public enum VPNStatus: Equatable, Sendable {
    case unavailable
    case disconnected
    case connecting
    case connected
    case disconnecting

    /// From `SCNetworkConnectionStatus` (-1 invalid, 0 disconnected, 1 connecting, 2 connected, 3 disconnecting).
    public init(systemStatus: Int32) {
        switch systemStatus {
        case 0: self = .disconnected
        case 1: self = .connecting
        case 2: self = .connected
        case 3: self = .disconnecting
        default: self = .unavailable
        }
    }
}

/// Remembers when the VPN came up, to show how long it has been connected.
public struct VPNConnectionClock: Equatable, Sendable {
    public private(set) var isConnected = false
    /// When NotchBox saw the connection come up; nil when it was already up at launch.
    public private(set) var connectedSince: Date?

    public init() {}

    public mutating func update(_ status: VPNStatus, at date: Date, isFirstReading: Bool = false) {
        let connected = status == .connected
        if connected, !isConnected {
            connectedSince = isFirstReading ? nil : date
        } else if !connected {
            connectedSince = nil
        }
        isConnected = connected
    }
}
