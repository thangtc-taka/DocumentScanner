import UIKit
import CoreImage
import Metal

/// Applies image enhancement to a perspective-corrected CIImage.
/// Uses a fused Metal pipeline for .blackAndWhite (GPU, no intermediate copies).
actor ImageEnhancer {

    private let configuration: DocumentScannerConfiguration

    init(configuration: DocumentScannerConfiguration) {
        self.configuration = configuration
    }

    func enhance(_ ciImage: CIImage, mode: DocumentScannerConfiguration.EnhancementMode) throws -> UIImage {
        switch mode {
        case .none:
            return try renderToUIImage(ciImage)

        case .grayscale:
            let gray = try applyGrayscale(ciImage)
            return try renderToUIImage(gray)

        case .blackAndWhite:
            if let metal = MetalContext.shared {
                return try metalAdaptiveThreshold(ciImage, context: metal)
            }
            // CPU fallback: grayscale + strong contrast
            let gray = try applyGrayscale(ciImage)
            return try renderToUIImage(gray)
        }
    }

    // MARK: - Grayscale (Core Image)

    private func applyGrayscale(_ image: CIImage) throws -> CIImage {
        // Remove chroma
        guard let satFilter = CIFilter(name: "CIColorControls") else {
            throw DocumentScannerError.enhancementFailed
        }
        satFilter.setValue(image, forKey: kCIInputImageKey)
        satFilter.setValue(0.0, forKey: kCIInputSaturationKey)
        satFilter.setValue(1.05, forKey: kCIInputContrastKey)

        guard let desaturated = satFilter.outputImage else {
            throw DocumentScannerError.enhancementFailed
        }

        // Luminance stretch: white → pure white, black → pure black
        guard let stretch = CIFilter(name: "CIColorMatrix") else {
            return desaturated
        }
        stretch.setValue(desaturated, forKey: kCIInputImageKey)
        stretch.setValue(CIVector(x: 1.1, y: 0, z: 0, w: 0), forKey: "inputRVector")
        stretch.setValue(CIVector(x: 0, y: 1.1, z: 0, w: 0), forKey: "inputGVector")
        stretch.setValue(CIVector(x: 0, y: 0, z: 1.1, w: 0), forKey: "inputBVector")
        stretch.setValue(CIVector(x: 0, y: 0, z: 0, w: 1),   forKey: "inputAVector")
        stretch.setValue(CIVector(x: -0.05, y: -0.05, z: -0.05, w: 0), forKey: "inputBiasVector")
        return stretch.outputImage ?? desaturated
    }

    // MARK: - Black & White via Metal

    private func metalAdaptiveThreshold(_ ciImage: CIImage, context: MetalContext) throws -> UIImage {
        let extent = ciImage.extent

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(extent.width),
            height: Int(extent.height),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let inTexture = context.device.makeTexture(descriptor: descriptor),
              let outTexture = context.device.makeTexture(descriptor: descriptor) else {
            throw DocumentScannerError.metalUnavailable
        }

        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw DocumentScannerError.metalUnavailable
        }

        // Step 1: Render CIImage → MTLTexture (grayscale colorspace)
        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        context.ciContext.render(
            ciImage,
            to: inTexture,
            commandBuffer: commandBuffer,
            bounds: extent,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        // Step 2: Dispatch adaptive threshold kernel
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw DocumentScannerError.metalUnavailable
        }
        encoder.setComputePipelineState(context.adaptiveThresholdPipeline)
        encoder.setTexture(inTexture,  index: 0)
        encoder.setTexture(outTexture, index: 1)

        var radius = configuration.adaptiveThresholdBlockRadius
        var offset = configuration.adaptiveThresholdOffset
        encoder.setBytes(&radius, length: MemoryLayout<Float>.size, index: 0)
        encoder.setBytes(&offset, length: MemoryLayout<Float>.size, index: 1)

        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width:  (Int(extent.width)  + 15) / 16,
            height: (Int(extent.height) + 15) / 16,
            depth:  1
        )
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Step 3: MTLTexture → CIImage → UIImage
        let resultCI = CIImage(mtlTexture: outTexture, options: nil)!
        guard let cgImage = context.ciContext.createCGImage(resultCI, from: resultCI.extent) else {
            throw DocumentScannerError.enhancementFailed
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Helpers

    private func renderToUIImage(_ ciImage: CIImage) throws -> UIImage {
        let ctx: CIContext
        if let metal = MetalContext.shared {
            ctx = metal.ciContext
        } else {
            ctx = CIContext()
        }
        guard let cgImage = ctx.createCGImage(ciImage, from: ciImage.extent) else {
            throw DocumentScannerError.enhancementFailed
        }
        return UIImage(cgImage: cgImage)
    }
}
