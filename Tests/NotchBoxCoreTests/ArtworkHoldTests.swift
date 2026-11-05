import Foundation
import Testing
@testable import NotchBoxCore

struct ArtworkHoldTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    /// Counts decodes; reference type so the escaping closure can update it.
    final class DecodeLog {
        var count = 0
    }

    /// Images are strings in these tests; bytes that are not UTF-8 fail to decode.
    func makeHold(_ log: DecodeLog = DecodeLog()) -> ArtworkHold<String> {
        ArtworkHold { data in
            log.count += 1
            return String(data: data, encoding: .utf8)
        }
    }

    func track(artwork: String?) -> NowPlayingInfo {
        track(artworkData: artwork.map { Data($0.utf8) })
    }

    func track(artworkData: Data?) -> NowPlayingInfo {
        NowPlayingInfo(
            title: "Song", artist: nil, album: nil, sourceBundleIdentifier: "com.apple.Music",
            clock: PlaybackClock(elapsed: 0, timestamp: Date(timeIntervalSince1970: 0), rate: 1, isPlaying: true, duration: nil),
            artwork: artworkData
        )
    }

    /// A hold that shows cover "A" (version 1).
    func showingA(_ log: DecodeLog = DecodeLog()) -> ArtworkHold<String> {
        var hold = makeHold(log)
        hold.update(for: track(artwork: "A"), at: t0)
        return hold
    }

    @Test func defaultHoldIsOneSecond() {
        #expect(ArtworkHold<String>.defaultHoldDuration == 1)
        #expect(makeHold().holdDuration == 1)
    }

    @Test func startsEmpty() {
        let hold = makeHold()
        #expect(hold.image == nil)
        #expect(hold.version == 0)
        #expect(hold.nextDeadline == nil)
    }

    @Test func firstCoverIsShownAtOnce() {
        let hold = showingA()
        #expect(hold.image == "A")
        #expect(hold.version == 1)
        #expect(hold.nextDeadline == nil)
    }

    @Test func sameBytesAreNotDecodedAgain() {
        let log = DecodeLog()
        var hold = showingA(log)
        hold.update(for: track(artwork: "A"), at: at(1))
        #expect(log.count == 1)
        #expect(hold.version == 1)
    }

    @Test func newBytesReplaceTheCover() {
        var hold = showingA()
        hold.update(for: track(artwork: "B"), at: at(1))
        #expect(hold.image == "B")
        #expect(hold.version == 2)
    }

    @Test func trackWithoutArtworkKeepsTheOldCoverForTheHold() {
        var hold = showingA()
        hold.update(for: track(artwork: nil), at: at(1))
        #expect(hold.image == "A")
        #expect(hold.nextDeadline == at(2))
        hold.tick(at: at(1.9))
        #expect(hold.image == "A")
        hold.tick(at: at(2))
        #expect(hold.image == nil)
        #expect(hold.version == 2)
        #expect(hold.nextDeadline == nil)
    }

    @Test func tickWithinAMillisecondOfTheDeadlineClears() {
        var hold = showingA()
        hold.update(for: track(artwork: nil), at: at(1))
        hold.tick(at: at(1.9995))
        #expect(hold.image == nil)
    }

    @Test func coverArrivingWithinTheHoldReplacesTheOldOne() {
        var hold = showingA()
        hold.update(for: track(artwork: nil), at: at(1))
        hold.update(for: track(artwork: "B"), at: at(1.5))
        #expect(hold.image == "B")
        #expect(hold.version == 2)
        #expect(hold.nextDeadline == nil)
        hold.tick(at: at(3))
        #expect(hold.image == "B")
    }

    @Test func sameCoverReturningWithinTheHoldStaysWithoutACrossfade() {
        var hold = showingA()
        hold.update(for: track(artwork: nil), at: at(1))
        hold.update(for: track(artwork: "A"), at: at(1.5))
        #expect(hold.image == "A")
        #expect(hold.version == 1)
        #expect(hold.nextDeadline == nil)
    }

    @Test func repeatedTracksWithoutArtworkKeepTheFirstDeadline() {
        var hold = showingA()
        hold.update(for: track(artwork: nil), at: at(1))
        hold.update(for: track(artwork: nil), at: at(1.5))
        #expect(hold.nextDeadline == at(2))
    }

    @Test func noTrackClearsAtOnce() {
        var hold = showingA()
        hold.update(for: nil, at: at(1))
        #expect(hold.image == nil)
        #expect(hold.version == 2)
        #expect(hold.nextDeadline == nil)
    }

    @Test func noTrackDuringTheHoldClearsAtOnceAndOnlyOnce() {
        var hold = showingA()
        hold.update(for: track(artwork: nil), at: at(1))
        hold.update(for: nil, at: at(1.2))
        #expect(hold.image == nil)
        #expect(hold.version == 2)
        #expect(hold.nextDeadline == nil)
        hold.tick(at: at(3))
        #expect(hold.version == 2)
    }

    @Test func noTrackWithoutACoverChangesNothing() {
        var hold = makeHold()
        hold.update(for: nil, at: t0)
        #expect(hold.version == 0)
    }

    @Test func trackWithoutArtworkAndNoCoverSchedulesNothing() {
        var hold = makeHold()
        hold.update(for: track(artwork: nil), at: t0)
        #expect(hold.nextDeadline == nil)
        #expect(hold.version == 0)
    }

    @Test func clearedCoverIsDecodedAgainWhenItReturns() {
        let log = DecodeLog()
        var hold = showingA(log)
        hold.update(for: nil, at: at(1))
        hold.update(for: track(artwork: "A"), at: at(2))
        #expect(hold.image == "A")
        #expect(hold.version == 3)
        #expect(log.count == 2)
    }

    @Test func undecodableBytesShowThePlaceholderAndAreNotDecodedAgain() {
        let log = DecodeLog()
        let bad = Data([0xFF, 0xFE])
        var hold = makeHold(log)
        hold.update(for: track(artworkData: bad), at: t0)
        #expect(hold.image == nil)
        #expect(hold.version == 1)
        hold.update(for: track(artworkData: bad), at: at(1))
        #expect(log.count == 1)
        #expect(hold.version == 1)
    }

    @Test func undecodableCoverIsNotHeldOrCleared() {
        var hold = makeHold()
        hold.update(for: track(artworkData: Data([0xFF])), at: t0)
        hold.update(for: track(artwork: nil), at: at(1))
        #expect(hold.nextDeadline == nil)
        hold.update(for: nil, at: at(2))
        #expect(hold.version == 1)
    }

    @Test func cancelPendingKeepsTheCover() {
        var hold = showingA()
        hold.update(for: track(artwork: nil), at: at(1))
        hold.cancelPending()
        #expect(hold.nextDeadline == nil)
        hold.tick(at: at(3))
        #expect(hold.image == "A")
    }

    @Test func customHoldDurationIsUsed() {
        var hold = ArtworkHold<String>(holdDuration: 3) { String(data: $0, encoding: .utf8) }
        hold.update(for: track(artwork: "A"), at: t0)
        hold.update(for: track(artwork: nil), at: at(1))
        #expect(hold.nextDeadline == at(4))
    }
}
