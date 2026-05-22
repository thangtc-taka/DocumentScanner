# DocumentScanner — Detailed Usage Guide

This guide covers everything from basic setup to advanced customization. Whether you're building a simple document scanning app or integrating into existing infrastructure, you'll find examples here.

## Table of Contents

1. [Installation & Setup](#installation--setup)
2. [Basic Usage](#basic-usage)
3. [Customizing the UI](#customizing-the-ui)
4. [Camera Permissions](#camera-permissions)
5. [Document Processing](#document-processing)
6. [PDF Export](#pdf-export)
7. [Error Handling](#error-handling)
8. [Advanced Patterns](#advanced-patterns)
9. [Performance Tips](#performance-tips)
10. [Troubleshooting](#troubleshooting)

---

## Installation & Setup

### Step 1: Add to Your Project

#### Option A: Xcode UI (Recommended)

1. In Xcode, go to **File** → **Add Packages**
2. Enter: `https://github.com/caothang/DocumentScanner.git`
3. Select version: **Up to Next Major** `1.0.0 <`
4. Choose your target
5. Click **Add Package**

#### Option B: Manual Package.swift

Edit your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/caothang/DocumentScanner.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["DocumentScanner"]
    )
]
```

Then run:
```bash
swift package resolve
```

### Step 2: Import

```swift
import DocumentScanner
import SwiftUI
```

### Step 3: Configure Info.plist

Add camera permission description:

```xml
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to scan documents.</string>
```

That's it! You're ready to use DocumentScanner.

---

## Basic Usage

### Simplest Example: Modal Scanner

```swift
import SwiftUI
import DocumentScanner

struct ContentView: View {
    @State private var isPresented = false
    @State private var lastDocument: ScannedDocument?

    var body: some View {
        VStack {
            if let doc = lastDocument {
                VStack {
                    Image(uiImage: doc.enhancedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                    
                    HStack {
                        Button("Share") {
                            shareDocument(doc)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Delete") {
                            lastDocument = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            } else {
                Text("No document scanned yet")
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: { isPresented = true }) {
                Label("Scan Document", systemImage: "doc.viewfinder")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
        .sheet(isPresented: $isPresented) {
            DocumentScannerView { document in
                lastDocument = document
                isPresented = false
            }
        }
    }
    
    private func shareDocument(_ doc: ScannedDocument) {
        Task {
            do {
                let pdf = try await doc.exportAsPDF(pageSize: .a4)
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("scanned_\(UUID()).pdf")
                try pdf.write(to: tmpURL)
                
                let vc = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = scene.windows.first?.rootViewController {
                    root.present(vc, animated: true)
                }
            } catch {
                print("Export failed: \(error)")
            }
        }
    }
}
```

**What happens:**
1. User taps "Scan Document"
2. `DocumentScannerView` opens as a sheet
3. Live camera preview shows with real-time quad detection
4. User moves camera until document is in frame
5. Quad turns green when stable
6. User taps (implied shutter)
7. Callback returns `ScannedDocument`
8. Sheet closes, image displayed

---

## Customizing the UI

### Example 1: Custom Shutter Button & Flash Toggle

```swift
struct CustomScannerView: View {
    @State private var documents: [ScannedDocument] = []
    @State private var showingScanner = false

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(documents) { doc in
                        NavigationLink {
                            DocumentDetailView(document: doc)
                        } label: {
                            HStack {
                                Image(uiImage: doc.enhancedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(4)
                                
                                VStack(alignment: .leading) {
                                    Text("Document #\(doc.id.uuidString.prefix(8))")
                                        .font(.headline)
                                    Text(doc.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .onDelete { indices in
                        documents.remove(atOffsets: indices)
                    }
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingScanner = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                DocumentScannerView(
                    configuration: .init(),
                    onCapture: { doc in
                        documents.insert(doc, at: 0)
                        showingScanner = false
                    },
                    overlay: { controller in
                        CustomScannerOverlay(controller: controller)
                    }
                )
            }
        }
    }
}

struct CustomScannerOverlay: View {
    let controller: DocumentScannerController
    @State private var isFlashOn = false
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            // Top bar: Flash toggle
            VStack {
                HStack {
                    Button(action: { isFlashOn.toggle() }) {
                        Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash")
                            .font(.title2)
                            .foregroundColor(isFlashOn ? .yellow : .white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    Text(controller.isDocumentStable ? "✓ Ready" : "Position document")
                        .font(.caption)
                        .foregroundColor(controller.isDocumentStable ? .green : .gray)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                }
                .padding()
                
                Spacer()
            }
            
            // Bottom: Shutter button
            VStack {
                Spacer()
                
                Button(action: captureDocument) {
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 80, height: 80)
                        
                        // Inner filled circle
                        Circle()
                            .fill(controller.isDocumentStable ? Color.green : Color.gray)
                            .frame(width: 60, height: 60)
                        
                        // Pulse animation when ready
                        if controller.isDocumentStable {
                            Circle()
                                .stroke(Color.green, lineWidth: 2)
                                .frame(width: 80, height: 80)
                                .opacity(0.5)
                                .scaleEffect(1.1)
                                .animation(
                                    Animation.easeInOut(duration: 1)
                                        .repeatForever(autoreverses: true),
                                    value: controller.isDocumentStable
                                )
                        }
                    }
                }
                .disabled(isCapturing)
                .padding()
            }
        }
    }
    
    private func captureDocument() {
        isCapturing = true
        Task {
            do {
                let doc = try await controller.captureDocument()
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                // The onCapture callback will handle storing the document
                await MainActor.run {
                    isCapturing = false
                }
            } catch {
                print("Capture error: \(error)")
                isCapturing = false
            }
        }
    }
}
```

### Example 2: Document Frame Guide Overlay

```swift
struct GuideOverlay: View {
    let controller: DocumentScannerController
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3).ignoresSafeArea()
            
            // Cutout frame showing where document should be
            Canvas { context in
                let frameSize = CGSize(width: 300, height: 400)
                let frameRect = CGRect(
                    x: (UIScreen.main.bounds.width - frameSize.width) / 2,
                    y: (UIScreen.main.bounds.height - frameSize.height) / 2,
                    width: frameSize.width,
                    height: frameSize.height
                )
                
                // Draw semi-transparent overlay
                var path = Path(CGRect(origin: .zero, size: UIScreen.main.bounds.size))
                path.addRect(frameRect)
                
                context.fill(
                    path,
                    with: .color(.black.opacity(0.7))
                )
                
                // Draw frame border
                context.stroke(
                    Path(roundedRect: frameRect, cornerRadius: 8),
                    with: .color(controller.isDocumentStable ? .green : .white),
                    lineWidth: 3
                )
            }
            
            // Instruction text
            VStack {
                HStack {
                    Image(systemName: "info.circle.fill")
                    Text(controller.isDocumentStable ? "Document locked!" : "Position your document within the frame")
                        .font(.caption)
                }
                .padding(8)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(6)
                
                Spacer()
            }
            .padding()
        }
    }
}
```

### Example 3: Multi-Document Batch Capture

```swift
struct BatchScannerView: View {
    @State private var documents: [ScannedDocument] = []
    @State private var controller: DocumentScannerController?
    @State private var isScannerVisible = false
    @State private var pageCount = 0

    var body: some View {
        VStack {
            if controller != nil && isScannerVisible {
                ZStack(alignment: .bottom) {
                    DocumentScannerView(
                        configuration: .init(),
                        onCapture: { doc in
                            documents.append(doc)
                            pageCount += 1
                            // Continue scanning (don't close)
                        },
                        overlay: { _ in
                            BatchControlOverlay(
                                pageCount: pageCount,
                                onDone: { isScannerVisible = false }
                            )
                        }
                    )
                }
            } else {
                DocumentList(documents: documents)
                
                Button("Start Batch Scan") {
                    Task {
                        do {
                            let ctrl = try await DocumentScannerController()
                            try await ctrl.startSession()
                            self.controller = ctrl
                            isScannerVisible = true
                            pageCount = 0
                        } catch {
                            print("Failed to start scanner: \(error)")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
    }
}

struct BatchControlOverlay: View {
    let pageCount: Int
    let onDone: () -> Void

    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Pages Scanned")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(pageCount)")
                        .font(.headline)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Spacer()
                
                Button(action: onDone) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }
}

struct DocumentList: View {
    let documents: [ScannedDocument]

    var body: some View {
        List {
            ForEach(documents, id: \.id) { doc in
                HStack {
                    Image(uiImage: doc.enhancedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 80)
                        .cornerRadius(4)
                    
                    VStack(alignment: .leading) {
                        Text("Page \(documents.firstIndex(where: { $0.id == doc.id })! + 1)")
                            .font(.headline)
                        Text(doc.capturedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}
```

---

## Camera Permissions

### Checking Permissions

```swift
import AVFoundation

func checkCameraPermission() -> CameraPermissionStatus {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    
    switch status {
    case .notDetermined:
        return .notDetermined
    case .restricted:
        return .restricted      // Parental controls
    case .denied:
        return .denied          // User said "Don't Allow"
    case .authorized:
        return .authorized      // User said "Allow"
    @unknown default:
        return .notDetermined
    }
}

enum CameraPermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
}

// Request permission
func requestCameraPermission() async -> Bool {
    let granted = await AVCaptureDevice.requestAccess(for: .video)
    return granted
}
```

### Handling Permission Denial

```swift
struct ScannerWithPermissionCheck: View {
    @State private var cameraPermission: CameraPermissionStatus = .notDetermined
    @State private var showPermissionAlert = false

    var body: some View {
        VStack {
            switch cameraPermission {
            case .authorized:
                DocumentScannerView { doc in
                    print("Scanned: \(doc.id)")
                }
                
            case .denied:
                VStack(spacing: 16) {
                    Image(systemName: "camera.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    
                    Text("Camera Access Denied")
                        .font(.headline)
                    
                    Text("Enable camera access in Settings to use the document scanner.")
                        .foregroundColor(.gray)
                    
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
            case .restricted:
                VStack(spacing: 16) {
                    Image(systemName: "lock")
                        .font(.system(size: 48))
                    
                    Text("Camera Access Restricted")
                        .font(.headline)
                    
                    Text("Camera access is restricted by parental controls.")
                        .foregroundColor(.gray)
                }
                .padding()
                
            case .notDetermined:
                VStack(spacing: 16) {
                    Image(systemName: "camera")
                        .font(.system(size: 48))
                    
                    Text("Camera Permission Required")
                        .font(.headline)
                    
                    Button("Allow Camera Access") {
                        Task {
                            let granted = await AVCaptureDevice.requestAccess(for: .video)
                            cameraPermission = granted ? .authorized : .denied
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .onAppear {
            checkPermission()
        }
    }

    private func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            cameraPermission = .notDetermined
        case .authorized:
            cameraPermission = .authorized
        case .denied:
            cameraPermission = .denied
        case .restricted:
            cameraPermission = .restricted
        @unknown default:
            cameraPermission = .notDetermined
        }
    }
}
```

---

## Document Processing

### Accessing All Three Image Versions

Each `ScannedDocument` contains three versions of the image:

```swift
let doc: ScannedDocument

// 1. Original: Raw full-resolution capture (no processing)
let original = doc.originalImage

// 2. Corrected: Perspective-corrected, flattened to rectangle (no enhancement)
let corrected = doc.correctedImage

// 3. Enhanced: Final output with enhancement applied (b&w or grayscale)
let enhanced = doc.enhancedImage

// Use the appropriate version based on your needs
let displayImage = enhanced              // For PDF / display
let archiveImage = corrected             // For archiving (smaller than original)
let rawBackup = original                 // For recovery / reprocessing
```

### Accessing the Detected Quad

The `detectedQuad` is in normalized Vision coordinates (origin bottom-left, 0.0–1.0):

```swift
let quad = doc.detectedQuad

// Convert to UIKit coordinates for overlay or custom rendering
let size = CGSize(width: 1080, height: 1920)
let uiKitQuad = quad.toUIKitCoordinates(in: size)

// Get a CGPath for rendering
let path = quad.path(in: size)

// Calculate document size relative to frame
let width = quad.topRight.x - quad.topLeft.x
let height = quad.topLeft.y - quad.bottomLeft.y
let aspectRatio = width / height
```

### Reprocessing with Different Enhancement Mode

```swift
// After capturing with .none, re-enhance with different settings
func reenhanceDocument(doc: ScannedDocument, mode: DocumentScannerConfiguration.EnhancementMode) async throws -> UIImage {
    let ciImage = CIImage(image: doc.correctedImage)!
    let enhancer = ImageEnhancer(configuration: DocumentScannerConfiguration())
    return try await enhancer.enhance(ciImage, mode: mode)
}

// Usage
let newImage = try await reenhanceDocument(doc: doc, mode: .blackAndWhite)
```

---

## PDF Export

### Single Page PDF

```swift
let doc: ScannedDocument

// Export with A4 page size
let pdfData = try await doc.exportAsPDF(pageSize: .a4)

// Save to file
let url = FileManager.default.temporaryDirectory
    .appendingPathComponent("document_\(UUID()).pdf")
try pdfData.write(to: url)

// Or share
let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
// present vc...
```

### Multi-Page PDF

```swift
let documents: [ScannedDocument] = [/* ... */]

// Export all documents to a single PDF
let pdfs = try await Task.detached {
    try PDFExporter().export(
        pages: documents.map { $0.enhancedImage },
        pageSize: .a4
    )
}.value

let url = FileManager.default.documentsDirectory
    .appendingPathComponent("batch_\(UUID()).pdf")
try pdfs.write(to: url)
```

### Custom Page Size

```swift
let custom = CGSize(width: 500, height: 700)  // Custom dimensions in points
let pdfData = try await doc.exportAsPDF(
    pageSize: .custom(custom)
)
```

### Save to Device

```swift
import DocumentPickerUI

func saveDocumentToDisk(doc: ScannedDocument) async throws {
    let filename = "Scanned_\(Date().formatted(date: .numeric, time: .standard)).pdf"
    
    let pdf = try await doc.exportAsPDF(pageSize: .a4)
    
    let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let docDirectory = urls[0]
    let fileURL = docDirectory.appendingPathComponent(filename)
    
    try pdf.write(to: fileURL)
    
    print("Saved to: \(fileURL.path)")
}
```

---

## Error Handling

### Comprehensive Error Handling

```swift
enum ScannerOperationResult {
    case success(ScannedDocument)
    case cameraPermissionDenied
    case cameraUnavailable
    case detectionFailed
    case enhancementFailed
    case exportFailed(Error)
    case unknown(Error)
}

func captureWithErrorHandling(controller: DocumentScannerController) async -> ScannerOperationResult {
    do {
        let doc = try await controller.captureDocument()
        return .success(doc)
    } catch DocumentScannerError.cameraPermissionDenied {
        return .cameraPermissionDenied
    } catch DocumentScannerError.cameraUnavailable {
        return .cameraUnavailable
    } catch DocumentScannerError.detectionFailed {
        return .detectionFailed
    } catch DocumentScannerError.enhancementFailed {
        return .enhancementFailed
    } catch DocumentScannerError.pdfExportFailed {
        return .exportFailed(DocumentScannerError.pdfExportFailed)
    } catch {
        return .unknown(error)
    }
}

// Usage
switch await captureWithErrorHandling(controller: controller) {
case .success(let doc):
    print("Document captured successfully")
    documents.append(doc)
    
case .cameraPermissionDenied:
    showAlert("Camera access required. Please enable in Settings.")
    
case .cameraUnavailable:
    showAlert("Camera is not available on this device.")
    
case .detectionFailed:
    showAlert("Could not detect document. Try repositioning.")
    
case .enhancementFailed:
    showAlert("Image enhancement failed. Please try again.")
    
case .exportFailed(let error):
    showAlert("PDF export failed: \(error.localizedDescription)")
    
case .unknown(let error):
    showAlert("Unknown error: \(error.localizedDescription)")
}
```

### Retry Logic

```swift
func captureWithRetry(controller: DocumentScannerController, maxRetries: Int = 3) async throws -> ScannedDocument {
    var lastError: Error?
    
    for attempt in 1...maxRetries {
        do {
            print("Capture attempt \(attempt)/\(maxRetries)")
            return try await controller.captureDocument()
        } catch DocumentScannerError.detectionFailed {
            lastError = DocumentScannerError.detectionFailed
            print("Detection failed, retrying...")
            try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second
        } catch {
            throw error  // Don't retry other errors
        }
    }
    
    throw lastError ?? DocumentScannerError.detectionFailed
}
```

---

## Advanced Patterns

### Pattern 1: Real-Time Confidence Display

```swift
struct ConfidenceOverlay: View {
    let controller: DocumentScannerController

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Document Detection")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Image(systemName: controller.detectedQuad != nil ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundColor(controller.detectedQuad != nil ? .green : .gray)
                        
                        Text(controller.detectedQuad != nil ? "Detected" : "Searching...")
                            .font(.caption)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(6)
                
                Spacer()
            }
            .padding()
            
            Spacer()
        }
    }
}
```

### Pattern 2: Document Storage & Retrieval

```swift
class DocumentStore: ObservableObject {
    @Published var documents: [StoredDocument] = []
    
    private let fileManager = FileManager.default
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func store(_ document: ScannedDocument) throws {
        let encoder = JSONEncoder()
        
        // Save metadata
        let stored = StoredDocument(
            id: document.id,
            capturedAt: document.capturedAt,
            filename: "doc_\(document.id).pdf"
        )
        
        let metaURL = documentsDirectory
            .appendingPathComponent("doc_\(document.id).json")
        let metaData = try encoder.encode(stored)
        try metaData.write(to: metaURL)
        
        // Save enhanced image
        let imgURL = documentsDirectory
            .appendingPathComponent("doc_\(document.id)_enhanced.jpg")
        if let imgData = document.enhancedImage.jpegData(compressionQuality: 0.95) {
            try imgData.write(to: imgURL)
        }
        
        // Save PDF
        let pdfData = try await document.exportAsPDF(pageSize: .a4)
        let pdfURL = documentsDirectory
            .appendingPathComponent(stored.filename)
        try pdfData.write(to: pdfURL)
        
        documents.append(stored)
    }
    
    func retrieve(id: UUID) -> StoredDocument? {
        documents.first { $0.id == id }
    }
    
    func delete(id: UUID) throws {
        documents.removeAll { $0.id == id }
        try fileManager.removeItem(at: documentsDirectory.appendingPathComponent("doc_\(id).json"))
        try fileManager.removeItem(at: documentsDirectory.appendingPathComponent("doc_\(id)_enhanced.jpg"))
        try fileManager.removeItem(at: documentsDirectory.appendingPathComponent("doc_\(id).pdf"))
    }
}

struct StoredDocument: Codable {
    let id: UUID
    let capturedAt: Date
    let filename: String
}
```

### Pattern 3: Configuration Persistence

```swift
class ScannerSettings {
    static let shared = ScannerSettings()
    
    private let defaults = UserDefaults.standard
    
    var enhancementMode: DocumentScannerConfiguration.EnhancementMode {
        get {
            let rawValue = defaults.string(forKey: "enhancementMode") ?? "blackAndWhite"
            switch rawValue {
            case "none": return .none
            case "grayscale": return .grayscale
            default: return .blackAndWhite
            }
        }
        set {
            let rawValue: String
            switch newValue {
            case .none: rawValue = "none"
            case .grayscale: rawValue = "grayscale"
            case .blackAndWhite: rawValue = "blackAndWhite"
            }
            defaults.set(rawValue, forKey: "enhancementMode")
        }
    }
    
    var pageSize: DocumentScannerConfiguration.PageSize {
        get {
            let rawValue = defaults.string(forKey: "pageSize") ?? "a4"
            switch rawValue {
            case "letter": return .letter
            default: return .a4
            }
        }
        set {
            let rawValue: String
            switch newValue {
            case .a4: rawValue = "a4"
            case .letter: rawValue = "letter"
            case .custom: rawValue = "custom"
            }
            defaults.set(rawValue, forKey: "pageSize")
        }
    }
    
    var smoothingBufferSize: Int {
        get { defaults.integer(forKey: "smoothingBufferSize") == 0 ? 5 : defaults.integer(forKey: "smoothingBufferSize") }
        set { defaults.set(newValue, forKey: "smoothingBufferSize") }
    }
    
    func configuration() -> DocumentScannerConfiguration {
        var config = DocumentScannerConfiguration()
        config.enhancementMode = enhancementMode
        config.pageSize = pageSize
        config.smoothingBufferSize = smoothingBufferSize
        return config
    }
}

// Usage
let config = ScannerSettings.shared.configuration()
DocumentScannerView(configuration: config) { doc in
    // ...
}
```

---

## Performance Tips

### 1. Reduce Enhancement Overhead

```swift
// Good: Use .none for live preview, .blackAndWhite only for final PDF
var config = DocumentScannerConfiguration()
config.enhancementMode = .none                    // Fast preview

// Then export with enhancement
let enhancedPDF = try await document.exportAsPDF(pageSize: .a4)  // Done after capture
```

### 2. Batch Operations

```swift
// Bad: Export each PDF individually (inefficient)
for doc in documents {
    let pdf = try await doc.exportAsPDF(pageSize: .a4)
    // ...
}

// Good: Batch to single PDF (faster, smaller file)
let images = documents.map { $0.enhancedImage }
let pdf = try await PDFExporter().export(pages: images, pageSize: .a4)
```

### 3. Memory Management for Large Images

```swift
// For very large document counts, process in chunks
func processDocumentsInChunks(_ documents: [ScannedDocument], chunkSize: Int = 10) async throws {
    for chunk in documents.chunked(into: chunkSize) {
        let images = chunk.map { $0.enhancedImage }
        let pdf = try await PDFExporter().export(pages: images, pageSize: .a4)
        
        // Save chunk and release memory
        try pdf.write(to: chunkURL(for: chunk.first!.id))
        // Memory is released after this block
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

---

## Troubleshooting

### Issue 1: "Cannot find module 'DocumentScanner'"

**Solution:** Ensure the package is added to your target's dependencies:
1. Target Settings → Build Phases → Link Binary With Libraries
2. Verify `DocumentScanner` is listed
3. Clean build folder (Cmd+Shift+K)

### Issue 2: Camera Permission Always Denied

**Solution:** Check Info.plist has `NSCameraUsageDescription`:
```xml
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to scan documents.</string>
```

### Issue 3: Metal Unavailable Error

**Cause:** Running on a simulator without GPU support or older Mac.

**Solution:** Fallback to CPU enhancement:
```swift
do {
    let doc = try await controller.captureDocument()
} catch DocumentScannerError.metalUnavailable {
    // Use grayscale enhancement instead
    var config = DocumentScannerConfiguration()
    config.enhancementMode = .grayscale
}
```

### Issue 4: Detection Inconsistent / Jittery

**Solution:** Increase smoothing buffer size:
```swift
var config = DocumentScannerConfiguration()
config.smoothingBufferSize = 7  // Default is 5, range 1-10
```

### Issue 5: PDF File Too Large

**Solution:** Reduce JPEG quality:
```swift
var config = DocumentScannerConfiguration()
config.capturePhotoQuality = 0.8  // Default is 1.0, range 0.0-1.0
```

### Issue 6: "Real-time Detection Too Slow"

**Solution:** Reduce the document size threshold:
```swift
var config = DocumentScannerConfiguration()
config.minimumDocumentSize = 0.1  // Default is 0.15, allow smaller documents
```

---

## Next Steps

- Check [DocumentScanner_Principles.md](DocumentScanner_Principles.md) for technical deep dive
- See [README.md](README.md) for quick reference
- Report issues: https://github.com/caothang/DocumentScanner/issues

**Happy scanning!** 📸
