import UIKit

/// Converts UIImages to PDF data using UIGraphicsPDFRenderer.
/// Stateless — safe to call from any concurrency context.
struct PDFExporter {

    func exportSingle(_ image: UIImage, pageSize: DocumentScannerConfiguration.PageSize) throws -> Data {
        try export(pages: [image], pageSize: pageSize)
    }

    func export(pages: [UIImage], pageSize: DocumentScannerConfiguration.PageSize) throws -> Data {
        let pageRect = CGRect(origin: .zero, size: pageSize.cgSize)
        let pageAspectRatio = pageSize.cgSize.width / pageSize.cgSize.height
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            for image in pages {
                context.beginPage()

                // Rotate image if landscape but page is portrait (or vice versa)
                let imageToUse = orientImageToMatch(image, pageAspectRatio: pageAspectRatio)

                // Fit image inside page preserving aspect ratio
                let imageRect = AVMakeRect(aspectRatio: imageToUse.size, insideRect: pageRect)
                imageToUse.draw(in: imageRect)
            }
        }

        guard !data.isEmpty else { throw DocumentScannerError.pdfExportFailed }
        return data
    }

    /// Rotate image to match page orientation (portrait page gets portrait image, landscape gets landscape).
    private func orientImageToMatch(_ image: UIImage, pageAspectRatio: CGFloat) -> UIImage {
        let imageAspectRatio = image.size.width / image.size.height
        let isPagePortrait = pageAspectRatio < 1
        let isImagePortrait = imageAspectRatio < 1

        // No rotation needed
        if isPagePortrait == isImagePortrait { return image }

        // Rotate image 90 degrees clockwise
        guard let cgImage = image.cgImage else { return image }
        let rotatedSize = CGSize(width: image.size.height, height: image.size.width)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(rotatedSize.width),
            height: Int(rotatedSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return image }

        context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        context.rotate(by: .pi / 2)
        context.draw(cgImage, in: CGRect(x: -image.size.height / 2, y: -image.size.width / 2, width: image.size.height, height: image.size.width))

        guard let rotatedCGImage = context.makeImage() else { return image }
        return UIImage(cgImage: rotatedCGImage, scale: image.scale, orientation: .up)
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
