import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private let updates = UpdateService()
    private var windowController: NotchWindowController?
    private var model: NotchViewModel?
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(updates: updates)
        updates.start()

        let nowPlayingService = AdapterNowPlayingService(location: .resolve())
        let model = NotchViewModel(
            nowPlayingService: nowPlayingService,
            volumeControl: VolumeService(),
            mediaKeys: MediaKeySender(),
            audioMeter: AudioLevelMeter(),
            tabReader: BrowserTabReader(),
            clipboardWatcher: ClipboardMonitor(),
            calendarProvider: CalendarService()
        )
        let windowController = NotchWindowController(model: model)
        windowController.start()
        model.start()
        self.model = model
        self.windowController = windowController

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { nowPlayingService.systemDidWake() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
    }
}
