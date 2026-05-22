import SwiftUI
import DocumentScanner

/// Central navigation state for the app.
/// Drives NavigationStack programmatically from any screen or ViewModel.
@MainActor
final class AppRouter: ObservableObject {

    /// Represents each destination in the navigation stack.
    enum Route: Hashable {
        case scan
        case result(UUID)       // UUID key; actual ScanResult stored in `results`
    }

    @Published var path = NavigationPath()

    // Store results by UUID so Route stays Hashable without wrapping ScannedDocument
    private(set) var results: [UUID: ScanResult] = [:]

    // MARK: - Navigation

    func startScan() {
        path.append(Route.scan)
    }

    func showResult(for result: ScanResult) {
        results[result.id] = result
        path.append(Route.result(result.id))
    }

    func goBackToHome() {
        path.removeLast(path.count)
        results.removeAll()
    }

    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func result(for id: UUID) -> ScanResult? {
        results[id]
    }
}
