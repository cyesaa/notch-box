import AppKit
import SwiftUI

/// The Settings window, opened from the menu bar icon (⌘,).
@MainActor
final class SettingsWindowController {
    private let settings: AppSettings
    private let auth: AuthModel
    private var window: NSWindow?

    init(settings: AppSettings, auth: AuthModel) {
        self.settings = settings
        self.auth = auth
    }

    func show() {
        settings.reload()
        let window = self.window ?? makeWindow()
        self.window = window
        // A menu bar app has to come forward for its window to take keyboard focus.
        NSApp.activate()
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView(settings: settings, auth: auth))
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.settingsTitle
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        return window
    }
}
