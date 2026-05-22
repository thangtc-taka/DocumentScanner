import Foundation
import UIKit
import DocumentScanner

/// Wrapper model representing a completed scan with optional PDF data.
/// Used as the navigation payload between Scan → Result screens.
struct ScanResult: Identifiable, Sendable {
    let id: UUID
    let scannedDocument: ScannedDocument
    var pdfData: Data?
    let capturedAt: Date

    init(document: ScannedDocument) {
        self.id = document.id
        self.scannedDocument = document
        self.pdfData = nil
        self.capturedAt = document.capturedAt
    }

    var enhancedImage: UIImage { scannedDocument.enhancedImage }
    var correctedImage: UIImage { scannedDocument.correctedImage }
    var originalImage: UIImage { scannedDocument.originalImage }
}
