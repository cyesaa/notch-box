import AppKit
import NotchBoxCore

/// Finds the built-in notched screen and reports changes (monitors, resolution, lid).
@MainActor
final class ScreenWatcher {
    var onChange: ((NotchGeometry?) -> Void)?
    private var observer: NSObjectProtocol?

    func start() {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    func refresh() {
        onChange?(Self.currentGeometry())
    }

    static func currentGeometry() -> NotchGeometry? {
        for screen in NSScreen.screens {
            if let geometry = NotchGeometry(
                screenFrame: screen.frame,
                safeAreaTop: screen.safeAreaInsets.top,
                auxiliaryTopLeft: screen.auxiliaryTopLeftArea,
                auxiliaryTopRight: screen.auxiliaryTopRightArea
            ) {
                return geometry
            }
        }
        return nil
    }
}
