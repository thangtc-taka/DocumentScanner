import CoreGraphics

/// Smooths detected quads over time to eliminate sensor jitter.
/// Replaces WeScan's RectangleFeaturesFunnel with a Swift actor.
actor DetectionSmoother {

    // MARK: - Configuration

    private let bufferSize: Int
    /// Max average vertex delta (normalized) before history is reset (camera moved).
    private let jumpThreshold: CGFloat = 0.15
    /// Max variance across history for the document to be considered "stable".
    private let stabilityThreshold: CGFloat = 0.02

    // MARK: - State

    private var history: [Quad] = []

    // MARK: - Init

    init(bufferSize: Int) {
        self.bufferSize = max(1, bufferSize)
    }

    // MARK: - Processing

    /// Feed a new detection result.
    /// Returns the exponentially weighted averaged quad and a stability flag.
    func process(_ quad: Quad?) -> (smoothed: Quad?, isStable: Bool) {
        guard let quad else {
            history.removeAll()
            return (nil, false)
        }

        if let last = history.last, last.distance(to: quad) > jumpThreshold {
            history.removeAll()
        }

        history.append(quad)
        if history.count > bufferSize { history.removeFirst() }

        let smoothed = weightedAverage()
        let stable = history.count == bufferSize && maxVariance() < stabilityThreshold
        return (smoothed, stable)
    }

    func reset() {
        history.removeAll()
    }

    // MARK: - Private math

    /// Exponential weighted average — recent frames have higher weight.
    private func weightedAverage() -> Quad {
        guard !history.isEmpty else { return .fullPage }

        var totalWeight: CGFloat = 0
        var tl = CGPoint.zero, tr = CGPoint.zero, br = CGPoint.zero, bl = CGPoint.zero

        for (i, q) in history.enumerated() {
            let weight: CGFloat = pow(2.0, CGFloat(i))
            totalWeight += weight
            tl.x += q.topLeft.x * weight;     tl.y += q.topLeft.y * weight
            tr.x += q.topRight.x * weight;    tr.y += q.topRight.y * weight
            br.x += q.bottomRight.x * weight; br.y += q.bottomRight.y * weight
            bl.x += q.bottomLeft.x * weight;  bl.y += q.bottomLeft.y * weight
        }

        return Quad(
            topLeft:     CGPoint(x: tl.x / totalWeight, y: tl.y / totalWeight),
            topRight:    CGPoint(x: tr.x / totalWeight, y: tr.y / totalWeight),
            bottomRight: CGPoint(x: br.x / totalWeight, y: br.y / totalWeight),
            bottomLeft:  CGPoint(x: bl.x / totalWeight, y: bl.y / totalWeight)
        )
    }

    /// Average of per-vertex variances across all history frames.
    private func maxVariance() -> CGFloat {
        guard history.count > 1 else { return 0 }
        let mean = weightedAverage()
        let variance = history.map { $0.distance(to: mean) }.reduce(0, +) / CGFloat(history.count)
        return variance
    }
}
