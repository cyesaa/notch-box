import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var windowController: NotchWindowController?
    private var model: NotchViewModel?
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController()

        let nowPlayingService = AdapterNowPlayingService(location: .resolve())
        let model = NotchViewModel(
            nowPlayingService: nowPlayingService,
            volumeControl: VolumeService(),
            mediaKeys: MediaKeySender()
        )
        let windowController = NotchWindowController(model: model)
        windowController.start()
        model.start()
        self.model = model
        self.windowController = windowController

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { nowPlayingService.ensureRunning() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
    }
}
