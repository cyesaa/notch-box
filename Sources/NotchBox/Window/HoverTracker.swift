import AppKit
import NotchBoxCore

/// Reports whether the cursor is inside `hotZone` (global screen coordinates).
/// Mouse-moved monitors need no permission.
@MainActor
final class HoverTracker {
    var hotZone: CGRect = .null {
        didSet { evaluate() }
    }
    var onHoverChange: ((Bool) -> Void)?
    private(set) var isHovering = false
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
        let inside = NotchGeometry.contains(hotZone, NSEvent.mouseLocation)
        // Keep the panel open while a drag that started inside it (a slider) continues outside.
        let dragging = isHovering && (NSEvent.pressedMouseButtons & 1) != 0
        let hovering = inside || dragging
        guard hovering != isHovering else { return }
        isHovering = hovering
        onHoverChange?(hovering)
    }
}
