import CoreGraphics

/// Where the hardware notch is on a screen, in global AppKit coordinates (origin bottom-left). On a screen
/// without one, a virtual notch: a notch-wide area at the top centre, as tall as the menu bar.
public struct NotchGeometry: Equatable, Sendable {
    public let screenFrame: CGRect
    public let notchRect: CGRect
    /// Drawn by NotchBox on a screen without a notch.
    public let isVirtual: Bool

    /// A typical notch width (14" and 16" MacBook Pro at default scaling).
    public static let virtualNotchWidth: CGFloat = 185
    public static let defaultMenuBarHeight: CGFloat = 24
    static let maxVirtualHeight: CGFloat = 40

    /// What `choose` needs to know about a screen.
    public struct ScreenInfo: Equatable, Sendable {
        public let frame: CGRect
        /// The top of the area below the menu bar (`NSScreen.visibleFrame.maxY`).
        public let visibleTop: CGFloat
        public let safeAreaTop: CGFloat
        public let auxiliaryTopLeft: CGRect?
        public let auxiliaryTopRight: CGRect?

        public init(frame: CGRect, visibleTop: CGFloat, safeAreaTop: CGFloat, auxiliaryTopLeft: CGRect?, auxiliaryTopRight: CGRect?) {
            self.frame = frame
            self.visibleTop = visibleTop
            self.safeAreaTop = safeAreaTop
            self.auxiliaryTopLeft = auxiliaryTopLeft
            self.auxiliaryTopRight = auxiliaryTopRight
        }
    }

    private init(screenFrame: CGRect, notchRect: CGRect, isVirtual: Bool) {
        self.screenFrame = screenFrame
        self.notchRect = notchRect
        self.isVirtual = isVirtual
    }

    /// A virtual notch for a screen without one. A hidden menu bar (height 0) uses the usual height.
    public static func virtual(screenFrame: CGRect, menuBarHeight: CGFloat) -> NotchGeometry {
        let height = menuBarHeight > 0 ? min(menuBarHeight, maxVirtualHeight) : defaultMenuBarHeight
        let rect = CGRect(
            x: screenFrame.midX - virtualNotchWidth / 2,
            y: screenFrame.maxY - height,
            width: virtualNotchWidth,
            height: height
        )
        return NotchGeometry(screenFrame: screenFrame, notchRect: rect, isVirtual: true)
    }

    /// The screen to use: the first one with a real notch; otherwise, when allowed, a virtual notch on the
    /// first screen (the one with the menu bar).
    public static func choose(from screens: [ScreenInfo], allowVirtual: Bool) -> NotchGeometry? {
        for screen in screens {
            if let geometry = NotchGeometry(
                screenFrame: screen.frame,
                safeAreaTop: screen.safeAreaTop,
                auxiliaryTopLeft: screen.auxiliaryTopLeft,
                auxiliaryTopRight: screen.auxiliaryTopRight
            ) {
                return geometry
            }
        }
        guard allowVirtual, let main = screens.first else { return nil }
        return virtual(screenFrame: main.frame, menuBarHeight: main.frame.maxY - main.visibleTop)
    }

    /// Returns nil when the screen has no notch.
    /// Only the widths of the auxiliary areas are used, so their coordinate space does not matter.
    public init?(screenFrame: CGRect, safeAreaTop: CGFloat, auxiliaryTopLeft: CGRect?, auxiliaryTopRight: CGRect?) {
        guard safeAreaTop > 0, let left = auxiliaryTopLeft, let right = auxiliaryTopRight else { return nil }
        let width = screenFrame.width - left.width - right.width
        guard width > 0 else { return nil }
        self.screenFrame = screenFrame
        self.notchRect = CGRect(
            x: screenFrame.minX + left.width,
            y: screenFrame.maxY - safeAreaTop,
            width: width,
            height: safeAreaTop
        )
        self.isVirtual = false
    }

    public var notchSize: CGSize { notchRect.size }

    /// A frame of `size`, horizontally centered on the notch (moved by `offsetX`) and pinned to the top
    /// of the screen.
    public func panelFrame(for size: CGSize, offsetX: CGFloat = 0) -> CGRect {
        CGRect(
            x: notchRect.midX + offsetX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// `rect` (origin top-left, inside content of `contentSize` shown at
    /// `panelFrame(for: contentSize, offsetX: offsetX)`) in global AppKit coordinates.
    public func screenRect(for rect: CGRect, inContentOf contentSize: CGSize, offsetX: CGFloat = 0) -> CGRect {
        let frame = panelFrame(for: contentSize, offsetX: offsetX)
        return CGRect(x: frame.minX + rect.minX, y: frame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Like `CGRect.contains`, but includes the max edges (the cursor can sit on the very top row).
    public static func contains(_ rect: CGRect, _ point: CGPoint) -> Bool {
        guard !rect.isNull, !rect.isEmpty else { return false }
        return point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
    }
}
