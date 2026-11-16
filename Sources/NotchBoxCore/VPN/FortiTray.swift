import Foundation

/// The VPN item in FortiClient's menu bar menu (FortiTray): "Connect to <name>" while the VPN is down,
/// "Disconnect <name>" while it is up or coming up. NotchBox presses it to connect with the credentials
/// FortiClient has saved.
public enum FortiTrayItem {
    /// FortiClient's window app (the "console"). The VPN connects without it; while it runs, it brings its
    /// window forward every time the VPN comes up.
    public static let consoleBundleID = "com.fortinet.FortiClient"

    public enum Kind: Equatable, Sendable {
        case connect
        case disconnect
        /// The label has no VPN name ("Disconnect "): FortiTray lost track after hurried presses and
        /// ignores every press until it is restarted.
        case stuck
        /// Not English, so the label does not say which way the press goes.
        case unknown
    }

    public enum ConnectStep: Equatable, Sendable {
        case press
        /// FortiClient is already bringing the VPN up; a press would cancel it.
        case nothing
        /// Restart FortiTray first.
        case repair
    }

    public static func kind(ofLabel label: String) -> Kind {
        // The label is "<verb> <name>"; without a name it ends in the space.
        if let last = label.unicodeScalars.last, CharacterSet.whitespaces.contains(last) { return .stuck }
        if label.hasPrefix("Disconnect") { return .disconnect }
        if label.hasPrefix("Connect") { return .connect }
        return .unknown
    }

    /// What to do with the item to connect. (Disconnecting goes through macOS instead: pressing the item
    /// to disconnect leaves FortiTray stuck.)
    public static func connectStep(label: String) -> ConnectStep {
        switch kind(ofLabel: label) {
        case .stuck: return .repair
        case .disconnect: return .nothing
        case .connect, .unknown: return .press
        }
    }
}

/// What NotchBox asked a VPN app to do and has not seen happen yet. The VPN still reads as disconnected
/// while FortiClient signs in (a few seconds, sometimes most of a minute) or OpenVPN Connect starts, so
/// without this the notch would go on offering "Connect", and a second press cancels the connection that
/// is coming up.
public struct VPNPendingAction: Equatable, Sendable {
    public enum Target: Equatable, Sendable {
        case connected
        case disconnected
    }

    public static let connectTimeout: TimeInterval = 90
    public static let disconnectTimeout: TimeInterval = 15
    /// How long "disconnecting" stays after a disconnect, even once the VPN is down: connecting again
    /// while FortiClient is still tidying up confuses it.
    public static let disconnectSettle: TimeInterval = 6
    /// Presses closer together than this are ignored: they cancelled connections and left FortiTray stuck.
    public static let pressCooldown: TimeInterval = 4

    private let connectLimit: TimeInterval
    private var target: Target?
    private var since: Date?
    private var lastPress: Date?

    /// `connectTimeout`: how long "connecting" is shown before giving up on a connection.
    public init(connectTimeout: TimeInterval = VPNPendingAction.connectTimeout) {
        connectLimit = connectTimeout
    }

    public func canPress(at date: Date) -> Bool {
        guard let lastPress else { return true }
        return date.timeIntervalSince(lastPress) >= Self.pressCooldown
    }

    public mutating func pressed(toward target: Target, at date: Date) {
        self.target = target
        since = date
        lastPress = date
    }

    /// The status to show: "connecting" or "disconnecting" while waiting for what was asked, the real
    /// status once it is reached or the wait has run out.
    public mutating func displayStatus(real: VPNStatus, at date: Date) -> VPNStatus {
        guard let target, let since else { return real }
        let waited = date.timeIntervalSince(since)
        switch target {
        case .connected:
            if real == .connected || waited > connectLimit {
                clear()
                return real
            }
            return .connecting
        case .disconnected:
            if waited > Self.disconnectTimeout || (real != .connected && waited >= Self.disconnectSettle) {
                clear()
                return real
            }
            return .disconnecting
        }
    }

    /// The notch shows a status macOS has not reported yet, so there is nothing to act on: no button.
    public mutating func isWaiting(real: VPNStatus, at date: Date) -> Bool {
        displayStatus(real: real, at: date) != real
    }

    private mutating func clear() {
        target = nil
        since = nil
    }
}

/// FortiClient and OpenVPN Connect bring their own window forward when a connection comes up (FortiClient
/// at the moment the VPN is up, seconds after it was asked). After NotchBox asks one to connect, it is hidden
/// again whenever it comes forward, until shortly after the VPN is up; then the app is the user's again.
public struct VPNAppHiding: Equatable, Sendable {
    /// How long after the VPN is up the app is still hidden when it comes forward.
    public static let graceAfterConnected: TimeInterval = 5

    private var deadlines: [String: Date] = [:]

    public init() {}

    public mutating func expect(_ bundleID: String, until deadline: Date) {
        deadlines[bundleID] = deadline
    }

    public mutating func stop(_ bundleID: String) {
        deadlines[bundleID] = nil
    }

    /// The VPN is up: its app's window comes with it, so hide for a little longer and no more.
    public mutating func connected(_ bundleID: String, at date: Date) {
        guard let deadline = deadlines[bundleID] else { return }
        deadlines[bundleID] = min(deadline, date.addingTimeInterval(Self.graceAfterConnected))
    }

    public func shouldHide(_ bundleID: String, at date: Date) -> Bool {
        guard let deadline = deadlines[bundleID] else { return false }
        return date <= deadline
    }
}
