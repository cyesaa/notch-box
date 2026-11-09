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
        var video: VideoSession?
        /// Simulate a system volume change after start (shows the volume row).
        var volumeChange = false
        /// The cursor over the mini notch's play/pause area.
        var overButton = false
        /// Where the hovering cursor came in.
        var entry: PanelEntry = .fromSide
        /// Nothing copied yet.
        var emptyClipboard = false
        /// The copied image shown large.
        var previewImage = false
        var calendarAccess: CalendarAccess = .granted
        /// A screen without a notch: NotchBox's own 185 x 24 notch.
        var virtualNotch = false
        var hideIdle = false
        var sides: SideWidgets = .default
        /// The VPN's status after it was seen disconnected (connected shows a running time).
        var vpn: VPNStatus = .disconnected
        /// OpenVPN Connect installed, with this status.
        var openVPN: VPNStatus?
    }

    static func render(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sampleClipboard = [
            .text("brew install --cask notchbox"),
            makeCover(colors: [NSColor(srgbRed: 0.3, green: 0.8, blue: 0.5, alpha: 1), NSColor(srgbRed: 0.1, green: 0.3, blue: 0.7, alpha: 1)], width: 1280, height: 720)
                .map { .image($0, type: "public.png") },
            .text("Toplantı yarın 10:30'da, Zoom bağlantısı takvimde.\nGündem: sürüm 0.3 planı"),
            .text("https://github.com/cyesaa/notch-box/releases/latest"),
            .text("sunucu-adresi.local"),
        ].compactMap { $0 }
        let warm = makeCover(colors: [NSColor(srgbRed: 1, green: 0.62, blue: 0.3, alpha: 1), NSColor(srgbRed: 0.85, green: 0.2, blue: 0.45, alpha: 1)])
        let video = makeCover(
            colors: [NSColor(srgbRed: 0.55, green: 0.7, blue: 0.8, alpha: 1), NSColor(srgbRed: 0.8, green: 0.6, blue: 0.4, alpha: 1)],
            width: 480, height: 270
        )
        let cool = makeCover(colors: [NSColor(srgbRed: 0.2, green: 0.75, blue: 0.85, alpha: 1), NSColor(srgbRed: 0.15, green: 0.2, blue: 0.6, alpha: 1)])
        let scenes = [
            Scene(name: "0a-virtual-notch-idle", state: .nothing, hovering: false, virtualNotch: true),
            Scene(name: "0a2-virtual-notch-idle-hidden", state: .nothing, hovering: false, virtualNotch: true, hideIdle: true),
            Scene(name: "0b-virtual-notch-mini", state: .info(track("Golden Hour", "Kai Moreno", "Late Light", playing: true, artwork: warm)), hovering: false, virtualNotch: true),
            Scene(name: "0c-virtual-notch-expanded", state: .info(track("Golden Hour", "Kai Moreno", "Late Light", playing: true, artwork: warm)), hovering: true, virtualNotch: true),
            Scene(name: "1a-mini-paused", state: .info(track("Golden Hour", "Kai Moreno", "Late Light", playing: false, artwork: warm)), hovering: false),
            Scene(name: "1b-mini-pointing-at-waveform", state: .info(track("Golden Hour", "Kai Moreno", "Late Light", playing: true, artwork: warm)), hovering: false, overButton: true),
            Scene(name: "9a-volume-while-playing", state: .info(track("Golden Hour", "Kai Moreno", "Late Light", playing: true, artwork: warm)), hovering: false, volumeChange: true),
            Scene(name: "9b-volume-nothing-playing", state: .nothing, hovering: false, volumeChange: true),
            Scene(name: "1-mini-video-thumbnail", state: .info(track("Sena Şener - Alışılır Mı Aşka (Visualizer)", "Sena Şener", nil, playing: true, artwork: video, app: "com.google.Chrome")), hovering: false),
            Scene(name: "2-expanded-video-thumbnail", state: .info(track("Sena Şener - Alışılır Mı Aşka (Visualizer)", "Sena Şener", nil, playing: true, artwork: video, app: "com.google.Chrome")), hovering: true),
            Scene(name: "2b-expanded-square-cover", state: .info(track("Golden Hour", "Kai Moreno", "Late Light", playing: true, artwork: warm)), hovering: true),
            Scene(name: "3-expanded-paused-long-title", state: .info(track("A Very Long Song Title That Does Not Fit On One Line", "Ocean Avenue Collective", nil, playing: false, artwork: cool)), hovering: true),
            Scene(name: "4-expanded-no-artwork", state: .info(track("Live Radio", nil, nil, playing: true, artwork: nil, duration: nil, app: "com.apple.Safari")), hovering: true),
            Scene(name: "5-nothing-playing", state: .nothing, hovering: true),
            Scene(name: "5b-nothing-playing-empty-clipboard", state: .nothing, hovering: true, emptyClipboard: true, calendarAccess: .notDetermined),
            Scene(name: "12a-vpn-connected", state: .info(track("Golden Hour", "Kai Moreno", "Late Light", playing: true, artwork: warm)), hovering: true, sides: SideWidgets(left: .clipboard, right: .vpn), vpn: .connected),
            Scene(name: "12b-vpn-disconnected", state: .nothing, hovering: true, sides: SideWidgets(left: .vpn, right: .calendar), vpn: .disconnected),
            Scene(name: "12d-forticlient-and-openvpn", state: .info(track("Golden Hour", "Kai Moreno", "Late Light", playing: true, artwork: warm)), hovering: true, sides: SideWidgets(left: .clipboard, right: .vpn), vpn: .disconnected, openVPN: .connected),
            Scene(name: "12e-openvpn-only-disconnected", state: .nothing, hovering: true, sides: SideWidgets(left: .vpn, right: .calendar), vpn: .unavailable, openVPN: .disconnected),
            Scene(name: "12c-only-left-column", state: .info(track("Golden Hour", "Kai Moreno", "Late Light", playing: true, artwork: warm)), hovering: true, sides: SideWidgets(left: .clipboard, right: nil)),
            Scene(name: "10-clipboard-image-preview", state: .info(track("Golden Hour", "Kai Moreno", "Late Light", playing: true, artwork: warm)), hovering: true, previewImage: true),
            Scene(name: "6-unavailable", state: .unavailable, hovering: true),
            Scene(
                name: "7-video",
                state: .info(track("Sena Şener - Alışılır Mı Aşka (Visualizer)", "Sena Şener", nil, playing: false, artwork: video, app: "com.google.Chrome")),
                hovering: false,
                video: VideoSession(videoID: "AAAAAAAAAAA", title: "Sena Şener - Alışılır Mı Aşka (Visualizer)", sourceBundleIdentifier: "com.google.Chrome")
            ),
            Scene(
                name: "8-video-see-through-from-the-side",
                state: .info(track("Sena Şener - Alışılır Mı Aşka (Visualizer)", "Sena Şener", nil, playing: false, artwork: video, app: "com.google.Chrome")),
                hovering: true,
                video: VideoSession(videoID: "AAAAAAAAAAA", title: "Sena Şener - Alışılır Mı Aşka (Visualizer)", sourceBundleIdentifier: "com.google.Chrome")
            ),
            Scene(
                name: "8b-video-usable-from-the-top",
                state: .info(track("Sena Şener - Alışılır Mı Aşka (Visualizer)", "Sena Şener", nil, playing: false, artwork: video, app: "com.google.Chrome")),
                hovering: true,
                video: VideoSession(videoID: "AAAAAAAAAAA", title: "Sena Şener - Alışılır Mı Aşka (Visualizer)", sourceBundleIdentifier: "com.google.Chrome"),
                entry: .fromTop
            ),
        ]
        for scene in scenes {
            try render(scene, to: directory.appendingPathComponent(scene.name + ".png"))
        }
        try renderSettings(to: directory.appendingPathComponent("11-settings.png"))
        print("Wrote \(scenes.count + 1) snapshots to \(directory.path)")
    }

    /// Newest first.
    private static var sampleClipboard: [ClipboardContent] = []

    private static func render(_ scene: Scene, to url: URL) throws {
        let clock = SnapshotClock()
        let notch = scene.virtualNotch ? CGSize(width: 185, height: 24) : CGSize(width: 200, height: 32)
        let volume = SnapshotVolume()
        let vpn = SnapshotVPN()
        vpn.hasService = scene.vpn != .unavailable
        let openVPN = scene.openVPN.map { SnapshotOpenVPN(status: $0, since: clock.now.addingTimeInterval(3_905 - 754)) }
        let model = NotchViewModel(
            nowPlayingService: SnapshotNowPlayingService(state: scene.state),
            volumeControl: volume,
            tabReader: SnapshotTabReader(),
            clipboardWatcher: SnapshotClipboard(items: scene.emptyClipboard ? [] : sampleClipboard),
            vpnControl: vpn,
            openVPN: openVPN,
            calendarProvider: SnapshotCalendar(access: scene.calendarAccess, now: clock.now),
            makePlayer: { _, _ in nil },
            now: { clock.now }
        )
        model.setNotchSize(notch, isVirtual: scene.virtualNotch)
        model.setSideWidgets(scene.sides)
        model.setHidesIdleVirtualNotch(scene.hideIdle)
        model.start()
        // A pinned row in every scene with a clipboard: the oldest sample item.
        if let oldest = model.clipboard.recent.last {
            model.togglePin(oldest)
        }
        if let video = scene.video {
            model.showVideo(video, start: 0)
        }
        if scene.sides.shows(.vpn) {
            // Seen disconnected first, then up for an hour and five minutes.
            vpn.status = scene.vpn
            model.refreshVPN()
            clock.now += 3_905
            model.refreshVPN()
        }
        if scene.volumeChange {
            volume.volume = 0.72
            volume.onChange?()
        }
        if scene.overButton {
            model.notchButtonHoverChanged(true)
        }
        if scene.hovering {
            model.hoverChanged(true, entry: scene.entry)
            clock.now += 1
            model.hoverChanged(true, entry: scene.entry)
        }
        if scene.previewImage, let image = model.clipboard.items.first(where: { if case .image = $0.content { return true } else { return false } }) {
            model.preview(image)
        }
        let panel = NotchLayout.windowSize(notch: notch)
        let canvas = CGSize(width: panel.width + 120, height: panel.height + 60)
        let content = ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 0.55, green: 0.62, blue: 0.78), Color(red: 0.86, green: 0.78, blue: 0.74)],
                startPoint: .top,
                endPoint: .bottom
            )
            if scene.virtualNotch {
                // The menu bar of a screen without a notch.
                Rectangle()
                    .fill(Color.white.opacity(0.55))
                    .frame(height: notch.height)
            }
            NotchRootView(model: model)
                .frame(width: panel.width, height: panel.height)
        }
        .frame(width: canvas.width, height: canvas.height)
        .environment(\.colorScheme, .dark)
        .environment(\.isRenderingSnapshot, true)
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

    /// The Settings window's content, drawn through AppKit (its controls are AppKit views, which
    /// ImageRenderer leaves blank).
    private static func renderSettings(to url: URL) throws {
        let settings = AppSettings(updates: UpdateService())
        let view = NSHostingView(rootView: SettingsView(settings: settings).environment(\.colorScheme, .dark))
        view.appearance = NSAppearance(named: .darkAqua)
        let size = view.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = view
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.fileWriteUnknown) }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url)
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
private final class SnapshotTabReader: BrowserTabReading {
    func readTabs(of bundleIdentifier: String, completion: @escaping @MainActor (Result<[BrowserTab], Error>) -> Void) {
        completion(.success([]))
    }
}

@MainActor
private final class SnapshotVolume: VolumeControlling {
    var volume: Float = 0.6
    let isSettable = true
    var onChange: (() -> Void)?
    func start() {}
    func setVolume(_ value: Float) {}
}

@MainActor
private final class SnapshotClipboard: ClipboardWatching {
    /// Newest first.
    let items: [ClipboardContent]
    var onCopy: ((ClipboardContent) -> Void)?
    let isDenied = false

    init(items: [ClipboardContent]) {
        self.items = items
    }

    func start() { items.reversed().forEach { onCopy?($0) } }
    func stop() {}
    func copy(_ content: ClipboardContent) {}
}

@MainActor
private final class SnapshotCalendar: CalendarProviding {
    let access: CalendarAccess
    var onChange: (() -> Void)?
    private let sample: [CalendarEvent]

    init(access: CalendarAccess, now: Date) {
        self.access = access
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        func at(_ base: Date, minutes: Double) -> Date { base.addingTimeInterval(minutes * 60) }
        let blue = ArtworkColor(red: 0.2, green: 0.55, blue: 1)
        let orange = ArtworkColor(red: 1, green: 0.6, blue: 0.2)
        let green = ArtworkColor(red: 0.3, green: 0.8, blue: 0.45)
        sample = [
            CalendarEvent(id: "1", title: "Sprint planlama", start: at(now, minutes: -20), end: at(now, minutes: 25), isAllDay: false, color: blue, meetingURL: URL(string: "https://meet.google.com/abc-defg-hij")),
            CalendarEvent(id: "2", title: "Tasarım incelemesi", start: at(now, minutes: 40), end: at(now, minutes: 70), isAllDay: false, color: orange, meetingURL: URL(string: "https://zoom.us/j/1")),
            CalendarEvent(id: "3", title: "Spor salonu", start: at(now, minutes: 300), end: at(now, minutes: 360), isAllDay: false, color: green, meetingURL: nil),
            CalendarEvent(id: "4", title: "Annemin doğum günü", start: today, end: tomorrow, isAllDay: true, color: orange, meetingURL: nil),
            CalendarEvent(id: "6", title: "Diş hekimi", start: at(today, minutes: -1440 * 2 + 900), end: at(today, minutes: -1440 * 2 + 960), isAllDay: false, color: green, meetingURL: nil),
            CalendarEvent(id: "5", title: "Haftalık 1:1", start: at(tomorrow, minutes: 600), end: at(tomorrow, minutes: 630), isAllDay: false, color: blue, meetingURL: URL(string: "https://teams.microsoft.com/l/meetup-join/x")),
        ]
    }

    func start() {}
    func requestAccess() {}
    func events(from start: Date, to end: Date) -> [CalendarEvent] {
        access == .granted ? sample : []
    }
}

@MainActor
private final class SnapshotVPN: VPNControlling {
    var status: VPNStatus = .disconnected
    var hasService = true

    func services() -> [VPNServiceInfo] {
        guard hasService else { return [] }
        return [VPNServiceInfo(id: "689A790A-026F-4E3D-9480-D4AF8362B958", name: "VPN", providerBundleID: "com.fortinet.forticlient.macos.vpn", isEnabled: true)]
    }

    func status(of serviceID: String) -> VPNStatus { status }
    func disconnect(_ serviceID: String) {}
}

@MainActor
private final class SnapshotOpenVPN: OpenVPNControlling {
    let status: VPNStatus
    let since: Date
    let isInstalled = true
    let profiles = [
        OpenVPNProfile(id: "1", name: "203.0.113.10 [office]", host: "203.0.113.10", lastConnected: nil),
        OpenVPNProfile(id: "2", name: "198.51.100.20 [home]", host: "198.51.100.20", lastConnected: nil),
    ]

    init(status: VPNStatus, since: Date) {
        self.status = status
        self.since = since
    }

    func read(preferring profileID: String?) -> OpenVPNReading {
        OpenVPNReading(
            status: status,
            connectedSince: status == .connected ? since : nil,
            profiles: profiles,
            activeProfile: status == .connected ? profiles[0] : nil
        )
    }

    func connect(profileID: String) {}
    func disconnect() {}
    func openApp() {}
}
