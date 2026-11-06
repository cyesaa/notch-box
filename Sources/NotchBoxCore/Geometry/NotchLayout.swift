import CoreGraphics

/// Sizes and radii for each display state. All values in points.
public enum NotchLayout {
    public static let miniSidePadding: CGFloat = 12
    public static let expandedSize = CGSize(width: 400, height: 200)
    public static let emptySize = CGSize(width: 300, height: 80)
    public static let expandedArtworkSide: CGFloat = 64
    public static let expandedArtworkRadius: CGFloat = 10
    public static let miniArtworkRadius: CGFloat = 6
    public static let videoWidth: CGFloat = 464
    public static let videoPadding: CGFloat = 16
    /// Title and buttons above the player.
    public static let videoBarHeight: CGFloat = 30
    /// Gap between the notch and the bar, and between the bar and the player.
    public static let videoGap: CGFloat = 8

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
        case .video:
            let player = videoPlayerSize(notch: notch)
            return CGSize(
                width: player.width + 2 * videoPadding,
                height: notch.height + videoGap + videoBarHeight + videoGap + player.height + videoPadding
            )
        }
    }

    /// The 16:9 player in the video state.
    public static func videoPlayerSize(notch: CGSize) -> CGSize {
        let width = max(videoWidth, notch.width + 80) - 2 * videoPadding
        return CGSize(width: width, height: (width * 9 / 16).rounded())
    }

    /// The smallest size that fits every state; the panel window uses this.
    public static func maxSize(notch: CGSize) -> CGSize {
        let sizes = NotchDisplayState.allCases.map { size(for: $0, notch: notch) }
        return CGSize(
            width: sizes.map(\.width).max() ?? notch.width,
            height: sizes.map(\.height).max() ?? notch.height
        )
    }

    public static func bottomCornerRadius(for state: NotchDisplayState) -> CGFloat {
        state.isOpen ? 20 : 8
    }

    /// Concave corners where the shape meets the top edge of the screen, drawn outside `size(for:)`
    /// so the panel flares into the bezel like the hardware notch. None while idle, to stay invisible.
    public static func topCornerRadius(for state: NotchDisplayState) -> CGFloat {
        switch state {
        case .idle: return 0
        case .mini: return 6
        case .expanded, .expandedEmpty, .video: return 12
        }
    }

    /// Transparent room around the shape for its drop shadow.
    public static let shadowMargin: CGFloat = 24

    /// The panel window: every state plus the flared corners on both sides and the shadow below.
    public static func windowSize(notch: CGSize) -> CGSize {
        let flare = NotchDisplayState.allCases.map(topCornerRadius(for:)).max() ?? 0
        let content = maxSize(notch: notch)
        return CGSize(width: content.width + 2 * (flare + shadowMargin), height: content.height + shadowMargin)
    }
}
