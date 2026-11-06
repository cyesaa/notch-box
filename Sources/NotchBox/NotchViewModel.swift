import AppKit
import NotchBoxCore
import Observation

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

    @ObservationIgnored var onDisplayStateChange: ((NotchDisplayState) -> Void)?
    @ObservationIgnored private var machine = NotchStateMachine()
    @ObservationIgnored private var deadlineTimer: Timer?
    @ObservationIgnored private var artwork = ArtworkHold<NSImage> { NSImage(data: $0) }
    @ObservationIgnored private var artworkTimer: Timer?
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
        artworkTimer?.invalidate()
        artwork.cancelPending()
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
