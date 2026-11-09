import Foundation

/// What can sit in a side column of the open player. New widgets are added here (and drawn by the app).
public enum NotchWidget: String, CaseIterable, Codable, Sendable {
    case clipboard
    case calendar
}

/// Which widget sits left and right of the open player; either side can be empty.
public struct SideWidgets: Equatable, Codable, Sendable {
    public enum Side: CaseIterable, Sendable {
        case left
        case right
    }

    public var left: NotchWidget?
    public var right: NotchWidget?

    public static let `default` = SideWidgets(left: .clipboard, right: .calendar)

    public init(left: NotchWidget?, right: NotchWidget?) {
        self.left = left
        self.right = right
    }

    public subscript(side: Side) -> NotchWidget? {
        get { side == .left ? left : right }
        set {
            if side == .left { left = newValue } else { right = newValue }
        }
    }

    public func shows(_ widget: NotchWidget) -> Bool {
        left == widget || right == widget
    }

    /// Puts `widget` on `side`. A widget can be shown once: if it is on the other side, the two sides swap.
    public mutating func set(_ widget: NotchWidget?, on side: Side) {
        let other: Side = side == .left ? .right : .left
        if let widget, self[other] == widget {
            self[other] = self[side]
        }
        self[side] = widget
    }

    /// Reads saved sides; a widget this version does not know (saved by a newer one) becomes an empty side.
    public static func decode(_ data: Data) -> SideWidgets? {
        guard let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
        return SideWidgets(
            left: raw["left"].flatMap(NotchWidget.init(rawValue:)),
            right: raw["right"].flatMap(NotchWidget.init(rawValue:))
        )
    }
}
