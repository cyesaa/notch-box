import AppKit
import NotchBoxCore

/// Reports whether the cursor is inside `hotZone`, and inside `closeButtonZone` (both in global screen
/// coordinates). The global monitor keeps reporting while the panel ignores the mouse.
/// Mouse-moved monitors need no permission.
@MainActor
final class HoverTracker {
    var hotZone: CGRect = .null {
        didSet { evaluate() }
    }
    /// The video panel's close button; `.null` when no video is showing.
    var closeButtonZone: CGRect = .null {
        didSet { evaluate() }
    }
    var onHoverChange: ((Bool) -> Void)?
    var onCloseButtonHoverChange: ((Bool) -> Void)?
    private(set) var isHovering = false
    private(set) var isOverCloseButton = false
    private var monitors: [Any] = []

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.evaluate() }
            return event
        }) {
            monitors.append(local)
        }
        evaluate()
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private func evaluate() {
        let overCloseButton = NotchGeometry.contains(closeButtonZone, NSEvent.mouseLocation)
        if overCloseButton != isOverCloseButton {
            isOverCloseButton = overCloseButton
            onCloseButtonHoverChange?(overCloseButton)
        }
        let inside = NotchGeometry.contains(hotZone, NSEvent.mouseLocation)
        // Keep the panel open while a drag that started inside it (a slider) continues outside.
        let dragging = isHovering && (NSEvent.pressedMouseButtons & 1) != 0
        let hovering = inside || dragging
        guard hovering != isHovering else { return }
        isHovering = hovering
        onHoverChange?(hovering)
    }
}
