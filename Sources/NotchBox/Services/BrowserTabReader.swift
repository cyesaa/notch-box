import Foundation
import NotchBoxCore
import os

@MainActor
protocol BrowserTabReading: AnyObject {
    /// Reads the open tabs of the browser with `bundleIdentifier`; completes on the main thread.
    func readTabs(of bundleIdentifier: String, completion: @escaping @MainActor (Result<[BrowserTab], Error>) -> Void)
}

/// Runs the `BrowserTabs` AppleScript with `/usr/bin/osascript`, off the main thread, because the
/// first run waits for macOS to ask "NotchBox wants to control <browser>" (Automation permission).
@MainActor
final class BrowserTabReader: BrowserTabReading {
    enum ReadError: Error {
        case unsupportedBrowser
        /// Non-zero exit: usually the Automation permission was denied.
        case scriptFailed(Int32, String)
    }

    static let timeout: TimeInterval = 60

    private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "browser")

    func readTabs(of bundleIdentifier: String, completion: @escaping @MainActor (Result<[BrowserTab], Error>) -> Void) {
        guard let script = BrowserTabs.script(forBundleIdentifier: bundleIdentifier) else {
            completion(.failure(ReadError.unsupportedBrowser))
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
        } catch {
            completion(.failure(error))
            return
        }
        let logger = self.logger
        // Drain the pipes while the script runs: many tabs can exceed the pipe buffer and block osascript.
        DispatchQueue.global(qos: .userInitiated).async {
            let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            process.waitUntilExit()
            let status = process.terminationStatus
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard status == 0 else {
                        logger.error("Reading browser tabs failed (\(status)): \(message, privacy: .public)")
                        completion(.failure(ReadError.scriptFailed(status, message)))
                        return
                    }
                    completion(.success(BrowserTabs.parse(text)))
                }
            }
        }
        // The permission prompt can stay open; give up eventually instead of leaving a process behind.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeout) {
            if process.isRunning { process.terminate() }
        }
    }
}
