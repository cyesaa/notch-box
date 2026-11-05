import Foundation
import NotchBoxCore

/// Absolute paths of the bundled adapter script, framework and test client.
struct AdapterLocation {
    /// `defaults write com.notchbox.NotchBox SimulateAdapterFailure -bool true` points the app at a
    /// missing script, which is how degraded mode is tested by hand.
    static let simulateFailureKey = "SimulateAdapterFailure"
    /// `defaults write com.notchbox.NotchBox SimulateHealthCheckFailure -bool true` points the health
    /// check at a missing test client. `stream` keeps working, but `test` fails whenever nothing is
    /// playing, which is how a silently blocked MediaRemote is tested by hand.
    static let simulateHealthCheckFailureKey = "SimulateHealthCheckFailure"
    static let testClientName = "MediaRemoteAdapterTestClient"

    let scriptPath: String
    let frameworkPath: String
    let testClientPath: String

    var baseArguments: [String] {
        AdapterCommandLine.baseArguments(scriptPath: scriptPath, frameworkPath: frameworkPath)
    }

    var healthCheckArguments: [String] {
        AdapterCommandLine.healthCheckArguments(scriptPath: scriptPath, frameworkPath: frameworkPath, testClientPath: testClientPath)
    }

    static func resolve(bundle: Bundle = .main, defaults: UserDefaults = .standard) -> AdapterLocation {
        let missingScript = "/nonexistent/mediaremote-adapter.pl"
        let script = defaults.bool(forKey: simulateFailureKey)
            ? missingScript
            : bundle.path(forResource: "mediaremote-adapter", ofType: "pl") ?? missingScript
        let framework = bundle.privateFrameworksPath.map { $0 + "/MediaRemoteAdapter.framework" }
            ?? "/nonexistent/MediaRemoteAdapter.framework"
        let missingClient = "/nonexistent/" + testClientName
        let client = defaults.bool(forKey: simulateHealthCheckFailureKey)
            ? missingClient
            : bundle.path(forAuxiliaryExecutable: testClientName) ?? missingClient
        return AdapterLocation(scriptPath: script, frameworkPath: framework, testClientPath: client)
    }
}
