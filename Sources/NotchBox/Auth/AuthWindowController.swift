import AppKit
import SwiftUI

/// The window where accounts are imported and deleted. Opening it asks for Touch ID (or the Mac's
/// password): it is the one place where the stored accounts can be changed.
@MainActor
final class AuthWindowController: NSObject, NSWindowDelegate {
    private let auth: AuthModel
    private var window: NSWindow?
    private var state: AuthManageState?
    private var isAsking = false

    init(auth: AuthModel) {
        self.auth = auth
    }

    func show() {
        if let window, window.isVisible {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        guard !isAsking else { return }
        isAsking = true
        DeviceOwnerCheck.confirm(reason: L10n.authUnlockReason) { [weak self] allowed in
            guard let self else { return }
            self.isAsking = false
            if allowed { self.open() }
        }
    }

    private func open() {
        // Read what is stored before showing it; an import then adds to it.
        auth.reload()
        let state = AuthManageState()
        self.state = state
        let hosting = NSHostingController(rootView: AuthManageView(auth: auth, state: state))
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.authWindowTitle
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        // A menu bar app has to come forward for its window to take keyboard focus.
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Closing turns the camera off and locks the accounts again: the next opening asks once more.
        state?.stopScanning()
        state = nil
        window?.contentViewController = nil
        window = nil
    }
}
