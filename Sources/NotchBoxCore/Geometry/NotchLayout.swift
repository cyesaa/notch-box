import CoreGraphics

/// Sizes and radii for each display state. All values in points.
public enum NotchLayout {
    public static let miniSidePadding: CGFloat = 12
    public static let expandedWidth: CGFloat = 400
    /// The expanded player below the notch: header, progress and controls. The band beside the notch
    /// holds the small icons, so nothing is wasted above the header.
    public static let expandedBodyHeight: CGFloat = 154
    public static let emptyWidth: CGFloat = 300
    /// A side column of the open player (clipboard, calendar, ...) and the places under it. Every widget
    /// beside the player has the same width, so two columns keep the panel symmetric.
    public static let sideColumnWidth: CGFloat = 240
    public static let clipboardWidth: CGFloat = sideColumnWidth
    public static let calendarWidth: CGFloat = sideColumnWidth
    public static let expandedArtworkSide: CGFloat = 64
    public static let expandedArtworkRadius: CGFloat = 10
    public static let miniArtworkRadius: CGFloat = 6
    public static let videoWidth: CGFloat = 464
    public static let videoPadding: CGFloat = 16
    /// Gap between the notch and the player. The source icon and the close button sit beside the notch.
    public static let videoGap: CGFloat = 8

    /// Width added on each side of the notch in the mini state.
    public static func miniSideWidth(notch: CGSize) -> CGFloat {
        notch.height + miniSidePadding
    }

    public static func miniArtworkSide(notch: CGSize) -> CGFloat {
        max(0, notch.height - 8)
    }

    public static func size(for state: NotchDisplayState, notch: CGSize, sides: SideWidgets = .default) -> CGSize {
        switch state {
        case .idle:
            return notch
        case .mini:
            return CGSize(width: notch.width + 2 * miniSideWidth(notch: notch), height: notch.height)
        case .expanded, .expandedEmpty:
            return CGSize(
                width: leadingExtension(for: state, sides: sides) + centerWidth(for: state, notch: notch) + trailingExtension(for: state, sides: sides),
                height: notch.height + expandedBodyHeight + bottomExtension(for: state, notch: notch, sides: sides)
            )
        case .volume:
            return CGSize(width: notch.width + 2 * miniSideWidth(notch: notch), height: notch.height + volumeRowHeight)
        case .auth:
            return CGSize(width: max(authWidth, notch.width + 2 * miniSideWidth(notch: notch)), height: notch.height + authRowHeight)
        case .video:
            let player = videoPlayerSize(notch: notch)
            return CGSize(
                width: player.width + 2 * videoPadding,
                height: notch.height + videoGap + player.height + videoPadding
            )
        }
    }

    public static let videoCloseButtonSide: CGFloat = 24
    /// The volume row under the notch in the volume state, including its bottom margin.
    public static let volumeRowHeight: CGFloat = 34

    /// The auth state is at least this wide, so an issuer, a code and its countdown fit on one row.
    public static let authWidth: CGFloat = 300
    /// The code row under the notch in the auth state, including its bottom margin.
    public static let authRowHeight: CGFloat = 46

    /// The auth state's code row, in content coordinates: the part that takes clicks (to copy the code)
    /// without opening the panel.
    public static func authActionFrame(notch: CGSize) -> CGRect {
        CGRect(x: 0, y: notch.height, width: size(for: .auth, notch: notch).width, height: authRowHeight)
    }

    /// The mini state's right wing (the waveform), in content coordinates: hovering it shows a
    /// play/pause button instead of opening the panel.
    public static func miniActionFrame(notch: CGSize) -> CGRect {
        let side = miniSideWidth(notch: notch)
        return CGRect(x: side + notch.width, y: 0, width: side, height: notch.height)
    }

    /// The video panel's close button, in content coordinates (origin top-left): right of the notch,
    /// at the right end of the panel.
    public static func videoCloseButtonFrame(notch: CGSize) -> CGRect {
        let width = size(for: .video, notch: notch).width
        return CGRect(
            x: width - videoPadding - videoCloseButtonSide,
            y: ((notch.height - videoCloseButtonSide) / 2).rounded(),
            width: videoCloseButtonSide,
            height: videoCloseButtonSide
        )
    }

    /// The 16:9 player in the video state.
    public static func videoPlayerSize(notch: CGSize) -> CGSize {
        let width = max(videoWidth, notch.width + 80) - 2 * videoPadding
        return CGSize(width: width, height: (width * 9 / 16).rounded())
    }

    /// The player's own width in the open states; the place below it is as wide.
    public static func centerWidth(for state: NotchDisplayState, notch: CGSize) -> CGFloat {
        max(state == .expandedEmpty ? emptyWidth : expandedWidth, notch.width + 80)
    }

    /// The row of widgets under the open player. As tall as the row above it (a header the height of
    /// the notch band, then the body), so a widget looks the same in either row.
    public static func bottomRowHeight(notch: CGSize) -> CGFloat {
        notch.height + expandedBodyHeight
    }

    /// Extra height added below a state: the open player's bottom row, when one of its places is taken.
    public static func bottomExtension(for state: NotchDisplayState, notch: CGSize, sides: SideWidgets = .default) -> CGFloat {
        hasSideColumns(state) && sides.hasBottomRow ? bottomRowHeight(notch: notch) : 0
    }

    /// Extra width added on the left of a state: the open player's left column, when a widget sits
    /// beside the player or under that place.
    public static func leadingExtension(for state: NotchDisplayState, sides: SideWidgets = .default) -> CGFloat {
        hasSideColumns(state) && sides.hasLeftColumn ? sideColumnWidth : 0
    }

    static func hasSideColumns(_ state: NotchDisplayState) -> Bool {
        state == .expanded || state == .expandedEmpty
    }

    /// Extra width added on the right of a state: the open player's right column.
    public static func trailingExtension(for state: NotchDisplayState, sides: SideWidgets = .default) -> CGFloat {
        hasSideColumns(state) && sides.hasRightColumn ? sideColumnWidth : 0
    }

    /// How far the content's centre sits from the notch's centre, so that the player itself stays
    /// centred under the notch whatever its side columns are.
    public static func horizontalOffset(for state: NotchDisplayState, sides: SideWidgets = .default) -> CGFloat {
        (trailingExtension(for: state, sides: sides) - leadingExtension(for: state, sides: sides)) / 2
    }

    /// A choice that takes both columns and the bottom row: the largest the open player gets.
    static let largestChoice = SideWidgets(left: .clipboard, right: .calendar, bottom: .vpn)

    /// The farthest any state reaches sideways from the notch's centre (width) and down (height), with
    /// every column and row in use: the window is made once and must fit whatever is chosen later.
    public static func contentReach(notch: CGSize) -> CGSize {
        let states = NotchDisplayState.allCases
        let reach = states.map { size(for: $0, notch: notch, sides: largestChoice).width / 2 }
        let heights = states.map { size(for: $0, notch: notch, sides: largestChoice).height }
        return CGSize(width: reach.max() ?? notch.width / 2, height: heights.max() ?? notch.height)
    }

    public static func bottomCornerRadius(for state: NotchDisplayState) -> CGFloat {
        if state == .volume || state == .auth { return 14 }
        return state.isOpen ? 20 : 8
    }

    /// Concave corners where the shape meets the top edge of the screen, drawn outside `size(for:)`
    /// so the panel flares into the bezel like the hardware notch. None while idle, to stay invisible.
    public static func topCornerRadius(for state: NotchDisplayState) -> CGFloat {
        switch state {
        case .idle: return 0
        case .mini, .volume, .auth: return 6
        case .expanded, .expandedEmpty, .video: return 12
        }
    }

    /// Transparent room around the shape for its drop shadow.
    public static let shadowMargin: CGFloat = 24

    /// The panel window, centred on the notch: every state plus the flared corners on both sides and
    /// the shadow below.
    public static func windowSize(notch: CGSize) -> CGSize {
        let flare = NotchDisplayState.allCases.map(topCornerRadius(for:)).max() ?? 0
        let reach = contentReach(notch: notch)
        return CGSize(width: 2 * (reach.width + flare + shadowMargin), height: reach.height + shadowMargin)
    }
}
