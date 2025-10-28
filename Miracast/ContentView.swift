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
