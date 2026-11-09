import NotchBoxCore
import SwiftUI

extension NotchWidget {
    var title: String {
        switch self {
        case .clipboard: return L10n.clipboardTitle
        case .calendar: return L10n.calendarTitle
        }
    }

    var symbol: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .calendar: return "calendar"
        }
    }
}

/// A side column of the open player, with the widget chosen for that side.
struct SideColumn: View {
    let widget: NotchWidget
    let side: SideWidgets.Side
    let model: NotchViewModel

    var body: some View {
        Group {
            switch widget {
            case .clipboard: ClipboardView(model: model)
            case .calendar: CalendarView(model: model)
            }
        }
        .sideColumnFrame(side: side, notchHeight: model.notchSize.height)
        .frame(width: NotchLayout.sideColumnWidth)
    }
}

extension View {
    /// Side columns are padded 16 at the panel's edge and 12 next to the player, with a hairline between
    /// them and the player below the notch band. Mirrored for the right side.
    func sideColumnFrame(side: SideWidgets.Side, notchHeight: CGFloat) -> some View {
        self
            .padding(.leading, side == .left ? 16 : 12)
            .padding(.trailing, side == .left ? 12 : 16)
            .padding(.bottom, 14)
            .overlay(alignment: side == .left ? .trailing : .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)
                    .padding(.top, notchHeight + 8)
                    .padding(.bottom, 18)
            }
    }
}
