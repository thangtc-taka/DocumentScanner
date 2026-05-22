import Foundation

public enum DocumentScannerError: Error, Sendable {
    case cameraPermissionDenied
    case cameraUnavailable
    case captureFailure(underlying: any Error)
    case detectionFailed
    case enhancementFailed
    case pdfExportFailed
    case metalUnavailable
}
