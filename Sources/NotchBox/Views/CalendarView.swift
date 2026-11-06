import NotchBoxCore
import SwiftUI

/// The calendar column right of the open player, mirroring the clipboard on the left: what is left of
/// today and tomorrow's events, with a join button for video calls.
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
            Text(Self.dayFormatter.string(from: model.agendaTime == .distantPast ? Date() : model.agendaTime))
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
            if isRenderingSnapshot {
                // ImageRenderer draws scroll views blank.
                agenda
            } else {
                ScrollView(.vertical, showsIndicators: false) { agenda }
            }
        }
    }

    private var agenda: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(model.agenda, id: \.day) { day in
                if day.day == .tomorrow {
                    Text(L10n.calendarTomorrow)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NotchTheme.tertiaryText)
                        .padding(.top, 4)
                        .padding(.leading, 2)
                }
                if day.day == .today, day.events.isEmpty {
                    Text(L10n.calendarNothingLeft)
                        .font(NotchTheme.detailFont)
                        .foregroundStyle(NotchTheme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: EventRow.height)
                        .padding(.leading, 2)
                }
                ForEach(day.events) { event in
                    EventRow(
                        event: event,
                        status: CalendarAgenda.status(of: event, at: model.agendaTime),
                        onOpen: model.openCalendar,
                        onJoin: { model.join(event) }
                    )
                }
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

private struct EventRow: View {
    let event: CalendarEvent
    let status: CalendarAgenda.Status
    let onOpen: () -> Void
    let onJoin: () -> Void

    static let height: CGFloat = 36

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
