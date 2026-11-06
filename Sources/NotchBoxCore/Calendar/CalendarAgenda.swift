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

/// The week strip and the events of the day picked in it.
public enum CalendarAgenda {
    public enum Status: Equatable, Sendable {
        case allDay
        case ongoing
        /// Starts within `soonThreshold`; minutes rounded up.
        case startingSoon(minutes: Int)
        case later
    }

    public static let soonThreshold: TimeInterval = 15 * 60

    /// The starts of the seven days of the week around `date`, from the calendar's first weekday.
    public static func week(containing date: Date, calendar: Calendar) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// The events to ask the calendar for: the whole week around `now`.
    public static func fetchRange(now: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let week = week(containing: now, calendar: calendar)
        let start = week.first ?? calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86_400)
        return (start, end)
    }

    /// The events on `day` (any time on that day), all-day first, then by start time. Today leaves out
    /// what has already ended.
    public static func events(on day: Date, from events: [CalendarEvent], now: Date, calendar: Calendar) -> [CalendarEvent] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let isToday = calendar.isDate(start, inSameDayAs: now)
        return events
            .filter { $0.start < end && $0.end > start && (!isToday || $0.end > now) }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                if lhs.start != rhs.start { return lhs.start < rhs.start }
                return lhs.title < rhs.title
            }
    }

    /// The starts of the days that have at least one event.
    public static func busyDays(from events: [CalendarEvent], calendar: Calendar) -> Set<Date> {
        var days = Set<Date>()
        for event in events {
            var day = calendar.startOfDay(for: event.start)
            days.insert(day)
            // Later days it reaches into; an event ending exactly at midnight does not touch the next day.
            while let next = calendar.date(byAdding: .day, value: 1, to: day), next < event.end {
                days.insert(next)
                day = next
            }
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
