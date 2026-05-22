import SwiftUI
import DocumentScanner

struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @EnvironmentObject private var router: AppRouter

    private let configuration: DocumentScannerConfiguration = {
        var config = DocumentScannerConfiguration()
        config.enhancementMode = .blackAndWhite
        config.pageSize = .a4
        config.smoothingBufferSize = 5
        return config
    }()

    var body: some View {
        DocumentScannerView(
            configuration: configuration,
            onCapture: { _ in
                // Handled directly via controller in the overlay
            },
            overlay: { controller in
                ScanOverlay(viewModel: viewModel, controller: controller)
            }
        )
        .ignoresSafeArea()
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: router.goBack) {
                    Image(systemName: "xmark")
                        .font(.body.bold())
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
        .alert("Scan Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
    }
}

// MARK: - Scan Overlay

private struct ScanOverlay: View {
    @ObservedObject var viewModel: ScanViewModel
    let controller: DocumentScannerController
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            // Top status bar
            VStack {
                statusBadge
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                Spacer()
            }

            // Bottom controls
            VStack {
                Spacer()
                bottomBar
            }
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                Circle()
                    .fill(controller.isDocumentStable ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .overlay {
                        if controller.isDocumentStable {
                            Circle()
                                .stroke(Color.green.opacity(0.5), lineWidth: 3)
                                .scaleEffect(1.6)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: controller.isDocumentStable)
                        }
                    }

                Text(statusText)
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.6)))
            Spacer()
        }
    }

    private var statusText: String {
        switch viewModel.captureState {
        case .idle:       return controller.isDocumentStable ? "Document detected — tap to capture" : "Looking for document…"
        case .capturing:  return "Capturing…"
        case .processing: return "Processing…"
        case .done:       return "Done!"
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 20) {
            // Enhancement mode indicator
            HStack(spacing: 16) {
                ModeChip(label: "B&W", icon: "circle.lefthalf.filled", active: true)
                ModeChip(label: "A4", icon: "doc", active: true)
            }

            // Shutter button
            ShutterButton(
                isReady: controller.isDocumentStable,
                isLoading: viewModel.captureState == .processing || viewModel.captureState == .capturing,
                action: { capture(controller: controller) }
            )
        }
        .padding(.bottom, 48)
        .padding(.horizontal, 24)
    }

    private func capture(controller: DocumentScannerController) {
        Task {
            guard let result = await viewModel.capture(using: controller) else { return }
            router.showResult(for: result)
        }
    }
}

// MARK: - Shutter Button

private struct ShutterButton: View {
    let isReady: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white.opacity(isReady ? 1 : 0.5), lineWidth: 4)
                    .frame(width: 80, height: 80)

                // Inner circle
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                } else {
                    Circle()
                        .fill(isReady ? Color.white : Color.gray)
                        .frame(width: 62, height: 62)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.2), value: isReady)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Mode Chip

private struct ModeChip: View {
    let label: String
    let icon: String
    let active: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.bold())
            Text(label)
                .font(.caption.bold())
        }
        .foregroundColor(active ? .white : .gray)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(active ? Color.white.opacity(0.2) : Color.clear)
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
        )
    }
}
