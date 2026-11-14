import Foundation

/// "Version/<installed Safari> Safari/605.1.15", appended to WebKit's bare user agent so YouTube's own
/// pages and Google's sign-in behave as they do in Safari.
enum SafariUserAgent {
    static let applicationName: String = {
        let version = Bundle(path: "/Applications/Safari.app")?.infoDictionary?["CFBundleShortVersionString"] as? String
        return "Version/\(version ?? "18.0") Safari/605.1.15"
    }()
}
