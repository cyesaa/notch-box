import AVFoundation
import NotchBoxObjC
import os

/// What the mirror asks of a camera. Snapshots use a stand-in without one.
protocol MirrorCameraControlling: AnyObject {
    /// nil when there is no real camera behind it (snapshots): a picture stands in for it.
    var session: AVCaptureSession? { get }
    /// Asks for the camera when needed, then starts it. Completes on the main thread with why it could
    /// not start, or nil.
    func start(completion: @escaping @MainActor (CameraFailure?) -> Void)
    func stop()
}

/// The Mac's camera for the mirror: only shown, never recorded or read.
///
/// Started the same careful way as `QRScanner`: the session keeps the size it picks for the camera (asking
/// for one before the camera is added made M1 laptops quit), and whatever the camera frameworks raise
/// becomes `.failed` instead of ending the app.
final class MirrorCamera: NSObject, MirrorCameraControlling, @unchecked Sendable {
    private let captureSession = AVCaptureSession()
    var session: AVCaptureSession? { captureSession }

    private let queue = DispatchQueue(label: "com.notchbox.NotchBox.mirror", qos: .userInitiated)
    /// On `queue`, from here on.
    private var isConfigured = false
    private var isConfiguring = false
    /// Between `start` and `stop`. The camera permission can be answered after the mirror was closed;
    /// the camera must not come on then.
    private var isWanted = false
    private static let logger = Logger(subsystem: "com.notchbox.NotchBox", category: "mirror")

    func start(completion: @escaping @MainActor (CameraFailure?) -> Void) {
        let finish: @Sendable (CameraFailure?) -> Void = { failure in
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(failure) } }
        }
        queue.async { self.isWanted = true }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            queue.async { finish(self.run()) }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                guard granted else { return finish(.denied) }
                self.queue.async { finish(self.run()) }
            }
        default:
            finish(.denied)
        }
    }

    func stop() {
        queue.async {
            self.isWanted = false
            _ = NBCatchException {
                if self.captureSession.isRunning { self.captureSession.stopRunning() }
            }
        }
    }

    /// On `queue`.
    private func run() -> CameraFailure? {
        guard isWanted else { return nil }
        var failure: CameraFailure?
        let exception = NBCatchException { failure = self.startCamera() }
        guard let exception else { return failure }
        Self.logger.error("The camera raised \(exception.name.rawValue, privacy: .public): \(exception.reason ?? "", privacy: .public)")
        let wasConfiguring = isConfiguring
        isConfiguring = false
        isConfigured = false
        _ = NBCatchException {
            self.captureSession.inputs.forEach(self.captureSession.removeInput)
            if wasConfiguring { self.captureSession.commitConfiguration() }
        }
        return .failed
    }

    /// On `queue`, inside `NBCatchException`: what has to outlive an exception is kept on the object.
    private func startCamera() -> CameraFailure? {
        if !isConfigured {
            guard let camera = QRScanner.camera(), let input = try? AVCaptureDeviceInput(device: camera),
                  captureSession.canAddInput(input)
            else { return .noCamera }
            captureSession.beginConfiguration()
            isConfiguring = true
            captureSession.addInput(input)
            captureSession.commitConfiguration()
            isConfiguring = false
            isConfigured = true
            let size = CMVideoFormatDescriptionGetDimensions(camera.activeFormat.formatDescription)
            Self.logger.notice("Mirror camera ready: \(size.width, privacy: .public)x\(size.height, privacy: .public)")
        }
        if !captureSession.isRunning { captureSession.startRunning() }
        return nil
    }
}
