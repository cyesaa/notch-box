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
    /// A browser's YouTube video playing in the notch. Stays open until closed, whatever the hover.
    case video
    /// The system volume just changed: a row with the level under the (mini) notch, for a moment.
    case volume

    public static let allCases: [NotchDisplayState] = [.idle, .mini, .expanded, .expandedEmpty, .video, .volume]

    public var isOpen: Bool { self == .expanded || self == .expandedEmpty || self == .video }
}
