import AppKit
import NotchBoxCore
import SwiftUI

/// Owns the panel: positions it over the notch and keeps hover/click handling in sync with the state.
@MainActor
final class NotchWindowController {
    private let panel = NotchPanel()
    private let model: NotchViewModel
    private let hoverTracker = HoverTracker()
    private let screenWatcher = ScreenWatcher()
    private var geometry: NotchGeometry?
    private var defaultsObserver: NSObjectProtocol?

    init(model: NotchViewModel) {
        self.model = model
        let hostingView = FirstMouseHostingView(rootView: NotchRootView(model: model))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
    }

    func start() {
        model.onDisplayStateChange = { [weak self] _ in self?.updateInteraction() }
        hoverTracker.onHoverChange = { [weak self] hovering, depth in self?.hoverChanged(hovering, depth: depth) }
        hoverTracker.onButtonHoverChange = { [weak self] _ in self?.updateInteraction() }
        screenWatcher.onChange = { [weak self] geometry in self?.apply(geometry) }
        model.setHidesIdleVirtualNotch(ScreenWatcher.hidesIdleVirtualNotch)
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.setHidesIdleVirtualNotch(ScreenWatcher.hidesIdleVirtualNotch) }
        }
        screenWatcher.start()
        hoverTracker.start()
    }

    private func apply(_ geometry: NotchGeometry?) {
        self.geometry = geometry
        guard let geometry else {
            panel.orderOut(nil)
            hoverTracker.hotZone = .null
            return
        }
        model.setNotchSize(geometry.notchSize, isVirtual: geometry.isVirtual)
        panel.setFrame(geometry.panelFrame(for: NotchLayout.windowSize(notch: geometry.notchSize)), display: true)
        panel.orderFrontRegardless()
        updateInteraction()
    }

    private func hoverChanged(_ hovering: Bool, depth: CGFloat) {
        let notchHeight = geometry?.notchSize.height ?? 0
        model.hoverChanged(hovering, entry: hovering ? NotchInteraction.entry(atDepth: depth, notchHeight: notchHeight) : nil)
        // Whether the video takes clicks depends on where the cursor came in.
        updateInteraction()
    }

    private func updateInteraction() {
        guard let geometry else { return }
        let state = model.displayState
        let offset = NotchLayout.horizontalOffset(for: state, sides: model.sideWidgets)
        hoverTracker.hotZone = geometry.panelFrame(for: model.contentSize, offsetX: offset)
        // The one clickable control of a click-through state. A little slack around the close button makes
        // it easy to hit while everything else clicks through.
        let button: CGRect?
        switch state {
        case .video: button = NotchLayout.videoCloseButtonFrame(notch: geometry.notchSize).insetBy(dx: -4, dy: -4)
        case .mini: button = NotchLayout.miniActionFrame(notch: geometry.notchSize)
        default: button = nil
        }
        hoverTracker.buttonSuppressesHover = NotchInteraction.buttonSuppressesHover(in: state)
        hoverTracker.buttonZone = button.map { geometry.screenRect(for: $0, inContentOf: model.contentSize, offsetX: offset) } ?? .null
        let overButton = hoverTracker.isOverButton
        model.notchButtonHoverChanged(overButton)
        panel.ignoresMouseEvents = !NotchInteraction.acceptsClicks(in: state, cursorOverButton: overButton, entry: model.hoverEntry)
    }
}
