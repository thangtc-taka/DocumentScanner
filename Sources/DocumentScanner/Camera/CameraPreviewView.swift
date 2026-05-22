import SwiftUI
import AVFoundation

/// A SwiftUI view that renders the live camera preview.
/// Embed inside a ZStack to layer overlays on top.
public struct CameraPreviewView: UIViewRepresentable {
    public let previewLayer: AVCaptureVideoPreviewLayer
    public var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    public init(previewLayer: AVCaptureVideoPreviewLayer, videoGravity: AVLayerVideoGravity = .resizeAspectFill) {
        self.previewLayer = previewLayer
        self.videoGravity = videoGravity
    }

    public func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        previewLayer.videoGravity = videoGravity
        view.attach(previewLayer)
        return view
    }

    public func updateUIView(_ uiView: PreviewUIView, context: Context) {
        previewLayer.videoGravity = videoGravity
        if uiView.captureLayer !== previewLayer {
            uiView.attach(previewLayer)
        }
    }
}

// MARK: - PreviewUIView

/// A plain UIView that hosts the CameraSession's AVCaptureVideoPreviewLayer directly
/// as a sublayer, so the session binding is always live without any session copying.
public final class PreviewUIView: UIView {
    public private(set) var captureLayer: AVCaptureVideoPreviewLayer?

    public func attach(_ layer: AVCaptureVideoPreviewLayer) {
        captureLayer?.removeFromSuperlayer()
        layer.frame = bounds
        self.layer.addSublayer(layer)
        captureLayer = layer
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        captureLayer?.frame = bounds
    }
}
