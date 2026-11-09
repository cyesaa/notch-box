import AppKit
import Darwin
import NotchBoxCore
import os

/// What NotchBox knows about OpenVPN Connect right now.
struct OpenVPNReading: Equatable {
    let status: VPNStatus
    /// From the log, so it is right even when the connection came up before NotchBox started.
    let connectedSince: Date?
    let profiles: [OpenVPNProfile]
    /// The profile of the current connection.
    let activeProfile: OpenVPNProfile?
}

@MainActor
protocol OpenVPNControlling: AnyObject {
    /// OpenVPN Connect is installed.
    var isInstalled: Bool { get }
    func read(preferring profileID: String?) -> OpenVPNReading
    func connect(profileID: String)
    func disconnect()
    func openApp()
}

/// Talks to OpenVPN Connect 3: its state comes from its log and config (it has no API), and it connects and
/// disconnects through its own command-line switches `--connect-shortcut=<profile id>` and
/// `--disconnect-shortcut` (the ones its Siri shortcuts use), which hand the request to the running app.
@MainActor
final class OpenVPNConnectService: OpenVPNControlling {
    static let bundleIdentifier = "org.openvpn.client.app"
    /// The end of the log that is read: the last event is always near the end.
    static let logTailBytes = 256 * 1024

    private let dataDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/OpenVPN Connect", isDirectory: true)
    private var profilesCache: (modified: Date, profiles: [OpenVPNProfile])?
    private var logCache: (modified: Date, size: Int, state: OpenVPNLogState?)?
    private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "vpn")

    private var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleIdentifier)
    }

    var isInstalled: Bool { appURL != nil }

    func read(preferring profileID: String?) -> OpenVPNReading {
        let profiles = loadProfiles()
        let state = loadLogState()
        let running = !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).isEmpty
        let status = OpenVPNLog.status(of: state, appRunning: running, interfaceUp: Self.hasIPv4Address)
        let active = state?.server.flatMap { OpenVPNProfiles.profile(forServer: $0, in: profiles, preferring: profileID) }
        return OpenVPNReading(
            status: status,
            connectedSince: status == .connected ? state?.date : nil,
            profiles: profiles,
            activeProfile: status == .disconnected ? nil : active
        )
    }

    func connect(profileID: String) {
        run(["--connect-shortcut=\(profileID)"])
    }

    func disconnect() {
        run(["--disconnect-shortcut"])
    }

    func openApp() {
        AppIconProvider.open(bundleIdentifier: Self.bundleIdentifier)
    }

    /// Starting the app's binary with a switch passes it to the running app (or starts the app with it).
    private func run(_ arguments: [String]) {
        guard let executable = appURL.flatMap({ Bundle(url: $0)?.executableURL }) else { return }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            logger.error("Could not reach OpenVPN Connect: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadProfiles() -> [OpenVPNProfile] {
        let url = dataDirectory.appendingPathComponent("config.json")
        guard let modified = Self.modificationDate(of: url) else { return [] }
        if let profilesCache, profilesCache.modified == modified { return profilesCache.profiles }
        let profiles = (try? Data(contentsOf: url)).map(OpenVPNProfiles.parse) ?? []
        profilesCache = (modified, profiles)
        return profiles
    }

    private func loadLogState() -> OpenVPNLogState? {
        let url = dataDirectory.appendingPathComponent("log/ovpn.log")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date,
              let size = (attributes[.size] as? NSNumber)?.intValue
        else { return nil }
        if let logCache, logCache.modified == modified, logCache.size == size { return logCache.state }
        var state: OpenVPNLogState?
        if let handle = try? FileHandle(forReadingFrom: url) {
            defer { try? handle.close() }
            try? handle.seek(toOffset: UInt64(max(0, size - Self.logTailBytes)))
            if let data = try? handle.readToEnd() {
                state = OpenVPNLog.lastState(in: String(decoding: data, as: UTF8.self), timeZone: .current)
            }
        }
        logCache = (modified, size, state)
        return state
    }

    private static func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// Whether a network interface (the tunnel) exists, is up and has an IPv4 address.
    private static func hasIPv4Address(_ name: String) -> Bool {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return false }
        defer { freeifaddrs(list) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            let interface = entry.pointee
            if String(cString: interface.ifa_name) == name,
               interface.ifa_flags & UInt32(IFF_UP) != 0,
               interface.ifa_addr?.pointee.sa_family == UInt8(AF_INET) {
                return true
            }
            cursor = interface.ifa_next
        }
        return false
    }
}
