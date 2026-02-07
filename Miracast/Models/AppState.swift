import Foundation
import Combine
import UIKit
import SmartView

/// Хранит глобальное состояние приложения
final class AppState: ObservableObject {
    @Published var showCastPhotos = false
    @Published var selectedPhotos: [UIImage] = []
    @Published var showCastVideos = false
    @Published var selectedVideoURLs: [URL] = []
    @Published var showCastSlideshow = false
    @Published var showWordDocumentScreen = false
    @Published var showWhiteboard = false
    @Published var showDeviceDiscovery = false
    @Published var isDeviceConnected = false
    @Published var connectedDeviceName = ""
    @Published var showCastYouTube = false
    @Published var showScreenMirroring = false

    /// Выбранное устройство SmartView
    @Published var connectedService: Service?
}
