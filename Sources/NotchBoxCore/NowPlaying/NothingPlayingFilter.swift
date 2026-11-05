import Foundation

/// Decides which `NowPlayingState` to publish from the adapter's stream.
/// On a track change the adapter briefly reports an empty payload between two tracks, so
/// "nothing playing" is applied only if no track arrives within `grace` (see docs/spike-results.md).
/// Pure value type: the caller passes the current time and calls `tick(at:)` at `nextDeadline`.
public struct NothingPlayingFilter: Sendable {
    public static let defaultGrace: TimeInterval = 1.5

    public let grace: TimeInterval
    public private(set) var state: NowPlayingState = .nothing

    private var nothingDueAt: Date?

    /// Absorbs floating point error when comparing the time with the deadline.
    private static let tolerance: TimeInterval = 0.001

    public init(grace: TimeInterval = NothingPlayingFilter.defaultGrace) {
        self.grace = grace
    }

    /// The moment a pending "nothing playing" applies. nil when nothing is pending.
    public var nextDeadline: Date? { nothingDueAt }

    /// A stream line with an empty payload. Repeats do not push the deadline back.
    public mutating func receivedNothing(at now: Date) {
        guard state != .nothing, nothingDueAt == nil else { return }
        nothingDueAt = now.addingTimeInterval(grace)
    }

    public mutating func received(_ info: NowPlayingInfo) {
        nothingDueAt = nil
        state = .info(info)
    }

    /// Degraded mode applies at once and drops a pending "nothing playing".
    public mutating func becameUnavailable() {
        nothingDueAt = nil
        state = .unavailable
    }

    public mutating func tick(at now: Date) {
        guard let nothingDueAt, now >= nothingDueAt.addingTimeInterval(-Self.tolerance) else { return }
        self.nothingDueAt = nil
        state = .nothing
    }

    /// Drops a pending "nothing playing" without changing the state, e.g. when the service stops.
    public mutating func cancelPending() {
        nothingDueAt = nil
    }
}
