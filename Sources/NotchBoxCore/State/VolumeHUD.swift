import Foundation

/// When to show the volume row under the notch: for a moment after the system volume changes.
/// The first reported volume (at launch, or the start value) is only recorded.
/// Pure value type: the caller passes the current time and calls `tick(at:)` at `nextDeadline`.
public struct VolumeHUD: Sendable {
    public static let displayDuration: TimeInterval = 1.5
    /// Volume steps smaller than this are noise (float round-trips through Core Audio).
    private static let minimumChange: Float = 0.001

    public private(set) var nextDeadline: Date?
    private var lastVolume: Float?

    public init() {}

    public mutating func volumeReported(_ volume: Float, at now: Date) {
        defer { lastVolume = volume }
        guard let lastVolume, abs(volume - lastVolume) >= Self.minimumChange else { return }
        nextDeadline = now.addingTimeInterval(Self.displayDuration)
    }

    public func isVisible(at now: Date) -> Bool {
        guard let nextDeadline else { return false }
        return now < nextDeadline
    }

    public mutating func tick(at now: Date) {
        if !isVisible(at: now) { nextDeadline = nil }
    }

    public mutating func hide() {
        nextDeadline = nil
    }
}
