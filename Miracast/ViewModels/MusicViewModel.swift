import SwiftUI
import MediaPlayer
import Combine

class MusicViewModel: ObservableObject {
    @Published var showAppleMusicAlert = false
    @Published var showSettingsAlert = false
    @Published var appleMusicAuthStatus: MPMediaLibraryAuthorizationStatus = MPMediaLibrary.authorizationStatus()

    func handleAppleMusicTap() {
        let status = MPMediaLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            showAppleMusicAlert = true
        case .denied, .restricted:
            showSettingsAlert = true
        case .authorized:
            // Здесь можно добавить действие при успешном доступе
            break
        @unknown default:
            break
        }
    }

    func requestAppleMusicAuth() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                self.appleMusicAuthStatus = status
                if status == .denied || status == .restricted {
                    self.showSettingsAlert = true
                }
            }
        }
    }
}
