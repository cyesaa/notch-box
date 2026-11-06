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

    init(model: NotchViewModel) {
        self.model = model
        let hostingView = FirstMouseHostingView(rootView: NotchRootView(model: model))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
    }

    func start() {
        model.onDisplayStateChange = { [weak self] _ in self?.updateInteraction() }
        hoverTracker.onHoverChange = { [weak self] hovering in self?.model.hoverChanged(hovering) }
        hoverTracker.onCloseButtonHoverChange = { [weak self] _ in self?.updateInteraction() }
        screenWatcher.onChange = { [weak self] geometry in self?.apply(geometry) }
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
        model.setNotchSize(geometry.notchSize)
        panel.setFrame(geometry.panelFrame(for: NotchLayout.windowSize(notch: geometry.notchSize)), display: true)
        panel.orderFrontRegardless()
        updateInteraction()
    }

    private func updateInteraction() {
        guard let geometry else { return }
        let state = model.displayState
        hoverTracker.hotZone = geometry.panelFrame(for: model.contentSize)
        // A little slack around the close button makes it easy to hit while everything else clicks through.
        hoverTracker.closeButtonZone = state == .video
            ? geometry.screenRect(
                for: NotchLayout.videoCloseButtonFrame(notch: geometry.notchSize).insetBy(dx: -4, dy: -4),
                inContentOf: model.contentSize
            )
            : .null
        panel.ignoresMouseEvents = !NotchInteraction.acceptsClicks(
            in: state, cursorOverCloseButton: hoverTracker.isOverCloseButton
        )
    }
}
