/// Keeps a video's YouTube page playing in the notch. WebKit refuses the page's own attempts to play
/// with sound because no click led to them (the video's start, and each switch between an ad and the
/// video), so YouTube stops there. Asking the player to play from the app works, because WebKit treats
/// a call from the app like a click. After a few refusals in a row the app asks for muted playback
/// (YouTube's own button turns the sound back on), and after that it stops asking, so a page that never
/// plays cannot keep it busy.
public struct WatchPageAutoplay: Equatable, Sendable {
    public enum Request: Equatable, Sendable {
        case play
        case playMuted
        case giveUp
    }

    /// Refusals in a row answered with `.play` before asking for muted playback.
    public static let attemptsWithSound = 3

    private var refusedInARow = 0

    public init() {}

    /// The page tried to play and WebKit refused; what to ask the player for.
    public mutating func refused() -> Request {
        refusedInARow += 1
        if refusedInARow <= Self.attemptsWithSound { return .play }
        return refusedInARow == Self.attemptsWithSound + 1 ? .playMuted : .giveUp
    }

    /// Something started playing (an ad or the video), so the next refusal starts the count over.
    public mutating func started() {
        refusedInARow = 0
    }
}
