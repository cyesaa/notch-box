import Foundation
import Testing
@testable import NotchBoxCore

struct AdapterStreamParserTests {
    let received = Date(timeIntervalSince1970: 1_800_000_000)

    func parse(_ line: String) -> AdapterStreamParser.Result {
        AdapterStreamParser.parse(line: line, receivedAt: received)
    }

    func info(_ line: String) -> NowPlayingInfo? {
        if case .info(let info) = parse(line) { return info }
        return nil
    }

    @Test func parsesPlayingTrack() {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.spotify.client","playing":true,"title":"Song","artist":"Artist","album":"Album","durationMicros":223000000,"elapsedTimeMicros":72000000,"timestampEpochMicros":1700000000000000,"playbackRate":1,"artworkData":"aGVsbG8=","artworkMimeType":"image/jpeg"}}"#
        let expected = NowPlayingInfo(
            title: "Song",
            artist: "Artist",
            album: "Album",
            sourceBundleIdentifier: "com.spotify.client",
            clock: PlaybackClock(elapsed: 72, timestamp: Date(timeIntervalSince1970: 1_700_000_000), rate: 1, isPlaying: true, duration: 223),
            artwork: Data("hello".utf8)
        )
        #expect(parse(line) == .info(expected))
    }

    @Test func prefersParentBundleIdentifier() {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.google.Chrome.helper","parentApplicationBundleIdentifier":"com.google.Chrome","playing":false,"title":"Video"}}"#
        #expect(info(line)?.sourceBundleIdentifier == "com.google.Chrome")
        #expect(info(line)?.clock.isPlaying == false)
    }

    @Test func acceptsNumericPlayingFlag() {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.apple.Music","playing":1,"title":"Song"}}"#
        #expect(info(line)?.clock.isPlaying == true)
    }

    @Test func emptyOrNullPayloadMeansNothingPlaying() {
        #expect(parse(#"{"type":"data","diff":false,"payload":{}}"#) == .nothingPlaying)
        #expect(parse(#"{"type":"data","diff":false,"payload":null}"#) == .nothingPlaying)
    }

    @Test func missingOrEmptyTitleMeansNothingPlaying() {
        #expect(parse(#"{"type":"data","diff":false,"payload":{"bundleIdentifier":"x","playing":true}}"#) == .nothingPlaying)
        #expect(parse(#"{"type":"data","diff":false,"payload":{"bundleIdentifier":"x","playing":true,"title":""}}"#) == .nothingPlaying)
    }

    @Test func rejectsGarbage() {
        #expect(parse("not json") == .invalid)
        #expect(parse("") == .invalid)
        #expect(parse(#"{"type":"other","payload":{}}"#) == .invalid)
        #expect(parse(#"{"payload":{}}"#) == .invalid)
    }

    @Test func missingTimestampUsesReceivedTime() {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"x","playing":true,"title":"Song","elapsedTimeMicros":5000000}}"#
        #expect(info(line)?.clock.timestamp == received)
        #expect(info(line)?.clock.elapsed == 5)
    }

    @Test func badFieldTypeDoesNotDropTheLine() {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"x","playing":true,"title":"Song","durationMicros":"abc"}}"#
        #expect(info(line)?.title == "Song")
        #expect(info(line)?.clock.duration == nil)
    }

    @Test func emptyArtistAndAlbumBecomeNil() {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"x","playing":true,"title":"Song","artist":"","album":""}}"#
        #expect(info(line)?.artist == nil)
        #expect(info(line)?.album == nil)
    }

    func payloadLine(_ fields: String) -> String {
        #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.apple.Music","playing":true,"title":"Song","# + fields + "}}"
    }

    @Test func hugeDurationBecomesNil() {
        #expect(info(payloadLine(#""durationMicros":1.7976931348623157e308"#))?.clock.duration == nil)
    }

    @Test func hugeElapsedIsClampedToMaxSeconds() {
        let clock = info(payloadLine(#""elapsedTimeMicros":1e300"#))?.clock
        #expect(clock?.elapsed == AdapterStreamParser.maxSeconds)
    }

    @Test func absurdRateFallsBackToOne() {
        #expect(info(payloadLine(#""playbackRate":1e300"#))?.clock.rate == 1)
    }

    @Test func absurdTimestampFallsBackToReceivedAt() {
        #expect(info(payloadLine(#""timestampEpochMicros":1e300"#))?.clock.timestamp == received)
    }

    @Test func invalidBase64ArtworkIsDropped() {
        let parsed = info(payloadLine(#""artworkData":"%%%""#))
        #expect(parsed != nil)
        #expect(parsed?.artwork == nil)
    }

    // Boundaries of the untrusted number bounds: the limit itself is accepted, just past it is not.
    // Microsecond values below 2^53 are exact doubles, so "limit + 1 µs" really is past the limit.

    @Test func durationAtMaxSecondsIsKept() {
        #expect(info(payloadLine(#""durationMicros":10000000000000"#))?.clock.duration == AdapterStreamParser.maxSeconds)
    }

    @Test func durationJustOverMaxSecondsBecomesNil() {
        #expect(info(payloadLine(#""durationMicros":10000000000001"#))?.clock.duration == nil)
    }

    @Test func zeroOrNegativeDurationBecomesNil() {
        #expect(info(payloadLine(#""durationMicros":0"#))?.clock.duration == nil)
        #expect(info(payloadLine(#""durationMicros":-1"#))?.clock.duration == nil)
    }

    @Test func smallestPositiveDurationIsKept() {
        #expect(info(payloadLine(#""durationMicros":1"#))?.clock.duration == 0.000001)
    }

    @Test func elapsedAtMaxSecondsIsKept() {
        #expect(info(payloadLine(#""elapsedTimeMicros":10000000000000"#))?.clock.elapsed == AdapterStreamParser.maxSeconds)
    }

    @Test func negativeElapsedIsClampedToZero() {
        #expect(info(payloadLine(#""elapsedTimeMicros":-1"#))?.clock.elapsed == 0)
    }

    @Test func rateAtMaxRateIsKeptInBothDirections() {
        #expect(info(payloadLine(#""playbackRate":16"#))?.clock.rate == AdapterStreamParser.maxRate)
        #expect(info(payloadLine(#""playbackRate":-16"#))?.clock.rate == -AdapterStreamParser.maxRate)
    }

    @Test func rateJustOverMaxRateFallsBackToOne() {
        #expect(info(payloadLine(#""playbackRate":16.000001"#))?.clock.rate == 1)
        #expect(info(payloadLine(#""playbackRate":-16.000001"#))?.clock.rate == 1)
    }

    @Test func timestampAtYear2100IsKept() {
        let timestamp = info(payloadLine(#""timestampEpochMicros":4102444800000000"#))?.clock.timestamp
        #expect(timestamp == Date(timeIntervalSince1970: AdapterStreamParser.maxEpochSeconds))
    }

    @Test func timestampJustAfterYear2100FallsBackToReceivedAt() {
        #expect(info(payloadLine(#""timestampEpochMicros":4102444800000001"#))?.clock.timestamp == received)
    }

    @Test func timestampAtTheEpochIsKeptButBeforeItFallsBack() {
        #expect(info(payloadLine(#""timestampEpochMicros":0"#))?.clock.timestamp == Date(timeIntervalSince1970: 0))
        #expect(info(payloadLine(#""timestampEpochMicros":-1"#))?.clock.timestamp == received)
    }

    @Test func numericTitleMeansNothingPlaying() {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.apple.Music","title":42}}"#
        #expect(parse(line) == .nothingPlaying)
    }
}
