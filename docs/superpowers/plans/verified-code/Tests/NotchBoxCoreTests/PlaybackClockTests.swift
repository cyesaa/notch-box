import Foundation
import Testing
@testable import NotchBoxCore

struct PlaybackClockTests {
    let t0 = Date(timeIntervalSince1970: 1_000)

    func clock(elapsed: TimeInterval = 10, rate: Double = 1, playing: Bool = true, duration: TimeInterval? = 200) -> PlaybackClock {
        PlaybackClock(elapsed: elapsed, timestamp: t0, rate: rate, isPlaying: playing, duration: duration)
    }

    @Test func pausedClockDoesNotAdvance() {
        #expect(clock(playing: false).elapsed(at: t0.addingTimeInterval(5)) == 10)
    }

    @Test func playingClockAdvancesWithRate() {
        #expect(clock().elapsed(at: t0.addingTimeInterval(5)) == 15)
        #expect(clock(rate: 2).elapsed(at: t0.addingTimeInterval(5)) == 20)
    }

    @Test func zeroRateWhilePlayingCountsAsNormalSpeed() {
        #expect(clock(rate: 0).elapsed(at: t0.addingTimeInterval(5)) == 15)
    }

    @Test func clampsToDurationAndZero() {
        #expect(clock(duration: 12).elapsed(at: t0.addingTimeInterval(5)) == 12)
        #expect(clock(elapsed: -3, playing: false).elapsed(at: t0) == 0)
    }

    @Test func futureTimestampDoesNotGoBackwards() {
        let future = PlaybackClock(elapsed: 10, timestamp: t0.addingTimeInterval(5), rate: 1, isPlaying: true, duration: 200)
        #expect(future.elapsed(at: t0) == 10)
    }

    @Test func seekedResetsPositionAndTimestamp() {
        let seeked = clock().seeked(to: 30, at: t0.addingTimeInterval(100))
        #expect(seeked.elapsed(at: t0.addingTimeInterval(101)) == 31)
    }

    @Test func hasDurationOnlyForPositiveDurations() {
        #expect(clock(duration: 200).hasDuration)
        #expect(!clock(duration: 0).hasDuration)
        #expect(!clock(duration: nil).hasDuration)
    }
}
