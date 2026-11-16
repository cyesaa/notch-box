import NotchBoxCore
import SwiftUI

extension NotchWidget {
    var title: String {
        switch self {
        case .clipboard: return L10n.clipboardTitle
        case .calendar: return L10n.calendarTitle
        case .vpn: return L10n.vpnTitle
        case .auth: return L10n.authTitle
        }
    }

    var symbol: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .calendar: return "calendar"
        case .vpn: return "lock.shield"
        case .auth: return "key.horizontal"
        }
    }
}

/// A place around the open player (beside it or in the row under it), with the widget chosen for it.
struct SideColumn: View {
    let widget: NotchWidget
    let side: SideWidgets.Side
    let model: NotchViewModel
    /// The glass card the widget sits on, when the widgets are separate cards (Liquid Glass).
    var card: WidgetCard?

    var body: some View {
        Group {
            switch widget {
            case .clipboard: ClipboardView(model: model)
            case .calendar: CalendarView(model: model)
            case .vpn: VPNView(model: model)
            case .auth: AuthView(model: model)
            }
        }
        .sideColumnFrame(side: side, notchHeight: model.notchSize.height, isCard: card != nil)
        // The place below the player is as wide as the player; the others are one column wide.
        .frame(width: side == .bottom ? nil : NotchLayout.sideColumnWidth)
        .frame(maxWidth: side == .bottom ? .infinity : nil)
        .background { card }
    }
}

extension View {
    /// Places in the left and right columns are padded 16 at the panel's edge and 12 next to the middle,
    /// with a hairline between them and the middle below their header. Mirrored for the right column.
    /// The place below the player has the middle to itself: 16 on both sides and no hairline.
    /// On a card of its own a widget is padded the same on both sides, and the card's edge does what
    /// the hairline did.
    func sideColumnFrame(side: SideWidgets.Side, notchHeight: CGFloat, isCard: Bool = false) -> some View {
        let isLeft = side == .left || side == .bottomLeft
        let isRight = side == .right || side == .bottomRight
        return self
            .padding(.leading, isCard ? 14 : isRight ? 12 : 16)
            .padding(.trailing, isCard ? 14 : isLeft ? 12 : 16)
            .padding(.bottom, 14)
            .overlay(alignment: isLeft ? .trailing : .leading) {
                if (isLeft || isRight) && !isCard {
                    Rectangle()
                        .fill(NotchTheme.ink.opacity(0.08))
                        .frame(width: 1)
                        .padding(.top, notchHeight + 8)
                        .padding(.bottom, 18)
                }
            }
    }
}
