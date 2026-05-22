import Testing
import CoreGraphics
import UIKit
@testable import DocumentScanner

// MARK: - Quad Tests

@Suite("Quad")
struct QuadTests {

    let unit = Quad(
        topLeft:     CGPoint(x: 0.1, y: 0.9),
        topRight:    CGPoint(x: 0.9, y: 0.9),
        bottomRight: CGPoint(x: 0.9, y: 0.1),
        bottomLeft:  CGPoint(x: 0.1, y: 0.1)
    )

    @Test("UIKit coordinate conversion flips y-axis")
    func uiKitConversion() {
        let size = CGSize(width: 100, height: 200)
        let converted = unit.toUIKitCoordinates(in: size)
        // topLeft.y in Vision = 0.9 → UIKit y = (1 - 0.9) * 200 = 20
        #expect(abs(converted.topLeft.y - 20) < 0.001)
        // topLeft.x in Vision = 0.1 → UIKit x = 0.1 * 100 = 10
        #expect(abs(converted.topLeft.x - 10) < 0.001)
    }

    @Test("Interpolation at factor 0.5 produces midpoint")
    func interpolationMidpoint() {
        let other = Quad(
            topLeft:     CGPoint(x: 0.5, y: 0.5),
            topRight:    CGPoint(x: 0.5, y: 0.5),
            bottomRight: CGPoint(x: 0.5, y: 0.5),
            bottomLeft:  CGPoint(x: 0.5, y: 0.5)
        )
        let mid = unit.interpolated(towards: other, by: 0.5)
        #expect(abs(mid.topLeft.x - 0.3) < 0.001)
    }

    @Test("Distance to self is zero")
    func distanceToSelf() {
        #expect(unit.distance(to: unit) < 0.0001)
    }

    @Test("Distance to shifted quad is non-zero")
    func distanceToOther() {
        let shifted = Quad(
            topLeft:     CGPoint(x: 0.2, y: 0.9),
            topRight:    CGPoint(x: 0.9, y: 0.9),
            bottomRight: CGPoint(x: 0.9, y: 0.1),
            bottomLeft:  CGPoint(x: 0.2, y: 0.1)
        )
        #expect(unit.distance(to: shifted) > 0)
    }

    @Test("Path bounding box is non-zero")
    func pathConstruction() {
        let path = unit.path(in: CGSize(width: 200, height: 200))
        #expect(path.boundingBox.width > 0)
        #expect(path.boundingBox.height > 0)
    }
}

// MARK: - DetectionSmoother Tests

@Suite("DetectionSmoother")
struct DetectionSmootherTests {

    let quad = Quad(
        topLeft:     CGPoint(x: 0.1, y: 0.9),
        topRight:    CGPoint(x: 0.9, y: 0.9),
        bottomRight: CGPoint(x: 0.9, y: 0.1),
        bottomLeft:  CGPoint(x: 0.1, y: 0.1)
    )

    @Test("Nil input returns nil smoothed quad")
    func nilInputReturnsNil() async {
        let smoother = DetectionSmoother(bufferSize: 3)
        let (smoothed, stable) = await smoother.process(nil)
        #expect(smoothed == nil)
        #expect(!stable)
    }

    @Test("Fills buffer and becomes stable")
    func stabilityAfterBufferFill() async {
        let smoother = DetectionSmoother(bufferSize: 3)
        var stable = false
        for _ in 0..<3 {
            let result = await smoother.process(quad)
            stable = result.isStable
        }
        #expect(stable)
    }

    @Test("Large jump resets history — not stable")
    func largeJumpResetsHistory() async {
        let smoother = DetectionSmoother(bufferSize: 3)
        for _ in 0..<3 { _ = await smoother.process(quad) }

        let farQuad = Quad(
            topLeft:     CGPoint(x: 0.8, y: 0.2),
            topRight:    CGPoint(x: 0.9, y: 0.2),
            bottomRight: CGPoint(x: 0.9, y: 0.1),
            bottomLeft:  CGPoint(x: 0.8, y: 0.1)
        )
        let (_, stable) = await smoother.process(farQuad)
        #expect(!stable)
    }

    @Test("Smoothed output is non-nil for valid input")
    func smoothedNotNil() async {
        let smoother = DetectionSmoother(bufferSize: 2)
        let (smoothed, _) = await smoother.process(quad)
        #expect(smoothed != nil)
    }
}

// MARK: - PDFExporter Tests

@Suite("PDFExporter")
struct PDFExporterTests {

    @Test("Single page export produces non-empty data")
    func exportSingleProducesData() throws {
        let image = makeTestImage()
        let data = try PDFExporter().exportSingle(image, pageSize: .a4)
        #expect(!data.isEmpty)
    }

    @Test("Multi-page export is larger than single page")
    func multiPageLargerThanSingle() throws {
        let image = makeTestImage()
        let single = try PDFExporter().export(pages: [image], pageSize: .a4)
        let multi  = try PDFExporter().export(pages: [image, image, image], pageSize: .a4)
        #expect(multi.count > single.count)
    }

    @Test("PDF data starts with %PDF header")
    func pdfHeader() throws {
        let data = try PDFExporter().exportSingle(makeTestImage(), pageSize: .a4)
        let header = String(data: data.prefix(4), encoding: .ascii)
        #expect(header == "%PDF")
    }

    private func makeTestImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 100, height: 140)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 140))
        }
    }
}

// MARK: - DocumentScannerConfiguration Tests

@Suite("DocumentScannerConfiguration")
struct ConfigurationTests {

    @Test("Default smoothing buffer size is 5")
    func defaultBufferSize() {
        #expect(DocumentScannerConfiguration.default.smoothingBufferSize == 5)
    }

    @Test("A4 page size has correct dimensions")
    func a4Dimensions() {
        let size = DocumentScannerConfiguration.PageSize.a4.cgSize
        #expect(abs(size.width - 595) < 1)
        #expect(abs(size.height - 842) < 1)
    }

    @Test("Letter page size has correct dimensions")
    func letterDimensions() {
        let size = DocumentScannerConfiguration.PageSize.letter.cgSize
        #expect(abs(size.width - 612) < 1)
        #expect(abs(size.height - 792) < 1)
    }

    @Test("Custom page size is preserved")
    func customPageSize() {
        let custom = CGSize(width: 400, height: 600)
        let size = DocumentScannerConfiguration.PageSize.custom(custom).cgSize
        #expect(size == custom)
    }
}
