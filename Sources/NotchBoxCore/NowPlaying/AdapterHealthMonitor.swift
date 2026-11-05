import Foundation

/// Schedules the adapter's `test` command and remembers whether it failed.
/// When macOS silently blocks MediaRemote, `stream` keeps running and only reports empty payloads,
/// so `AdapterSupervisor` never notices; `test` exits non-zero instead.
/// Pure value type: the caller passes the current time and calls `tick(at:)` at `nextDeadline`.
public struct AdapterHealthMonitor: Sendable {
    public static let checkInterval: TimeInterval = 30 * 60
    /// A normal check takes at most about 10 s (two 2 s reads, 3 s client setup, 3 s cleanup).
    public static let checkTimeout: TimeInterval = 30

    public enum Action: Equatable, Sendable {
        /// Run `… test` now and report its result with `checkFinished(passed:at:)`.
        case startCheck
        /// The running check timed out and already counts as failed: terminate it.
        case stopCheck
    }

    /// The last check failed and no track info has arrived since.
    public private(set) var isFailing = false

    private var checkStartedAt: Date?
    private var nextCheckAt: Date?

    /// Absorbs floating point error when comparing the time with deadlines.
    private static let tolerance: TimeInterval = 0.001

    public init() {}

    public var isChecking: Bool { checkStartedAt != nil }

    /// The running check's timeout, or the next scheduled check. nil when nothing is scheduled.
    public var nextDeadline: Date? {
        if let checkStartedAt { return checkStartedAt.addingTimeInterval(Self.checkTimeout) }
        return nextCheckAt
    }

    /// At launch and after wake: check now unless a check is already running.
    public mutating func requestCheck(at now: Date) -> Action? {
        guard checkStartedAt == nil else { return nil }
        return startCheck(at: now)
    }

    public mutating func tick(at now: Date) -> Action? {
        guard let deadline = nextDeadline, now >= deadline.addingTimeInterval(-Self.tolerance) else { return nil }
        if checkStartedAt != nil {
            finish(passed: false, at: now)
            return .stopCheck
        }
        return startCheck(at: now)
    }

    /// Ignored when no check is running, e.g. the exit of a check that already timed out.
    public mutating func checkFinished(passed: Bool, at now: Date) {
        guard checkStartedAt != nil else { return }
        finish(passed: passed, at: now)
    }

    /// Real track info from `stream` proves MediaRemote works, whatever the last check said.
    public mutating func receivedTrackInfo() {
        isFailing = false
    }

    /// What to publish: degraded mode while failing, otherwise the stream's state.
    public func state(from streamState: NowPlayingState) -> NowPlayingState {
        isFailing ? .unavailable : streamState
    }

    /// Stops scheduling and forgets a running check (the caller terminates it). Keeps `isFailing`.
    public mutating func cancel() {
        checkStartedAt = nil
        nextCheckAt = nil
    }

    private mutating func startCheck(at now: Date) -> Action {
        checkStartedAt = now
        nextCheckAt = nil
        return .startCheck
    }

    private mutating func finish(passed: Bool, at now: Date) {
        checkStartedAt = nil
        isFailing = !passed
        nextCheckAt = now.addingTimeInterval(Self.checkInterval)
    }
}
