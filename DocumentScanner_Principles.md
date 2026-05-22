# Technical Architecture: Document Scanning & Live Edge Detection

This document provides a deep dive into the engineering principles behind **WeScan**. It covers the end-to-end pipeline from real-time computer vision to the final PDF generation.

---

## 1. Real-Time Vision Pipeline (The Live Feed)
The process begins with `AVFoundation`, where we establish an `AVCaptureSession`. Instead of processing static images, WeScan operates on a continuous stream of video frames.

- **Frame Acquisition**: We use `AVCaptureVideoDataOutput` to receive `CMSampleBuffer` frames.
- **Pixel Conversion**: Each buffer is converted to a `CVPixelBuffer` or `CIImage`. To maintain high performance (30+ FPS), the vision requests are executed on a dedicated serial background queue to avoid blocking the Main (UI) thread.

## 2. Advanced Rectangle Detection (The "Brain")
WeScan leverages Apple’s hardware-accelerated frameworks to detect document boundaries.

### A. The Vision Framework (iOS 11+)
Using `VNDetectRectanglesRequest`, the system performs:
- **Edge Gradient Analysis**: Identifying high-contrast transitions (e.g., a white paper on a dark desk).
- **Feature Extraction**: Searching for four-sided polygons that resemble a rectangle based on configurable parameters like `minimumAspectRatio` and `quadratureTolerance`.

### B. Core Image Detector (Legacy/Fallback)
For older devices, `CIDetector(ofType: CIDetectorTypeRectangle)` is used. It employs a similar Hough Transform approach to find line segments and their intersections.

## 3. Signal Processing: The "Rectangle Funnel"
One of the biggest challenges in live scanning is **jitter**—the flickering of the detected box due to sensor noise or hand tremors.

- **Temporal Smoothing**: WeScan uses a custom `RectangleFeaturesFunnel`. It maintains a historical buffer of the last $N$ detected quads.
- **Validation**: A new detection is only accepted if its vertices are within a certain threshold of the previous ones.
- **Averaging**: The vertices displayed to the user are the weighted average of the current and previous detections. This creates the "sticky," smooth blue overlay effect.

## 4. Geometric Rectification (Perspective Correction)
When a user captures a document, it is often skewed because the camera is not perfectly parallel to the paper. This is a 3D-to-2D projection problem.

- **The Mathematical Principle**: We apply a **Perspective Transform** (Homography). Given four source points (the detected corners) and four destination points (the corners of a perfect rectangle), we calculate a $3 \times 3$ transformation matrix.
- **Implementation**: We use the `CIPerspectiveCorrection` filter. It re-samples the pixels from the warped quadrilateral into a flat, rectangular grid, effectively "flying" the camera to a top-down position.

## 5. Intelligent Image Enhancement
To make a photo look like a professional scan, we apply two primary transformations:

### A. Adaptive Thresholding
Standard thresholding (turning everything below 50% gray to black) fails if there are shadows. 
- WeScan analyzes local neighborhoods of pixels. If a pixel is darker than its immediate neighbors, it's treated as text (ink). If it's lighter, it's treated as background (paper). This removes shadows while keeping text crisp.

### B. Color Correction & Normalization
- **Grayscale Conversion**: Removing chroma information to focus on luminance.
- **Luminance Expansion**: Stretching the histogram so that the "whitest" parts of the paper become pure white (#FFFFFF) and the "blackest" ink becomes pure black (#000000).

## 6. PDF Orchestration
The final step is converting the processed `UIImage` into a portable, industry-standard format.

- **Coordinate Mapping**: Image coordinates (pixels) are mapped to PDF points ($1/72$ inch).
- **UIGraphicsPDFRenderer**: 
    1. We initialize a PDF context with standard page bounds (e.g., A4 or US Letter).
    2. We begin a new PDF page.
    3. The `UIImage` is drawn into the context. Because the image was already deskewed in Step 4, it fits perfectly into the page boundaries.
    4. The context is closed, generating a binary `Data` blob ready for disk storage or `UIActivityViewController` sharing.

---

## Summary of the Data Flow
1. **Input**: `AVCaptureSession` Raw Video Stream.
2. **Analysis**: `VNRectangleObservation` (Detection) ➔ `RectangleFeaturesFunnel` (Smoothing).
3. **Capture**: High-resolution `UIImage` capture based on smoothed coordinates.
4. **Transform**: `CIPerspectiveCorrection` (Perspective Flattening).
5. **Process**: `CIAdaptiveThreshold` + `CIColorControls` (Enhancement).
6. **Output**: `UIGraphicsPDFRenderer` ➔ Final `.pdf` file.
