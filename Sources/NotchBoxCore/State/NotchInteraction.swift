/// How the panel treats the cursor in each state.
public enum NotchInteraction {
    /// Open panels take clicks. The video panel takes them only over its close button, so the windows
    /// behind the see-through video stay clickable, and the mini notch only over its play/pause button.
    /// Other closed states never take them.
    public static func acceptsClicks(in state: NotchDisplayState, cursorOverButton: Bool) -> Bool {
        switch state {
        case .video, .mini: return cursorOverButton
        default: return state.isOpen
        }
    }

    /// Whether the cursor over the state's button counts as "not hovering": the mini notch's play/pause
    /// area must not open the panel, while the video's close button sits inside the hovered panel.
    public static func buttonSuppressesHover(in state: NotchDisplayState) -> Bool {
        state == .mini
    }

    /// The video panel turns see-through while the cursor is over it.
    public static func isSeeThrough(_ state: NotchDisplayState, hovering: Bool) -> Bool {
        state == .video && hovering
    }
}
