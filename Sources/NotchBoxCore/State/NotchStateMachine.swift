import Foundation

/// Decides which `NotchDisplayState` to show from hover, media and time.
/// Pure value type: the caller passes the current time and calls `tick(at:)` at `nextDeadline`.
public struct NotchStateMachine: Sendable {
    public struct Timing: Equatable, Sendable {
        public var openDelay: TimeInterval
        public var closeDelay: TimeInterval
        public var pauseTimeout: TimeInterval

        public init(openDelay: TimeInterval = 0.1, closeDelay: TimeInterval = 0.3, pauseTimeout: TimeInterval = 300) {
            self.openDelay = openDelay
            self.closeDelay = closeDelay
            self.pauseTimeout = pauseTimeout
        }
    }

    public enum Media: Equatable, Sendable {
        case nothing
        case playing
        case paused
        /// Degraded mode: no track info, but controls still work.
        case unavailable
    }

    public let timing: Timing
    public private(set) var displayState: NotchDisplayState = .idle

    private var media: Media = .nothing
    private var pausedSince: Date?
    private var isHovering = false
    private var hoverChangedAt = Date.distantPast
    private var isOpen = false

    /// Absorbs floating point error when comparing elapsed time with delays.
    private static let tolerance: TimeInterval = 0.001

    public init(timing: Timing = Timing()) {
        self.timing = timing
    }

    public mutating func setHovering(_ hovering: Bool, at now: Date) {
        if hovering != isHovering {
            isHovering = hovering
            hoverChangedAt = now
        }
        update(at: now)
    }

    public mutating func setMedia(_ newMedia: Media, at now: Date) {
        if newMedia == .paused {
            if media != .paused { pausedSince = now }
        } else {
            pausedSince = nil
        }
        media = newMedia
        update(at: now)
    }

    public mutating func tick(at now: Date) {
        update(at: now)
    }

    /// The next moment the state may change on its own. nil when nothing is pending.
    public var nextDeadline: Date? {
        var candidates: [Date] = []
        if isHovering && !isOpen {
            candidates.append(hoverChangedAt.addingTimeInterval(timing.openDelay))
        }
        if !isHovering && isOpen {
            candidates.append(hoverChangedAt.addingTimeInterval(timing.closeDelay))
        }
        if displayState == .mini, media == .paused, let pausedSince {
            candidates.append(pausedSince.addingTimeInterval(timing.pauseTimeout))
        }
        return candidates.min()
    }

    private mutating func update(at now: Date) {
        let sinceHoverChange = now.timeIntervalSince(hoverChangedAt)
        if isHovering && !isOpen && sinceHoverChange >= timing.openDelay - Self.tolerance {
            isOpen = true
        }
        if !isHovering && isOpen && sinceHoverChange >= timing.closeDelay - Self.tolerance {
            isOpen = false
        }
        if isOpen {
            displayState = media == .nothing ? .expandedEmpty : .expanded
        } else {
            displayState = showsMini(at: now) ? .mini : .idle
        }
    }

    private func showsMini(at now: Date) -> Bool {
        switch media {
        case .playing:
            return true
        case .paused:
            guard let pausedSince else { return false }
            return now.timeIntervalSince(pausedSince) < timing.pauseTimeout - Self.tolerance
        case .nothing, .unavailable:
            return false
        }
    }
}
