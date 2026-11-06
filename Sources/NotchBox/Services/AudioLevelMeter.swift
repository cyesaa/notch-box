import Foundation
import NotchBoxCore
import Observation
import os

/// Bar heights for the waveform from what is actually playing. Runs the system audio tap only while
/// it is switched on (music playing and the notch showing it). Without macOS 14.2, without the
/// permission, or in silence, `isLive` stays false and the waveform animates on its own.
@MainActor
@Observable
final class AudioLevelMeter {
    static let bandCount = 5
    static let refreshInterval: TimeInterval = 1.0 / 30.0
    /// Samples per spectrum: about 43 ms at 48 kHz.
    static let frameSize = 2048

    private(set) var levels: [Double] = Array(repeating: 0, count: AudioLevelMeter.bandCount)
    private(set) var isLive = false

    @ObservationIgnored private var state = AudioLevelMeterState(bandCount: AudioLevelMeter.bandCount)
    @ObservationIgnored private var tap: AnyObject?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var isActive = false
    /// Bumped on every start and stop, so a slow start that finishes after a stop is ignored.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var sampleRate: Double = 48_000
    @ObservationIgnored private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "audio-meter")
    @ObservationIgnored private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        active ? start() : stop()
    }

    private func start() {
        guard #available(macOS 14.2, *) else { return }
        generation += 1
        let current = generation
        let tap = SystemAudioTap()
        self.tap = tap
        // The first start waits for the permission prompt, so it runs off the main thread.
        tap.start { [weak self] result in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.tapStarted(result, generation: current) }
            }
        }
    }

    private func tapStarted(_ result: Result<Double, Error>, generation started: Int) {
        guard started == generation, isActive else { return }
        switch result {
        case .failure(let error):
            logger.error("System audio tap failed: \(String(describing: error), privacy: .public)")
            stopTap()
        case .success(let rate):
            sampleRate = rate
            let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    private func stop() {
        generation += 1
        stopTap()
        state.reset()
        publish()
    }

    private func stopTap() {
        timer?.invalidate()
        timer = nil
        if #available(macOS 14.2, *) {
            (tap as? SystemAudioTap)?.stop()
        }
        tap = nil
    }

    private func refresh() {
        guard #available(macOS 14.2, *), let tap = tap as? SystemAudioTap else { return }
        let samples = tap.latestSamples()
        guard samples.count >= Self.frameSize else { return }
        let wasLive = state.isLive
        state.update(samples: Array(samples.suffix(Self.frameSize)), sampleRate: sampleRate, at: now())
        if state.isLive != wasLive {
            logger.info("Audio levels \(self.state.isLive ? "live" : "silent", privacy: .public)")
        }
        publish()
    }

    private func publish() {
        if levels != state.levels { levels = state.levels }
        if isLive != state.isLive { isLive = state.isLive }
    }
}
