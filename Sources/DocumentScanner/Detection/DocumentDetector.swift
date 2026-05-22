import Vision
import CoreVideo
import CoreImage
import UIKit

/// Detects and tracks document boundaries in video frames.
///
/// Uses a detect-then-track strategy:
/// - Initial detection: `VNDetectDocumentSegmentationRequest` (ML model, Neural Engine on A12+)
/// - Subsequent frames: `VNTrackRectangleRequest` (optical flow, ~5 ms vs ~50 ms per frame)
/// - Falls back to ML detection when tracking confidence drops below threshold.
actor DocumentDetector {

    // MARK: - State

    private enum Mode {
        case detecting
        case tracking(VNRectangleObservation)
    }

    private var mode: Mode = .detecting
    private var sequenceHandler = VNSequenceRequestHandler()

    private static let trackingConfidenceThreshold: Float = 0.3

    // MARK: - Video frame detection

    func detect(in sampleBuffer: CMSampleBuffer) throws -> Quad? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        switch mode {
        case .detecting:
            return try runMLDetection(on: pixelBuffer, orientation: .up)
        case .tracking(let observation):
            return try runTracking(on: pixelBuffer, observation: observation, orientation: .up)
        }
    }

    /// Resets to ML detection mode. Call after capture or session stop so the next
    /// scan starts with a fresh ML detection rather than a stale tracking observation.
    func reset() {
        mode = .detecting
        sequenceHandler = VNSequenceRequestHandler()
    }

    // MARK: - Still image detection (used after high-res capture)

    func detect(in image: UIImage) throws -> Quad? {
        guard let cgImage = image.cgImage else { return nil }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        let request = VNDetectDocumentSegmentationRequest()
        try handler.perform([request])
        return request.results?.first.map { Quad(observation: $0) }
    }

    // MARK: - ML Detection

    private func runMLDetection(
        on pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) throws -> Quad? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        let request = VNDetectDocumentSegmentationRequest()
        try handler.perform([request])

        guard let observation = request.results?.first else { return nil }
        mode = .tracking(observation)
        return Quad(observation: observation)
    }

    // MARK: - Rectangle Tracking

    private func runTracking(
        on pixelBuffer: CVPixelBuffer,
        observation: VNRectangleObservation,
        orientation: CGImagePropertyOrientation
    ) throws -> Quad? {
        let request = VNTrackRectangleRequest(rectangleObservation: observation)
        request.trackingLevel = .accurate

        try sequenceHandler.perform([request], on: pixelBuffer, orientation: orientation)

        guard let tracked = request.results?.first as? VNRectangleObservation,
              tracked.confidence >= Self.trackingConfidenceThreshold else {
            // Tracking lost — create a fresh sequence handler and re-detect with ML.
            sequenceHandler = VNSequenceRequestHandler()
            mode = .detecting
            return try runMLDetection(on: pixelBuffer, orientation: orientation)
        }

        mode = .tracking(tracked)
        return Quad(observation: tracked)
    }
}

// MARK: - CGImagePropertyOrientation from UIImage.Orientation

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:            self = .up
        case .upMirrored:    self = .upMirrored
        case .down:          self = .down
        case .downMirrored:  self = .downMirrored
        case .left:          self = .left
        case .leftMirrored:  self = .leftMirrored
        case .right:         self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}
