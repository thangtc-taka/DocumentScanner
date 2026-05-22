import SwiftUI
import PDFKit
import DocumentScanner

struct ResultView: View {
    @StateObject private var viewModel: ResultViewModel
    @EnvironmentObject private var router: AppRouter

    init(result: ScanResult) {
        _viewModel = StateObject(wrappedValue: ResultViewModel(result: result))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Document preview card
                documentPreviewCard

                // Image mode picker
                imageModePicker

                // Metadata section
                metadataSection

                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Scan Result")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: router.goBackToHome) {
                    HStack(spacing: 4) {
                        Image(systemName: "house")
                        Text("Home")
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let url = viewModel.exportedPDFURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $viewModel.showPDFPreview) {
            if let url = viewModel.exportedPDFURL {
                PDFPreviewView(url: url)
            }
        }
        .alert("Notice", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Document Preview Card

    private var documentPreviewCard: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: viewModel.displayedImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

            // Success badge
            Label("Scanned", systemImage: "checkmark.seal.fill")
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green)
                .clipShape(Capsule())
                .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Image Mode Picker

    private var imageModePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("View Mode")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            Picker("Mode", selection: $viewModel.selectedImageMode) {
                ForEach(ResultViewModel.ImageMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(spacing: 0) {
            MetadataRow(label: "Captured", value: viewModel.result.capturedAt.formatted(date: .abbreviated, time: .shortened))
            Divider().padding(.horizontal, 16)
            MetadataRow(label: "Enhancement", value: "Black & White (GPU)")
            Divider().padding(.horizontal, 16)
            MetadataRow(label: "Page Size", value: "A4 (595 × 842 pt)")
            Divider().padding(.horizontal, 16)
            MetadataRow(label: "Format", value: "JPEG + PDF")
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary: Export PDF
            Button(action: { Task { await viewModel.exportPDF() } }) {
                HStack {
                    if viewModel.isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "doc.richtext.fill")
                    }
                    Text(viewModel.isExporting ? "Generating PDF…" : "View as PDF")
                        .font(.body.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isExporting)

            // Secondary: Share
            Button(action: { Task { await viewModel.shareDocument() } }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Document")
                        .font(.body.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemGroupedBackground))
                .foregroundColor(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isExporting)

            // Tertiary: Save to Files
            Button(action: { Task { await viewModel.saveToFiles() } }) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("Save to Files")
                        .font(.body.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemGroupedBackground))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isExporting)

            // Scan again
            Button(action: {
                router.goBack()
                router.startScan()
            }) {
                Label("Scan Another Document", systemImage: "camera.fill")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - MetadataRow

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - PDFPreviewView (UIViewRepresentable)

struct PDFPreviewView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - ShareSheet (UIActivityViewController)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
