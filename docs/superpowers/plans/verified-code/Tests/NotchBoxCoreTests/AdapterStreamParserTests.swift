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
}
