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

    /// Выбранное устройство SmartView SDK (новые Samsung TV, 2015+)
    @Published var connectedService: Service?

    /// Выбранный DLNA MediaRenderer (старые Samsung и прочие DLNA-TV).
    /// Для стриминга экрана приоритет отдаётся DLNA (универсально), SmartView — fallback.
    @Published var connectedRenderer: DLNARenderer?
}
