import AppKit
import WebKit

/// A window where the user signs into their own YouTube account. It shares WebKit's default, persistent
/// data store with the notch player, so the session is kept and reused (a YouTube Premium account then plays
/// in the notch without ads). The user signs in on YouTube's own pages; NotchBox never sees the password.
@MainActor
final class SignInWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onClose: (() -> Void)?

    /// Opens the sign-in window (bringing the app forward so it can take keyboard focus) and calls
    /// `onClose` once the user closes it, so the player can reload with the new session.
    func show(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate()
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = SafariUserAgent.applicationName
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 480, height: 640), configuration: configuration)
        webView.load(URLRequest(url: URL(string: "https://www.youtube.com/")!))

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = L10n.signInTitle
        window.contentView = webView
        window.isReleasedWhenClosed = false
        window.delegate = self
        return window
    }

    func windowWillClose(_ notification: Notification) {
        let onClose = self.onClose
        self.onClose = nil
        // Drop the window (and its WebView) so the next sign-in starts fresh on youtube.com.
        window = nil
        onClose?()
    }
}
