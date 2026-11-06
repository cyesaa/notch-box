import AppKit
import NotchBoxCore
import os

/// Looks for a newer NotchBox release on GitHub soon after launch and twice a day, and installs it by
/// running the one-line installer, which quits this copy, puts the new one in place and opens it.
/// GitHub answers only while the repository is public; otherwise the check quietly finds nothing.
@MainActor
final class UpdateService {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(LatestRelease)
        case installing
        case failed
    }

    private static let automaticKey = "CheckForUpdatesAutomatically"
    /// For testing: `defaults write com.notchbox.NotchBox UpdateFeedURL file:///path/release.json` reads that
    /// file instead of GitHub, and `UpdateInstallCommand '<shell command>'` runs that instead of the installer.
    private static let feedOverrideKey = "UpdateFeedURL"
    private static let installOverrideKey = "UpdateInstallCommand"

    private var feedURL: URL {
        UserDefaults.standard.string(forKey: Self.feedOverrideKey).flatMap(URL.init(string:)) ?? UpdateCheck.latestReleaseURL
    }

    private var installCommand: String {
        UserDefaults.standard.string(forKey: Self.installOverrideKey) ?? UpdateCheck.installCommand
    }

    private(set) var status: Status = .idle {
        didSet { if status != oldValue { onChange?() } }
    }
    var onChange: (() -> Void)?
    let currentVersion: AppVersion?
    private let session: URLSession
    private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "update")
    private var timer: Timer?

    init(bundle: Bundle = .main) {
        currentVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        session = URLSession(configuration: configuration)
    }

    var checksAutomatically: Bool {
        get { UserDefaults.standard.object(forKey: Self.automaticKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.automaticKey)
            schedule()
        }
    }

    var availableRelease: LatestRelease? {
        if case .available(let release) = status { return release }
        return nil
    }

    func start() {
        schedule()
    }

    private func schedule() {
        timer?.invalidate()
        timer = nil
        guard checksAutomatically else { return }
        let first = Timer(timeInterval: UpdateCheck.launchDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.check(userInitiated: false)
                let repeating = Timer(timeInterval: UpdateCheck.interval, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.check(userInitiated: false) }
                }
                repeating.tolerance = 60 * 10
                RunLoop.main.add(repeating, forMode: .common)
                self.timer = repeating
            }
        }
        RunLoop.main.add(first, forMode: .common)
        timer = first
    }

    /// Asks GitHub for the latest release. A user-initiated check reports its result in an alert.
    func check(userInitiated: Bool) {
        guard status != .checking, status != .installing, let currentVersion else { return }
        status = .checking
        var request = URLRequest(url: feedURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("NotchBox/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        session.dataTask(with: request) { data, response, error in
            // A file:// feed (testing) has no HTTP status.
            let code = (response as? HTTPURLResponse)?.statusCode ?? (data == nil ? 0 : 200)
            let release = code == 200 ? data.flatMap(LatestRelease.parse) : nil
            let failed = error != nil || code != 200
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.finishCheck(release: release, failed: failed, code: code, userInitiated: userInitiated)
                }
            }
        }.resume()
    }

    private func finishCheck(release: LatestRelease?, failed: Bool, code: Int, userInitiated: Bool) {
        guard let currentVersion else { return }
        if failed {
            logger.notice("Update check failed (HTTP \(code, privacy: .public))")
            status = .failed
        } else if let update = UpdateCheck.availableUpdate(current: currentVersion, latest: release) {
            logger.notice("Update available: \(update.version.description, privacy: .public)")
            status = .available(update)
        } else {
            status = .upToDate
        }
        guard userInitiated else { return }
        switch status {
        case .available: installWithConfirmation()
        case .upToDate: alert(L10n.updateUpToDate(currentVersion.description), info: nil)
        default: alert(L10n.updateCheckFailed, info: L10n.updateCheckFailedHint)
        }
    }

    /// Asks once more, then runs the installer.
    func installWithConfirmation() {
        guard let release = availableRelease, let currentVersion else { return }
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = L10n.updateAvailableTitle(release.version.description)
        alert.informativeText = L10n.updateAvailableInfo(currentVersion.description)
        alert.addButton(withTitle: L10n.updateInstall)
        alert.addButton(withTitle: L10n.updateReleaseNotes)
        alert.addButton(withTitle: L10n.updateLater)
        switch alert.runModal() {
        case .alertFirstButtonReturn: install()
        case .alertSecondButtonReturn: NSWorkspace.shared.open(release.pageURL)
        default: break
        }
    }

    /// Runs the installer in a shell that outlives this process: the installer quits NotchBox, replaces
    /// the app and opens the new one. Its output goes to ~/Library/Logs/NotchBox/update.log.
    private func install() {
        let logURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/NotchBox", isDirectory: true)
        try? FileManager.default.createDirectory(at: logURL, withIntermediateDirectories: true)
        let logFile = logURL.appendingPathComponent("update.log")
        FileManager.default.createFile(atPath: logFile.path, contents: nil)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "set -o pipefail; \(installCommand)"]
        if let handle = try? FileHandle(forWritingTo: logFile) {
            process.standardOutput = handle
            process.standardError = handle
        }
        process.terminationHandler = { process in
            // A successful install quits NotchBox first, so this runs only when the installer failed.
            let code = process.terminationStatus
            guard code != 0 else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.installFailed(code: code, log: logFile) }
            }
        }
        do {
            try process.run()
            status = .installing
            logger.notice("Running the installer")
        } catch {
            logger.error("Could not start the installer: \(error.localizedDescription, privacy: .public)")
            installFailed(code: -1, log: logFile)
        }
    }

    private func installFailed(code: Int32, log: URL) {
        logger.error("Installer exited with \(code, privacy: .public)")
        status = .failed
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(UpdateCheck.installCommand, forType: .string)
        alert(L10n.updateInstallFailed, info: L10n.updateInstallFailedHint)
        NSWorkspace.shared.activateFileViewerSelecting([log])
    }

    private func alert(_ message: String, info: String?) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = message
        if let info { alert.informativeText = info }
        alert.runModal()
    }
}
