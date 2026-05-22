import CoreGraphics
import Vision

/// A quadrilateral representing a detected document boundary.
/// All coordinates are normalized (0.0–1.0) in Vision coordinate space
/// (origin at bottom-left).
public struct Quad: Sendable, Equatable {
    public let topLeft: CGPoint
    public let topRight: CGPoint
    public let bottomRight: CGPoint
    public let bottomLeft: CGPoint

    public init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    // MARK: - Vision initializer

    init(observation: VNRectangleObservation) {
        self.topLeft = observation.topLeft
        self.topRight = observation.topRight
        self.bottomRight = observation.bottomRight
        self.bottomLeft = observation.bottomLeft
    }

    // MARK: - Coordinate conversion

    /// Converts from Vision coords (origin bottom-left) to UIKit coords (origin top-left).
    public func toUIKitCoordinates(in size: CGSize) -> Quad {
        func flip(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x * size.width, y: (1.0 - p.y) * size.height)
        }
        return Quad(
            topLeft: flip(topLeft),
            topRight: flip(topRight),
            bottomRight: flip(bottomRight),
            bottomLeft: flip(bottomLeft)
        )
    }

    // MARK: - Geometry

    /// Builds a closed CGPath for rendering as an overlay.
    public func path(in size: CGSize) -> CGPath {
        let q = toUIKitCoordinates(in: size)
        let path = CGMutablePath()
        path.move(to: q.topLeft)
        path.addLine(to: q.topRight)
        path.addLine(to: q.bottomRight)
        path.addLine(to: q.bottomLeft)
        path.closeSubpath()
        return path
    }

    /// Weighted interpolation towards another quad.
    func interpolated(towards other: Quad, by factor: CGFloat) -> Quad {
        func lerp(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * factor, y: a.y + (b.y - a.y) * factor)
        }
        return Quad(
            topLeft: lerp(topLeft, other.topLeft),
            topRight: lerp(topRight, other.topRight),
            bottomRight: lerp(bottomRight, other.bottomRight),
            bottomLeft: lerp(bottomLeft, other.bottomLeft)
        )
    }

    /// Average Euclidean distance between corresponding vertices.
    func distance(to other: Quad) -> CGFloat {
        func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            hypot(a.x - b.x, a.y - b.y)
        }
        return (dist(topLeft, other.topLeft) +
                dist(topRight, other.topRight) +
                dist(bottomRight, other.bottomRight) +
                dist(bottomLeft, other.bottomLeft)) / 4.0
    }

    // MARK: - Default (full-frame fallback)

    static let fullPage = Quad(
        topLeft: CGPoint(x: 0, y: 1),
        topRight: CGPoint(x: 1, y: 1),
        bottomRight: CGPoint(x: 1, y: 0),
        bottomLeft: CGPoint(x: 0, y: 0)
    )
}
