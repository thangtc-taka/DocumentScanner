import AVFoundation
import UIKit

actor CameraSession {

    // MARK: - Private state

    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "com.documentscanner.video", qos: .userInitiated)

    private var framePublisher: FramePublisher?
    private var frameContinuation: AsyncStream<CMSampleBuffer>.Continuation?

    // MARK: - Public interface

    nonisolated let previewLayer: AVCaptureVideoPreviewLayer

    init(configuration: DocumentScannerConfiguration) throws {
        previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.videoGravity = .resizeAspectFill
    }

    // MARK: - Session lifecycle

    func start() async throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied,
              AVCaptureDevice.authorizationStatus(for: .video) != .restricted else {
            throw DocumentScannerError.cameraPermissionDenied
        }

        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else { throw DocumentScannerError.cameraPermissionDenied }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw DocumentScannerError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: device)

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        if captureSession.canAddOutput(photoOutput) { captureSession.addOutput(photoOutput) }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }

        captureSession.commitConfiguration()

        previewLayer.session = captureSession
        captureSession.startRunning()
    }

    func stop() {
        captureSession.stopRunning()
        frameContinuation?.finish()
        frameContinuation = nil
        framePublisher = nil
    }

    // MARK: - Frame stream

    /// Returns an AsyncStream of video frames. Each new call invalidates the previous stream.
    func frames() -> AsyncStream<CMSampleBuffer> {
        frameContinuation?.finish()
        let stream = AsyncStream<CMSampleBuffer>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let publisher = FramePublisher(continuation: continuation)
            self.framePublisher = publisher
            self.frameContinuation = continuation
            self.videoOutput.setSampleBufferDelegate(publisher, queue: self.videoQueue)
        }
        return stream
    }

    // MARK: - Photo capture

    func captureHighResPhoto() async throws -> UIImage {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoCaptureDelegate(continuation: continuation)
            // Retain delegate for the duration of the capture
            objc_setAssociatedObject(self.photoOutput, &PhotoCaptureDelegate.key, delegate, .OBJC_ASSOCIATION_RETAIN)
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
}

// MARK: - PhotoCaptureDelegate

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    static var key: UInt8 = 0
    private let continuation: CheckedContinuation<UIImage, any Error>

    init(continuation: CheckedContinuation<UIImage, any Error>) {
        self.continuation = continuation
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        if let error {
            continuation.resume(throwing: DocumentScannerError.captureFailure(underlying: error))
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            continuation.resume(throwing: DocumentScannerError.captureFailure(underlying: DocumentScannerError.cameraUnavailable))
            return
        }
        continuation.resume(returning: image)
    }
}
