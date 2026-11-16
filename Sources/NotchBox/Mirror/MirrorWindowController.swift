import AppKit
import SwiftUI

/// The mirror over a whole screen, above the menu bar and the notch. Esc or the close button ends it.
@MainActor
final class MirrorWindowController {
    private let window: MirrorWindow
    /// The app that was in front before the mirror took the keyboard (for Esc); it gets it back after.
    private var previousApp: NSRunningApplication?

    init(model: MirrorModel) {
        window = MirrorWindow(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.onCancel = { [weak model] in model?.closeFullScreen() }
        let hosting = NSHostingView(rootView: MirrorFullScreenView(model: model))
        hosting.safeAreaRegions = []
        window.contentView = hosting
    }

    func show(on screen: NSScreen) {
        window.setFrame(screen.frame, display: false)
        window.alphaValue = 0
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }
    }

    func hide() {
        let window = window
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated { window.orderOut(nil) }
        })
        previousApp?.activate()
        previousApp = nil
    }
}

/// Borderless, yet it takes the keyboard, for Esc.
private final class MirrorWindow: NSWindow {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        // Esc, for when no view passed it on as cancelOperation.
        if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }
    }
}

/// The camera over the whole screen, with a close button in the corner.
private struct MirrorFullScreenView: View {
    let model: MirrorModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
            switch model.camera {
            case .failed(let failure):
                Text(MirrorView.message(for: failure))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .off, .starting, .running:
                if let session = model.session {
                    CameraPreview(session: session)
                }
                if model.camera == .starting {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Button(action: model.closeFullScreen) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.black.opacity(0.45)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help(L10n.mirrorExitFullScreen)
            .accessibilityLabel(L10n.mirrorExitFullScreen)
            .padding(28)
        }
        .ignoresSafeArea()
    }
}
