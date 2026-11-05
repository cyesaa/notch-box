import Foundation
import NotchBoxCore

/// Absolute paths of the bundled adapter script and framework.
struct AdapterLocation {
    /// `defaults write com.notchbox.NotchBox SimulateAdapterFailure -bool true` points the app at a
    /// missing script, which is how degraded mode is tested by hand.
    static let simulateFailureKey = "SimulateAdapterFailure"

    let scriptPath: String
    let frameworkPath: String

    var baseArguments: [String] {
        AdapterCommandLine.baseArguments(scriptPath: scriptPath, frameworkPath: frameworkPath)
    }

    static func resolve(bundle: Bundle = .main, defaults: UserDefaults = .standard) -> AdapterLocation {
        let missingScript = "/nonexistent/mediaremote-adapter.pl"
        let script = defaults.bool(forKey: simulateFailureKey)
            ? missingScript
            : bundle.path(forResource: "mediaremote-adapter", ofType: "pl") ?? missingScript
        let framework = bundle.privateFrameworksPath.map { $0 + "/MediaRemoteAdapter.framework" }
            ?? "/nonexistent/MediaRemoteAdapter.framework"
        return AdapterLocation(scriptPath: script, frameworkPath: framework)
    }
}
