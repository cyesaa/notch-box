import AppKit
import NotchBoxCore

/// Reports whether the cursor is inside `hotZone`, and inside `buttonZone` (both in global screen
/// coordinates). The global monitor keeps reporting while the panel ignores the mouse.
/// Mouse-moved monitors need no permission.
@MainActor
final class HoverTracker {
    var hotZone: CGRect = .null {
        didSet { evaluate() }
    }
    /// The one control that takes clicks in a click-through state (the video's close button, the mini
    /// notch's play/pause); `.null` when there is none.
    var buttonZone: CGRect = .null {
        didSet { evaluate() }
    }
    /// The cursor over `buttonZone` does not count as hovering the panel (so it does not open).
    var buttonSuppressesHover = false {
        didSet { evaluate() }
    }
    /// Called with the new hover state and, when the cursor comes in, how far below the zone's top edge
    /// it first appeared (0 when it goes out).
    var onHoverChange: ((Bool, CGFloat) -> Void)?
    var onButtonHoverChange: ((Bool) -> Void)?
    private(set) var isHovering = false
    private(set) var isOverButton = false
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
        let overButton = NotchGeometry.contains(buttonZone, NSEvent.mouseLocation)
        if overButton != isOverButton {
            isOverButton = overButton
            onButtonHoverChange?(overButton)
        }
        let location = NSEvent.mouseLocation
        let inside = NotchGeometry.contains(hotZone, location) && !(overButton && buttonSuppressesHover)
        // Keep the panel open while a drag that started inside it (a slider) continues outside.
        let dragging = isHovering && (NSEvent.pressedMouseButtons & 1) != 0
        let hovering = inside || dragging
        guard hovering != isHovering else { return }
        isHovering = hovering
        onHoverChange?(hovering, hovering ? max(0, hotZone.maxY - location.y) : 0)
    }
}
