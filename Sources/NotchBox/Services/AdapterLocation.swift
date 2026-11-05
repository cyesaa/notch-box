import Foundation
import NotchBoxCore

/// Absolute paths of the bundled adapter script and framework.
struct AdapterLocation {
    /// `defaults write com.notchbox.NotchBox AdapterScriptOverride /path` replaces the script
    /// (a missing path is how degraded mode is tested by hand).
    static let scriptOverrideKey = "AdapterScriptOverride"

    let scriptPath: String
    let frameworkPath: String

    var baseArguments: [String] {
        AdapterCommandLine.baseArguments(scriptPath: scriptPath, frameworkPath: frameworkPath)
    }

    static func resolve(bundle: Bundle = .main, defaults: UserDefaults = .standard) -> AdapterLocation {
        let script = defaults.string(forKey: scriptOverrideKey)
            ?? bundle.path(forResource: "mediaremote-adapter", ofType: "pl")
            ?? "/nonexistent/mediaremote-adapter.pl"
        let framework = bundle.privateFrameworksPath.map { $0 + "/MediaRemoteAdapter.framework" }
            ?? "/nonexistent/MediaRemoteAdapter.framework"
        return AdapterLocation(scriptPath: script, frameworkPath: framework)
    }
}
