import AppKit
import NotchBoxCore
import Observation

/// A browser's YouTube video playing in the notch.
struct VideoSession: Equatable {
    let videoID: String
    let title: String
    /// The browser it came from, to hand playback back to.
    let sourceBundleIdentifier: String
}

/// Single source of truth for the views. Combines the state machine with the services.
@MainActor
@Observable
final class NotchViewModel {
    private(set) var displayState: NotchDisplayState = .idle
    private(set) var notchSize = CGSize(width: 185, height: 32)
    private(set) var nowPlaying: NowPlayingState = .nothing
    private(set) var artworkImage: NSImage?
    private(set) var artworkVersion = 0
    /// Tint picked from the cover (`ArtworkAccent`); a neutral light colour without one.
    private(set) var accent = ArtworkAccent.fallback
    private(set) var sourceAppIcon: NSImage?
    private(set) var volume: Float = 0
    private(set) var isVolumeSettable = false
    /// Slider position while the user drags the progress bar.
    private(set) var scrubPosition: TimeInterval?
    /// Non-nil while a video plays in the notch; the notch then stays open in `.video`.
    private(set) var video: VideoSession?
    /// The cursor is over the panel.
    private(set) var isHovering = false
    /// Where the cursor came into the panel; nil while it is outside.
    private(set) var hoverEntry: PanelEntry?
    /// The cursor is over the clickable control of a click-through state (the mini play/pause area).
    private(set) var isOverNotchButton = false
    /// Looking for the video in the browser's tabs.
    private(set) var isFindingVideo = false
    /// A short note shown in the player for a few seconds (no video found, no permission, ...).
    private(set) var videoMessage: String?
    @ObservationIgnored private(set) var videoPlayer: YouTubePlayer?
    /// The last things the user copied, newest first.
    private(set) var clipboard = ClipboardHistory()
    /// The item just put back on the pasteboard, for a moment, to show it worked.
    private(set) var recentlyCopiedID: Int?
    /// The clipboard image shown large in place of the player, until closed or the panel closes.
    private(set) var previewedClipboardItem: ClipboardItem?
    /// What is left of today and tomorrow's events, refreshed while the open player shows them.
    private(set) var agenda: [AgendaDay] = [AgendaDay(day: .today, events: [])]
    private(set) var calendarAccess: CalendarAccess = .notDetermined
    /// The time the agenda was read at, for "in 5 min" and "now".
    private(set) var agendaTime = Date.distantPast

    @ObservationIgnored var onDisplayStateChange: ((NotchDisplayState) -> Void)?
    @ObservationIgnored private var machine = NotchStateMachine()
    @ObservationIgnored private var deadlineTimer: Timer?
    @ObservationIgnored private var artwork = ArtworkHold<NSImage> { NSImage(data: $0) }
    @ObservationIgnored private var artworkTimer: Timer?
    @ObservationIgnored private let nowPlayingService: NowPlayingService?
    @ObservationIgnored private let volumeControl: VolumeControlling?
    @ObservationIgnored private let mediaKeys: MediaKeySending?
    /// Live bar heights for the waveform; nil in snapshots.
    @ObservationIgnored let audioMeter: AudioLevelMeter?
    @ObservationIgnored private let tabReader: BrowserTabReading?
    @ObservationIgnored private let makePlayer: @MainActor (String, TimeInterval) -> YouTubePlayer?
    @ObservationIgnored private var messageWork: DispatchWorkItem?
    @ObservationIgnored private var volumeHUD = VolumeHUD()
    @ObservationIgnored private var volumeHUDTimer: Timer?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let clipboardWatcher: ClipboardWatching?
    @ObservationIgnored private let calendarProvider: CalendarProviding?
    @ObservationIgnored private var agendaTimer: Timer?
    @ObservationIgnored private let thumbnails = ClipboardThumbnails()
    @ObservationIgnored private var copiedWork: DispatchWorkItem?

    static let messageDuration: TimeInterval = 4
    static let copiedFeedbackDuration: TimeInterval = 1.2
    /// Wait after closing the player before seeking the browser, so the command reaches the browser again.
    static let handBackDelay: TimeInterval = 0.8

    init(
        nowPlayingService: NowPlayingService? = nil,
        volumeControl: VolumeControlling? = nil,
        mediaKeys: MediaKeySending? = nil,
        audioMeter: AudioLevelMeter? = nil,
        tabReader: BrowserTabReading? = nil,
        clipboardWatcher: ClipboardWatching? = nil,
        calendarProvider: CalendarProviding? = nil,
        makePlayer: @escaping @MainActor (String, TimeInterval) -> YouTubePlayer? = { YouTubePlayer(videoID: $0, start: $1) },
        now: @escaping () -> Date = Date.init
    ) {
        self.tabReader = tabReader
        self.clipboardWatcher = clipboardWatcher
        self.calendarProvider = calendarProvider
        self.makePlayer = makePlayer
        self.nowPlayingService = nowPlayingService
        self.volumeControl = volumeControl
        self.mediaKeys = mediaKeys
        self.audioMeter = audioMeter
        self.now = now
    }

    var info: NowPlayingInfo? {
        if case .info(let info) = nowPlaying { return info }
        return nil
    }

    var isUnavailable: Bool { nowPlaying == .unavailable }

    var contentSize: CGSize { NotchLayout.size(for: displayState, notch: notchSize) }

    func start() {
        nowPlayingService?.onChange = { [weak self] state in self?.nowPlayingChanged(state) }
        volumeControl?.onChange = { [weak self] in self?.volumeChanged() }
        clipboardWatcher?.onCopy = { [weak self] content in self?.copied(content) }
        clipboardWatcher?.start()
        calendarProvider?.onChange = { [weak self] in self?.refreshAgenda() }
        calendarProvider?.start()
        refreshAgenda()
        nowPlayingService?.start()
        volumeControl?.start()
        volumeChanged()
    }

    func stop() {
        deadlineTimer?.invalidate()
        artworkTimer?.invalidate()
        volumeHUDTimer?.invalidate()
        artwork.cancelPending()
        audioMeter?.setActive(false)
        videoPlayer?.stop()
        videoPlayer = nil
        nowPlayingService?.stop()
        clipboardWatcher?.stop()
        copiedWork?.cancel()
        agendaTimer?.invalidate()
    }

    // MARK: Calendar

    static let agendaRefreshInterval: TimeInterval = 30

    /// The open player shows the clipboard and calendar columns.
    var showsSideColumns: Bool { displayState == .expanded || displayState == .expandedEmpty }

    func requestCalendarAccess() {
        calendarProvider?.requestAccess()
    }

    func openCalendar() {
        CalendarService.openCalendarApp()
    }

    func join(_ event: CalendarEvent) {
        guard let url = event.meetingURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func refreshAgenda() {
        guard let calendarProvider else { return }
        let time = now()
        calendarAccess = calendarProvider.access
        let range = CalendarAgenda.fetchRange(now: time, calendar: .current)
        let events = calendarProvider.events(from: range.start, to: range.end)
        let days = CalendarAgenda.days(from: events, now: time, calendar: .current)
        if days != agenda { agenda = days }
        agendaTime = time
    }

    /// Reads the calendar when the open player appears, and keeps "in 5 min" current while it is open.
    private func updateAgendaTimer() {
        guard showsSideColumns else {
            agendaTimer?.invalidate()
            agendaTimer = nil
            return
        }
        guard agendaTimer == nil else { return }
        refreshAgenda()
        let timer = Timer(timeInterval: Self.agendaRefreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAgenda() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        agendaTimer = timer
    }

    // MARK: Clipboard

    /// NotchBox may not read the pasteboard (turned off in System Settings).
    var isClipboardDenied: Bool { clipboardWatcher?.isDenied ?? false }

    /// Puts an earlier item back on the pasteboard; it moves to the top of the list.
    func copyAgain(_ item: ClipboardItem) {
        clipboardWatcher?.copy(item.content)
        clipboard.record(item.content, at: now())
        recentlyCopiedID = item.id
        copiedWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.recentlyCopiedID = nil }
        copiedWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.copiedFeedbackDuration, execute: work)
    }

    func removeFromClipboard(_ item: ClipboardItem) {
        clipboard.remove(id: item.id)
        thumbnails.keep(clipboard.items)
        if previewedClipboardItem?.id == item.id { previewedClipboardItem = nil }
    }

    func clearClipboard() {
        clipboard.clear()
        thumbnails.keep([])
        previewedClipboardItem = nil
    }

    func thumbnail(for item: ClipboardItem) -> ClipboardThumbnails.Thumbnail? {
        thumbnails.thumbnail(for: item)
    }

    /// Shows a clipboard image large where the player is.
    func preview(_ item: ClipboardItem) {
        guard case .image = item.content else { return }
        previewedClipboardItem = item
    }

    func closePreview() {
        previewedClipboardItem = nil
    }

    func previewImage(for item: ClipboardItem) -> NSImage? {
        thumbnails.preview(for: item)
    }

    private func copied(_ content: ClipboardContent) {
        clipboard.record(content, at: now())
        thumbnails.keep(clipboard.items)
    }

    func setNotchSize(_ size: CGSize) {
        guard size != notchSize else { return }
        notchSize = size
        onDisplayStateChange?(displayState)
    }

    /// The video panel fades away under a cursor that came in from the side or below, so the windows
    /// behind it can be seen and clicked. Coming down from the menu bar keeps it usable.
    var isSeeThrough: Bool { NotchInteraction.isSeeThrough(displayState, hovering: isHovering, entry: hoverEntry) }

    func notchButtonHoverChanged(_ over: Bool) {
        if over != isOverNotchButton { isOverNotchButton = over }
    }

    func hoverChanged(_ hovering: Bool, entry: PanelEntry? = .fromSide) {
        isHovering = hovering
        hoverEntry = hovering ? entry : nil
        machine.setHovering(hovering, at: now())
        apply()
    }

    func togglePlayPause() { perform(.togglePlayPause) }
    func next() { perform(.next) }
    func previous() { perform(.previous) }

    func seek(to position: TimeInterval) {
        perform(.seek(to: position))
        // Move the bar right away instead of waiting for the next adapter line.
        if case .info(var info) = nowPlaying {
            info.clock = info.clock.seeked(to: position, at: now())
            nowPlaying = .info(info)
        }
    }

    func scrub(to position: TimeInterval) {
        scrubPosition = position
    }

    func endScrub() {
        guard let position = scrubPosition else { return }
        scrubPosition = nil
        seek(to: position)
    }

    func setVolume(_ value: Float) {
        volumeControl?.setVolume(value)
    }

    func openSourceApp() {
        guard let bundleIdentifier = info?.sourceBundleIdentifier else { return }
        AppIconProvider.open(bundleIdentifier: bundleIdentifier)
    }

    /// The playing app is a browser whose tabs NotchBox can read.
    var canWatchInNotch: Bool {
        guard let info, tabReader != nil else { return false }
        return BrowserTabs.isSupportedBrowser(info.sourceBundleIdentifier)
    }

    /// Finds the playing YouTube video in the browser's tabs, pauses it there and plays it in the notch
    /// from the same moment.
    func watchInNotch() {
        guard let info, tabReader != nil, !isFindingVideo, video == nil else { return }
        isFindingVideo = true
        findVideo(for: info, retriesLeft: 1)
    }

    /// Wait before reading the tabs again when no YouTube video turned up (a page still loading, or the
    /// first read right after macOS granted the Automation permission).
    static let tabRetryDelay: TimeInterval = 0.7

    private func findVideo(for info: NowPlayingInfo, retriesLeft: Int) {
        guard let tabReader else { return }
        let browser = info.sourceBundleIdentifier
        tabReader.readTabs(of: browser) { [weak self] result in
            guard let self else { return }
            self.isFindingVideo = false
            switch result {
            case .failure(let error):
                let refused = (error as? BrowserTabReader.ReadError) == .notAuthorized
                self.show(message: refused ? L10n.browserAccessNeeded : L10n.noYouTubeVideo)
            case .success(let tabs):
                guard let videoID = BrowserTabs.pickYouTubeVideo(from: tabs, nowPlayingTitle: info.title) else {
                    if retriesLeft > 0 {
                        self.isFindingVideo = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + Self.tabRetryDelay) { [weak self] in
                            MainActor.assumeIsolated { self?.findVideo(for: info, retriesLeft: retriesLeft - 1) }
                        }
                    } else {
                        self.show(message: L10n.noYouTubeVideo)
                    }
                    return
                }
                let current = self.info ?? info
                if current.clock.isPlaying { self.nowPlayingService?.send(.togglePlayPause) }
                self.showVideo(
                    VideoSession(videoID: videoID, title: current.title, sourceBundleIdentifier: browser),
                    start: current.clock.elapsed(at: self.now())
                )
            }
        }
    }

    /// Opens the video panel. Also used by the snapshot renderer, which passes no player.
    func showVideo(_ session: VideoSession, start: TimeInterval) {
        videoPlayer?.stop()
        let player = makePlayer(session.videoID, start)
        player?.onError = { [weak self] _ in
            self?.closeVideo()
            self?.show(message: L10n.videoNotEmbeddable)
        }
        videoPlayer = player
        video = session
        apply()
    }

    /// Closes the video panel and moves the browser (paused) to where the notch player stopped.
    func closeVideo() {
        guard video != nil else { return }
        let player = videoPlayer
        let finish: @MainActor (TimeInterval?) -> Void = { [weak self] time in
            guard let self else { return }
            player?.stop()
            self.videoPlayer = nil
            self.video = nil
            self.apply()
            // Best effort: the seek goes to whichever player macOS considers active, normally the browser again.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.handBackDelay) { [weak self] in
                MainActor.assumeIsolated {
                    if let time { self?.nowPlayingService?.send(.seek(to: time)) }
                }
            }
        }
        if let player {
            player.currentTime(completion: finish)
        } else {
            finish(nil)
        }
    }

    private func show(message: String) {
        messageWork?.cancel()
        videoMessage = message
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.videoMessage = nil }
        }
        messageWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.messageDuration, execute: work)
    }

    private func perform(_ command: MediaCommand) {
        if isUnavailable {
            if let code = MediaKeyCode.code(for: command) { mediaKeys?.send(code: code) }
        } else {
            nowPlayingService?.send(command)
        }
    }

    private func nowPlayingChanged(_ state: NowPlayingState) {
        let old = info
        nowPlaying = state
        let current = info
        updateArtwork(current)
        if current?.sourceBundleIdentifier != old?.sourceBundleIdentifier {
            sourceAppIcon = current.flatMap { AppIconProvider.icon(for: $0.sourceBundleIdentifier) }
        }
        machine.setMedia(state.machineMedia, at: now())
        apply()
    }

    private func updateArtwork(_ current: NowPlayingInfo?) {
        artwork.update(for: current, at: now())
        applyArtwork()
    }

    /// Publishes the hold's cover and arms the timer for its next deadline.
    private func applyArtwork() {
        if artwork.version != artworkVersion {
            artworkImage = artwork.image
            artworkVersion = artwork.version
            accent = ArtworkSampler.accent(for: artwork.image)
        }
        artworkTimer?.invalidate()
        artworkTimer = nil
        guard let deadline = artwork.nextDeadline else { return }
        artworkTimer = makeTimer(firingAfter: deadline) { [weak self] in
            guard let self else { return }
            self.artwork.tick(at: self.now())
            self.applyArtwork()
        }
    }

    private func volumeChanged() {
        volume = volumeControl?.volume ?? 0
        isVolumeSettable = volumeControl?.isSettable ?? false
        volumeHUD.volumeReported(volume, at: now())
        apply()
    }

    private func tick() {
        machine.tick(at: now())
        apply()
    }

    private func apply() {
        // A video keeps the notch open whatever the hover or media state says; the volume row shows
        // briefly after a volume change unless the full player (with its own volume bar) is open.
        let base = machine.displayState
        let newState: NotchDisplayState
        if video != nil {
            newState = .video
        } else if !base.isOpen, volumeHUD.isVisible(at: now()) {
            newState = .volume
        } else {
            newState = base
        }
        if newState != displayState {
            displayState = newState
            onDisplayStateChange?(newState)
        }
        // An image preview belongs to this opening of the panel.
        if !showsSideColumns, previewedClipboardItem != nil {
            previewedClipboardItem = nil
        }
        updateAgendaTimer()
        // Listen to the audio only while a moving waveform is on screen.
        let showsWaveform = displayState == .mini || displayState == .expanded || displayState == .volume
        audioMeter?.setActive(showsWaveform && info?.clock.isPlaying == true)
        scheduleNextTick()
        scheduleVolumeHUDTick()
    }

    private func scheduleVolumeHUDTick() {
        volumeHUDTimer?.invalidate()
        volumeHUDTimer = nil
        guard let deadline = volumeHUD.nextDeadline else { return }
        volumeHUDTimer = makeTimer(firingAfter: deadline) { [weak self] in
            guard let self else { return }
            self.volumeHUD.tick(at: self.now())
            self.apply()
        }
    }

    private func scheduleNextTick() {
        deadlineTimer?.invalidate()
        deadlineTimer = nil
        guard let deadline = machine.nextDeadline else { return }
        deadlineTimer = makeTimer(firingAfter: deadline) { [weak self] in self?.tick() }
    }

    /// A one-shot main run loop timer that fires just after `deadline`.
    private func makeTimer(firingAfter deadline: Date, action: @escaping @MainActor () -> Void) -> Timer {
        let interval = max(0.01, deadline.timeIntervalSince(now()) + 0.005)
        let timer = Timer(timeInterval: interval, repeats: false) { _ in
            MainActor.assumeIsolated { action() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
