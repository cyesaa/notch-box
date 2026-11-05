import AppKit

@main
@MainActor
enum NotchBoxApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
