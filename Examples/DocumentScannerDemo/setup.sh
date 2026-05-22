#!/bin/bash
# ============================================================
# DocumentScannerDemo — Auto-create Xcode project using xcodegen
# Run this script once to generate the .xcodeproj
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "📦 DocumentScannerDemo — Xcode Project Setup"
echo "============================================="

# Check xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    echo ""
    echo "⚠️  xcodegen not found. Install it first:"
    echo "   brew install xcodegen"
    echo ""
    echo "After installing, run this script again."
    exit 1
fi

# Generate project.yml for xcodegen
cat > project.yml << 'YAML'
name: DocumentScannerDemo
options:
  bundleIdPrefix: com.documentscanner
  deploymentTarget:
    iOS: "16.0"

packages:
  DocumentScanner:
    path: ../..

targets:
  DocumentScannerDemo:
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    sources:
      - path: Sources/DocumentScannerDemo
    settings:
      base:
        INFOPLIST_FILE: Sources/DocumentScannerDemo/App/Info.plist
        SWIFT_VERSION: 5.9
        PRODUCT_BUNDLE_IDENTIFIER: com.documentscanner.demo
    dependencies:
      - package: DocumentScanner
        product: DocumentScanner
    info:
      path: Sources/DocumentScannerDemo/App/Info.plist
      properties:
        NSCameraUsageDescription: "DocumentScanner needs camera access to scan documents in real time."
        UILaunchScreen: {}
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
YAML

echo "📝 Generated project.yml"

xcodegen generate
echo ""
echo "✅ DocumentScannerDemo.xcodeproj created!"
echo ""
echo "Next steps:"
echo "  1. open DocumentScannerDemo.xcodeproj"
echo "  2. Select your team in Signing & Capabilities"
echo "  3. Run on a real device for camera support"
echo ""
echo "Note: Camera does not work in the Simulator."
