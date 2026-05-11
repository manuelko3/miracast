//
//  ContentView.swift
//  Miracast
//
//  Created by Yauheni Palupanau on 21/10/2025.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var connection = ConnectionState()
    @StateObject private var navigation = NavigationState()
    @StateObject private var media = MediaPickerState()

    var body: some View {
        TabView {
            HomeView()
                .environmentObject(connection)
                .environmentObject(navigation)
                .environmentObject(media)
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
            MusicView()
                .environmentObject(connection)
                .environmentObject(navigation)
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
        .fullScreenCover(isPresented: $navigation.showCastPhotos) {
            CastPhotosView(initialImages: media.selectedPhotos, onDismiss: {
                navigation.showCastPhotos = false
            })
        }
        .fullScreenCover(isPresented: $navigation.showCastVideos) {
            CastVideosView(initialVideos: media.selectedVideoURLs, onDismiss: {
                media.selectedVideoURLs = []
                navigation.showCastVideos = false
            })
        }
        .fullScreenCover(isPresented: $navigation.showCastSlideshow) {
            CastSlideshowView(initialImages: media.selectedPhotos, onDismiss: {
                media.selectedPhotos = []
                navigation.showCastSlideshow = false
            })
        }
        .fullScreenCover(isPresented: $navigation.showWordDocumentScreen) {
            WordDocumentScreen(isPresented: $navigation.showWordDocumentScreen)
        }
        .fullScreenCover(isPresented: $navigation.showWhiteboard) {
            WhiteboardMainView(isPresented: $navigation.showWhiteboard)
        }
        .fullScreenCover(isPresented: $navigation.showCastYouTube) {
            CastYouTubeView()
                .environmentObject(connection)
        }
    }
}

//#Preview {
//    ContentView()
//}
