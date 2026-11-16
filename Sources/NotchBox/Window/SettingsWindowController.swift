import AppKit
import SwiftUI

/// The Settings window, opened from the menu bar icon (⌘,).
@MainActor
final class SettingsWindowController {
    private let settings: AppSettings
    private let auth: AuthModel
    private let navigation = SettingsNavigation()
    private var window: NSWindow?

    init(settings: AppSettings, auth: AuthModel) {
        self.settings = settings
        self.auth = auth
    }

    func show() {
        settings.reload()
        let window = self.window ?? Self.makeWindow(settings: settings, auth: auth, navigation: navigation)
        self.window = window
        // A menu bar app has to come forward for its window to take keyboard focus.
        NSApp.activate()
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
    }

    /// The stage at the top of the window runs under the title bar, up to the window's edge: the notch
    /// in its drawing hangs from the top of the window the way the real one hangs from the top of the
    /// screen. The window's height follows the part of the settings that is showing.
    static func makeWindow(settings: AppSettings, auth: AuthModel, navigation: SettingsNavigation) -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView(settings: settings, auth: auth, navigation: navigation))
        hosting.sizingOptions = [.preferredContentSize]
        // No inset for the title bar: the view starts at the window's top edge, and the window is exactly
        // as tall as the view.
        hosting.safeAreaRegions = []
        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.settingsTitle
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        return window
    }
}
