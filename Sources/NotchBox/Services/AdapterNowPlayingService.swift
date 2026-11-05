import Foundation
import NotchBoxCore
import os

/// Runs `mediaremote-adapter.pl … stream` for the app's lifetime and restarts it when it exits.
/// Runs `… test` at launch, after wake and every 30 minutes; while it fails the service reports `.unavailable`.
@MainActor
final class AdapterNowPlayingService: NowPlayingService {
    private(set) var state: NowPlayingState = .nothing
    var onChange: ((NowPlayingState) -> Void)?

    private let location: AdapterLocation
    private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "adapter")
    private var process: Process?
    private var supervisor = AdapterSupervisor()
    private var restartWork: DispatchWorkItem?
    private var nothingFilter = NothingPlayingFilter()
    private var filterTick: DispatchWorkItem?
    private var health = AdapterHealthMonitor()
    private var healthProcess: Process?
    private var healthTick: DispatchWorkItem?
    private var lineAssembler = AdapterLineAssembler()
    private var isStopped = true
    private let now: () -> Date

    init(location: AdapterLocation, now: @escaping () -> Date = Date.init) {
        self.location = location
        self.now = now
    }

    func start() {
        guard isStopped else { return }
        isStopped = false
        launch()
        perform(health.requestCheck(at: now()))
    }

    func stop() {
        isStopped = true
        restartWork?.cancel()
        restartWork = nil
        nothingFilter.cancelPending()
        health.cancel()
        scheduleTicks()
        process?.terminate()
        process = nil
        healthProcess?.terminate()
        healthProcess = nil
    }

    /// Called after wake: launch the stream now if it is not running (skips any pending delay) and check health.
    func systemDidWake() {
        guard !isStopped else { return }
        if process == nil {
            restartWork?.cancel()
            restartWork = nil
            launch()
        }
        perform(health.requestCheck(at: now()))
    }

    func send(_ command: MediaCommand) {
        let commandProcess = Process()
        commandProcess.executableURL = URL(fileURLWithPath: AdapterCommandLine.perlPath)
        commandProcess.arguments = location.baseArguments + AdapterCommandLine.arguments(for: command)
        commandProcess.standardOutput = FileHandle.nullDevice
        commandProcess.standardError = FileHandle.nullDevice
        do {
            try commandProcess.run()
        } catch {
            logger.error("Command failed to launch: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func launch() {
        lineAssembler.reset()
        let streamProcess = Process()
        streamProcess.executableURL = URL(fileURLWithPath: AdapterCommandLine.perlPath)
        streamProcess.arguments = location.baseArguments + AdapterCommandLine.streamArguments
        let stdout = Pipe()
        let stderr = Pipe()
        streamProcess.standardOutput = stdout
        streamProcess.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                // EOF: stop the handler, otherwise it spins on empty reads until the process exit is reported.
                handle.readabilityHandler = nil
                return
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.consume(data, from: streamProcess) }
            }
        }
        Self.log(stderr, as: "adapter stderr", to: logger)
        streamProcess.terminationHandler = { [weak self] finished in
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.handleExit(of: finished) }
            }
        }

        supervisor.processStarted(at: now())
        do {
            try streamProcess.run()
            process = streamProcess
        } catch {
            logger.error("Adapter failed to launch: \(error.localizedDescription, privacy: .public)")
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            scheduleRestart()
        }
    }

    /// Logs what a process writes to `pipe` as errors (the adapter prints only errors to stderr).
    private static func log(_ pipe: Pipe, as label: String, to logger: Logger) {
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                // EOF: stop the handler, otherwise it spins on empty reads until the process exit is reported.
                handle.readabilityHandler = nil
                return
            }
            guard let text = String(data: data, encoding: .utf8) else { return }
            logger.error("\(label, privacy: .public): \(text, privacy: .public)")
        }
    }

    private func consume(_ data: Data, from source: Process) {
        guard source === process else { return }
        let output = lineAssembler.append(data)
        for line in output.lines {
            handle(line: line)
        }
        if output.discardedOverlongLine {
            logger.error("Adapter output exceeded \(self.lineAssembler.maxLineBytes) bytes without a newline; discarding buffer")
        }
    }

    private func handle(line: String) {
        switch AdapterStreamParser.parse(line: line, receivedAt: now()) {
        case .invalid:
            logger.debug("Skipped unparseable adapter line")
        case .nothingPlaying:
            supervisor.receivedOutput()
            nothingFilter.receivedNothing(at: now())
            apply()
        case .info(let info):
            supervisor.receivedOutput()
            health.receivedTrackInfo()
            nothingFilter.received(info)
            apply()
        }
    }

    private func handleExit(of finished: Process) {
        guard finished === process else { return }
        process = nil
        logger.notice("Adapter exited with status \(finished.terminationStatus)")
        guard !isStopped else { return }
        scheduleRestart()
    }

    private func scheduleRestart() {
        let delay = supervisor.processExited(at: now())
        if supervisor.isDegraded {
            nothingFilter.becameUnavailable()
            apply()
        }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isStopped else { return }
                self.restartWork = nil
                self.launch()
            }
        }
        restartWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func perform(_ action: AdapterHealthMonitor.Action?) {
        switch action {
        case .startCheck:
            runHealthCheck()
        case .stopCheck:
            logger.error("Adapter test did not finish within \(AdapterHealthMonitor.checkTimeout) s; showing degraded mode")
            healthProcess?.terminate()
            healthProcess = nil
        case nil:
            break
        }
        apply()
    }

    private func runHealthCheck() {
        let check = Process()
        check.executableURL = URL(fileURLWithPath: AdapterCommandLine.perlPath)
        check.arguments = location.healthCheckArguments
        check.standardOutput = FileHandle.nullDevice
        let stderr = Pipe()
        check.standardError = stderr
        Self.log(stderr, as: "adapter test stderr", to: logger)
        check.terminationHandler = { [weak self] finished in
            stderr.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.healthCheckExited(finished) }
            }
        }
        do {
            try check.run()
            healthProcess = check
        } catch {
            logger.error("Adapter test failed to launch: \(error.localizedDescription, privacy: .public)")
            stderr.fileHandleForReading.readabilityHandler = nil
            health.checkFinished(passed: false, at: now())
        }
    }

    private func healthCheckExited(_ finished: Process) {
        guard finished === healthProcess else { return }
        healthProcess = nil
        let passed = finished.terminationReason == .exit && finished.terminationStatus == 0
        if passed {
            logger.info("Adapter test passed")
        } else {
            logger.error("Adapter test exited with status \(finished.terminationStatus); showing degraded mode")
        }
        health.checkFinished(passed: passed, at: now())
        apply()
    }

    /// Publishes the state and arms the timers for the next deadlines.
    private func apply() {
        let newState = health.state(from: nothingFilter.state)
        if newState != state {
            state = newState
            onChange?(newState)
        }
        scheduleTicks()
    }

    private func scheduleTicks() {
        filterTick = schedule(replacing: filterTick, at: nothingFilter.nextDeadline) { service in
            service.nothingFilter.tick(at: service.now())
            service.apply()
        }
        healthTick = schedule(replacing: healthTick, at: health.nextDeadline) { service in
            service.perform(service.health.tick(at: service.now()))
        }
    }

    /// Cancels `old` and returns a main queue work item that runs `action` at `deadline` (nil: none).
    private func schedule(
        replacing old: DispatchWorkItem?,
        at deadline: Date?,
        action: @escaping @MainActor (AdapterNowPlayingService) -> Void
    ) -> DispatchWorkItem? {
        old?.cancel()
        guard let deadline else { return nil }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                action(self)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, deadline.timeIntervalSince(now())), execute: work)
        return work
    }
}
