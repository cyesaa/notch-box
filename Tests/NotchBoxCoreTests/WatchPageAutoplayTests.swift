import Testing
@testable import NotchBoxCore

struct WatchPageAutoplayTests {
    @Test func asksToPlayWithSoundAFewTimesThenMutedThenGivesUp() {
        var autoplay = WatchPageAutoplay()
        let requests = (0..<(WatchPageAutoplay.attemptsWithSound + 3)).map { _ in autoplay.refused() }
        #expect(requests == Array(repeating: .play, count: WatchPageAutoplay.attemptsWithSound) + [.playMuted, .giveUp, .giveUp])
    }

    @Test func playbackStartingStartsTheCountOver() {
        var autoplay = WatchPageAutoplay()
        for _ in 0..<WatchPageAutoplay.attemptsWithSound { _ = autoplay.refused() }
        autoplay.started()
        #expect(autoplay.refused() == .play)
    }

    /// Each ad and the video itself are separate sources, each refused once before it plays.
    @Test func everyAdAndTheVideoGetTheirOwnAttempts() {
        var autoplay = WatchPageAutoplay()
        for _ in 0..<5 {
            #expect(autoplay.refused() == .play)
            autoplay.started()
        }
    }

    @Test func triesWithSoundThreeTimes() {
        #expect(WatchPageAutoplay.attemptsWithSound == 3)
    }
}
