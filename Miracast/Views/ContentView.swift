//
//  ContentView.swift
//  Miracast
//
//  Created by Yauheni Palupanau on 21/10/2025.
//

import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var showCastPhotos = false
    @Published var selectedPhotos: [UIImage] = []
    @Published var showCastVideos = false
    @Published var selectedVideoURLs: [URL] = []
    @Published var showCastSlideshow = false
    @Published var showWordDocumentScreen = false // новое состояние
}

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        if appState.showCastPhotos {
            CastPhotosView(initialImages: appState.selectedPhotos, onDismiss: {
                appState.showCastPhotos = false
            })
        } else if appState.showCastVideos {
            CastVideosView(initialVideos: appState.selectedVideoURLs, onDismiss: {
                // очистим ссылки на временные видео и закроем экран
                appState.selectedVideoURLs = []
                appState.showCastVideos = false
            })
        } else if appState.showCastSlideshow {
            CastSlideshowView(initialImages: appState.selectedPhotos, onDismiss: {
                // clear selected photos and close
                appState.selectedPhotos = []
                appState.showCastSlideshow = false
            })
        } else if appState.showWordDocumentScreen {
            WordDocumentScreen(isPresented: $appState.showWordDocumentScreen)
        } else {
            TabView {
                HomeView()
                    .environmentObject(appState)
                    .tabItem {
                        Image(systemName: "house")
                        Text("Home")
                    }
                MusicView()
                    .tabItem {
                        Image(systemName: "music.note")
                        Text("Music")
                    }
                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
            }
        }
    }
}

//#Preview {
//    ContentView()
//}
