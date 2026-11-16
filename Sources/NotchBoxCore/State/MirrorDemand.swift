/// When the mirror's camera runs: while the mirror is open in its widget and that widget is on screen,
/// or while the mirror fills the screen. Hovering over the panel alone never turns the camera on.
public struct MirrorDemand: Equatable, Sendable {
    /// The user opened the mirror in its card. Closing the panel closes it, so that every opening of the
    /// panel starts with the camera off.
    public private(set) var isOpenInPanel = false
    public private(set) var isFullScreen = false
    /// The mirror's widget is in the open panel.
    public private(set) var isColumnVisible = false

    public init() {}

    public var wantsCamera: Bool { (isOpenInPanel && isColumnVisible) || isFullScreen }

    /// The card's button, or a click on the picture: opens the mirror in the card, or closes it.
    public mutating func toggleInPanel() {
        guard isColumnVisible else { return }
        isOpenInPanel.toggle()
    }

    public mutating func setColumnVisible(_ visible: Bool) {
        isColumnVisible = visible
        if !visible { isOpenInPanel = false }
    }

    public mutating func setFullScreen(_ fullScreen: Bool) {
        isFullScreen = fullScreen
    }
}
