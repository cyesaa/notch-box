import AVFoundation
import CoreImage
import os
import SwiftUI
import Vision

/// Reads QR codes with the Mac's camera, for importing accounts. Frames are looked at a few times a
/// second and thrown away; nothing is recorded.
final class QRScanner: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    enum Failure: Equatable {
        case noCamera
        /// The user (or a policy) said no to the camera.
        case denied
    }

    let session = AVCaptureSession()
    /// Called on the main thread with the text of each QR code in view — the same code many times while
    /// it stays there.
    var onPayload: (@MainActor (String) -> Void)?

    private let queue = DispatchQueue(label: "com.notchbox.NotchBox.qr-scanner", qos: .userInitiated)
    private var isConfigured = false
    /// Between `start` and `stop`. The camera permission can be answered after the window was closed;
    /// the camera must not come on then.
    private var isWanted = false
    private var lastLook = Date.distantPast
    /// Gap between two looks at the picture; reading a dense code is slower than the camera is fast.
    private static let lookInterval: TimeInterval = 0.12
    private static let logger = Logger(subsystem: "com.notchbox.NotchBox", category: "auth")
    /// Said once, not for every frame.
    private nonisolated(unsafe) static var hasLoggedFailure = false

    /// Asks for the camera when needed, then starts it. Completes on the main thread with why it could
    /// not start, or nil.
    func start(completion: @escaping @MainActor (Failure?) -> Void) {
        let finish: @Sendable (Failure?) -> Void = { failure in
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
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    /// The text of every QR code in a picture.
    static func payloads(in handler: VNImageRequestHandler) -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        do {
            try handler.perform([request])
        } catch {
            if !hasLoggedFailure {
                hasLoggedFailure = true
                logger.error("Looking for a QR code failed: \(error.localizedDescription, privacy: .public)")
            }
            return []
        }
        return (request.results ?? []).compactMap(\.payloadStringValue)
    }

    /// Pictures narrower than this get a second look, enlarged: a 720p camera (the one in M1 laptops)
    /// shows an export of many accounts with modules only a pixel or two wide.
    private static let smallPictureWidth: CGFloat = 1_700

    /// The text of every QR code in a picture. When nothing is found in a small picture it is looked at
    /// again, enlarged and sharpened, which reads codes that are a little too fine or soft as they are.
    static func payloads(in image: CIImage) -> [String] {
        let found = payloads(in: VNImageRequestHandler(ciImage: image, options: [:]))
        guard found.isEmpty, image.extent.width < smallPictureWidth, image.extent.width > 0 else { return found }
        let enlarged = image
            .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 2.0, kCIInputAspectRatioKey: 1.0])
            .applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: 2.5, kCIInputIntensityKey: 1.2])
        return payloads(in: VNImageRequestHandler(ciImage: enlarged, options: [:]))
    }

    /// The text of every QR code in a picture file (a screenshot of the code, say); nil when the file
    /// is not a picture.
    static func payloads(inPictureAt url: URL) -> [String]? {
        guard let image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else { return nil }
        return payloads(in: image)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = Date()
        guard time.timeIntervalSince(lastLook) >= Self.lookInterval, let image = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastLook = time
        let payloads = Self.payloads(in: CIImage(cvPixelBuffer: image))
        guard !payloads.isEmpty else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated { payloads.forEach { self.onPayload?($0) } }
        }
    }

    /// On `queue`.
    private func run() -> Failure? {
        guard isWanted else { return nil }
        if !isConfigured {
            guard let camera = Self.camera(), let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else {
                return .noCamera
            }
            session.beginConfiguration()
            // As sharp as the camera goes: an export of many accounts is a dense code.
            if session.canSetSessionPreset(.hd1920x1080) { session.sessionPreset = .hd1920x1080 }
            session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            // Frames in a format every reader takes. Left to the camera, an older one hands over its own
            // format (the 720p camera's is not the newer cameras'), and the code might never be found.
            if output.availableVideoPixelFormatTypes.contains(kCVPixelFormatType_32BGRA) {
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            }
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()
            isConfigured = true
        }
        if !session.isRunning { session.startRunning() }
        return nil
    }

    /// The Mac's own camera when it has one; an iPhone offered as a camera comes last, since the phone
    /// is what shows the code.
    private static func camera() -> AVCaptureDevice? {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external], mediaType: .video, position: .unspecified
        ).devices
        return devices.first { $0.deviceType == .builtInWideAngleCamera && !$0.isContinuityCamera }
            ?? devices.first { !$0.isContinuityCamera }
            ?? AVCaptureDevice.default(for: .video)
    }
}

/// What the camera sees, mirrored like a mirror so that moving the phone feels natural.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    /// Changes when the camera starts, so that `updateNSView` runs then.
    let isRunning: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.backgroundColor = NSColor.black.cgColor
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    /// The layer gets its connection only once the camera is set up, which is after it is made; this
    /// runs again when the camera reports that it started.
    func updateNSView(_ view: NSView, context: Context) {
        guard let connection = (view.layer as? AVCaptureVideoPreviewLayer)?.connection,
              connection.isVideoMirroringSupported, !connection.isVideoMirrored else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = true
    }
}
