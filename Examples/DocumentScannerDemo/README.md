# DocumentScanner Demo App

Example iOS app demonstrating DocumentScanner SPM with MVVM + SwiftUI.

## Architecture

```
MVVM + SwiftUI + NavigationStack (programmatic)
```

**3 screens:**
- **Home** — Landing screen with "Start Scan" button
- **Scan** — Live camera + document detection + custom capture UI
- **Result** — Scanned image preview, PDF export, share, save

## Setup in Xcode

### Step 1: Create New Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Fill in:
   - **Product Name:** `DocumentScannerDemo`
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Choose save location and click **Create**

### Step 2: Add DocumentScanner Package

1. In Xcode: **File → Add Packages**
2. Click **Add Local…** (bottom left)
3. Navigate to the `DocumentScanner/` folder (the parent SPM package)
4. Click **Add Package**
5. Check **DocumentScanner** library → **Add to Target: DocumentScannerDemo**

### Step 3: Add Source Files

Copy all Swift files from `Sources/DocumentScannerDemo/` into your Xcode project:

```
App/
  DocumentScannerDemoApp.swift    ← Replace ContentView.swift with this
Navigation/
  AppRouter.swift
Models/
  ScanResult.swift
Screens/
  Home/HomeView.swift
  Home/HomeViewModel.swift
  Scan/ScanView.swift
  Scan/ScanViewModel.swift
  Result/ResultView.swift
  Result/ResultViewModel.swift
```

Drag-drop into Xcode, check **Copy items if needed** and your target.

### Step 4: Configure Info.plist

Add camera permission:
```xml
<key>NSCameraUsageDescription</key>
<string>DocumentScanner needs camera access to scan documents in real time.</string>
```

Or in Xcode: Target → Info → Custom iOS Target Properties → **+** → Privacy - Camera Usage Description

### Step 5: Delete the Default ContentView

- Delete `ContentView.swift` from your project
- Open `DocumentScannerDemoApp.swift` — your `@main` entry is there

### Step 6: Run

Select an **iPhone simulator or real device** and hit **Run (⌘R)**.

> Note: Camera works on real device only. On simulator, camera returns a black feed.

---

## File Structure

```
DocumentScannerDemo/
├── App/
│   ├── DocumentScannerDemoApp.swift   @main entry point + NavigationStack setup
│   └── Info.plist                     Camera permission
├── Navigation/
│   └── AppRouter.swift                @MainActor ObservableObject — drives navigation
├── Models/
│   └── ScanResult.swift               Wraps ScannedDocument for navigation
└── Screens/
    ├── Home/
    │   ├── HomeView.swift              Landing page, "Start Scan" button
    │   └── HomeViewModel.swift         Camera permission logic
    ├── Scan/
    │   ├── ScanView.swift              DocumentScannerView + custom overlay
    │   └── ScanViewModel.swift         Capture state management
    └── Result/
        ├── ResultView.swift            Image preview, PDF export, share, save
        └── ResultViewModel.swift        Export logic, UIActivityViewController
```

## Key Code Patterns

### 1. Navigation (AppRouter)

```swift
// Inject AppRouter as EnvironmentObject
.environmentObject(router)

// Navigate from any view/viewmodel
router.startScan()
router.showResult(for: result)
router.goBackToHome()
```

### 2. Using DocumentScannerView

```swift
DocumentScannerView(
    configuration: config,
    onCapture: { _ in /* handled in overlay */ },
    overlay: { controller in
        // Access controller.detectedQuad, controller.isDocumentStable
        // Call controller.captureDocument() on button tap
        MyCustomOverlay(controller: controller)
    }
)
```

### 3. Exporting PDF

```swift
let pdfData = try await result.scannedDocument.exportAsPDF(pageSize: .a4)
let url = FileManager.default.temporaryDirectory.appendingPathComponent("scan.pdf")
try pdfData.write(to: url)

// Show in PDF viewer
PDFPreviewView(url: url)

// Share
UIActivityViewController(activityItems: [url], applicationActivities: nil)
```

### 4. ScanResult Model

```swift
// Created from a ScannedDocument after capture
let scanResult = ScanResult(document: document)

// Passed to Result screen via AppRouter
router.showResult(for: scanResult)
```

---

## Screenshots / Screen Flow

```
┌─────────────────┐     tap "Start Scan"    ┌─────────────────┐
│   HOME SCREEN   │ ─────────────────────→  │   SCAN SCREEN   │
│                 │                         │                 │
│  [App Logo]     │                         │  [Live Camera]  │
│  [Features]     │                         │  [Quad Overlay] │
│  [Start Scan]   │                         │  [Shutter Btn]  │
└─────────────────┘                         └────────┬────────┘
                                                     │ capture
                                                     ↓
                                            ┌─────────────────┐
                                            │  RESULT SCREEN  │
                                            │                 │
                                            │  [Scanned Doc]  │
                                            │  [Mode Picker]  │
                                            │  [View as PDF]  │
                                            │  [Share]        │
                                            │  [Save]         │
                                            └─────────────────┘
```

## Troubleshooting

**Camera shows black screen?**
→ Test on a real device, not simulator.

**"No such module 'DocumentScanner'"?**
→ File → Add Packages → Add Local → select the DocumentScanner folder.

**Build error "NavigationPath"?**
→ Ensure iOS Deployment Target is 16.0+.

**PDF preview is blank?**
→ Check that `exportedPDFURL` is not nil; add a breakpoint in `exportPDF()`.
