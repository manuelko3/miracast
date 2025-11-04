import SwiftUI
import AVKit

struct CastVideosView: View {
    @State private var currentVideoIndex: Int = 0
    @State private var isCasting = false
    @State private var selectedVideoURLs: [URL] = []
    @State private var thumbnails: [UIImage?] = []
    @State private var showVideoPicker = false
    @State private var player: AVPlayer? = nil
    var initialVideos: [URL] = []
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top nav
                VStack(spacing: 0) {
                    ZStack {
                        Text("Cast Videos")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.black)
                            .kerning(0)
                            .lineLimit(1)
                            .lineSpacing(0)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)

                        HStack {
                            Button(action: { doCleanupAndDismiss() }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                .frame(width: 44, height: 44)
                            }
                            Spacer()
                            Button(action: { showVideoPicker = true }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 44)
                }
                .padding(.top, 12)
                .padding(.bottom, 12)

                Spacer(minLength: 0)

                if !selectedVideoURLs.isEmpty {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 18)

                        GeometryReader { geo in
                            let targetHeight = min(496, geo.size.height * 0.78)
                            VStack(spacing: 0) {
                                if let url = selectedVideoURLs[safe: currentVideoIndex] {
                                    // Use AVURLAsset + AVPlayerItem to create player (iOS 18 API guidance)
                                    VideoPlayer(player: player)
                                        .onAppear {
                                            let asset = AVURLAsset(url: url)
                                            let item = AVPlayerItem(asset: asset)
                                            player = AVPlayer(playerItem: item)
                                            player?.play()
                                        }
                                        .onChange(of: currentVideoIndex) { oldIndex, newIndex in
                                            if let newURL = selectedVideoURLs[safe: newIndex] {
                                                player?.pause()
                                                let asset = AVURLAsset(url: newURL)
                                                let item = AVPlayerItem(asset: asset)
                                                player = AVPlayer(playerItem: item)
                                                player?.play()
                                            }
                                        }
                                        .frame(width: geo.size.width, height: targetHeight, alignment: .top)
                                        .clipped()
                                }
                            }
                            .frame(height: targetHeight)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: min(496, UIScreen.main.bounds.height * 0.78))

                        Spacer().frame(height: 21)

                        // Thumbnails
                        if !thumbnails.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(thumbnails.indices, id: \.self) { index in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                currentVideoIndex = index
                                            }
                                        }) {
                                            let img = thumbnails[index] ?? UIImage(systemName: "video")!
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 72, height: 72)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle()
                                                        .stroke(currentVideoIndex == index ? Color(red: 62/255, green: 134/255, blue: 233/255) : Color.clear, lineWidth: 3)
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }

                Spacer().frame(height: 28)

                CastButton(isCasting: $isCasting)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 35)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $showVideoPicker) {
            VideoPicker(selectionLimit: 0) { urls in
                if !urls.isEmpty {
                    appendVideos(urls)
                }
                showVideoPicker = false
            }
        }
        .onAppear {
            selectedVideoURLs = initialVideos
            generateAllThumbnails()
            if !selectedVideoURLs.isEmpty {
                // initialize player with AVURLAsset as above
                let asset = AVURLAsset(url: selectedVideoURLs[currentVideoIndex])
                let item = AVPlayerItem(asset: asset)
                player = AVPlayer(playerItem: item)
                player?.play()
            }
        }
        .onChange(of: selectedVideoURLs) { old, new in
            // if videos removed, stop player
            if new.isEmpty {
                player?.pause()
                player = nil
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
            // clean up temp files when view disappears
            cleanupTempVideos()
        }
    }

    // Append new videos and generate thumbnails
    private func appendVideos(_ urls: [URL]) {
        // Append urls and reserve placeholder slots to keep indices aligned
        for url in urls {
            selectedVideoURLs.append(url)
            thumbnails.append(nil)
            let newIndex = thumbnails.count - 1
            generateThumbnail(for: url) { img in
                DispatchQueue.main.async {
                    thumbnails[newIndex] = img ?? UIImage(systemName: "video")
                }
            }
        }
    }

    private func generateAllThumbnails() {
        thumbnails = Array(repeating: nil, count: selectedVideoURLs.count)
        for (idx, url) in selectedVideoURLs.enumerated() {
            generateThumbnail(for: url) { img in
                DispatchQueue.main.async {
                    thumbnails[idx] = img ?? UIImage(systemName: "video")
                }
            }
        }
    }

    private func generateThumbnail(for url: URL, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Use AVURLAsset and async generator
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 200, height: 200)
            let time = CMTime(seconds: 1.0, preferredTimescale: 600)

            // Use async batch generation API to avoid deprecated copyCGImage
            let times = [NSValue(time: time)]
            gen.generateCGImagesAsynchronously(forTimes: times) { requestedTime, cgImage, actualTime, result, error in
                if let cgImage = cgImage {
                    let uiImage = UIImage(cgImage: cgImage)
                    DispatchQueue.main.async {
                        completion(uiImage)
                    }
                } else {
                    print("Thumbnail generation error:", error?.localizedDescription ?? "unknown")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
    }

    private func doCleanupAndDismiss() {
        cleanupTempVideos()
        onDismiss?()
    }

    private func cleanupTempVideos() {
        let tmp = FileManager.default.temporaryDirectory.path
        for url in selectedVideoURLs {
            let path = url.path
            if path.hasPrefix(tmp) {
                if FileManager.default.fileExists(atPath: path) {
                    do {
                        try FileManager.default.removeItem(at: url)
                    } catch {
                        // ignore errors but log
                        print("Failed to remove temp video at \(url): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// Safe index helper
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
