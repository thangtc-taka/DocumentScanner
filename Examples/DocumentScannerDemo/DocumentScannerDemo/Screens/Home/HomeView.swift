import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Hero section
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 120, height: 120)

                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 56, weight: .light))
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }

                    VStack(spacing: 8) {
                        Text("DocumentScanner")
                            .font(.largeTitle.bold())

                        Text("Scan any document instantly.\nPerspective-corrected. GPU-enhanced.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }

                Spacer()

                // Feature pills
                VStack(spacing: 12) {
                    FeaturePill(icon: "cpu", label: "Neural Engine Detection", color: .blue)
                    FeaturePill(icon: "bolt.fill", label: "Metal GPU Enhancement", color: .orange)
                    FeaturePill(icon: "doc.fill", label: "PDF Export", color: .green)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Start Scan button
                startButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear { viewModel.onAppear() }
        .alert("Camera Access Required", isPresented: $viewModel.showPermissionAlert) {
            Button("Open Settings") { viewModel.openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable camera access in Settings to scan documents.")
        }
    }

    @ViewBuilder
    private var startButton: some View {
        Button(action: handleStartScan) {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.title3.bold())
                Text("Start Scanning")
                    .font(.title3.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .blue.opacity(0.4), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func handleStartScan() {
        switch viewModel.cameraPermission {
        case .granted:
            router.startScan()
        case .unknown:
            Task { await viewModel.requestPermission()
                if viewModel.cameraPermission == .granted {
                    router.startScan()
                }
            }
        case .denied, .restricted:
            viewModel.showPermissionAlert = true
        }
    }
}

// MARK: - Feature Pill

private struct FeaturePill: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout.bold())
                .foregroundColor(color)
                .frame(width: 32)

            Text(label)
                .font(.callout)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(color.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
