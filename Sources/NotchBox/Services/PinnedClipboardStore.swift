import Foundation
import NotchBoxCore
import os

@MainActor
protocol PinnedClipboardStoring: AnyObject {
    func load() -> [ClipboardContent]
    func save(_ pinned: [ClipboardContent])
}

/// Keeps the clipboard items the user pinned across restarts, in
/// ~/Library/Application Support/NotchBox/pinned-clipboard.json (readable only by the user). Recent,
/// unpinned items are never written.
@MainActor
final class PinnedClipboardStore: PinnedClipboardStoring {
    private let url: URL
    private let logger = Logger(subsystem: AppConstants.logSubsystem, category: "clipboard")

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("NotchBox", isDirectory: true)) {
        url = directory.appendingPathComponent("pinned-clipboard.json")
    }

    func load() -> [ClipboardContent] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder().decode([ClipboardContent].self, from: data)
        } catch {
            logger.error("Could not read pinned clipboard items: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func save(_ pinned: [ClipboardContent]) {
        let manager = FileManager.default
        do {
            if pinned.isEmpty {
                if manager.fileExists(atPath: url.path) { try manager.removeItem(at: url) }
                return
            }
            try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(pinned).write(to: url, options: [.atomic])
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            logger.error("Could not save pinned clipboard items: \(error.localizedDescription, privacy: .public)")
        }
    }
}
