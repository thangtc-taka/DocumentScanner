import AVFoundation

/// Bridges AVCaptureVideoDataOutput delegate callbacks into an AsyncStream.
final class FramePublisher: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let continuation: AsyncStream<CMSampleBuffer>.Continuation

    init(continuation: AsyncStream<CMSampleBuffer>.Continuation) {
        self.continuation = continuation
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        continuation.yield(sampleBuffer)
    }
}
