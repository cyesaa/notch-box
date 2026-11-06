import AppKit
import NotchBoxCore
import os

@MainActor
protocol ClipboardWatching: AnyObject {
    /// Called on the main thread with each new thing the user copies.
    var onCopy: ((ClipboardContent) -> Void)? { get set }
    /// The user turned off NotchBox's pasteboard access in System Settings.
    var isDenied: Bool { get }
    func start()
    func stop()
    /// Puts `content` back on the pasteboard.
    func copy(_ content: ClipboardContent)
}

/// Watches the general pasteboard. macOS has no change notification, so it checks the change count twice
/// a second and reads the contents only after it changes. The first read may make macOS ask whether
/// NotchBox may paste from other apps.
@MainActor
final class ClipboardMonitor: ClipboardWatching {
    static let interval: TimeInterval = 0.5

    var onCopy: ((ClipboardContent) -> Void)?
    private let pasteboard = NSPasteboard.general
    private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "clipboard")
    /// Starts unknown, so whatever is on the pasteboard at launch is the first item.
    private var lastChangeCount: Int?
    private var timer: Timer?

    var isDenied: Bool {
        if #available(macOS 15.4, *) { return pasteboard.accessBehavior == .alwaysDeny }
        return false
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func copy(_ content: ClipboardContent) {
        pasteboard.clearContents()
        switch content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let data, let type):
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType(type))
        }
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        guard !isDenied else { return }
        let types = pasteboard.types?.map(\.rawValue) ?? []
        let content: ClipboardContent?
        switch ClipboardReading.kind(of: types) {
        case .text:
            content = pasteboard.string(forType: .string).flatMap(ClipboardReading.content(text:))
        case .image(let type):
            content = pasteboard.data(forType: NSPasteboard.PasteboardType(type))
                .flatMap { ClipboardReading.content(image: $0, type: type) }
        case nil:
            content = nil
        }
        guard let content else { return }
        onCopy?(content)
    }
}
