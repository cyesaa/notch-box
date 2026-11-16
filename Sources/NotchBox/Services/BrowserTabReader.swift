import AppKit
import NotchBoxCore
import os
import ScriptingBridge

@MainActor
protocol BrowserTabReading: AnyObject {
    /// Reads the open tabs of every running copy of the browser with `bundleIdentifier`;
    /// completes on the main thread.
    func readTabs(of bundleIdentifier: String, completion: @escaping @MainActor (Result<[BrowserTab], Error>) -> Void)
    /// Reads the address of the tab in view in the front window of one running copy of a browser (nil
    /// when it has no window); completes on the main thread.
    func readActiveTab(of bundleIdentifier: String, process: pid_t, completion: @escaping @MainActor (Result<String?, Error>) -> Void)
}

/// Reads browser tabs through ScriptingBridge, addressing each running copy of the browser by process ID.
/// (An AppleScript `tell application "Google Chrome"` reaches only one copy, so a second Chrome, for example
/// one started by a test tool, hid the user's windows.) Runs off the main thread, because the first read
/// waits for macOS to ask "NotchBox wants to control <browser>" (Automation permission).
@MainActor
final class BrowserTabReader: BrowserTabReading {
    enum ReadError: Error, Equatable {
        case unsupportedBrowser
        case notRunning
        /// Every copy refused the Apple Events: usually the Automation permission was denied.
        case notAuthorized
    }

    private let queue = DispatchQueue(label: "com.notchbox.NotchBox.browser-tabs", qos: .userInitiated)
    private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "browser")

    func readTabs(of bundleIdentifier: String, completion: @escaping @MainActor (Result<[BrowserTab], Error>) -> Void) {
        guard let titleKey = BrowserTabs.titleKey(forBundleIdentifier: bundleIdentifier) else {
            completion(.failure(ReadError.unsupportedBrowser))
            return
        }
        let processes = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .map(\.processIdentifier)
        guard !processes.isEmpty else {
            completion(.failure(ReadError.notRunning))
            return
        }
        let logger = self.logger
        queue.async {
            let perProcess = processes.map { Self.tabs(ofProcess: $0, titleKey: titleKey) }
            let tabs = perProcess.compactMap { $0 }.flatMap { $0 }
            let refusedCount = perProcess.filter { $0 == nil }.count
            let videos = tabs.filter { YouTubeLink.videoID(from: $0.url) != nil }.count
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    logger.notice("Read \(tabs.count, privacy: .public) tabs from \(processes.count, privacy: .public) browser processes (\(videos, privacy: .public) YouTube videos, \(refusedCount, privacy: .public) refused)")
                    completion(refusedCount == processes.count ? .failure(ReadError.notAuthorized) : .success(tabs))
                }
            }
        }
    }

    func readActiveTab(of bundleIdentifier: String, process: pid_t, completion: @escaping @MainActor (Result<String?, Error>) -> Void) {
        guard let tabKey = BrowserTabs.activeTabKey(forBundleIdentifier: bundleIdentifier) else {
            completion(.failure(ReadError.unsupportedBrowser))
            return
        }
        queue.async {
            let result = Self.activeTabURL(ofProcess: process, tabKey: tabKey)
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(result) } }
        }
    }

    /// The address of the tab in view in a browser process's front window. The address is never logged.
    private nonisolated static func activeTabURL(ofProcess process: pid_t, tabKey: String) -> Result<String?, Error> {
        guard let app = SBApplication(processIdentifier: process) else { return .failure(ReadError.notRunning) }
        let errors = EventErrors()
        app.delegate = errors
        // Windows are listed front to back.
        guard let windows = app.value(forKey: "windows") as? SBElementArray, let window = windows.firstObject as? SBObject else {
            return errors.failed ? .failure(ReadError.notAuthorized) : .success(nil)
        }
        let tab = window.value(forKey: tabKey) as? SBObject
        // A property comes back as its value, or as a reference that still has to be fetched.
        let raw = tab?.value(forKey: "URL")
        let url = (raw as? String) ?? ((raw as? SBObject)?.get() as? String)
        if url == nil, errors.failed { return .failure(ReadError.notAuthorized) }
        return .success(url)
    }

    /// The tabs of one browser process, or nil when it refused (or failed) the Apple Events.
    private nonisolated static func tabs(ofProcess process: pid_t, titleKey: String) -> [BrowserTab]? {
        guard let app = SBApplication(processIdentifier: process) else { return nil }
        let errors = EventErrors()
        app.delegate = errors
        guard let windows = app.value(forKey: "windows") as? SBElementArray else { return nil }
        var tabs: [BrowserTab] = []
        for case let window as SBObject in windows {
            guard let windowTabs = window.value(forKey: "tabs") as? SBElementArray else { continue }
            // One Apple Event per list instead of two per tab.
            let urls = (windowTabs.value(forKey: "URL") as? [Any] ?? []).map { $0 as? String ?? "" }
            let titles = (windowTabs.value(forKey: titleKey) as? [Any] ?? []).map { $0 as? String ?? "" }
            tabs += BrowserTabs.tabs(urls: urls, titles: titles)
        }
        return errors.failed && tabs.isEmpty ? nil : tabs
    }
}

/// Records failed Apple Events instead of logging them, so a refusal can be told apart from "no tabs".
private final class EventErrors: NSObject, SBApplicationDelegate {
    private(set) var failed = false

    func eventDidFail(_ event: UnsafePointer<AppleEvent>, withError error: Error) -> Any? {
        failed = true
        return nil
    }
}
