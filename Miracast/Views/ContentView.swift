//
//  ContentView.swift
//  Miracast
//
//  Created by Yauheni Palupanau on 21/10/2025.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        TabView {
            HomeView()
                .environmentObject(appState)
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
            MusicView()
                .environmentObject(appState)
                .tabItem {
                    Image(systemName: "music.note")
                    Text("Music")
                }
            SettingsView()
                .environmentObject(appState)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
        // Present cast/photo/video/slideshow screens as full screen covers over the TabView
        .fullScreenCover(isPresented: $appState.showCastPhotos) {
            CastPhotosView(initialImages: appState.selectedPhotos, onDismiss: {
                appState.showCastPhotos = false
                // optionally clear selectedPhotos here if desired
            })
        }
        .fullScreenCover(isPresented: $appState.showCastVideos) {
            CastVideosView(initialVideos: appState.selectedVideoURLs, onDismiss: {
                appState.selectedVideoURLs = []
                appState.showCastVideos = false
            })
        }
        .fullScreenCover(isPresented: $appState.showCastSlideshow) {
            CastSlideshowView(initialImages: appState.selectedPhotos, onDismiss: {
                appState.selectedPhotos = []
                appState.showCastSlideshow = false
            })
        }
        .fullScreenCover(isPresented: $appState.showWordDocumentScreen) {
            WordDocumentScreen(isPresented: $appState.showWordDocumentScreen)
        }
        .fullScreenCover(isPresented: $appState.showWhiteboard) {
            WhiteboardMainView(isPresented: $appState.showWhiteboard)
        }
        .fullScreenCover(isPresented: $appState.showCastYouTube) {
            CastYouTubeView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $appState.showScreenMirroring) {
            ScreenMirroringView()
                .environmentObject(appState)
        }
    }
}

//#Preview {
//    ContentView()
//}
