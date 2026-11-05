import SwiftUI

/// The panel is never key, so the first click must reach SwiftUI controls directly.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
