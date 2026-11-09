import AppKit
import NotchBoxCore

/// Finds the notched screen, or a screen for a virtual notch when there is none, and reports changes
/// (monitors, resolution, lid, the "show on screens without a notch" setting).
@MainActor
final class ScreenWatcher {
    /// UserDefaults key; on unless turned off in the menu.
    static let showWithoutNotchKey = "ShowOnScreensWithoutNotch"

    static var showsWithoutNotch: Bool {
        get { UserDefaults.standard.object(forKey: showWithoutNotchKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: showWithoutNotchKey) }
    }

    /// UserDefaults key; off unless turned on in the menu: a virtual notch stays visible while idle.
    static let hideIdleKey = "HideIdleVirtualNotch"

    static var hidesIdleVirtualNotch: Bool {
        get { UserDefaults.standard.bool(forKey: hideIdleKey) }
        set { UserDefaults.standard.set(newValue, forKey: hideIdleKey) }
    }

    var onChange: ((NotchGeometry?) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var last: NotchGeometry??

    func start() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        observers.append(center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh(onlyIfChanged: true) }
        })
        refresh()
    }

    func refresh(onlyIfChanged: Bool = false) {
        let geometry = Self.currentGeometry()
        if onlyIfChanged, let last, last == geometry { return }
        last = geometry
        onChange?(geometry)
    }

    static func currentGeometry() -> NotchGeometry? {
        // For testing on a notched Mac: `defaults write com.notchbox.NotchBox ForceVirtualNotch -bool YES`
        // treats every screen as one without a notch.
        let ignoreNotches = UserDefaults.standard.bool(forKey: "ForceVirtualNotch")
        // The first screen is the one with the menu bar.
        let screens = NSScreen.screens.map { screen in
            NotchGeometry.ScreenInfo(
                frame: screen.frame,
                visibleTop: screen.visibleFrame.maxY,
                safeAreaTop: ignoreNotches ? 0 : screen.safeAreaInsets.top,
                auxiliaryTopLeft: ignoreNotches ? nil : screen.auxiliaryTopLeftArea,
                auxiliaryTopRight: ignoreNotches ? nil : screen.auxiliaryTopRightArea
            )
        }
        return NotchGeometry.choose(from: screens, allowVirtual: showsWithoutNotch)
    }
}
