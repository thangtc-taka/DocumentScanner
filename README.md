# DocumentScanner

A modern, customizable document scanning Swift Package for iOS 16+ built with Apple's native frameworks. No dependencies. No compromises.

<div align="center">

[![iOS](https://img.shields.io/badge/iOS-16.0%2B-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)](https://www.swift.org/)
[![SPM](https://img.shields.io/badge/SPM-compatible-green)](https://swift.org/package-manager/)

</div>

## Features

✨ **Modern Architecture**
- ML-based document detection via `VNDetectDocumentSegmentationRequest` (iOS 16+)
- Automatic Neural Engine dispatch on A12+ devices
- Swift Concurrency (`actor` + `async`/`await`)
- Type-safe, compiler-enforced thread safety

⚡ **High Performance**
- GPU-accelerated image enhancement via custom Metal compute shader
- 10–50x faster than CPU-based thresholding
- Real-time 30+ FPS live detection
- Smooth 60 FPS SwiftUI preview with zero UI jank

🎨 **Fully Customizable**
- SwiftUI integration with custom overlay support
- Your own shutter button, flash control, guides, and animations
- Complete control over capture flow and output formats
- Not like `VNDocumentCameraViewController` (black box)

🏗️ **Production Ready**
- Comprehensive unit tests (16 tests, all passing)
- Clean layer separation (Camera → Detection → Enhancement → Export)
- Comprehensive error handling
- Full PDFKit integration (single/multi-page export)

## Why DocumentScanner?

`VNDocumentCameraViewController` works out-of-the-box, but it's **completely non-customizable**. If you want:
- Custom UI overlays
- Branded shutter button
- Haptic feedback on document lock
- Integration with your own document management
- Batch scanning with auto-progression

...you need DocumentScanner.

## Requirements

- **iOS 16.0+** (for `VNDetectDocumentSegmentationRequest`)
- **Xcode 14.0+** (for Swift 5.9 and SwiftUI 4)
- **Swift 5.9+**

No third-party dependencies. Uses only Apple frameworks:
- `AVFoundation`
- `Vision`
- `Core Image`
- `Metal` (optional, for GPU acceleration)
- `SwiftUI`
- `Combine`
- `PDFKit` (optional, for PDF export)

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/caothang/DocumentScanner.git", from: "1.0.0")
]
```

Or via Xcode:
1. File → Add Packages
2. Paste: `https://github.com/caothang/DocumentScanner.git`
3. Version: 1.0.0 or later
4. Add to your target

## Quick Start

```swift
import SwiftUI
import DocumentScanner

struct ContentView: View {
    @State private var scannedDocuments: [ScannedDocument] = []
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(scannedDocuments) { doc in
                    DocumentCell(document: doc)
                }
                .onDelete { indices in
                    scannedDocuments.removeAll { i in indices.contains(scannedDocuments.firstIndex(of: $0)!) }
                }
            }
            .navigationTitle("Scanned Docs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Scan") { showScanner = true }
                }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerView { doc in
                    scannedDocuments.append(doc)
                    showScanner = false
                }
            }
        }
    }
}

struct DocumentCell: View {
    let document: ScannedDocument

    var body: some View {
        VStack(alignment: .leading) {
            Image(uiImage: document.enhancedImage)
                .resizable()
                .scaledToFit()
                .frame(height: 200)
            
            Button("Export PDF") {
                Task {
                    let pdf = try? await document.exportAsPDF(pageSize: .a4)
                    // Share or save pdf
                }
            }
        }
    }
}
```

**That's it!** The scanner handles everything: camera setup, document detection, perspective correction, image enhancement, PDF export.

## Documentation

- **[HowToUse.md](HowToUse.md)** — Detailed guide with advanced examples
- **[DocumentScanner_Principles.md](DocumentScanner_Principles.md)** — Technical architecture & design decisions

## Architecture

### Data Flow

```
User opens DocumentScannerView
    ↓
CameraSession starts (AVCaptureSession on background actor)
    ↓
Live video frames → AsyncStream<CMSampleBuffer> (auto back-pressure)
    ↓
DocumentDetector (VNDetectDocumentSegmentationRequest, Neural Engine)
    ↓
DetectionSmoother (temporal smoothing, stability detection)
    ↓
@Published detectedQuad & isDocumentStable → SwiftUI re-render
    ↓
User taps "Capture"
    ↓
CameraSession.captureHighResPhoto() → UIImage (full resolution)
    ↓
Re-detect on full-res + PerspectiveCorrector (CIPerspectiveCorrection)
    ↓
ImageEnhancer (Metal GPU or grayscale)
    ↓
ScannedDocument (original, corrected, enhanced images + quad)
    ↓
Optional: exportAsPDF() → Data
```

### Layer Structure

| Layer | Responsibility | Actor? |
|-------|-----------------|--------|
| **Camera** | AVCaptureSession, frame streaming, photo capture | ✅ `CameraSession` |
| **Detection** | Vision ML request, document boundary extraction | ✅ `DocumentDetector` |
| **Smoothing** | Temporal filtering, stability signal | ✅ `DetectionSmoother` |
| **Processing** | Perspective flattening, GPU enhancement | ❌ (stateless) |
| **Controller** | Orchestration, @Published updates | ✅ `@MainActor` |
| **UI** | SwiftUI view, preview, overlays | N/A |

## Key Types

### `DocumentScannerView`

The main entry point. A SwiftUI view that handles everything.

```swift
DocumentScannerView(
    configuration: DocumentScannerConfiguration(
        enhancementMode: .blackAndWhite,
        pageSize: .a4
    ),
    onCapture: { document in
        // Handle the scanned document
    },
    overlay: { controller in
        // Custom UI: buttons, guides, etc.
        VStack {
            Spacer()
            Button("Scan") {
                Task {
                    let doc = try? await controller.captureDocument()
                }
            }
        }
    }
)
```

### `DocumentScannerController`

Access to underlying logic. Use this for custom layouts.

```swift
@MainActor
let controller = try await DocumentScannerController(configuration: config)

// Observable properties
@Published var detectedQuad: Quad?       // Real-time quad (normalized coords)
@Published var isDocumentStable: Bool    // Stability signal
@Published var captureState: CaptureState
@Published var scannedDocuments: [ScannedDocument]

// Methods
try await controller.startSession()
try await controller.stopSession()
let doc = try await controller.captureDocument()
try await controller.removeDocument(id: uuid)
let pdf = try await controller.exportAllAsPDF()
```

### `ScannedDocument`

The result of a capture.

```swift
public struct ScannedDocument: Sendable, Identifiable {
    let id: UUID
    let originalImage: UIImage          // Raw full-resolution capture
    let correctedImage: UIImage         // Perspective-corrected, no enhancement
    let enhancedImage: UIImage          // Final output (b&w or grayscale)
    let detectedQuad: Quad              // Document boundary (normalized coords)
    let capturedAt: Date
    
    func exportAsPDF(pageSize: DocumentScannerConfiguration.PageSize) async throws -> Data
}
```

### `DocumentScannerConfiguration`

Tunable parameters.

```swift
var configuration = DocumentScannerConfiguration()
configuration.enhancementMode = .blackAndWhite              // .none, .grayscale, .blackAndWhite
configuration.pageSize = .a4                               // .a4, .letter, .custom(size)
configuration.smoothingBufferSize = 5                      // Frames to average (1-10)
configuration.capturePhotoQuality = 1.0                    // 0.0-1.0 JPEG quality
configuration.adaptiveThresholdBlockRadius = 15            // Pixel neighborhood size
configuration.adaptiveThresholdOffset = -0.05              // Threshold adjustment
```

### `Quad`

Document boundary in normalized Vision coordinates (origin bottom-left, 0.0–1.0 range).

```swift
public struct Quad: Sendable, Equatable {
    let topLeft, topRight, bottomRight, bottomLeft: CGPoint
    
    func toUIKitCoordinates(in size: CGSize) -> Quad
    func path(in size: CGSize) -> CGPath                    // For rendering overlay
    func distance(to other: Quad) -> CGFloat
    func interpolated(towards other: Quad, by factor: CGFloat) -> Quad
}
```

## Performance

- **Detection latency:** ~50 ms per frame (ML inference via Neural Engine)
- **GPU enhancement:** ~20 ms for 2–5 MP image
- **Full pipeline (capture to PDF):** ~500 ms
- **Frame dropping:** Automatic via AsyncStream back-pressure (no stalls)
- **UI FPS:** Constant 60 FPS (all heavy work off main thread)

Tested on:
- iPhone 16e (A18 Pro)
- iPhone 17 (A19)
- iPhone 11 Pro (A13 Bionic)

## Error Handling

```swift
do {
    let doc = try await controller.captureDocument()
} catch DocumentScannerError.cameraPermissionDenied {
    print("User denied camera access")
} catch DocumentScannerError.captureFailure(let underlying) {
    print("Capture failed: \(underlying)")
} catch DocumentScannerError.metalUnavailable {
    print("GPU enhancement unavailable (simulator?), fallback to CPU")
} catch {
    print("Unknown error: \(error)")
}
```

## License

MIT License. See [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please:
1. Fork the repo
2. Create a feature branch
3. Add tests for new functionality
4. Submit a PR

## Roadmap

- [ ] Batch scanning with auto-progression
- [ ] Document history / database integration
- [ ] OCR support (via Vision Kit)
- [ ] Multi-document page merging
- [ ] Custom ML model support (Core ML)
- [ ] Dark mode UI templates
- [ ] Localization (i18n)

## Support

Found a bug? Have a question? Open an issue on [GitHub](https://github.com/caothang/DocumentScanner/issues).

---

**Made with ❤️ for iOS developers who want control.**
