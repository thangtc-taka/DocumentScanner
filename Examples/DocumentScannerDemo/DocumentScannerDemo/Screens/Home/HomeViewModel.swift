import Foundation
import UIKit
import AVFoundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var cameraPermission: CameraPermission = .unknown
    @Published var showPermissionAlert = false

    enum CameraPermission {
        case unknown, granted, denied, restricted
    }

    // MARK: - Lifecycle

    func onAppear() {
        checkPermission()
    }

    // MARK: - Camera Permission

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    cameraPermission = .granted
        case .denied:        cameraPermission = .denied
        case .restricted:    cameraPermission = .restricted
        case .notDetermined: cameraPermission = .unknown
        @unknown default:    cameraPermission = .unknown
        }
    }

    func requestPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraPermission = granted ? .granted : .denied
        if !granted { showPermissionAlert = true }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
