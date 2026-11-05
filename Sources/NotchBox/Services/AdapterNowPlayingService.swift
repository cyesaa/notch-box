import Foundation
import NotchBoxCore
import os

/// Runs `mediaremote-adapter.pl … stream` for the app's lifetime and restarts it when it exits.
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
    }

    func stop() {
        isStopped = true
        restartWork?.cancel()
        restartWork = nil
        nothingFilter.cancelPending()
        scheduleFilterTick()
        process?.terminate()
        process = nil
    }

    /// Called after wake: launch now if the process is not running (skips any pending delay).
    func ensureRunning() {
        guard !isStopped, process == nil else { return }
        restartWork?.cancel()
        restartWork = nil
        launch()
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
        let logger = self.logger
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            logger.error("adapter stderr: \(text, privacy: .public)")
        }
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

    /// Publishes the filter's state and arms the timer for its next deadline.
    private func apply() {
        let newState = nothingFilter.state
        if newState != state {
            state = newState
            onChange?(newState)
        }
        scheduleFilterTick()
    }

    private func scheduleFilterTick() {
        filterTick?.cancel()
        filterTick = nil
        guard let deadline = nothingFilter.nextDeadline else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.filterTick = nil
                self.nothingFilter.tick(at: self.now())
                self.apply()
            }
        }
        filterTick = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, deadline.timeIntervalSince(now())), execute: work)
    }
}
