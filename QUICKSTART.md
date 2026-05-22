# DocumentScanner — Quick Start

Just want to get scanning in 5 minutes? You're in the right place.

## 1. Add to Your Project

**Xcode:** File → Add Packages → `https://github.com/caothang/DocumentScanner.git`

**Or manually** in `Package.swift`:
```swift
.package(url: "https://github.com/caothang/DocumentScanner.git", from: "1.0.0")
```

## 2. Add Camera Permission

Edit `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan documents.</string>
```

## 3. Scan Documents

```swift
import SwiftUI
import DocumentScanner

struct ContentView: View {
    @State private var document: ScannedDocument?

    var body: some View {
        VStack {
            if let doc = document {
                Image(uiImage: doc.enhancedImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("No document yet")
            }

            Button("Scan") {
                // Open scanner (see below)
            }
        }
        .sheet(isPresented: .constant(document == nil)) {
            DocumentScannerView { scannedDoc in
                document = scannedDoc
            }
        }
    }
}
```

**That's it!** You now have:
- ✅ Live camera feed with real-time document detection
- ✅ Automatic perspective correction (flattening)
- ✅ GPU-accelerated image enhancement
- ✅ Full control over the UI

## Next: Customize UI

Add a custom shutter button and guides:

```swift
DocumentScannerView { document in
    self.document = document
} overlay: { controller in
    VStack {
        Spacer()
        
        Button(action: {
            Task {
                let doc = try? await controller.captureDocument()
            }
        }) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .fill(controller.isDocumentStable ? Color.green : Color.gray)
                    .frame(width: 60, height: 60)
            }
        }
        .padding()
    }
}
```

## Next: Export PDF

```swift
let pdfData = try await document.exportAsPDF(pageSize: .a4)

// Save or share
let url = FileManager.default.temporaryDirectory
    .appendingPathComponent("scan.pdf")
try pdfData.write(to: url)
```

## Configuration

```swift
var config = DocumentScannerConfiguration()
config.enhancementMode = .blackAndWhite  // or .grayscale, .none
config.pageSize = .a4                    // or .letter
config.smoothingBufferSize = 5           // For stability
```

## Handling Errors

```swift
do {
    let doc = try await controller.captureDocument()
} catch DocumentScannerError.cameraPermissionDenied {
    print("User denied camera access")
} catch {
    print("Error: \(error)")
}
```

## Need More?

- **How-To Guide:** See [HowToUse.md](HowToUse.md) for 20+ examples
- **Architecture:** See [DocumentScanner_Principles.md](DocumentScanner_Principles.md)
- **API Reference:** See [README.md](README.md#key-types)

---

**Questions?** Open an issue on [GitHub](https://github.com/caothang/DocumentScanner/issues)
