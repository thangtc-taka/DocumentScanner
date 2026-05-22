import Foundation
import UIKit
import DocumentScanner

@MainActor
final class ResultViewModel: ObservableObject {
    @Published var result: ScanResult
    @Published var isExporting = false
    @Published var showShareSheet = false
    @Published var exportedPDFURL: URL?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var selectedImageMode: ImageMode = .enhanced
    @Published var showPDFPreview = false

    enum ImageMode: String, CaseIterable {
        case enhanced  = "Enhanced"
        case corrected = "Corrected"
        case original  = "Original"
    }

    init(result: ScanResult) {
        self.result = result
    }

    // MARK: - Image display

    var displayedImage: UIImage {
        switch selectedImageMode {
        case .enhanced:  return result.enhancedImage
        case .corrected: return result.correctedImage
        case .original:  return result.originalImage
        }
    }

    // MARK: - Export

    func exportPDF() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let pdfData = try await result.scannedDocument.exportAsPDF(pageSize: .a4)
            result.pdfData = pdfData

            // Write to temp file for sharing
            let fileName = "scan_\(result.id.uuidString.prefix(8)).pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try pdfData.write(to: url)

            exportedPDFURL = url
            showPDFPreview = true
        } catch {
            errorMessage = "PDF export failed: \(error.localizedDescription)"
            showError = true
        }
    }

    func shareDocument() async {
        if exportedPDFURL == nil {
            await exportPDF()
        }
        if exportedPDFURL != nil {
            showShareSheet = true
        }
    }

    // MARK: - Save to Files

    func saveToFiles() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let pdfData: Data
            if let existing = result.pdfData {
                pdfData = existing
            } else {
                pdfData = try await result.scannedDocument.exportAsPDF(pageSize: .a4)
                result.pdfData = pdfData
            }

            let fileName = "DocumentScan_\(formatDate(result.capturedAt)).pdf"
            let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dest = docsURL.appendingPathComponent(fileName)
            try pdfData.write(to: dest)

            errorMessage = "Saved to Files: \(fileName)"
            showError = true  // reuse as success toast
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: date)
    }
}
