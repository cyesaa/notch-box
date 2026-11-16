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

    var body: some View {
        Group {
            switch widget {
            case .clipboard: ClipboardView(model: model)
            case .calendar: CalendarView(model: model)
            case .vpn: VPNView(model: model)
            case .auth: AuthView(model: model)
            }
        }
        .sideColumnFrame(side: side, notchHeight: model.notchSize.height)
        // The place below the player is as wide as the player; the others are one column wide.
        .frame(width: side == .bottom ? nil : NotchLayout.sideColumnWidth)
        .frame(maxWidth: side == .bottom ? .infinity : nil)
    }
}

extension View {
    /// Places in the left and right columns are padded 16 at the panel's edge and 12 next to the middle,
    /// with a hairline between them and the middle below their header. Mirrored for the right column.
    /// The place below the player has the middle to itself: 16 on both sides and no hairline.
    func sideColumnFrame(side: SideWidgets.Side, notchHeight: CGFloat) -> some View {
        let isLeft = side == .left || side == .bottomLeft
        let isRight = side == .right || side == .bottomRight
        return self
            .padding(.leading, isRight ? 12 : 16)
            .padding(.trailing, isLeft ? 12 : 16)
            .padding(.bottom, 14)
            .overlay(alignment: isLeft ? .trailing : .leading) {
                if isLeft || isRight {
                    Rectangle()
                        .fill(NotchTheme.ink.opacity(0.08))
                        .frame(width: 1)
                        .padding(.top, notchHeight + 8)
                        .padding(.bottom, 18)
                }
            }
    }
}
