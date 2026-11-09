import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private let updates = UpdateService()
    private var settings: AppSettings?
    private var settingsWindow: SettingsWindowController?
    private var windowController: NotchWindowController?
    private var model: NotchViewModel?
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = AppSettings(updates: updates)
        let settingsWindow = SettingsWindowController(settings: settings)
        self.settings = settings
        self.settingsWindow = settingsWindow
        statusItemController = StatusItemController(updates: updates) { settingsWindow.show() }
        updates.start()

        let nowPlayingService = AdapterNowPlayingService(location: .resolve())
        let model = NotchViewModel(
            nowPlayingService: nowPlayingService,
            volumeControl: VolumeService(),
            mediaKeys: MediaKeySender(),
            audioMeter: AudioLevelMeter(),
            tabReader: BrowserTabReader(),
            clipboardWatcher: ClipboardMonitor(),
            pinnedStore: PinnedClipboardStore(),
            calendarProvider: CalendarService()
        )
        model.setSideWidgets(settings.sideWidgets)
        settings.onSideWidgetsChange = { [weak model] sides in model?.setSideWidgets(sides) }
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
