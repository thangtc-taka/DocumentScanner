import Metal
import CoreImage

/// Shared Metal device and command queue. Initialized once at first use.
final class MetalContext: @unchecked Sendable {

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary
    let adaptiveThresholdPipeline: MTLComputePipelineState

    // CIContext backed by the same MTLDevice to avoid GPU round-trips.
    let ciContext: CIContext

    static let shared: MetalContext? = try? MetalContext()

    private init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw DocumentScannerError.metalUnavailable
        }
        guard let queue = device.makeCommandQueue() else {
            throw DocumentScannerError.metalUnavailable
        }
        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.module) else {
            throw DocumentScannerError.metalUnavailable
        }
        guard let fn = library.makeFunction(name: "adaptiveThreshold"),
              let pipeline = try? device.makeComputePipelineState(function: fn) else {
            throw DocumentScannerError.metalUnavailable
        }

        self.device = device
        self.commandQueue = queue
        self.library = library
        self.adaptiveThresholdPipeline = pipeline
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull()])
    }
}
