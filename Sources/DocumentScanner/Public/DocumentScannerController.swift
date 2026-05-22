import UIKit
import AVFoundation
import CoreImage
import Combine

/// The primary controller. Wires together all pipeline actors.
/// All @Published properties update on the MainActor.
@MainActor
public final class DocumentScannerController: ObservableObject {

    // MARK: - Public state

    @Published public private(set) var detectedQuad: Quad?
    @Published public private(set) var isDocumentStable: Bool = false
    @Published public private(set) var captureState: CaptureState = .idle
    @Published public private(set) var scannedDocuments: [ScannedDocument] = []

    public enum CaptureState: Sendable {
        case idle, capturing, processing
    }

    public let configuration: DocumentScannerConfiguration

    /// The preview layer to embed in a custom layout via CameraPreviewView.
    public var previewLayer: AVCaptureVideoPreviewLayer {
        get async { await cameraSession.previewLayer }
    }

    // MARK: - Private actors

    private let cameraSession: CameraSession
    private let detector: DocumentDetector
    private let smoother: DetectionSmoother
    private let enhancer: ImageEnhancer
    private var frameTask: Task<Void, Never>?

    // MARK: - Init

    public init(configuration: DocumentScannerConfiguration = .default) throws {
        self.configuration = configuration
        self.cameraSession = try CameraSession(configuration: configuration)
        self.detector = DocumentDetector()
        self.smoother = DetectionSmoother(bufferSize: configuration.smoothingBufferSize)
        self.enhancer = ImageEnhancer(configuration: configuration)
    }

    // MARK: - Session control

    public func startSession() async throws {
        try await cameraSession.start()
        startFrameProcessing()
    }

    public func stopSession() async {
        frameTask?.cancel()
        frameTask = nil
        await cameraSession.stop()
    }

    // MARK: - Frame processing loop

    private func startFrameProcessing() {
        frameTask?.cancel()
        frameTask = Task { [weak self] in
            guard let self else { return }
            let stream = await self.cameraSession.frames()
            for await sampleBuffer in stream {
                guard !Task.isCancelled else { break }
                await self.processFrame(sampleBuffer)
            }
        }
    }

    private func processFrame(_ sampleBuffer: CMSampleBuffer) async {
        let quad = try? await detector.detect(in: sampleBuffer)
        let (smoothed, stable) = await smoother.process(quad)
        detectedQuad = smoothed
        isDocumentStable = stable
    }

    // MARK: - Capture

    public func captureDocument() async throws -> ScannedDocument {
        guard captureState == .idle else {
            throw DocumentScannerError.captureFailure(underlying: CancellationError())
        }
        captureState = .capturing

        defer { captureState = .idle }

        let original = try await cameraSession.captureHighResPhoto()
        captureState = .processing

        // Re-detect on the full-resolution still for accuracy
        let quad = (try? await detector.detect(in: original)) ?? detectedQuad ?? .fullPage

        guard let ciImage = CIImage(image: original) else {
            throw DocumentScannerError.enhancementFailed
        }

        let correctedCI = try PerspectiveCorrector().correct(image: ciImage, quad: quad)
        let corrected = try await enhancer.enhance(correctedCI, mode: .none)
        let enhanced = try await enhancer.enhance(correctedCI, mode: configuration.enhancementMode)

        let doc = ScannedDocument(
            originalImage: original,
            correctedImage: corrected,
            enhancedImage: enhanced,
            detectedQuad: quad
        )
        scannedDocuments.append(doc)
        return doc
    }

    // MARK: - Document management

    public func removeDocument(id: UUID) {
        scannedDocuments.removeAll { $0.id == id }
    }

    public func exportAllAsPDF() async throws -> Data {
        let images = scannedDocuments.map(\.enhancedImage)
        return try await Task.detached(priority: .userInitiated) {
            try PDFExporter().export(pages: images, pageSize: self.configuration.pageSize)
        }.value
    }
}
