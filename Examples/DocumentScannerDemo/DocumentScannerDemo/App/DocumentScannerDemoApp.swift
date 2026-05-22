import SwiftUI

@main
struct DocumentScannerDemoApp: App {
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                HomeView()
                    .navigationDestination(for: AppRouter.Route.self) { route in
                        switch route {
                        case .scan:
                            ScanView()
                        case .result(let id):
                            if let result = router.result(for: id) {
                                ResultView(result: result)
                            }
                        }
                    }
            }
            .environmentObject(router)
        }
    }
}
