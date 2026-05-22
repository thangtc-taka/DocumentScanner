import UIKit

/// Converts UIImages to PDF data using UIGraphicsPDFRenderer.
/// Stateless — safe to call from any concurrency context.
struct PDFExporter {

    func exportSingle(_ image: UIImage, pageSize: DocumentScannerConfiguration.PageSize) throws -> Data {
        try export(pages: [image], pageSize: pageSize)
    }

    func export(pages: [UIImage], pageSize: DocumentScannerConfiguration.PageSize) throws -> Data {
        let pageRect = CGRect(origin: .zero, size: pageSize.cgSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            for image in pages {
                context.beginPage()
                // Fit image inside page preserving aspect ratio
                let imageRect = AVMakeRect(aspectRatio: image.size, insideRect: pageRect)
                image.draw(in: imageRect)
            }
        }

        guard !data.isEmpty else { throw DocumentScannerError.pdfExportFailed }
        return data
    }
}

// MARK: - AVFoundation-free aspect ratio helper

private func AVMakeRect(aspectRatio: CGSize, insideRect: CGRect) -> CGRect {
    let targetRatio = aspectRatio.width / aspectRatio.height
    let containerRatio = insideRect.width / insideRect.height

    let fittedWidth: CGFloat
    let fittedHeight: CGFloat
    if targetRatio > containerRatio {
        fittedWidth = insideRect.width
        fittedHeight = insideRect.width / targetRatio
    } else {
        fittedHeight = insideRect.height
        fittedWidth = insideRect.height * targetRatio
    }

    return CGRect(
        x: insideRect.midX - fittedWidth / 2,
        y: insideRect.midY - fittedHeight / 2,
        width: fittedWidth,
        height: fittedHeight
    )
}
