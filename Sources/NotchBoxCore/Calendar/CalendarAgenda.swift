import Foundation

/// A calendar event as the notch shows it.
public struct CalendarEvent: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    /// The calendar's colour.
    public let color: ArtworkColor?
    /// A video call to join (Zoom, Meet, Teams, ...), found in the event's URL, location or notes.
    public let meetingURL: URL?

    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool, color: ArtworkColor?, meetingURL: URL?) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.color = color
        self.meetingURL = meetingURL
    }
}

public struct AgendaDay: Equatable, Sendable {
    public enum Day: Equatable, Sendable {
        case today
        case tomorrow
    }

    public let day: Day
    public let events: [CalendarEvent]

    public init(day: Day, events: [CalendarEvent]) {
        self.day = day
        self.events = events
    }
}

/// What is left of today and what is on tomorrow.
public enum CalendarAgenda {
    public enum Status: Equatable, Sendable {
        case allDay
        case ongoing
        /// Starts within `soonThreshold`; minutes rounded up.
        case startingSoon(minutes: Int)
        case later
    }

    public static let maxEvents = 8
    public static let soonThreshold: TimeInterval = 15 * 60

    /// The events to ask the calendar for: from the start of today to the end of tomorrow.
    public static func fetchRange(now: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 2, to: start) ?? start.addingTimeInterval(2 * 86_400)
        return (start, end)
    }

    /// Events that have not ended, grouped into today (always present) and tomorrow (only when it has
    /// events). All-day events come first, then by start time; at most `maxEvents` in all.
    public static func days(from events: [CalendarEvent], now: Date, calendar: Calendar) -> [AgendaDay] {
        let range = fetchRange(now: now, calendar: calendar)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: range.start) ?? range.end
        let remaining = events
            .filter { $0.end > now && $0.start < range.end }
            .sorted { lhs, rhs in
                let lhsDay = lhs.start < startOfTomorrow ? 0 : 1
                let rhsDay = rhs.start < startOfTomorrow ? 0 : 1
                if lhsDay != rhsDay { return lhsDay < rhsDay }
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                if lhs.start != rhs.start { return lhs.start < rhs.start }
                return lhs.title < rhs.title
            }
            .prefix(maxEvents)
        let today = remaining.filter { $0.start < startOfTomorrow }
        let tomorrow = remaining.filter { $0.start >= startOfTomorrow }
        var days = [AgendaDay(day: .today, events: Array(today))]
        if !tomorrow.isEmpty {
            days.append(AgendaDay(day: .tomorrow, events: Array(tomorrow)))
        }
        return days
    }

    public static func status(of event: CalendarEvent, at now: Date) -> Status {
        if event.isAllDay { return .allDay }
        if event.start <= now, now < event.end { return .ongoing }
        let untilStart = event.start.timeIntervalSince(now)
        if untilStart > 0, untilStart <= soonThreshold {
            return .startingSoon(minutes: Int((untilStart / 60).rounded(.up)))
        }
        return .later
    }
}

/// Finds a video-call link in an event's text fields.
public enum MeetingLink {
    /// Hosts of video-call services, matched as the host or a subdomain of it.
    public static let hosts = [
        "zoom.us", "zoomgov.com", "meet.google.com", "teams.microsoft.com", "teams.live.com",
        "webex.com", "facetime.apple.com", "whereby.com", "meet.jit.si", "chime.aws", "gotomeeting.com",
    ]

    private static let urlPattern = try! NSRegularExpression(pattern: #"https?://[^\s<>"']+"#)
    private static let trailingPunctuation = CharacterSet(charactersIn: ".,;:!?)]}>")

    /// The first meeting link in the first field that has one (pass URL, location, notes in that order).
    public static func find(in texts: [String?]) -> URL? {
        for case let text? in texts {
            let range = NSRange(text.startIndex..., in: text)
            for match in urlPattern.matches(in: text, range: range) {
                guard let matchRange = Range(match.range, in: text) else { continue }
                let candidate = String(text[matchRange]).trimmingCharacters(in: trailingPunctuation)
                guard let url = URL(string: candidate), let host = url.host?.lowercased() else { continue }
                if hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
                    return url
                }
            }
        }
        return nil
    }
}
