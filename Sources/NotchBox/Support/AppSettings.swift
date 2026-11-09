import AppKit
import NotchBoxCore
import Observation
import os
import ServiceManagement

/// Everything the Settings window changes, saved in UserDefaults. The screen watcher and the update
/// service read their own keys; the side widgets are passed on through `onSideWidgetsChange`.
@MainActor
@Observable
final class AppSettings {
    private static let sideWidgetsKey = "SideWidgets"

    private(set) var sideWidgets: SideWidgets
    private(set) var showsWithoutNotch: Bool
    private(set) var hidesIdleVirtualNotch: Bool
    private(set) var launchesAtLogin: Bool
    private(set) var checksForUpdates: Bool

    @ObservationIgnored var onSideWidgetsChange: ((SideWidgets) -> Void)?
    @ObservationIgnored let updates: UpdateService
    @ObservationIgnored private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "settings")

    init(updates: UpdateService) {
        self.updates = updates
        sideWidgets = UserDefaults.standard.data(forKey: Self.sideWidgetsKey).flatMap(SideWidgets.decode) ?? .default
        showsWithoutNotch = ScreenWatcher.showsWithoutNotch
        hidesIdleVirtualNotch = ScreenWatcher.hidesIdleVirtualNotch
        launchesAtLogin = SMAppService.mainApp.status == .enabled
        checksForUpdates = updates.checksAutomatically
    }

    /// Picks up changes made elsewhere (login items in System Settings) when the window opens.
    func reload() {
        launchesAtLogin = SMAppService.mainApp.status == .enabled
        checksForUpdates = updates.checksAutomatically
    }

    func setWidget(_ widget: NotchWidget?, on side: SideWidgets.Side) {
        var sides = sideWidgets
        sides.set(widget, on: side)
        guard sides != sideWidgets else { return }
        sideWidgets = sides
        if let data = try? JSONEncoder().encode(sides) {
            UserDefaults.standard.set(data, forKey: Self.sideWidgetsKey)
        }
        onSideWidgetsChange?(sides)
    }

    func setShowsWithoutNotch(_ value: Bool) {
        showsWithoutNotch = value
        ScreenWatcher.showsWithoutNotch = value
    }

    func setHidesIdleVirtualNotch(_ value: Bool) {
        hidesIdleVirtualNotch = value
        ScreenWatcher.hidesIdleVirtualNotch = value
    }

    func setLaunchesAtLogin(_ value: Bool) {
        do {
            if value {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
        }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setChecksForUpdates(_ value: Bool) {
        updates.checksAutomatically = value
        checksForUpdates = value
    }
}
