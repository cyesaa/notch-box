import CoreGraphics

/// Where the hardware notch is on a screen, in global AppKit coordinates (origin bottom-left).
public struct NotchGeometry: Equatable, Sendable {
    public let screenFrame: CGRect
    public let notchRect: CGRect

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
    }

    public var notchSize: CGSize { notchRect.size }

    /// A frame of `size`, horizontally centered on the notch and pinned to the top of the screen.
    public func panelFrame(for size: CGSize) -> CGRect {
        CGRect(
            x: notchRect.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// `rect` (origin top-left, inside content of `contentSize` shown at `panelFrame(for: contentSize)`)
    /// in global AppKit coordinates.
    public func screenRect(for rect: CGRect, inContentOf contentSize: CGSize) -> CGRect {
        let frame = panelFrame(for: contentSize)
        return CGRect(x: frame.minX + rect.minX, y: frame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Like `CGRect.contains`, but includes the max edges (the cursor can sit on the very top row).
    public static func contains(_ rect: CGRect, _ point: CGPoint) -> Bool {
        guard !rect.isNull, !rect.isEmpty else { return false }
        return point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
    }
}
