import AppKit
import ImageIO
import NotchBoxCore
import SwiftUI
import UniformTypeIdentifiers

/// `NotchBox.app/Contents/MacOS/NotchBox --render-snapshots <dir>` draws every notch state with sample
/// data into PNGs and exits, without opening a window. Used to review the UI (no Xcode previews here).
@MainActor
enum SnapshotRenderer {
    static let argument = "--render-snapshots"

    private struct Scene {
        let name: String
        let state: NowPlayingState
        let hovering: Bool
    }

    static func render(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let warm = makeCover(colors: [NSColor(srgbRed: 1, green: 0.62, blue: 0.3, alpha: 1), NSColor(srgbRed: 0.85, green: 0.2, blue: 0.45, alpha: 1)])
        let video = makeCover(
            colors: [NSColor(srgbRed: 0.55, green: 0.7, blue: 0.8, alpha: 1), NSColor(srgbRed: 0.8, green: 0.6, blue: 0.4, alpha: 1)],
            width: 480, height: 270
        )
        let cool = makeCover(colors: [NSColor(srgbRed: 0.2, green: 0.75, blue: 0.85, alpha: 1), NSColor(srgbRed: 0.15, green: 0.2, blue: 0.6, alpha: 1)])
        let scenes = [
            Scene(name: "1-mini-video-thumbnail", state: .info(track("Sena Şener - Alışılır Mı Aşka (Visualizer)", "Sena Şener", nil, playing: true, artwork: video, app: "com.google.Chrome")), hovering: false),
            Scene(name: "2-expanded-video-thumbnail", state: .info(track("Sena Şener - Alışılır Mı Aşka (Visualizer)", "Sena Şener", nil, playing: true, artwork: video, app: "com.google.Chrome")), hovering: true),
            Scene(name: "2b-expanded-square-cover", state: .info(track("Golden Hour", "Kai Moreno", "Late Light", playing: true, artwork: warm)), hovering: true),
            Scene(name: "3-expanded-paused-long-title", state: .info(track("A Very Long Song Title That Does Not Fit On One Line", "Ocean Avenue Collective", nil, playing: false, artwork: cool)), hovering: true),
            Scene(name: "4-expanded-no-artwork", state: .info(track("Live Radio", nil, nil, playing: true, artwork: nil, duration: nil, app: "com.apple.Safari")), hovering: true),
            Scene(name: "5-nothing-playing", state: .nothing, hovering: true),
            Scene(name: "6-unavailable", state: .unavailable, hovering: true),
        ]
        for scene in scenes {
            try render(scene, to: directory.appendingPathComponent(scene.name + ".png"))
        }
        print("Wrote \(scenes.count) snapshots to \(directory.path)")
    }

    private static func render(_ scene: Scene, to url: URL) throws {
        let clock = SnapshotClock()
        let notch = CGSize(width: 200, height: 32)
        let model = NotchViewModel(
            nowPlayingService: SnapshotNowPlayingService(state: scene.state),
            volumeControl: SnapshotVolume(),
            now: { clock.now }
        )
        model.setNotchSize(notch)
        model.start()
        if scene.hovering {
            model.hoverChanged(true)
            clock.now += 1
            model.hoverChanged(true)
        }
        let panel = NotchLayout.windowSize(notch: notch)
        let canvas = CGSize(width: panel.width + 120, height: panel.height + 60)
        let content = ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 0.55, green: 0.62, blue: 0.78), Color(red: 0.86, green: 0.78, blue: 0.74)],
                startPoint: .top,
                endPoint: .bottom
            )
            NotchRootView(model: model)
                .frame(width: panel.width, height: panel.height)
        }
        .frame(width: canvas.width, height: canvas.height)
        .environment(\.colorScheme, .dark)
        .transaction { $0.disablesAnimations = true }

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let rendered = renderer.cgImage,
              let image = standardRange(rendered),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        model.stop()
    }

    /// App icons can carry HDR content, which turns the whole render into a PQ (extended range) image
    /// that looks dim as a PNG. Redrawing it into 8-bit sRGB tone-maps it back.
    private static func standardRange(_ image: CGImage) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    private static func track(
        _ title: String, _ artist: String?, _ album: String?, playing: Bool, artwork: Data?,
        duration: TimeInterval? = 214, app: String = "com.apple.Music"
    ) -> NowPlayingInfo {
        NowPlayingInfo(
            title: title,
            artist: artist,
            album: album,
            sourceBundleIdentifier: app,
            clock: PlaybackClock(elapsed: 72, timestamp: Date(), rate: 1, isPlaying: playing, duration: duration),
            artwork: artwork
        )
    }

    /// A sample cover: a diagonal gradient with a soft circle, as PNG bytes.
    private static func makeCover(colors: [NSColor], width: Int = 300, height: Int = 300) -> Data? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let rect = NSRect(x: 0, y: 0, width: width, height: height)
        NSGradient(colors: colors)?.draw(in: rect, angle: -45)
        NSColor(white: 1, alpha: 0.25).setFill()
        NSBezierPath(ovalIn: NSRect(x: 150, y: 40, width: 190, height: 190)).fill()
        NSColor(white: 0, alpha: 0.18).setFill()
        NSBezierPath(ovalIn: NSRect(x: -60, y: 170, width: 200, height: 200)).fill()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])
    }
}

private final class SnapshotClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
}

@MainActor
private final class SnapshotNowPlayingService: NowPlayingService {
    let state: NowPlayingState
    var onChange: ((NowPlayingState) -> Void)?

    init(state: NowPlayingState) {
        self.state = state
    }

    func start() { onChange?(state) }
    func stop() {}
    func send(_ command: MediaCommand) {}
}

@MainActor
private final class SnapshotVolume: VolumeControlling {
    let volume: Float = 0.6
    let isSettable = true
    var onChange: (() -> Void)?
    func start() {}
    func setVolume(_ value: Float) {}
}
