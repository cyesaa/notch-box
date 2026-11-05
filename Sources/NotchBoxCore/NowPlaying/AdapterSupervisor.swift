import Foundation

/// Restart policy for the adapter `stream` process.
public struct AdapterSupervisor: Sendable {
    public static let restartDelays: [TimeInterval] = [1, 2, 5, 10, 30]
    public static let quickExitWindow: TimeInterval = 5
    public static let quickExitLimit = 3
    public static let degradedRetryInterval: TimeInterval = 60

    public private(set) var isDegraded = false

    private var startedAt: Date?
    private var restartIndex = 0
    private var consecutiveQuickExits = 0

    public init() {}

    public mutating func processStarted(at now: Date) {
        startedAt = now
    }

    /// Any parseable line proves the adapter works: restart backoff and degraded mode reset.
    /// Quick exits keep counting (they reset only after a run of at least `quickExitWindow`),
    /// so an adapter that prints once and then crashes immediately still ends up degraded.
    public mutating func receivedOutput() {
        restartIndex = 0
        isDegraded = false
    }

    /// Call when the process exits or fails to launch. Returns the delay before the next launch.
    public mutating func processExited(at now: Date) -> TimeInterval {
        let ranFor = startedAt.map { now.timeIntervalSince($0) } ?? 0
        startedAt = nil
        if ranFor < Self.quickExitWindow {
            consecutiveQuickExits += 1
        } else {
            consecutiveQuickExits = 0
        }
        if consecutiveQuickExits >= Self.quickExitLimit {
            isDegraded = true
        }
        if isDegraded {
            return Self.degradedRetryInterval
        }
        let delay = Self.restartDelays[min(restartIndex, Self.restartDelays.count - 1)]
        restartIndex += 1
        return delay
    }
}
