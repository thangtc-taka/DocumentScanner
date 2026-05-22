import UIKit
import Foundation

public struct ScannedDocument: Sendable, Identifiable {
    public let id: UUID
    /// The original full-resolution capture before any processing.
    public let originalImage: UIImage
    /// Perspective-corrected image (flat, rectangular).
    public let correctedImage: UIImage
    /// Post-enhancement image (grayscale or black-and-white).
    public let enhancedImage: UIImage
    /// The document quad used for perspective correction (Vision normalized coords).
    public let detectedQuad: Quad
    public let capturedAt: Date

    init(
        originalImage: UIImage,
        correctedImage: UIImage,
        enhancedImage: UIImage,
        detectedQuad: Quad
    ) {
        self.id = UUID()
        self.originalImage = originalImage
        self.correctedImage = correctedImage
        self.enhancedImage = enhancedImage
        self.detectedQuad = detectedQuad
        self.capturedAt = Date()
    }

    // MARK: - Export

    public func exportAsPDF(pageSize: DocumentScannerConfiguration.PageSize = .a4) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try PDFExporter().exportSingle(self.enhancedImage, pageSize: pageSize)
        }.value
    }
}
