import AppKit
import NotchBoxCore
import Observation

/// A browser's YouTube video playing in the notch.
struct VideoSession: Equatable {
    let videoID: String
    let title: String
    /// The browser it came from, to hand playback back to.
    let sourceBundleIdentifier: String
    /// NotchBox paused the browser to open it; the browser plays on if the video cannot play in the notch.
    var pausedSource = false
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
    /// The notch's YouTube page is signed out, so a "Sign in" button is offered (see `signInToYouTube`).
    private(set) var videoNeedsSignIn = false
    /// A short note shown in the player for a few seconds (no video found, no permission, ...).
    private(set) var videoMessage: String?
    @ObservationIgnored private(set) var videoPlayer: YouTubePlayer?
    /// The last things the user copied, newest first.
    private(set) var clipboard = ClipboardHistory()
    /// The item just put back on the pasteboard, for a moment, to show it worked.
    private(set) var recentlyCopiedID: Int?
    /// The clipboard image shown large in place of the player, until closed or the panel closes.
    private(set) var previewedClipboardItem: ClipboardItem?
    /// The seven days of this week (starts of day), for the week strip.
    private(set) var week: [Date] = []
    /// Days of this week that have events (a dot under the day).
    private(set) var busyDays: Set<Date> = []
    /// The day picked in the week strip; today until the user picks another, and again when the panel closes.
    private(set) var selectedDay: Date?
    /// The picked day's events (today: what has not ended yet).
    private(set) var dayEvents: [CalendarEvent] = []
    private(set) var calendarAccess: CalendarAccess = .notDetermined
    /// The time the calendar was read at, for "in 5 min" and "now".
    private(set) var agendaTime = Date.distantPast
    @ObservationIgnored private var weekEvents: [CalendarEvent] = []

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
    @ObservationIgnored private var signInWindow: SignInWindowController?
    @ObservationIgnored private var messageWork: DispatchWorkItem?
    @ObservationIgnored private var volumeHUD = VolumeHUD()
    @ObservationIgnored private var volumeHUDTimer: Timer?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let clipboardWatcher: ClipboardWatching?
    @ObservationIgnored private let pinnedStore: PinnedClipboardStoring?
    @ObservationIgnored private let vpnControl: VPNControlling?
    @ObservationIgnored private var vpnClock = VPNConnectionClock()
    @ObservationIgnored private var vpnTimer: Timer?
    @ObservationIgnored private var hasReadVPN = false
    @ObservationIgnored private let openVPN: OpenVPNControlling?
    /// The OpenVPN profile NotchBox last connected, to tell profiles on the same server apart.
    @ObservationIgnored private var requestedOpenVPNProfile: String?
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
        pinnedStore: PinnedClipboardStoring? = nil,
        vpnControl: VPNControlling? = nil,
        openVPN: OpenVPNControlling? = nil,
        calendarProvider: CalendarProviding? = nil,
        makePlayer: @escaping @MainActor (String, TimeInterval) -> YouTubePlayer? = { YouTubePlayer(videoID: $0, start: $1) },
        now: @escaping () -> Date = Date.init
    ) {
        self.tabReader = tabReader
        self.clipboardWatcher = clipboardWatcher
        self.pinnedStore = pinnedStore
        self.vpnControl = vpnControl
        self.openVPN = openVPN
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

    var contentSize: CGSize { NotchLayout.size(for: displayState, notch: notchSize, sides: sideWidgets) }

    /// What sits left and right of the open player (chosen in Settings).
    private(set) var sideWidgets = SideWidgets.default

    func setSideWidgets(_ sides: SideWidgets) {
        guard sides != sideWidgets else { return }
        sideWidgets = sides
        if !sides.shows(.clipboard), previewedClipboardItem != nil { previewedClipboardItem = nil }
        updateClipboardWatching()
        updateVPNWatching()
        refreshAgenda()
        onDisplayStateChange?(displayState)
    }

    /// The pasteboard is read only while the clipboard column is on one side.
    private func updateClipboardWatching() {
        if sideWidgets.shows(.clipboard) {
            clipboardWatcher?.start()
        } else {
            clipboardWatcher?.stop()
        }
    }

    func start() {
        nowPlayingService?.onChange = { [weak self] state in self?.nowPlayingChanged(state) }
        volumeControl?.onChange = { [weak self] in self?.volumeChanged() }
        if let saved = pinnedStore?.load(), !saved.isEmpty {
            clipboard.restorePinned(saved, at: now())
        }
        clipboardWatcher?.onCopy = { [weak self] content in self?.copied(content) }
        updateClipboardWatching()
        updateVPNWatching()
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
        vpnTimer?.invalidate()
    }

    // MARK: VPN

    /// A VPN in the VPN column.
    struct VPNEntry: Equatable, Identifiable {
        enum Kind: Equatable {
            /// A VPN macOS knows about (FortiClient's, or one from System Settings).
            case system(VPNServiceInfo)
            case openVPN
        }

        let kind: Kind
        let status: VPNStatus
        let connectedSince: Date?
        /// OpenVPN's profiles, to pick one to connect.
        let profiles: [OpenVPNProfile]
        /// OpenVPN's profile in use.
        let activeProfile: OpenVPNProfile?

        var id: String {
            switch kind {
            case .system(let service): return "system:" + service.id
            case .openVPN: return "openvpn"
            }
        }

        var name: String {
            switch kind {
            case .system(let service): return service.displayName
            case .openVPN: return "OpenVPN"
            }
        }

        var isFortiClient: Bool {
            if case .system(let service) = kind { return service.isFortiClient }
            return false
        }
    }

    static let vpnRefreshInterval: TimeInterval = 1

    /// FortiClient's (or another system) VPN and OpenVPN Connect, whichever are installed.
    private(set) var vpns: [VPNEntry] = []
    /// The time of the last reading, so connected times count up.
    private(set) var vpnTime = Date.distantPast

    /// Disconnects a VPN.
    func disconnect(_ entry: VPNEntry) {
        switch entry.kind {
        case .system(let service): vpnControl?.disconnect(service.id)
        case .openVPN: openVPN?.disconnect()
        }
        refreshVPN()
    }

    /// Connects an OpenVPN profile.
    func connect(_ profile: OpenVPNProfile) {
        requestedOpenVPNProfile = profile.id
        openVPN?.connect(profileID: profile.id)
        refreshVPN()
    }

    /// Opens the VPN's own app: FortiClient (which connects its VPN only itself), OpenVPN Connect, or the
    /// VPN settings for other VPNs.
    func openApp(for entry: VPNEntry) {
        switch entry.kind {
        case .system(let service):
            if service.isFortiClient {
                AppIconProvider.open(bundleIdentifier: "com.fortinet.FortiClient")
            } else if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        case .openVPN:
            openVPN?.openApp()
        }
    }

    /// VPNs are read every second while the VPN column is chosen, also with the panel closed, so a
    /// connection's time starts when it really came up.
    private func updateVPNWatching() {
        guard vpnControl != nil || openVPN != nil, sideWidgets.shows(.vpn) else {
            vpnTimer?.invalidate()
            vpnTimer = nil
            return
        }
        guard vpnTimer == nil else { return }
        refreshVPN()
        let timer = Timer(timeInterval: Self.vpnRefreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshVPN() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        vpnTimer = timer
    }

    /// Reads the VPNs now (the timer does this every second; snapshots call it directly).
    func refreshVPN() {
        let time = now()
        var entries: [VPNEntry] = []
        if let vpnControl {
            var service = VPNServiceList.preferred(in: vpnControl.services())
            var status = service.map { vpnControl.status(of: $0.id) } ?? .unavailable
            if status == .unavailable, service != nil {
                // The configuration may have been replaced (FortiClient does on each connection); read again.
                service = VPNServiceList.preferred(in: vpnControl.services())
                status = service.map { vpnControl.status(of: $0.id) } ?? .unavailable
            }
            if let service {
                vpnClock.update(status, at: time, isFirstReading: !hasReadVPN)
                hasReadVPN = true
                entries.append(VPNEntry(kind: .system(service), status: status, connectedSince: vpnClock.connectedSince, profiles: [], activeProfile: nil))
            }
        }
        if let openVPN, openVPN.isInstalled {
            let reading = openVPN.read(preferring: requestedOpenVPNProfile)
            entries.append(VPNEntry(
                kind: .openVPN, status: reading.status, connectedSince: reading.connectedSince,
                profiles: reading.profiles, activeProfile: reading.activeProfile
            ))
        }
        if entries != vpns { vpns = entries }
        // Only tick the clock that drives the connected times while they are shown.
        if showsSideColumns || vpnTime == .distantPast { vpnTime = time }
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

    /// The day shown under the week strip.
    var shownDay: Date { selectedDay ?? Calendar.current.startOfDay(for: agendaTime == .distantPast ? now() : agendaTime) }

    var isShowingToday: Bool { Calendar.current.isDate(shownDay, inSameDayAs: agendaTime) }

    func selectDay(_ day: Date) {
        selectedDay = Calendar.current.isDate(day, inSameDayAs: now()) ? nil : day
        updateDayEvents()
    }

    func join(_ event: CalendarEvent) {
        guard let url = event.meetingURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func refreshAgenda() {
        guard let calendarProvider, sideWidgets.shows(.calendar) else { return }
        let time = now()
        calendarAccess = calendarProvider.access
        let calendar = Calendar.current
        let range = CalendarAgenda.fetchRange(now: time, calendar: calendar)
        weekEvents = calendarProvider.events(from: range.start, to: range.end)
        let newWeek = CalendarAgenda.week(containing: time, calendar: calendar)
        if newWeek != week { week = newWeek }
        let busy = CalendarAgenda.busyDays(from: weekEvents, calendar: calendar)
        if busy != busyDays { busyDays = busy }
        agendaTime = time
        updateDayEvents()
    }

    private func updateDayEvents() {
        let events = CalendarAgenda.events(on: shownDay, from: weekEvents, now: now(), calendar: .current)
        if events != dayEvents { dayEvents = events }
    }

    /// Reads the calendar when the open player appears, and keeps "in 5 min" current while it is open.
    private func updateAgendaTimer() {
        guard showsSideColumns else {
            agendaTimer?.invalidate()
            agendaTimer = nil
            if selectedDay != nil {
                selectedDay = nil
                updateDayEvents()
            }
            return
        }
        guard agendaTimer == nil else { return }
        refreshAgenda()
        if sideWidgets.shows(.vpn) { refreshVPN() }
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
        if item.isPinned { savePins() }
    }

    /// Pins an item (kept on top and across restarts) or unpins it.
    func togglePin(_ item: ClipboardItem) {
        if item.isPinned {
            clipboard.unpin(id: item.id)
        } else {
            guard clipboard.pin(id: item.id) else { return }
        }
        savePins()
    }

    private func savePins() {
        pinnedStore?.save(clipboard.pinned.map(\.content))
    }

    /// Clears the recent items; pinned ones stay.
    func clearClipboard() {
        clipboard.clear()
        thumbnails.keep(clipboard.items)
        if let previewed = previewedClipboardItem, !clipboard.items.contains(where: { $0.id == previewed.id }) {
            previewedClipboardItem = nil
        }
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

    /// The notch is NotchBox's own, on a screen without one: the mini notch shows the title where a real
    /// notch has its camera.
    private(set) var isVirtualNotch = false
    /// The user chose to hide a virtual notch while nothing is shown in it.
    private(set) var hidesIdleVirtualNotch = false

    /// Whether the idle shape is drawn: always invisible on a real notch (the hardware is there), and on a
    /// virtual one unless the user hid it.
    var hidesIdleShape: Bool { isVirtualNotch && hidesIdleVirtualNotch }

    func setHidesIdleVirtualNotch(_ hides: Bool) {
        if hides != hidesIdleVirtualNotch { hidesIdleVirtualNotch = hides }
    }

    func setNotchSize(_ size: CGSize, isVirtual: Bool = false) {
        guard size != notchSize || isVirtual != isVirtualNotch else { return }
        notchSize = size
        isVirtualNotch = isVirtual
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
                let pause = current.clock.isPlaying
                if pause { self.nowPlayingService?.send(.togglePlayPause) }
                self.showVideo(
                    VideoSession(videoID: videoID, title: current.title, sourceBundleIdentifier: browser, pausedSource: pause),
                    start: current.clock.elapsed(at: self.now())
                )
            }
        }
    }

    /// Opens the video panel. Also used by the snapshot renderer, which passes no player.
    func showVideo(_ session: VideoSession, start: TimeInterval) {
        videoPlayer?.stop()
        videoNeedsSignIn = false
        let player = makePlayer(session.videoID, start)
        player?.onError = { [weak self] _ in
            self?.videoFailed()
        }
        player?.onNeedsSignIn = { [weak self] needsSignIn in
            self?.videoNeedsSignIn = needsSignIn
        }
        videoPlayer = player
        video = session
        apply()
    }

    /// Opens a window where the user signs into their own YouTube account; when it closes, the notch
    /// reloads the page with the new session (a YouTube Premium account then plays without ads).
    func signInToYouTube() {
        guard let player = videoPlayer else { return }
        let controller = signInWindow ?? SignInWindowController()
        signInWindow = controller
        controller.show { [weak player] in player?.reloadWatchPage() }
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
            self.videoNeedsSignIn = false
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

    /// The video cannot play in the notch: close it and leave the browser where it was (a failed player
    /// reports 0 s, so handing its position back would rewind the browser), playing again if NotchBox paused it.
    private func videoFailed() {
        guard let session = video else { return }
        videoPlayer?.stop()
        videoPlayer = nil
        video = nil
        videoNeedsSignIn = false
        apply()
        show(message: L10n.videoUnavailable)
        guard session.pausedSource else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.handBackDelay) { [weak self] in
            MainActor.assumeIsolated { self?.nowPlayingService?.send(.togglePlayPause) }
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
