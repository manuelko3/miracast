import SwiftUI
import Combine
import Photos


class HomeViewModel: ObservableObject {
    @Published var showCastScreen = false
    @Published var showCastPhotos = false
    @Published var showVideoPicker = false
    @Published var selectedPhotos: [UIImage] = []
    // При выборе видео будем хранить URL-ы во внешнем AppState, но нужен флаг для показа пикера
    @Published var showCastVideos = false
    // Slideshow support
    @Published var showSlideshowPicker = false
    @Published var showCastSlideshow = false
    // YouTube support
    @Published var showCastYouTube = false
    @Published var services: [HomeService] = [
        .init(icon: "Main/screencast_icon", text: "Screen Cast", isAsset: true),
        .init(icon: "Main/photos_icon", text: "Photos", isAsset: true),
        .init(icon: "Main/videos_icon", text: "Videos", isAsset: true),
        .init(icon: "Main/slideshow_icon", text: "Slide - Show", isAsset: true),
        .init(icon: "Main/youtube_icon", text: "Youtube", isAsset: true),
        .init(icon: "Main/tiktok_icon", text: "Tik Tok", isAsset: true),
        .init(icon: "Main/twitch_icon", text: "Twitch", isAsset: true),
        .init(icon: "Main/kick_icon", text: "Kick", isAsset: true),
        .init(icon: "Main/netflix_icon", text: "Netflix", isAsset: true),
        .init(icon: "Main/word_icon", text: "Documents", isAsset: true),
        .init(icon: "Main/presentation_icon", text: "Presentations", isAsset: true),
        .init(icon: "Main/whiteboard_icon", text: "Whiteboard", isAsset: true),
        .init(icon: "Main/browser_icon", text: "Browser", isAsset: true),
        .init(icon: "Main/games_icon", text: "Games", isAsset: true)
    ]

    // For showing a custom alert directing user to Settings when access denied
    @Published var showPhotoSettingsAlert: Bool = false
    @Published var showVideoSettingsAlert: Bool = false
    // Show the system photo picker when access is available
    @Published var showPhotoPicker: Bool = false
    @Published var showWebService = false
    @Published var webServiceURL: URL? = nil
    @Published var webServiceTitle: String = ""
    @Published var showDocumentPicker = false
    @Published var showCastDocument = false
    @Published var selectedDocumentURL: URL? = nil

    func handleServiceTap(_ service: HomeService) {
        if service.text == "Screen Cast" {
            showCastScreen = true
            return
        }
        if service.text == "Photos" {
            requestPhotoAccess()
            return
        }
        if service.text == "Slide - Show" {
            // request access and open picker for slideshow
            requestPhotoAccessForSlideshow()
            return
        }
        if service.text == "Videos" {
            requestVideoAccess()
            return
        }
        if service.text == "Youtube" {
            webServiceURL = URL(string: "https://www.youtube.com")
            webServiceTitle = "Cast YouTube"
            showWebService = true
            return
        }
        if service.text == "Tik Tok" {
            webServiceURL = URL(string: "https://www.tiktok.com")
            webServiceTitle = "Cast TikTok"
            showWebService = true
            return
        }
        if service.text == "Twitch" {
            webServiceURL = URL(string: "https://www.twitch.tv")
            webServiceTitle = "Cast Twitch"
            showWebService = true
            return
        }
        if service.text == "Kick" {
            webServiceURL = URL(string: "https://www.kick.com")
            webServiceTitle = "Cast Kick"
            showWebService = true
            return
        }
        if service.text == "Netflix" {
            webServiceURL = URL(string: "https://www.netflix.com")
            webServiceTitle = "Cast Netflix"
            showWebService = true
            return
        }
        if service.text == "Documents" {
            requestDocumentAccess()
            return
        }
        if service.text == "Whiteboard" {
            // Переход к whiteboard экрану через AppState будет обрабатываться в HomeView
            return
        }
        // Здесь можно добавить обработку других сервисов
    }

    func showPhotosAfterSelection() {
        showCastPhotos = true
    }

    func showVideosAfterSelection() {
        showCastVideos = true
    }

    func showSlideshowAfterSelection() {
        showCastSlideshow = true
    }

    // Request access to Photo Library. Will show system prompt on .notDetermined.
    func requestPhotoAccess() {
        // For iOS 14+ use readWrite
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch current {
        case .authorized, .limited:
            // already allowed — present gallery
            DispatchQueue.main.async {
                self.showPhotoPicker = true
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized, .limited:
                        // granted — present gallery
                        self?.showPhotoPicker = true
                    case .denied, .restricted:
                        // user denied — show custom alert directing to Settings
                        self?.showPhotoSettingsAlert = true
                    default:
                        break
                    }
                }
            }
        case .denied, .restricted:
            // already denied — show alert to open Settings
            showPhotoSettingsAlert = true
        @unknown default:
            break
        }
    }

    // Request access specifically for slideshow flow
    func requestPhotoAccessForSlideshow() {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch current {
        case .authorized, .limited:
            DispatchQueue.main.async {
                self.showSlideshowPicker = true
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized, .limited:
                        self?.showSlideshowPicker = true
                    case .denied, .restricted:
                        self?.showPhotoSettingsAlert = true
                    default:
                        break
                    }
                }
            }
        case .denied, .restricted:
            showPhotoSettingsAlert = true
        @unknown default:
            break
        }
    }

    // Request access for videos: reuse the same photo library authorization flow
    func requestVideoAccess() {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch current {
        case .authorized, .limited:
            DispatchQueue.main.async {
                self.showVideoPicker = true
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized, .limited:
                        self?.showVideoPicker = true
                    case .denied, .restricted:
                        self?.showVideoSettingsAlert = true
                    default:
                        break
                    }
                }
            }
        case .denied, .restricted:
            showVideoSettingsAlert = true
        @unknown default:
            break
        }
    }

    // Запрос доступа к файлам через document picker
    func requestDocumentAccess() {
        // Просто показываем document picker, т.к. доступ запрашивается системой
        DispatchQueue.main.async {
            self.showDocumentPicker = true
        }
    }

    func showDocumentAfterSelection(url: URL) {
        selectedDocumentURL = url
        showCastDocument = true
    }
}
