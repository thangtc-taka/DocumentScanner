# Contributing to DocumentScanner

Thank you for your interest in contributing to DocumentScanner! This document provides guidelines and instructions for contributing.

## Code of Conduct

Be respectful, inclusive, and constructive. We value diverse perspectives and welcome contributions from everyone.

## Getting Started

### 1. Fork & Clone

```bash
git clone https://github.com/YOUR_USERNAME/DocumentScanner.git
cd DocumentScanner
```

### 2. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

Use descriptive names:
- ✅ `feature/metal-optimization`
- ✅ `fix/detection-jitter`
- ✅ `docs/update-quickstart`
- ❌ `feature/fix`

### 3. Set Up Development Environment

```bash
# Build the package
xcodebuild -scheme DocumentScanner -destination 'generic/platform=iOS Simulator' build

# Run tests
xcodebuild -scheme DocumentScanner -destination 'platform=iOS Simulator,id=<UUID>' test
```

## Development Guidelines

### Code Style

- **Swift:** Follow [Apple's Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- **Naming:** Use descriptive, concise names (`documentDetector`, not `dd`)
- **Comments:** Only for the "why", not the "what" (code should be self-documenting)
- **Max line width:** 100 characters for readability

### Thread Safety

- All public types that are accessed from multiple threads must be `Sendable`
- Use `actor` for isolated state (not manual locks)
- Avoid `@unchecked Sendable` unless absolutely necessary (with clear comment)

### Formatting

```bash
# Format code (using swift-format if available)
swift-format -i -r Sources/ Tests/
```

### Testing

- Add tests for all new functionality
- Use Swift Testing (`@Test`, `#expect`)
- Aim for >80% code coverage
- Test both happy path and error cases

Example test:
```swift
@Suite("MyFeature")
struct MyFeatureTests {
    @Test("Does X when Y")
    func testXWhenY() {
        let result = doSomething()
        #expect(result == expected)
    }
}
```

## Making Changes

### Camera Layer Changes

If modifying `Sources/DocumentScanner/Camera/`:
- Test with real device (simulator camera is limited)
- Verify back-pressure behavior under slow detection
- Ensure no memory leaks with long-running sessions

### Detection Layer Changes

If modifying `Sources/DocumentScanner/Detection/`:
- Test with various document angles, lighting, backgrounds
- Verify temporal smoothing doesn't introduce lag
- Benchmark stability threshold tuning

### Metal/GPU Changes

If modifying `Sources/DocumentScanner/Metal/` or `Processing/ImageEnhancer.swift`:
- Test on both A12+ (Neural Engine) and non-ML devices
- Verify GPU pipeline memory is released
- Profile with Xcode Instruments (Metal Debugger, Allocation)

### UI/Public API Changes

If modifying public types or `DocumentScannerView`:
- Maintain backward compatibility
- Update all documentation
- Add examples to `HowToUse.md`
- Test on iOS 16.0, 17, 18

## Commit Message Guidelines

Write clear, descriptive commit messages:

```
Improve detection stability via adaptive thresholding

Add configurable blockRadius and offset parameters to Metal
adaptive threshold kernel. Allows tuning for different document
types and lighting conditions.

- Add adaptiveThresholdBlockRadius config parameter (default: 15)
- Add adaptiveThresholdOffset config parameter (default: -0.05)
- Update Metal kernel to use parameters
- Add tests for threshold edge cases
- Update documentation with tuning examples

Fixes #42
```

### Format

```
[Type] Summary (50 chars max)

[Detailed explanation (72 chars per line)]

[Related changes]
- Item 1
- Item 2

[References]
Fixes #123
Related #456
```

Types:
- `feat:` New feature
- `fix:` Bug fix
- `perf:` Performance improvement
- `refactor:` Code reorganization
- `docs:` Documentation
- `test:` Tests
- `chore:` Build, dependencies, etc.

## Pull Request Process

1. **Before opening PR:** Run tests locally
   ```bash
   xcodebuild -scheme DocumentScanner -destination 'platform=iOS Simulator,id=<UUID>' test
   ```

2. **Open PR with:**
   - Descriptive title
   - Summary of changes
   - Related issues (`Fixes #123`)
   - Testing notes (what you tested, how to verify)

3. **PR Template:**
   ```markdown
   ## Summary
   Brief description of what this PR does.

   ## Testing
   - [ ] Tested on iOS 16
   - [ ] Tested on iOS 17
   - [ ] Tested on iPhone SE (no ML)
   - [ ] All tests passing

   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Self-review completed
   - [ ] Comments added for complex logic
   - [ ] Documentation updated
   - [ ] Tests added/updated
   - [ ] No new warnings generated

   ## Screenshots (if UI changes)
   Before/after images for UI modifications
   ```

4. **Address review feedback:**
   - Respond to all comments
   - Make requested changes in new commits (don't amend)
   - Re-request review when ready

## Testing Checklist

Before submitting:

- [ ] `swift build` succeeds (iOS Simulator)
- [ ] All tests pass (`swift test`)
- [ ] No compiler warnings
- [ ] Tested on iOS 16.0 device (if possible)
- [ ] Tested on iOS 17+ device (if possible)
- [ ] Error cases handled
- [ ] Memory leaks checked (Instruments)
- [ ] Documentation updated

## Areas for Contribution

### Easy (Good for First-Time Contributors)
- Documentation improvements
- Test coverage for existing features
- Example apps or sample code
- Performance micro-benchmarks
- Build-time improvements

### Medium
- New enhancement modes (Color, HSL, etc.)
- Camera controls (zoom, exposure, focus)
- Batch scanning improvements
- Archive/export format support (ZIP, TIFF)

### Hard
- Alternative detection algorithms (ONNX, TensorFlow Lite)
- Real-time OCR integration
- Document classification (ID, passport, business card)
- Multi-page auto-segmentation
- Cloud storage integration (S3, GCS, Azure)

## Reporting Bugs

Open an issue with:
- iOS version and device model
- Steps to reproduce
- Expected vs actual behavior
- Code snippet or screenshot
- Xcode version

**Example:**
```
Title: Detection fails with extreme lighting

iOS: 17.2
Device: iPhone SE (3rd gen)
Xcode: 15.1

Steps to reproduce:
1. Open DocumentScanner in bright outdoor sunlight
2. Position document at angle > 60°
3. Wait for detection

Expected: Quad overlay appears
Actual: No detection after 5 seconds

Device logs show Metal errors:
[MTLCompilerError] ...
```

## Sharing Your Ideas

Have an idea but not ready to code? 
- Open a **Discussion** or **Issue** to gather feedback
- Tag with `idea:` or `discussion:`
- Include use case and motivation

## Recognition

Contributors will be recognized in:
- Commit history (git)
- Release notes
- Future contributors list

Thank you for making DocumentScanner better! 🙏
