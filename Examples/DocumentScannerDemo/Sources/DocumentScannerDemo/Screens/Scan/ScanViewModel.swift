import Foundation
import DocumentScanner

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var captureState: CapturePhase = .idle
    @Published var errorMessage: String?
    @Published var showError = false

    enum CapturePhase {
        case idle
        case capturing
        case processing
        case done
    }

    // MARK: - Capture

    func capture(using controller: DocumentScannerController) async -> ScanResult? {
        guard captureState == .idle else { return nil }

        captureState = .capturing
        defer { if captureState != .done { captureState = .idle } }

        do {
            captureState = .processing
            let document = try await controller.captureDocument()
            captureState = .done
            return ScanResult(document: document)
        } catch DocumentScannerError.cameraPermissionDenied {
            showError(message: "Camera permission denied.")
        } catch DocumentScannerError.captureFailure(let underlying) {
            showError(message: "Capture failed: \(underlying.localizedDescription)")
        } catch DocumentScannerError.detectionFailed {
            showError(message: "Could not detect document. Reposition and try again.")
        } catch {
            showError(message: "Unexpected error: \(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - Helpers

    private func showError(message: String) {
        captureState = .idle
        errorMessage = message
        showError = true
    }
}
