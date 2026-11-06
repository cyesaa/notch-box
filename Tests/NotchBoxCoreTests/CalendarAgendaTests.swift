import Foundation
import Testing
@testable import NotchBoxCore

struct CalendarAgendaTests {
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()

    /// 6 November 2026 at `hour`:`minute` in Istanbul (`day` 7 is tomorrow).
    func date(_ hour: Int, _ minute: Int = 0, day: Int = 6) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func event(_ id: String, _ start: Date, _ end: Date, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: id, title: id, start: start, end: end, isAllDay: allDay, color: nil, meetingURL: nil)
    }

    @Test func theWeekStartsOnTheCalendarsFirstWeekday() {
        var monday = calendar
        monday.firstWeekday = 2
        let week = CalendarAgenda.week(containing: date(14), calendar: monday)
        #expect(week == (2...8).map { date(0, day: $0) })
        var sunday = calendar
        sunday.firstWeekday = 1
        #expect(CalendarAgenda.week(containing: date(14), calendar: sunday) == (1...7).map { date(0, day: $0) })
    }

    @Test func fetchesTheWholeWeek() {
        var monday = calendar
        monday.firstWeekday = 2
        let range = CalendarAgenda.fetchRange(now: date(14), calendar: monday)
        #expect(range.start == date(0, day: 2))
        #expect(range.end == date(0, day: 9))
    }

    @Test func todayLeavesOutEndedEvents() {
        let events = CalendarAgenda.events(
            on: date(0), from: [event("past", date(9), date(10)), event("now", date(13), date(15)), event("next", date(16), date(17))],
            now: date(14), calendar: calendar
        )
        #expect(events.map(\.id) == ["now", "next"])
    }

    @Test func otherDaysShowAllTheirEvents() {
        let events = CalendarAgenda.events(
            on: date(0, day: 5),
            from: [event("yesterday", date(9, day: 5), date(10, day: 5)), event("today", date(16), date(17))],
            now: date(14), calendar: calendar
        )
        #expect(events.map(\.id) == ["yesterday"])
    }

    @Test func allDayEventsComeFirstThenByStartTime() {
        let events = CalendarAgenda.events(
            on: date(0),
            from: [
                event("b", date(16), date(17)),
                event("a", date(15), date(16)),
                event("holiday", date(0), date(0, day: 7), allDay: true),
            ],
            now: date(14), calendar: calendar
        )
        #expect(events.map(\.id) == ["holiday", "a", "b"])
    }

    @Test func eventsSpanningMidnightShowOnBothDays() {
        let late = event("late", date(23), date(1, day: 7))
        #expect(CalendarAgenda.events(on: date(0), from: [late], now: date(14), calendar: calendar).map(\.id) == ["late"])
        #expect(CalendarAgenda.events(on: date(0, day: 7), from: [late], now: date(14), calendar: calendar).map(\.id) == ["late"])
        // An all-day event ends at the next midnight and does not spill into the next day.
        let holiday = event("holiday", date(0), date(0, day: 7), allDay: true)
        #expect(CalendarAgenda.events(on: date(0, day: 7), from: [holiday], now: date(14), calendar: calendar).isEmpty)
    }

    @Test func busyDaysMarkEveryDayWithAnEvent() {
        let busy = CalendarAgenda.busyDays(
            from: [event("a", date(9, day: 3), date(10, day: 3)), event("late", date(23), date(1, day: 7))],
            calendar: calendar
        )
        #expect(busy == [date(0, day: 3), date(0), date(0, day: 7)])
    }

    @Test func statusTellsOngoingSoonAndLater() {
        let now = date(14)
        #expect(CalendarAgenda.status(of: event("x", date(13), date(15)), at: now) == .ongoing)
        #expect(CalendarAgenda.status(of: event("x", date(14, 10), date(15)), at: now) == .startingSoon(minutes: 10))
        #expect(CalendarAgenda.status(of: event("x", date(14, 15), date(15)), at: now) == .startingSoon(minutes: 15))
        #expect(CalendarAgenda.status(of: event("x", date(14, 16), date(15)), at: now) == .later)
        #expect(CalendarAgenda.status(of: event("x", date(0), date(0, day: 7), allDay: true), at: now) == .allDay)
        // Partial minutes round up: 30 seconds to go reads "in 1 min".
        #expect(CalendarAgenda.status(of: event("x", now.addingTimeInterval(30), date(15)), at: now) == .startingSoon(minutes: 1))
    }
}

struct MeetingLinkTests {
    @Test func findsCommonMeetingServices() {
        let links = [
            "https://us02web.zoom.us/j/123456789?pwd=abc",
            "https://meet.google.com/abc-defg-hij",
            "https://teams.microsoft.com/l/meetup-join/19%3ameeting_x/0",
            "https://teams.live.com/meet/9876",
            "https://acme.webex.com/meet/jane",
            "https://facetime.apple.com/join#v=1&p=xyz",
        ]
        for link in links {
            #expect(MeetingLink.find(in: ["Join: \(link)"])?.absoluteString == link)
        }
    }

    @Test func ignoresOtherLinks() {
        #expect(MeetingLink.find(in: ["Agenda at https://docs.google.com/document/d/1"]) == nil)
        #expect(MeetingLink.find(in: [nil, "Room 4"]) == nil)
    }

    @Test func takesTheFirstFieldThatHasOne() {
        let url = MeetingLink.find(in: [nil, "https://meet.google.com/aaa-bbbb-ccc", "https://zoom.us/j/1"])
        #expect(url?.absoluteString == "https://meet.google.com/aaa-bbbb-ccc")
    }

    @Test func trimsTrailingPunctuation() {
        let url = MeetingLink.find(in: ["(link: https://zoom.us/j/42)."])
        #expect(url?.absoluteString == "https://zoom.us/j/42")
    }

    @Test func findsLinksInsideHTMLNotes() {
        let url = MeetingLink.find(in: [#"<a href="https://meet.google.com/xyz-abcd-efg">Join</a>"#])
        #expect(url?.absoluteString == "https://meet.google.com/xyz-abcd-efg")
    }
}

struct CalendarLayoutTests {
    let notch = CGSize(width: 185, height: 32)

    @Test func theOpenPlayerGrowsToTheRightForTheCalendar() {
        #expect(NotchLayout.calendarWidth == 240)
        // Symmetric: as wide as the clipboard on the left.
        #expect(NotchLayout.calendarWidth == NotchLayout.clipboardWidth)
        #expect(NotchLayout.trailingExtension(for: .expanded) == 240)
        #expect(NotchLayout.trailingExtension(for: .expandedEmpty) == 240)
        #expect(NotchLayout.trailingExtension(for: .video) == 0)
        let expected: CGFloat = 240 + 400 + 240
        #expect(NotchLayout.size(for: .expanded, notch: notch).width == expected)
    }
}
