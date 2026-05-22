import Vision
import CoreVideo
import CoreImage
import UIKit

/// Detects document boundaries in video frames using the Vision ML model.
/// VNDetectDocumentSegmentationRequest dispatches automatically to the Neural Engine
/// on A12+ devices — no manual hardware selection needed.
actor DocumentDetector {

    // MARK: - Video frame detection

    func detect(in sampleBuffer: CMSampleBuffer) throws -> Quad? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        return try detectInPixelBuffer(pixelBuffer, orientation: .up)
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

    // MARK: - Private helpers

    private func detectInPixelBuffer(
        _ pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) throws -> Quad? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        let request = VNDetectDocumentSegmentationRequest()
        try handler.perform([request])
        return request.results?.first.map { Quad(observation: $0) }
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
