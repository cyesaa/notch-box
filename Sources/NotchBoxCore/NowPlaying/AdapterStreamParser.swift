import Foundation

/// Payload of a mediaremote-adapter line produced with `--micros`.
/// Every field is decoded leniently: a field with an unexpected type becomes nil
/// instead of dropping the whole line.
struct NowPlayingPayload: Decodable, Equatable {
    var bundleIdentifier: String?
    var parentApplicationBundleIdentifier: String?
    var playing: Bool?
    var title: String?
    var artist: String?
    var album: String?
    var durationMicros: Double?
    var elapsedTimeMicros: Double?
    var timestampEpochMicros: Double?
    var playbackRate: Double?
    var artworkData: String?

    enum CodingKeys: String, CodingKey {
        case bundleIdentifier, parentApplicationBundleIdentifier, playing, title, artist, album
        case durationMicros, elapsedTimeMicros, timestampEpochMicros, playbackRate, artworkData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try? container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        parentApplicationBundleIdentifier = try? container.decodeIfPresent(String.self, forKey: .parentApplicationBundleIdentifier)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        artist = try? container.decodeIfPresent(String.self, forKey: .artist)
        album = try? container.decodeIfPresent(String.self, forKey: .album)
        durationMicros = try? container.decodeIfPresent(Double.self, forKey: .durationMicros)
        elapsedTimeMicros = try? container.decodeIfPresent(Double.self, forKey: .elapsedTimeMicros)
        timestampEpochMicros = try? container.decodeIfPresent(Double.self, forKey: .timestampEpochMicros)
        playbackRate = try? container.decodeIfPresent(Double.self, forKey: .playbackRate)
        artworkData = try? container.decodeIfPresent(String.self, forKey: .artworkData)
        if let flag = try? container.decodeIfPresent(Bool.self, forKey: .playing) {
            playing = flag
        } else if let number = try? container.decodeIfPresent(Int.self, forKey: .playing) {
            playing = number != 0
        } else {
            playing = nil
        }
    }
}

/// One `stream` line: {"type":"data","diff":false,"payload":{...}}
struct StreamEnvelope: Decodable {
    let type: String
    let payload: NowPlayingPayload?
}

public enum AdapterStreamParser {
    public enum Result: Equatable, Sendable {
        case nothingPlaying
        case info(NowPlayingInfo)
        case invalid
    }

    /// Bounds for untrusted adapter values.
    static let maxSeconds: TimeInterval = 10_000_000
    static let maxRate: Double = 16
    static let maxEpochSeconds: TimeInterval = 4_102_444_800 // year 2100

    public static func parse(line: String, receivedAt now: Date) -> Result {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(StreamEnvelope.self, from: data),
              envelope.type == "data"
        else { return .invalid }
        guard let payload = envelope.payload, let info = makeInfo(from: payload, receivedAt: now) else {
            return .nothingPlaying
        }
        return .info(info)
    }

    static func makeInfo(from payload: NowPlayingPayload, receivedAt now: Date) -> NowPlayingInfo? {
        guard let title = payload.title, !title.isEmpty, let bundle = payload.bundleIdentifier else { return nil }
        var duration: TimeInterval?
        if let micros = payload.durationMicros, micros.isFinite {
            let value = micros / 1_000_000
            if value > 0, value <= maxSeconds { duration = value }
        }
        var elapsed: TimeInterval = 0
        if let micros = payload.elapsedTimeMicros, micros.isFinite {
            elapsed = min(max(0, micros / 1_000_000), maxSeconds)
        }
        var rate = 1.0
        if let value = payload.playbackRate, value.isFinite, abs(value) <= maxRate { rate = value }
        var timestamp = now
        if let micros = payload.timestampEpochMicros, micros.isFinite {
            let value = micros / 1_000_000
            if value >= 0, value <= maxEpochSeconds { timestamp = Date(timeIntervalSince1970: value) }
        }
        let clock = PlaybackClock(
            elapsed: elapsed,
            timestamp: timestamp,
            rate: rate,
            isPlaying: payload.playing ?? false,
            duration: duration
        )
        return NowPlayingInfo(
            title: title,
            artist: nonEmpty(payload.artist),
            album: nonEmpty(payload.album),
            sourceBundleIdentifier: nonEmpty(payload.parentApplicationBundleIdentifier) ?? bundle,
            clock: clock,
            artwork: payload.artworkData.flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) }
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
