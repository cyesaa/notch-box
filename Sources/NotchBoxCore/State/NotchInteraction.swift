/// How the panel treats the cursor in each state.
public enum NotchInteraction {
    /// Open panels take clicks. The video panel takes them only over its close button, so the windows
    /// behind the see-through video stay clickable; closed states never take them.
    public static func acceptsClicks(in state: NotchDisplayState, cursorOverCloseButton: Bool) -> Bool {
        state == .video ? cursorOverCloseButton : state.isOpen
    }

    /// The video panel turns see-through while the cursor is over it.
    public static func isSeeThrough(_ state: NotchDisplayState, hovering: Bool) -> Bool {
        state == .video && hovering
    }
}
