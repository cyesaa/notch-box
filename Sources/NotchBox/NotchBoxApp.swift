import AppKit

@main
@MainActor
enum NotchBoxApp {
    static func main() {
        let app = NSApplication.shared
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
