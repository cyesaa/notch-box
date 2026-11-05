import Testing
@testable import NotchBoxCore

struct TimeFormatterTests {
    @Test func formatsMinutesAndHours() {
        #expect(TimeFormatter.string(from: 0) == "0:00")
        #expect(TimeFormatter.string(from: 59.9) == "0:59")
        #expect(TimeFormatter.string(from: 72) == "1:12")
        #expect(TimeFormatter.string(from: 3723) == "1:02:03")
        #expect(TimeFormatter.string(from: -5) == "0:00")
    }

    @Test func formatsRemainingTime() {
        #expect(TimeFormatter.remaining(elapsed: 72, duration: 223) == "-2:31")
        #expect(TimeFormatter.remaining(elapsed: 300, duration: 223) == "-0:00")
    }

    @Test func nonFiniteInputFormatsAsZero() {
        #expect(TimeFormatter.string(from: .infinity) == "0:00")
        #expect(TimeFormatter.string(from: .nan) == "0:00")
        #expect(TimeFormatter.string(from: -.infinity) == "0:00")
    }

    @Test func hugeInputCapsAtNinetyNineHours() {
        #expect(TimeFormatter.string(from: .greatestFiniteMagnitude) == "99:59:59")
        #expect(TimeFormatter.string(from: 359_999) == "99:59:59")
    }

    @Test func remainingWithInfiniteDurationDoesNotTrapAndFormatsNonFiniteAsZero() {
        #expect(TimeFormatter.remaining(elapsed: 0, duration: .infinity) == "-0:00")
    }
}
