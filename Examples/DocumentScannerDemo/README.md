# DocumentScannerDemo

Example iOS app — MVVM + SwiftUI + NavigationStack — 3 màn hình.

## Mở project

```bash
open Examples/DocumentScannerDemo/DocumentScannerDemo.xcodeproj
```

Project đã sẵn sàng, **không cần thêm tool nào**. Chỉ cần thêm package DocumentScanner qua Xcode SPM.

---

## Thêm DocumentScanner Package (bắt buộc)

Project chưa có dependency — bạn tự thêm để kiểm soát version:

1. Trong Xcode: **File → Add Package Dependencies…**
2. Chọn **Add Local…** (góc dưới trái)
3. Điều hướng đến thư mục **`DocumentScanner/`** (thư mục cha của Examples)
4. Click **Add Package**
5. Chọn library **DocumentScanner** → **Add to Target: DocumentScannerDemo**

> Hoặc dùng URL remote nếu đã push lên GitHub:
> `https://github.com/caothang/DocumentScanner.git`

---

## Cấu trúc project

```
DocumentScannerDemo.xcodeproj      ← Mở file này trong Xcode
DocumentScannerDemo/
├── App/
│   ├── DocumentScannerDemoApp.swift   @main + NavigationStack
│   └── Info.plist                     Camera permission
├── Navigation/
│   └── AppRouter.swift                Điều hướng 3 màn hình
├── Models/
│   └── ScanResult.swift               Wrapper ScannedDocument
└── Screens/
    ├── Home/
    │   ├── HomeView.swift             Màn hình chính + "Start Scan"
    │   └── HomeViewModel.swift        Kiểm tra quyền camera
    ├── Scan/
    │   ├── ScanView.swift             Camera live + custom overlay
    │   └── ScanViewModel.swift        Capture state machine
    └── Result/
        ├── ResultView.swift           Preview + PDF + Share + Save
        └── ResultViewModel.swift       Export logic
```

---

## 3 màn hình

### 1. Home
- App branding + feature list
- Kiểm tra và xin quyền camera tự động
- Button **"Start Scan"** → chuyển sang Scan

### 2. Scan
- `DocumentScannerView` với custom overlay (không phải VNDocumentCameraViewController)
- Badge trạng thái: **xanh lam** (đang tìm) → **xanh lá** (document ổn định)
- Shutter button: **xám** → **trắng** khi document ổn định, có hiệu ứng pulse
- `ProgressView` khi đang processing
- Tự động navigate sang Result sau khi capture

### 3. Result
- Xem ảnh 3 chế độ: **Enhanced / Corrected / Original** (SegmentedPicker)
- Metadata: thời gian chụp, enhancement mode, page size
- **View as PDF** → mở PDFKit preview trong sheet
- **Share Document** → `UIActivityViewController`
- **Save to Files** → lưu vào Documents directory
- Button quay về Home hoặc scan lại

---

## Navigation pattern (AppRouter)

```swift
// DocumentScannerDemoApp.swift
NavigationStack(path: $router.path) {
    HomeView()
        .navigationDestination(for: AppRouter.Route.self) { route in
            switch route {
            case .scan:            ScanView()
            case .result(let id): ResultView(result: router.result(for: id)!)
            }
        }
}
.environmentObject(router)

// Từ bất kỳ View nào
@EnvironmentObject private var router: AppRouter
router.startScan()             // Home → Scan
router.showResult(for: result) // Scan → Result
router.goBackToHome()          // Result → Home
```

---

## Lưu ý khi chạy

| | Simulator | Real Device |
|---|---|---|
| Camera live feed | ❌ | ✅ |
| Document detection | ❌ | ✅ |
| PDF export | ✅ | ✅ |
| Share sheet | ✅ | ✅ |

> **Team signing:** Xcode có thể yêu cầu chọn Development Team.  
> Vào **Target → Signing & Capabilities → Team** → chọn Apple ID của bạn.

---

## Troubleshooting

**"No such module 'DocumentScanner'"**
→ Chưa thêm package. Thực hiện bước **Thêm DocumentScanner Package** ở trên.

**Camera đen hoàn toàn**
→ Chạy trên real device, không phải simulator.

**Build lỗi `NavigationPath`**
→ Kiểm tra Deployment Target = iOS 16.0 (đã set sẵn trong project).

**PDF trống**
→ `exportPDF()` cần `enhancedImage` khác nil — chỉ xảy ra nếu scan thật.
