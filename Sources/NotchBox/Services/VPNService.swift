import AppKit
import NotchBoxCore
import os
import SystemConfiguration

@MainActor
protocol VPNControlling: AnyObject {
    /// The VPNs configured in macOS.
    func services() -> [VPNServiceInfo]
    func status(of serviceID: String) -> VPNStatus
    /// Asks macOS to disconnect, as the VPN menu in System Settings does.
    func disconnect(_ serviceID: String)
}

/// Reads VPN state through SystemConfiguration. Connecting is left to the VPN's own app: FortiClient's VPN
/// starts only from FortiClient (started by macOS it goes back to disconnected at once), so this only reads
/// the status and disconnects.
@MainActor
final class VPNService: VPNControlling {
    /// How long the list of VPNs is reused before `scutil` is asked again.
    static let listLifetime: TimeInterval = 30

    private var cachedServices: (date: Date, services: [VPNServiceInfo])?
    private var connections: [String: SCNetworkConnection] = [:]
    private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "vpn")

    func services() -> [VPNServiceInfo] {
        if let cachedServices, Date().timeIntervalSince(cachedServices.date) < Self.listLifetime {
            return cachedServices.services
        }
        let services = VPNServiceList.parse(Self.runScutilList())
        cachedServices = (Date(), services)
        return services
    }

    func status(of serviceID: String) -> VPNStatus {
        guard let connection = connection(for: serviceID) else { return .unavailable }
        let status = VPNStatus(systemStatus: SCNetworkConnectionGetStatus(connection).rawValue)
        if status == .unavailable {
            // FortiClient replaces its VPN configuration (with a new ID) when it connects; read the list again.
            connections[serviceID] = nil
            cachedServices = nil
        }
        return status
    }

    func disconnect(_ serviceID: String) {
        guard let connection = connection(for: serviceID) else { return }
        if !SCNetworkConnectionStop(connection, true) {
            let reason = String(cString: SCErrorString(SCError()))
            logger.error("Could not disconnect the VPN: \(reason, privacy: .public)")
        }
    }

    private func connection(for serviceID: String) -> SCNetworkConnection? {
        if let connection = connections[serviceID] { return connection }
        guard let connection = SCNetworkConnectionCreateWithServiceID(nil, serviceID as CFString, nil, nil) else { return nil }
        connections[serviceID] = connection
        return connection
    }

    /// `scutil --nc list` is the simplest way to see VPNs added by apps (with their extension's bundle ID).
    private static func runScutilList() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        process.arguments = ["--nc", "list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
