import NotchBoxCore
import SwiftUI

/// The calendar column right of the open player, mirroring the clipboard on the left: this week as a strip
/// of days (dots mark days with events), and the picked day's events below, with a join button for calls.
struct CalendarView: View {
    let model: NotchViewModel
    @Environment(\.isRenderingSnapshot) private var isRenderingSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(height: model.notchSize.height)
                .padding(.bottom, 4)
            content
                // minHeight 0: a long agenda scrolls instead of making the panel taller.
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
        }
        // Mirrors the clipboard's padding (16 outside, 12 next to the player).
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .padding(.bottom, 14)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.top, model.notchSize.height + 8)
                .padding(.bottom, 18)
        }
    }

    /// Sits in the band right of the camera.
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .semibold))
            Text(Self.dayFormatter.string(from: model.shownDay))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(action: model.openCalendar) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .help(L10n.calendarOpen)
            .accessibilityLabel(L10n.calendarOpen)
        }
        .foregroundStyle(NotchTheme.secondaryText)
    }

    @ViewBuilder
    private var content: some View {
        switch model.calendarAccess {
        case .notDetermined:
            VStack(spacing: 8) {
                Text(L10n.calendarAllowHint)
                    .font(NotchTheme.detailFont)
                    .foregroundStyle(NotchTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                Button(action: model.requestCalendarAccess) {
                    Text(L10n.calendarAllow)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(NotchTheme.primaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied:
            Text(L10n.calendarDenied)
                .font(NotchTheme.detailFont)
                .foregroundStyle(NotchTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .granted:
            VStack(spacing: 6) {
                WeekStrip(
                    days: model.week,
                    selected: model.shownDay,
                    today: model.agendaTime,
                    busyDays: model.busyDays,
                    onSelect: model.selectDay
                )
                Group {
                    if isRenderingSnapshot {
                        // ImageRenderer draws scroll views blank.
                        events
                    } else {
                        ScrollView(.vertical, showsIndicators: false) { events }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var events: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.dayEvents.isEmpty {
                Text(model.isShowingToday ? L10n.calendarNothingLeft : L10n.calendarNoEvents)
                    .font(NotchTheme.detailFont)
                    .foregroundStyle(NotchTheme.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: EventRow.height)
            }
            ForEach(model.dayEvents) { event in
                EventRow(
                    event: event,
                    status: CalendarAgenda.status(of: event, at: model.agendaTime),
                    onOpen: model.openCalendar,
                    onJoin: { model.join(event) }
                )
            }
        }
    }

    /// "Fri 6 Nov" / "Cum 6 Kas", in the user's language.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter
    }()
}

/// This week's seven days side by side: today filled, the picked day ringed, a dot under days with events.
private struct WeekStrip: View {
    let days: [Date]
    let selected: Date
    let today: Date
    let busyDays: Set<Date>
    let onSelect: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                Button { onSelect(day) } label: { cell(day) }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel(Self.fullDate.string(from: day))
                    .accessibilityAddTraits(isSelected(day) ? .isSelected : [])
            }
        }
    }

    private func cell(_ day: Date) -> some View {
        let isToday = Calendar.current.isDate(day, inSameDayAs: today)
        let selected = isSelected(day)
        return VStack(spacing: 2) {
            Text(Self.weekday.string(from: day))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isToday ? NotchTheme.primaryText : NotchTheme.tertiaryText)
                .lineLimit(1)
            Text(Self.dayNumber.string(from: day))
                .font(.system(size: 12, weight: isToday || selected ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.black : NotchTheme.primaryText.opacity(selected ? 1 : 0.8))
                .frame(width: 22, height: 22)
                .background(
                    Circle().fill(isToday ? Color.white : selected ? Color.white.opacity(0.18) : Color.clear)
                )
            Circle()
                .fill(busyDays.contains(day) ? NotchTheme.secondaryText : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func isSelected(_ day: Date) -> Bool {
        Calendar.current.isDate(day, inSameDayAs: selected)
    }

    /// "Pzt" / "Mon".
    private static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    private static let dayNumber: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
}

private struct EventRow: View {
    let event: CalendarEvent
    let status: CalendarAgenda.Status
    let onOpen: () -> Void
    let onJoin: () -> Void

    static let height: CGFloat = 34

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onOpen) {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(event.color.map { Color($0) } ?? NotchTheme.secondaryText)
                        .frame(width: 3, height: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(NotchTheme.primaryText)
                        Text(detail)
                            .font(.system(size: 10.5))
                            .foregroundStyle(isSoon ? NotchTheme.primaryText.opacity(0.85) : NotchTheme.secondaryText)
                            .monospacedDigit()
                    }
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 6)
                .frame(height: Self.height)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .help(L10n.calendarOpen)
            if event.meetingURL != nil {
                Button(action: onJoin) {
                    Text(L10n.calendarJoin)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(Capsule().fill(Color(red: 0.36, green: 0.84, blue: 0.48)))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .help(event.meetingURL?.host ?? L10n.calendarJoin)
                .accessibilityLabel("\(L10n.calendarJoin): \(event.title)")
            }
        }
        .padding(.trailing, event.meetingURL == nil ? 0 : 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(status == .ongoing ? Color.white.opacity(0.16) : NotchTheme.tile)
        )
    }

    private var isSoon: Bool {
        switch status {
        case .ongoing, .startingSoon: return true
        default: return false
        }
    }

    private var detail: String {
        switch status {
        case .allDay: return L10n.calendarAllDay
        case .ongoing: return L10n.calendarNowUntil(Self.time.string(from: event.end))
        case .startingSoon(let minutes): return "\(L10n.calendarInMinutes(minutes)) · \(Self.time.string(from: event.start))"
        case .later: return "\(Self.time.string(from: event.start)) – \(Self.time.string(from: event.end))"
        }
    }

    private static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
