import Foundation

public struct NowPlayingInfo: Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var album: String?
    /// The app to show and open: the parent app for browser helpers.
    public var sourceBundleIdentifier: String
    public var clock: PlaybackClock
    public var artwork: Data?

    public init(title: String, artist: String?, album: String?, sourceBundleIdentifier: String, clock: PlaybackClock, artwork: Data?) {
        self.title = title
        self.artist = artist
        self.album = album
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.clock = clock
        self.artwork = artwork
    }
}

public enum NowPlayingState: Equatable, Sendable {
    case nothing
    case info(NowPlayingInfo)
    /// Degraded mode: the adapter does not work.
    case unavailable

    public var machineMedia: NotchStateMachine.Media {
        switch self {
        case .nothing: return .nothing
        case .unavailable: return .unavailable
        case .info(let info): return info.clock.isPlaying ? .playing : .paused
        }
    }
}

public enum MediaCommand: Equatable, Sendable {
    case togglePlayPause
    case next
    case previous
    /// Absolute position in seconds.
    case seek(to: TimeInterval)
}

/// Source of now playing info and sink for commands.
@MainActor
public protocol NowPlayingService: AnyObject {
    var state: NowPlayingState { get }
    var onChange: ((NowPlayingState) -> Void)? { get set }
    func start()
    func stop()
    func send(_ command: MediaCommand)
}

/// NX_KEYTYPE_* codes for the media key fallback used in degraded mode.
public enum MediaKeyCode {
    public static let playPause: Int32 = 16
    public static let next: Int32 = 17
    public static let previous: Int32 = 18

    /// nil for commands media keys cannot express (seek).
    public static func code(for command: MediaCommand) -> Int32? {
        switch command {
        case .togglePlayPause: return playPause
        case .next: return next
        case .previous: return previous
        case .seek: return nil
        }
    }
}
