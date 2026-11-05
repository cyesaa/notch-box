import AppKit
import NotchBoxCore
import Observation

/// Single source of truth for the views. Combines the state machine with the services.
@MainActor
@Observable
final class NotchViewModel {
    /// The adapter sends the new track's metadata before its artwork, so the old cover is kept this long to avoid a placeholder blink.
    static let artworkHoldDuration: TimeInterval = 1.0

    private(set) var displayState: NotchDisplayState = .idle
    private(set) var notchSize = CGSize(width: 185, height: 32)
    private(set) var nowPlaying: NowPlayingState = .nothing
    private(set) var artworkImage: NSImage?
    private(set) var artworkVersion = 0
    private(set) var sourceAppIcon: NSImage?
    private(set) var volume: Float = 0
    private(set) var isVolumeSettable = false
    /// Slider position while the user drags the progress bar.
    private(set) var scrubPosition: TimeInterval?

    @ObservationIgnored var onDisplayStateChange: ((NotchDisplayState) -> Void)?
    @ObservationIgnored private var machine = NotchStateMachine()
    @ObservationIgnored private var deadlineTimer: Timer?
    @ObservationIgnored private var artworkClearWork: DispatchWorkItem?
    /// Bytes of the cover currently shown, to skip rebuilding an identical image.
    @ObservationIgnored private var displayedArtwork: Data?
    @ObservationIgnored private let nowPlayingService: NowPlayingService?
    @ObservationIgnored private let volumeControl: VolumeControlling?
    @ObservationIgnored private let mediaKeys: MediaKeySending?
    @ObservationIgnored private let now: () -> Date

    init(
        nowPlayingService: NowPlayingService? = nil,
        volumeControl: VolumeControlling? = nil,
        mediaKeys: MediaKeySending? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.nowPlayingService = nowPlayingService
        self.volumeControl = volumeControl
        self.mediaKeys = mediaKeys
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
        nowPlayingService?.start()
        volumeControl?.start()
        volumeChanged()
    }

    func stop() {
        deadlineTimer?.invalidate()
        cancelArtworkClear()
        nowPlayingService?.stop()
    }

    func setNotchSize(_ size: CGSize) {
        guard size != notchSize else { return }
        notchSize = size
        onDisplayStateChange?(displayState)
    }

    func hoverChanged(_ hovering: Bool) {
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
        updateArtwork(old: old, current: current)
        if current?.sourceBundleIdentifier != old?.sourceBundleIdentifier {
            sourceAppIcon = current.flatMap { AppIconProvider.icon(for: $0.sourceBundleIdentifier) }
        }
        machine.setMedia(state.machineMedia, at: now())
        apply()
    }

    private func updateArtwork(old: NowPlayingInfo?, current: NowPlayingInfo?) {
        guard let current else {
            cancelArtworkClear()
            if artworkImage != nil {
                artworkImage = nil
                displayedArtwork = nil
                artworkVersion += 1
            }
            return
        }
        if let data = current.artwork {
            cancelArtworkClear()
            if data != displayedArtwork {
                artworkImage = NSImage(data: data)
                displayedArtwork = data
                artworkVersion += 1
            }
        } else if artworkImage != nil, artworkClearWork == nil {
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.artworkClearWork = nil
                    self.artworkImage = nil
                    self.displayedArtwork = nil
                    self.artworkVersion += 1
                }
            }
            artworkClearWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.artworkHoldDuration, execute: work)
        }
    }

    private func cancelArtworkClear() {
        artworkClearWork?.cancel()
        artworkClearWork = nil
    }

    private func volumeChanged() {
        volume = volumeControl?.volume ?? 0
        isVolumeSettable = volumeControl?.isSettable ?? false
    }

    private func tick() {
        machine.tick(at: now())
        apply()
    }

    private func apply() {
        let newState = machine.displayState
        if newState != displayState {
            displayState = newState
            onDisplayStateChange?(newState)
        }
        scheduleNextTick()
    }

    private func scheduleNextTick() {
        deadlineTimer?.invalidate()
        deadlineTimer = nil
        guard let deadline = machine.nextDeadline else { return }
        let interval = max(0.01, deadline.timeIntervalSince(now()) + 0.005)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        deadlineTimer = timer
    }
}
