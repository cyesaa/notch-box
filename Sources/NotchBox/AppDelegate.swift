import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var windowController: NotchWindowController?
    private var model: NotchViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController()

        let model = NotchViewModel()
        let windowController = NotchWindowController(model: model)
        windowController.start()
        model.start()
        self.model = model
        self.windowController = windowController
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
    }
}
