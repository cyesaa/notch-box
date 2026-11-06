import AppKit
import EventKit
import NotchBoxCore

enum CalendarAccess: Equatable {
    case notDetermined
    case granted
    case denied
}

@MainActor
protocol CalendarProviding: AnyObject {
    var access: CalendarAccess { get }
    /// The calendar's events or the access changed.
    var onChange: (() -> Void)? { get set }
    func start()
    /// Asks macOS for read access (shows the system prompt once).
    func requestAccess()
    func events(from start: Date, to end: Date) -> [CalendarEvent]
}

/// Reads events with EventKit. Read-only: NotchBox never changes the calendar.
@MainActor
final class CalendarService: CalendarProviding {
    var onChange: (() -> Void)?
    private let store = EKEventStore()
    private var observer: NSObjectProtocol?

    var access: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notDetermined
        case .fullAccess: return .granted
        default: return .denied
        }
    }

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onChange?() }
        }
    }

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] _, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    // A new grant does not refresh the store's sources by itself.
                    self.store.reset()
                    self.onChange?()
                }
            }
        }
    }

    func events(from start: Date, to end: Date) -> [CalendarEvent] {
        guard access == .granted else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { event in
            CalendarEvent(
                // Occurrences of a repeating event share an identifier.
                id: "\(event.calendarItemIdentifier)@\(event.startDate.timeIntervalSince1970)",
                title: event.title?.isEmpty == false ? event.title : "—",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                color: event.calendar.flatMap { Self.color($0.color) },
                meetingURL: MeetingLink.find(in: [event.url?.absoluteString, event.location, event.notes])
            )
        }
    }

    static func openCalendarApp() {
        AppIconProvider.open(bundleIdentifier: "com.apple.iCal")
    }

    private static func color(_ color: NSColor?) -> ArtworkColor? {
        guard let rgb = color?.usingColorSpace(.sRGB) else { return nil }
        return ArtworkColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
    }
}
