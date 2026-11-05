import AppKit

@MainActor
enum AppIconProvider {
    private static var cache: [String: NSImage] = [:]

    static func icon(for bundleIdentifier: String) -> NSImage? {
        if let cached = cache[bundleIdentifier] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleIdentifier] = icon
        return icon
    }

    static func open(bundleIdentifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }
}
