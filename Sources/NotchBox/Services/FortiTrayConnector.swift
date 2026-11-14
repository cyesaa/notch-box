import AppKit
import ApplicationServices
import NotchBoxCore
import os

@MainActor
protocol FortiTrayConnecting: AnyObject {
    /// Whether NotchBox may control other apps' UI (the Accessibility permission).
    var isTrusted: Bool { get }
    /// Shows the Accessibility prompt that sends the user to System Settings.
    func requestTrust()
    /// Connects FortiClient's VPN by pressing its menu bar item, without opening the menu on screen.
    /// False when it could not (FortiTray not running, no permission), so the caller opens FortiClient.
    func connect() -> Bool
}

/// Connects FortiClient's VPN the way its menu bar icon does: by pressing FortiTray's VPN item, which uses
/// the credentials FortiClient has saved (no password). FortiClient refuses a VPN that macOS starts (see
/// `VPNService`) and offers no command or URL to connect, so NotchBox drives its menu through the
/// Accessibility API. The VPN item is the first enabled one (after the disabled "VPN" heading).
/// Disconnecting stays with macOS (`VPNService.disconnect`): pressing the item to disconnect leaves
/// FortiTray stuck on a nameless "Disconnect " that ignores every press.
@MainActor
final class FortiTrayConnector: FortiTrayConnecting {
    /// FortiTray's launchd job, restarted to repair it.
    static let trayJob = "com.fortinet.forticlient.fortitray"
    /// How long a restarted FortiTray takes to show its menu again.
    static let repairDelay: TimeInterval = 3
    /// How long to wait for FortiClient's console to quit before connecting anyway (it takes a few seconds).
    static let consoleQuitTimeout: TimeInterval = 8

    private static let notRunning = "<notrunning>"
    private static let noItem = "<noitem>"
    private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "vpn")

    var isTrusted: Bool { AXIsProcessTrusted() }

    func requestTrust() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
    }

    func connect() -> Bool {
        guard let label = itemLabel() else { return false }
        switch FortiTrayItem.connectStep(label: label) {
        case .press:
            quitConsole { [weak self] in _ = self?.press() }
            return true
        case .nothing:
            logger.notice("FortiClient is already connecting; not pressing")
            return true
        case .repair:
            logger.notice("FortiTray is stuck; restarting it before connecting")
            repair()
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.repairDelay) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, let label = self.itemLabel(),
                          FortiTrayItem.connectStep(label: label) == .press else { return }
                    self.quitConsole { [weak self] in _ = self?.press() }
                }
            }
            return true
        }
    }

    /// FortiClient's console brings its window forward the moment the VPN comes up. The VPN connects just
    /// the same (and faster) without the console running, and then nothing appears at all, so it is asked
    /// to quit first: unless the user is in it right now. FortiTray and FortiClient's services stay.
    private func quitConsole(then action: @escaping @MainActor () -> Void) {
        let consoles = NSRunningApplication.runningApplications(withBundleIdentifier: FortiTrayItem.consoleBundleID)
        guard !consoles.isEmpty, !consoles.contains(where: \.isActive) else {
            action()
            return
        }
        logger.notice("Quitting FortiClient's console before connecting")
        consoles.forEach { $0.terminate() }
        waitForExit(of: consoles, until: Date().addingTimeInterval(Self.consoleQuitTimeout), then: action)
    }

    private func waitForExit(of apps: [NSRunningApplication], until deadline: Date, then action: @escaping @MainActor () -> Void) {
        if apps.allSatisfy(\.isTerminated) || Date() >= deadline {
            action()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            MainActor.assumeIsolated { self?.waitForExit(of: apps, until: deadline, then: action) }
        }
    }

    /// Restarts FortiTray's launchd job; its menu is back within a couple of seconds. The first connection
    /// after that takes most of a minute instead of a few seconds.
    private func repair() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["kickstart", "-k", "gui/\(getuid())/\(Self.trayJob)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            logger.error("Could not restart FortiTray: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The VPN item's label, or nil when FortiTray is not running or cannot be read.
    private func itemLabel() -> String? {
        let source = """
        tell application "System Events"
          if not (exists process "FortiTray") then return "\(Self.notRunning)"
          tell process "FortiTray"
            repeat with mi in (menu items of menu 1 of menu bar item 1 of menu bar 1)
              if enabled of mi then
                try
                  return name of mi
                end try
                return ""
              end if
            end repeat
            return "\(Self.noItem)"
          end tell
        end tell
        """
        guard let label = run(source), label != Self.notRunning, label != Self.noItem else { return nil }
        return label
    }

    /// AXPress on the item, without clicking the menu bar item open, so nothing flashes on screen.
    private func press() -> Bool {
        let source = """
        tell application "System Events"
          tell process "FortiTray"
            repeat with mi in (menu items of menu 1 of menu bar item 1 of menu bar 1)
              if enabled of mi then
                perform action "AXPress" of mi
                return "pressed"
              end if
            end repeat
            return "\(Self.noItem)"
          end tell
        end tell
        """
        let result = run(source)
        logger.notice("FortiTray press: \(result ?? "failed", privacy: .public)")
        return result == "pressed"
    }

    private func run(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let output = script.executeAndReturnError(&error)
        if let error {
            logger.error("FortiTray AppleScript failed: \(error, privacy: .public)")
            return nil
        }
        return output.stringValue
    }
}
