import Foundation

/// Playback position at a point in time, extrapolated locally so the UI does not poll.
public struct PlaybackClock: Equatable, Sendable {
    /// Seconds elapsed at `timestamp`.
    public var elapsed: TimeInterval
    public var timestamp: Date
    public var rate: Double
    public var isPlaying: Bool
    /// Track length in seconds; nil or 0 for live streams.
    public var duration: TimeInterval?

    public init(elapsed: TimeInterval, timestamp: Date, rate: Double, isPlaying: Bool, duration: TimeInterval?) {
        self.elapsed = elapsed
        self.timestamp = timestamp
        self.rate = rate
        self.isPlaying = isPlaying
        self.duration = duration
    }

    public var hasDuration: Bool { (duration ?? 0) > 0 }

    public func elapsed(at now: Date) -> TimeInterval {
        var value = elapsed
        if isPlaying {
            let effectiveRate = rate > 0 ? rate : 1
            value += max(0, now.timeIntervalSince(timestamp)) * effectiveRate
        }
        if let duration, duration > 0 {
            value = min(value, duration)
        }
        return max(0, value)
    }

    public func seeked(to position: TimeInterval, at now: Date) -> PlaybackClock {
        var copy = self
        copy.elapsed = position
        copy.timestamp = now
        return copy
    }
}
