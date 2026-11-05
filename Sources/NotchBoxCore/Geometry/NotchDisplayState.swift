/// The four visual states of the notch panel.
public enum NotchDisplayState: Equatable, Sendable {
    /// Same size as the hardware notch: invisible.
    case idle
    /// Music is playing: mini artwork on the left, waveform on the right.
    case mini
    /// Hovered with media info (or in degraded mode): full player.
    case expanded
    /// Hovered with nothing playing: small "Nothing playing" panel.
    case expandedEmpty

    public var isOpen: Bool { self == .expanded || self == .expandedEmpty }
}
