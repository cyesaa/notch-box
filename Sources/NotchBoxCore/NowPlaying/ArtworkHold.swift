import Foundation

/// Which cover to show. The adapter sends a new track's metadata before its artwork, so the old cover
/// is kept for `holdDuration` to avoid a placeholder blink. The same bytes arriving again are not decoded again.
/// Generic over the image type so this stays free of AppKit (the app uses `NSImage`).
/// Pure value type: the caller passes the current time and calls `tick(at:)` at `nextDeadline`.
public struct ArtworkHold<Image> {
    public static var defaultHoldDuration: TimeInterval { 1.0 }

    public let holdDuration: TimeInterval
    /// nil shows the placeholder (no cover, or bytes that did not decode).
    public private(set) var image: Image?
    /// Bumped whenever `image` is replaced or cleared; drives the crossfade.
    public private(set) var version = 0
    /// The moment a held cover is cleared. nil when nothing is pending.
    public private(set) var nextDeadline: Date?

    /// Bytes of the cover currently shown, to skip rebuilding an identical image.
    private var displayedBytes: Data?
    private let decode: (Data) -> Image?

    /// Absorbs floating point error when comparing the time with the deadline.
    private static var tolerance: TimeInterval { 0.001 }

    public init(holdDuration: TimeInterval = ArtworkHold.defaultHoldDuration, decode: @escaping (Data) -> Image?) {
        self.holdDuration = holdDuration
        self.decode = decode
    }

    /// Call on every now playing change. `info` is nil when there is no track (nothing playing, degraded mode).
    public mutating func update(for info: NowPlayingInfo?, at now: Date) {
        guard let info else {
            nextDeadline = nil
            if image != nil { clear() }
            return
        }
        if let data = info.artwork {
            nextDeadline = nil
            if data != displayedBytes {
                image = decode(data)
                displayedBytes = data
                version += 1
            }
        } else if image != nil, nextDeadline == nil {
            nextDeadline = now.addingTimeInterval(holdDuration)
        }
    }

    public mutating func tick(at now: Date) {
        guard let nextDeadline, now >= nextDeadline.addingTimeInterval(-Self.tolerance) else { return }
        self.nextDeadline = nil
        clear()
    }

    /// Drops a pending clear without changing the cover, e.g. when the app stops.
    public mutating func cancelPending() {
        nextDeadline = nil
    }

    private mutating func clear() {
        image = nil
        displayedBytes = nil
        version += 1
    }
}
