import AppKit
import NotchBoxCore
import os
import ServiceManagement

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let launchAtLoginItem = NSMenuItem()
    private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "status-item")

    override init() {
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "NotchBox")

        launchAtLoginItem.title = L10n.launchAtLogin
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        launchAtLoginItem.target = self

        let quitItem = NSMenuItem(title: L10n.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            logger.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
