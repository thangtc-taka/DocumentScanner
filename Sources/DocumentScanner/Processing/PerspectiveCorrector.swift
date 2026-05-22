import CoreImage

/// Applies CIPerspectiveCorrection to flatten a skewed document quadrilateral.
/// Stateless — safe to call from any concurrency context.
struct PerspectiveCorrector {

    /// - Parameters:
    ///   - image: The source CIImage in Core Image coordinates (origin bottom-left).
    ///   - quad:  Quad with normalized Vision coordinates (origin bottom-left, 0.0–1.0).
    /// - Returns: A perspective-corrected CIImage. Not yet rendered to a bitmap.
    func correct(image: CIImage, quad: Quad) throws -> CIImage {
        let extent = image.extent

        // Vision and Core Image share the same coordinate origin (bottom-left),
        // so only scale normalization is needed — no y-flip.
        func toImagePoint(_ p: CGPoint) -> CIVector {
            CIVector(x: p.x * extent.width, y: p.y * extent.height)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            throw DocumentScannerError.enhancementFailed
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(toImagePoint(quad.topLeft),     forKey: "inputTopLeft")
        filter.setValue(toImagePoint(quad.topRight),    forKey: "inputTopRight")
        filter.setValue(toImagePoint(quad.bottomRight), forKey: "inputBottomRight")
        filter.setValue(toImagePoint(quad.bottomLeft),  forKey: "inputBottomLeft")

        guard let output = filter.outputImage else {
            throw DocumentScannerError.enhancementFailed
        }
        return output
    }
}
