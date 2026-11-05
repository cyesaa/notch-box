import Foundation
import Testing
@testable import NotchBoxCore

struct NothingPlayingFilterTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func track(_ title: String) -> NowPlayingInfo {
        NowPlayingInfo(
            title: title, artist: nil, album: nil, sourceBundleIdentifier: "com.apple.Music",
            clock: PlaybackClock(elapsed: 0, timestamp: Date(timeIntervalSince1970: 0), rate: 1, isPlaying: true, duration: nil),
            artwork: nil
        )
    }

    /// A filter that shows `track("A")`.
    func playingFilter() -> NothingPlayingFilter {
        var filter = NothingPlayingFilter()
        filter.received(track("A"))
        return filter
    }

    @Test func defaultGraceIsOneAndAHalfSeconds() {
        #expect(NothingPlayingFilter.defaultGrace == 1.5)
        #expect(NothingPlayingFilter().grace == 1.5)
    }

    @Test func startsWithNothingAndNoDeadline() {
        let filter = NothingPlayingFilter()
        #expect(filter.state == .nothing)
        #expect(filter.nextDeadline == nil)
    }

    @Test func trackIsShownAtOnce() {
        let filter = playingFilter()
        #expect(filter.state == .info(track("A")))
        #expect(filter.nextDeadline == nil)
    }

    @Test func nothingAfterATrackWaitsForTheGrace() {
        var filter = playingFilter()
        filter.receivedNothing(at: at(1))
        #expect(filter.state == .info(track("A")))
        #expect(filter.nextDeadline == at(2.5))
        filter.tick(at: at(2.4))
        #expect(filter.state == .info(track("A")))
        filter.tick(at: at(2.5))
        #expect(filter.state == .nothing)
        #expect(filter.nextDeadline == nil)
    }

    @Test func tickWithinAMillisecondOfTheDeadlineApplies() {
        var filter = playingFilter()
        filter.receivedNothing(at: at(1))
        filter.tick(at: at(2.4995))
        #expect(filter.state == .nothing)
    }

    @Test func trackWithinTheGraceCancelsNothing() {
        var filter = playingFilter()
        filter.receivedNothing(at: at(1))
        filter.received(track("B"))
        #expect(filter.state == .info(track("B")))
        #expect(filter.nextDeadline == nil)
        filter.tick(at: at(3))
        #expect(filter.state == .info(track("B")))
    }

    @Test func repeatedNothingKeepsTheFirstDeadline() {
        var filter = playingFilter()
        filter.receivedNothing(at: at(1))
        filter.receivedNothing(at: at(2))
        #expect(filter.nextDeadline == at(2.5))
    }

    @Test func nothingWhileShowingNothingSchedulesNothing() {
        var filter = NothingPlayingFilter()
        filter.receivedNothing(at: t0)
        #expect(filter.state == .nothing)
        #expect(filter.nextDeadline == nil)
    }

    @Test func unavailableIsShownAtOnceAndCancelsPendingNothing() {
        var filter = playingFilter()
        filter.receivedNothing(at: at(1))
        filter.becameUnavailable()
        #expect(filter.state == .unavailable)
        #expect(filter.nextDeadline == nil)
        filter.tick(at: at(3))
        #expect(filter.state == .unavailable)
    }

    @Test func nothingWhileUnavailableAlsoWaitsForTheGrace() {
        var filter = NothingPlayingFilter()
        filter.becameUnavailable()
        filter.receivedNothing(at: t0)
        #expect(filter.state == .unavailable)
        #expect(filter.nextDeadline == at(1.5))
        filter.tick(at: at(1.5))
        #expect(filter.state == .nothing)
    }

    @Test func cancelPendingKeepsTheCurrentState() {
        var filter = playingFilter()
        filter.receivedNothing(at: at(1))
        filter.cancelPending()
        #expect(filter.nextDeadline == nil)
        filter.tick(at: at(3))
        #expect(filter.state == .info(track("A")))
    }

    @Test func customGraceIsUsed() {
        var filter = NothingPlayingFilter(grace: 5)
        filter.received(track("A"))
        filter.receivedNothing(at: t0)
        #expect(filter.nextDeadline == at(5))
    }
}
