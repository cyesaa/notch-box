import Foundation

/// What can sit in a side column of the open player. New widgets are added here (and drawn by the app).
public enum NotchWidget: String, CaseIterable, Codable, Sendable {
    case clipboard
    case calendar
    case vpn
    /// Sign-in codes (2FA).
    case auth
    /// The Mac's camera as a mirror.
    case mirror
}

/// Which widget sits in each place around the open player: left and right of it, and in a second row
/// under it (bottom left, below, bottom right). Any place can be empty; the bottom row exists only when
/// one of its places is taken.
public struct SideWidgets: Equatable, Codable, Sendable {
    public enum Side: String, CaseIterable, Sendable {
        case left
        case right
        case bottomLeft
        case bottom
        case bottomRight
    }

    public var left: NotchWidget?
    public var right: NotchWidget?
    public var bottomLeft: NotchWidget?
    public var bottom: NotchWidget?
    public var bottomRight: NotchWidget?

    public static let `default` = SideWidgets(left: .clipboard, right: .calendar)

    public init(
        left: NotchWidget?, right: NotchWidget?,
        bottomLeft: NotchWidget? = nil, bottom: NotchWidget? = nil, bottomRight: NotchWidget? = nil
    ) {
        self.left = left
        self.right = right
        self.bottomLeft = bottomLeft
        self.bottom = bottom
        self.bottomRight = bottomRight
    }

    public subscript(side: Side) -> NotchWidget? {
        get {
            switch side {
            case .left: return left
            case .right: return right
            case .bottomLeft: return bottomLeft
            case .bottom: return bottom
            case .bottomRight: return bottomRight
            }
        }
        set {
            switch side {
            case .left: left = newValue
            case .right: right = newValue
            case .bottomLeft: bottomLeft = newValue
            case .bottom: bottom = newValue
            case .bottomRight: bottomRight = newValue
            }
        }
    }

    public func shows(_ widget: NotchWidget) -> Bool {
        Side.allCases.contains { self[$0] == widget }
    }

    /// The left column is there when a widget sits beside the player or under that place.
    public var hasLeftColumn: Bool { left != nil || bottomLeft != nil }
    public var hasRightColumn: Bool { right != nil || bottomRight != nil }
    public var hasBottomRow: Bool { bottomLeft != nil || bottom != nil || bottomRight != nil }

    /// Puts `widget` on `side`. A widget can be shown once: if it already sits somewhere else, the two
    /// places swap.
    public mutating func set(_ widget: NotchWidget?, on side: Side) {
        if let widget, let other = Side.allCases.first(where: { $0 != side && self[$0] == widget }) {
            self[other] = self[side]
        }
        self[side] = widget
    }

    /// Reads a saved choice. A widget this version does not know (saved by a newer one) becomes an empty
    /// place, and a choice saved before the bottom row existed has an empty bottom row.
    public static func decode(_ data: Data) -> SideWidgets? {
        guard let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
        var sides = SideWidgets(left: nil, right: nil)
        for side in Side.allCases {
            sides[side] = raw[side.rawValue].flatMap(NotchWidget.init(rawValue:))
        }
        return sides
    }
}
