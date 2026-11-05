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
    private var buffer = Data()
    private var isStopped = true

    init(location: AdapterLocation) {
        self.location = location
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
        buffer.removeAll()
        let streamProcess = Process()
        streamProcess.executableURL = URL(fileURLWithPath: AdapterCommandLine.perlPath)
        streamProcess.arguments = location.baseArguments + AdapterCommandLine.streamArguments
        let stdout = Pipe()
        let stderr = Pipe()
        streamProcess.standardOutput = stdout
        streamProcess.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
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

        supervisor.processStarted(at: Date())
        do {
            try streamProcess.run()
            process = streamProcess
        } catch {
            logger.error("Adapter failed to launch: \(error.localizedDescription, privacy: .public)")
            scheduleRestart()
        }
    }

    private func consume(_ data: Data, from source: Process) {
        guard source === process else { return }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            if let line = String(data: lineData, encoding: .utf8) {
                handle(line: line)
            }
        }
    }

    private func handle(line: String) {
        switch AdapterStreamParser.parse(line: line, receivedAt: Date()) {
        case .invalid:
            logger.debug("Skipped unparseable adapter line")
        case .nothingPlaying:
            supervisor.receivedOutput()
            update(.nothing)
        case .info(let info):
            supervisor.receivedOutput()
            update(.info(info))
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
        let delay = supervisor.processExited(at: Date())
        if supervisor.isDegraded {
            update(.unavailable)
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

    private func update(_ newState: NowPlayingState) {
        guard newState != state else { return }
        state = newState
        onChange?(newState)
    }
}
