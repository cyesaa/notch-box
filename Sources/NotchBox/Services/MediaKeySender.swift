import AppKit
import ApplicationServices

/// Degraded-mode fallback: posts system media key events. Needs Accessibility permission,
/// which is requested the first time a key is sent.
@MainActor
final class MediaKeySender: MediaKeySending {
    func send(code: Int32) {
        guard isTrusted(prompt: true) else { return }
        post(code: code, down: true)
        post(code: code, down: false)
    }

    private func isTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func post(code: Int32, down: Bool) {
        let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
        let data1 = Int((code << 16) | ((down ? 0xA : 0xB) << 8))
        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )
        event?.cgEvent?.post(tap: .cghidEventTap)
    }
}
