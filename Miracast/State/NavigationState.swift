import Foundation
import Combine

/// Глобальные UI-флаги модальных экранов и full-screen cover'ов.
///
/// Хранятся в одном объекте чтобы любая вью могла открыть нужный экран
/// (например HomeView триггерит showCastYouTube, который рендерится в ContentView).
final class NavigationState: ObservableObject {
    @Published var showCastPhotos = false
    @Published var showCastVideos = false
    @Published var showCastSlideshow = false
    @Published var showWordDocumentScreen = false
    @Published var showWhiteboard = false
    @Published var showDeviceDiscovery = false
    @Published var showCastYouTube = false
}
