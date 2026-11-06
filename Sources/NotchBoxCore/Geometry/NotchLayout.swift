import CoreGraphics

/// Sizes and radii for each display state. All values in points.
public enum NotchLayout {
    public static let miniSidePadding: CGFloat = 12
    public static let expandedSize = CGSize(width: 400, height: 200)
    public static let emptySize = CGSize(width: 300, height: 80)
    public static let expandedArtworkSide: CGFloat = 64
    public static let expandedArtworkRadius: CGFloat = 10
    public static let miniArtworkRadius: CGFloat = 6

    /// Width added on each side of the notch in the mini state.
    public static func miniSideWidth(notch: CGSize) -> CGFloat {
        notch.height + miniSidePadding
    }

    public static func miniArtworkSide(notch: CGSize) -> CGFloat {
        max(0, notch.height - 8)
    }

    public static func size(for state: NotchDisplayState, notch: CGSize) -> CGSize {
        switch state {
        case .idle:
            return notch
        case .mini:
            return CGSize(width: notch.width + 2 * miniSideWidth(notch: notch), height: notch.height)
        case .expanded:
            return CGSize(
                width: max(expandedSize.width, notch.width + 80),
                height: max(expandedSize.height, notch.height + 160)
            )
        case .expandedEmpty:
            return CGSize(
                width: max(emptySize.width, notch.width + 80),
                height: max(emptySize.height, notch.height + 40)
            )
        }
    }

    /// The smallest size that fits every state; the panel window uses this.
    public static func maxSize(notch: CGSize) -> CGSize {
        let states: [NotchDisplayState] = [.idle, .mini, .expanded, .expandedEmpty]
        let sizes = states.map { size(for: $0, notch: notch) }
        return CGSize(
            width: sizes.map(\.width).max() ?? notch.width,
            height: sizes.map(\.height).max() ?? notch.height
        )
    }

    public static func bottomCornerRadius(for state: NotchDisplayState) -> CGFloat {
        state.isOpen ? 20 : 8
    }
}
