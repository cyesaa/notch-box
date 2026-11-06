import AppKit

@main
@MainActor
enum NotchBoxApp {
    static func main() {
        let app = NSApplication.shared
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: SnapshotRenderer.argument), index + 1 < arguments.count {
            do {
                try SnapshotRenderer.render(to: URL(fileURLWithPath: arguments[index + 1]))
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("error: \(error)\n".utf8))
                exit(1)
            }
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        // Route SIGTERM (e.g. `pkill`) through normal termination so the adapter child is stopped.
        signal(SIGTERM, SIG_IGN)
        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        termSource.setEventHandler {
            MainActor.assumeIsolated { app.terminate(nil) }
        }
        termSource.resume()
        withExtendedLifetime((delegate, termSource)) {
            app.run()
        }
    }
}
