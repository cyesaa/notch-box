import AppKit
import AVFoundation
import NotchBoxCore
import Observation

/// The mirror: the camera in its card around the open player, or filling the screen. The camera runs
/// only while one of them is open (see `MirrorDemand`).
@MainActor
@Observable
final class MirrorModel {
    enum Camera: Equatable {
        case off
        case starting
        case running
        case failed(CameraFailure)
    }

    private(set) var demand = MirrorDemand()
    private(set) var camera = Camera.off

    @ObservationIgnored private let source: MirrorCameraControlling
    @ObservationIgnored private var window: MirrorWindowController?
    /// Tells a late answer from the camera from the current one.
    @ObservationIgnored private var attempt = 0

    init(source: MirrorCameraControlling = MirrorCamera()) {
        self.source = source
    }

    var session: AVCaptureSession? { source.session }
    var isOpenInPanel: Bool { demand.isOpenInPanel }
    var isFullScreen: Bool { demand.isFullScreen }

    /// The card's button, or a click on the picture in it.
    func toggle() {
        demand.toggleInPanel()
        update()
    }

    /// Whether the mirror's card is in the open panel. Closing the panel closes the mirror in it.
    func setColumnVisible(_ visible: Bool) {
        guard visible != demand.isColumnVisible else { return }
        demand.setColumnVisible(visible)
        update()
    }

    /// Fills the screen the pointer is on (the one with the notch the button was pressed in).
    func openFullScreen() {
        guard !demand.isFullScreen else { return }
        demand.setFullScreen(true)
        update()
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let screen else { return closeFullScreen() }
        let window = window ?? MirrorWindowController(model: self)
        self.window = window
        window.show(on: screen)
    }

    func closeFullScreen() {
        guard demand.isFullScreen else { return }
        demand.setFullScreen(false)
        window?.hide()
        update()
    }

    private func update() {
        if demand.wantsCamera {
            guard camera == .off else { return }
            camera = .starting
            attempt += 1
            let current = attempt
            source.start { [weak self] failure in
                guard let self, current == self.attempt, self.demand.wantsCamera else { return }
                self.camera = failure.map(Camera.failed) ?? .running
            }
        } else if camera != .off {
            attempt += 1
            source.stop()
            camera = .off
        }
    }
}
