import CoreGraphics

/// Where the cursor came into the open panel. Coming down from the menu bar (through the band beside the
/// notch) means "I want to use this panel"; coming in from below or the sides means "I am passing over it".
public enum PanelEntry: Equatable, Sendable {
    case fromTop
    case fromSide
}

/// How the panel treats the cursor in each state.
public enum NotchInteraction {
    /// Extra depth below the notch band that still counts as entering from the top, so a fast cursor
    /// whose first sample lands a little lower is not misread.
    public static let topEntrySlack: CGFloat = 8

    /// Classifies an entry by how far below the panel's top edge the cursor first appeared.
    public static func entry(atDepth depth: CGFloat, notchHeight: CGFloat) -> PanelEntry {
        depth <= notchHeight + topEntrySlack ? .fromTop : .fromSide
    }

    /// Open panels take clicks. The video panel takes them all only when entered from the top; entered
    /// from elsewhere it takes them only over its close button, so the windows behind the see-through
    /// video stay clickable. The mini notch takes them only over its play/pause button. Other closed
    /// states never take them.
    public static func acceptsClicks(in state: NotchDisplayState, cursorOverButton: Bool, entry: PanelEntry?) -> Bool {
        switch state {
        case .video: return cursorOverButton || entry == .fromTop
        case .mini: return cursorOverButton
        default: return state.isOpen
        }
    }

    /// Whether the cursor over the state's button counts as "not hovering": the mini notch's play/pause
    /// area must not open the panel, while the video's close button sits inside the hovered panel.
    public static func buttonSuppressesHover(in state: NotchDisplayState) -> Bool {
        state == .mini
    }

    /// The video panel turns see-through while the cursor is over it, unless it came in from the top.
    public static func isSeeThrough(_ state: NotchDisplayState, hovering: Bool, entry: PanelEntry?) -> Bool {
        state == .video && hovering && entry != .fromTop
    }
}
