import Foundation
import Testing
@testable import NotchBoxCore

struct NowPlayingStateTests {
    func info(playing: Bool) -> NowPlayingInfo {
        NowPlayingInfo(
            title: "Song", artist: nil, album: nil, sourceBundleIdentifier: "x",
            clock: PlaybackClock(elapsed: 0, timestamp: Date(timeIntervalSince1970: 0), rate: 1, isPlaying: playing, duration: nil),
            artwork: nil
        )
    }

    @Test func mapsToStateMachineMedia() {
        #expect(NowPlayingState.nothing.machineMedia == .nothing)
        #expect(NowPlayingState.unavailable.machineMedia == .unavailable)
        #expect(NowPlayingState.info(info(playing: true)).machineMedia == .playing)
        #expect(NowPlayingState.info(info(playing: false)).machineMedia == .paused)
    }

    @Test func mediaKeyCodes() {
        #expect(MediaKeyCode.code(for: .togglePlayPause) == 16)
        #expect(MediaKeyCode.code(for: .next) == 17)
        #expect(MediaKeyCode.code(for: .previous) == 18)
        #expect(MediaKeyCode.code(for: .seek(to: 10)) == nil)
    }
}
