import SwiftUI
import AVFoundation

/// A ready-to-use SwiftUI document scanner view.
/// Layer custom UI on top via the `overlay` parameter.
///
/// **Minimal usage:**
/// ```swift
/// DocumentScannerView { doc in
///     // handle ScannedDocument
/// }
/// ```
///
/// **Custom overlay:**
/// ```swift
/// DocumentScannerView { doc in
///     saveToDisk(doc)
/// } overlay: { controller in
///     VStack {
///         Spacer()
///         Button("Scan") { Task { try? await controller.captureDocument() } }
///             .padding()
///     }
/// }
/// ```
public struct DocumentScannerView<Overlay: View>: View {

    @StateObject private var controller: DocumentScannerController
    private let onCapture: @Sendable (ScannedDocument) -> Void
    private let overlay: (DocumentScannerController) -> Overlay

    public init(
        configuration: DocumentScannerConfiguration = .default,
        onCapture: @escaping @Sendable (ScannedDocument) -> Void,
        @ViewBuilder overlay: @escaping (DocumentScannerController) -> Overlay
    ) {
        _controller = StateObject(wrappedValue: (try? DocumentScannerController(configuration: configuration)) ?? DocumentScannerController._fallback)
        self.onCapture = onCapture
        self.overlay = overlay
    }

    public var body: some View {
        ScannerBodyView(controller: controller, onCapture: onCapture, overlay: overlay)
    }
}

// Convenience init without overlay
public extension DocumentScannerView where Overlay == EmptyView {
    init(
        configuration: DocumentScannerConfiguration = .default,
        onCapture: @escaping @Sendable (ScannedDocument) -> Void
    ) {
        self.init(configuration: configuration, onCapture: onCapture) { _ in EmptyView() }
    }
}

// MARK: - Body

private struct ScannerBodyView<Overlay: View>: View {
    @ObservedObject var controller: DocumentScannerController
    let onCapture: @Sendable (ScannedDocument) -> Void
    let overlay: (DocumentScannerController) -> Overlay

    @State private var previewLayer: AVCaptureVideoPreviewLayer?

    var body: some View {
        ZStack {
            if let layer = previewLayer {
                CameraPreviewView(previewLayer: layer)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            // Quad overlay
            if let quad = controller.detectedQuad {
                QuadOverlayShape(quad: quad)
                    .stroke(controller.isDocumentStable ? Color.green : Color.blue, lineWidth: 2)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.2), value: controller.isDocumentStable)
            }

            overlay(controller)
        }
        .task {
            previewLayer = await controller.previewLayer
            try? await controller.startSession()
        }
        .onDisappear {
            Task { await controller.stopSession() }
        }
        .onChange(of: controller.scannedDocuments.count) { _ in
            if let last = controller.scannedDocuments.last {
                onCapture(last)
            }
        }
    }
}

// MARK: - Quad overlay shape

private struct QuadOverlayShape: Shape {
    let quad: Quad

    func path(in rect: CGRect) -> Path {
        Path(quad.path(in: rect.size))
    }
}

// MARK: - Fallback controller (if init throws)

extension DocumentScannerController {
    fileprivate static var _fallback: DocumentScannerController {
        (try? DocumentScannerController()) ?? {
            fatalError("DocumentScannerController: cannot initialize camera session")
        }()
    }
}
