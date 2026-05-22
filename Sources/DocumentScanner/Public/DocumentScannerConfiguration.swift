import CoreGraphics

public struct DocumentScannerConfiguration: Sendable {

    // MARK: - Detection

    /// Minimum fraction of the frame area that the document must occupy (0.0–1.0).
    public var minimumDocumentSize: CGFloat = 0.15

    /// Number of consecutive frames averaged for temporal smoothing.
    public var smoothingBufferSize: Int = 5

    // MARK: - Capture

    /// JPEG quality for the high-resolution still capture (0.0–1.0).
    public var capturePhotoQuality: Float = 1.0

    // MARK: - Enhancement

    public enum EnhancementMode: Sendable {
        /// No post-processing — raw perspective-corrected image.
        case none
        /// Convert to grayscale with luminance stretch.
        case grayscale
        /// GPU adaptive threshold → crisp black-and-white scan.
        case blackAndWhite
    }

    public var enhancementMode: EnhancementMode = .blackAndWhite

    // MARK: - PDF export

    public enum PageSize: Sendable {
        case a4
        case letter
        case custom(CGSize)

        var cgSize: CGSize {
            switch self {
            case .a4:     return CGSize(width: 595, height: 842)   // 72 dpi points
            case .letter: return CGSize(width: 612, height: 792)
            case .custom(let s): return s
            }
        }
    }

    public var pageSize: PageSize = .a4

    // MARK: - Metal adaptive threshold tuning

    /// Neighbourhood radius for the adaptive threshold kernel (pixels).
    public var adaptiveThresholdBlockRadius: Float = 15

    /// Offset applied to local mean before comparison (negative = more black).
    public var adaptiveThresholdOffset: Float = -0.05

    // MARK: - Defaults

    public static let `default` = DocumentScannerConfiguration()

    public init() {}
}
