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
        view.previewLayer.session = previewLayer.session
        view.previewLayer.videoGravity = videoGravity
        return view
    }

    public func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.videoGravity = videoGravity
    }
}

// MARK: - PreviewUIView

public final class PreviewUIView: UIView {
    public override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    public var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
