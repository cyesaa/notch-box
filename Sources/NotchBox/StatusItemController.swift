import AppKit
import NotchBoxCore

/// The menu bar icon: an update line when one is waiting, Settings, Check for Updates and Quit.
/// The options themselves live in the Settings window.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let updateItem = NSMenuItem()
    private let updateSeparator = NSMenuItem.separator()
    private let checkForUpdatesItem = NSMenuItem()
    private let updates: UpdateService
    private let onOpenSettings: () -> Void

    init(updates: UpdateService, onOpenSettings: @escaping () -> Void) {
        self.updates = updates
        self.onOpenSettings = onOpenSettings
        super.init()

        updateItem.action = #selector(installUpdate)
        updateItem.target = self
        checkForUpdatesItem.title = L10n.checkForUpdates
        checkForUpdatesItem.action = #selector(checkForUpdates)
        checkForUpdatesItem.target = self

        let settingsItem = NSMenuItem(title: L10n.settingsMenuItem, action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        let quitItem = NSMenuItem(title: L10n.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(updateItem)
        menu.addItem(updateSeparator)
        menu.addItem(settingsItem)
        menu.addItem(checkForUpdatesItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu

        updates.onChange = { [weak self] in self?.refresh() }
        refresh()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }

    /// The update line at the top of the menu and a dot on the icon while an update waits.
    private func refresh() {
        let release = updates.availableRelease
        let installing = updates.status == .installing
        updateItem.isHidden = release == nil && !installing
        updateSeparator.isHidden = updateItem.isHidden
        if installing {
            updateItem.attributedTitle = nil
            updateItem.title = L10n.updateInstalling
            updateItem.isEnabled = false
        } else if let release {
            updateItem.attributedTitle = NSAttributedString(
                string: L10n.updateMenuItem(release.version.description),
                attributes: [.font: NSFont.menuFont(ofSize: 0).bold]
            )
            updateItem.isEnabled = true
        }
        checkForUpdatesItem.isEnabled = updates.status != .checking && !installing
        checkForUpdatesItem.title = updates.status == .checking ? L10n.checkingForUpdates : L10n.checkForUpdates
        let version = updates.currentVersion.map { " \($0)" } ?? ""
        statusItem.button?.image = Self.icon(withDot: release != nil)
        statusItem.button?.toolTip = release.map { L10n.updateMenuItem($0.version.description) } ?? "NotchBox\(version)"
    }

    /// The music note, with a small dot at the top right when an update is available. A template image,
    /// so it follows the menu bar's colour.
    private static func icon(withDot dot: Bool) -> NSImage? {
        guard let note = NSImage(systemSymbolName: "music.note", accessibilityDescription: "NotchBox") else { return nil }
        guard dot else { return note }
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let noteSize = note.size
            note.draw(in: NSRect(
                x: (rect.width - noteSize.width) / 2 - 1, y: (rect.height - noteSize.height) / 2,
                width: noteSize.width, height: noteSize.height
            ))
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.maxX - 6, y: rect.maxY - 6, width: 5, height: 5)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "NotchBox"
        return image
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func installUpdate() {
        updates.installWithConfirmation()
    }

    @objc private func checkForUpdates() {
        updates.check(userInitiated: true)
    }
}

private extension NSFont {
    var bold: NSFont { NSFontManager.shared.convert(self, toHaveTrait: .boldFontMask) }
}
