import SwiftUI
import AVKit
import AVFoundation

struct CastSlideshowView: View {
    @State private var isRendering: Bool = false
    @State private var renderProgress: Double = 0
    @State private var outputURL: URL? = nil
    @State private var player: AVPlayer? = nil
    @State private var showOptionsSheet: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var showReorderSheet: Bool = false
    @State private var showDurationPicker: Bool = false
    @State private var showMusicPicker: Bool = false
    @State private var isPlaying: Bool = true
    @State private var tempURLsToCleanup: [URL] = []
    @State private var selectedImages: [UIImage] = []
    @State private var selectedDuration: Double = 30
    @State private var selectedMusicURL: URL? = nil
    @State private var optionsButtonFrame: CGRect = .zero

    var initialImages: [UIImage] = []
    var onDismiss: (() -> Void)? = nil

    // Configure slideshow duration
    private var totalDurationSeconds: Double { selectedDuration }
    private let fps: Int32 = 30

    var body: some View {
        ZStack {
            // Background gradient same as others
            LinearGradient(gradient: Gradient(colors: [Color(red: 217/255, green: 233/255, blue: 255/255), Color.white]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation
                VStack(spacing: 0) {
                    ZStack {
                        Text("Slide - Show")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.black)

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
                            }
                            Spacer()
                            Menu {
                                Button {
                                    showPhotoPicker = true
                                } label: {
                                    Label("Add", systemImage: "photo.badge.plus")
                                }
                                Button {
                                    showReorderSheet = true
                                } label: {
                                    Label("Reorder", systemImage: "arrow.up.arrow.down")
                                }
                                Button {
                                    showDurationPicker = true
                                } label: {
                                    Label("Duration", systemImage: "clock")
                                }
                                Button {
                                    showMusicPicker = true
                                } label: {
                                    Label("Music", systemImage: "music.note")
                                }
                                Button {
                                    shareVideo()
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 44)
                }
                .padding(.top, 12)
                .padding(.bottom, 12)

                Spacer()

                // Player or rendering indicator
                if let url = outputURL {
                    VideoPlayer(player: player)
                        .onAppear {
                            if player == nil {
                                player = AVPlayer(url: url)
                                player?.play()
                            }
                        }
                        .onDisappear {
                            player?.pause()
                            player = nil
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        if isRendering {
                            ProgressView(value: renderProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .padding(.horizontal, 24)
                            Text("Rendering slideshow... \(Int(renderProgress * 100))%")
                                .foregroundColor(.gray)
                        } else {
                            Text("Preparing slideshow")
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer()

                // Cast button at bottom
                CastButton(isCasting: .constant(false))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 35)
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(didFinishPicking: { newImages in
                selectedImages.append(contentsOf: newImages)
                needsRerender()
            })
        }
        .sheet(isPresented: $showReorderSheet) {
            ReorderPhotosSheet(images: $selectedImages, onSave: {
                showReorderSheet = false
                needsRerender()
            })
        }
        .overlay(
            Group {
                if showDurationPicker {
                    DurationPickerActionSheet(
                        isPresented: $showDurationPicker,
                        selectedDuration: $selectedDuration
                    ) { newValue in
                        needsRerender()
                    }
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
                }
            }
        )
        .sheet(isPresented: $showMusicPicker) {
            MusicPickerSheet(selectedMusicURL: $selectedMusicURL, onSave: {
                showMusicPicker = false
                needsRerender()
            })
        }
        .onDisappear {
            cleanupTempFiles()
        }
    }

    private func startRenderingIfNeeded() {
        guard outputURL == nil, !isRendering else { return }
        let images = selectedImages
        guard !images.isEmpty else { return }
        isRendering = true
        renderProgress = 0

        DispatchQueue.global(qos: .userInitiated).async {
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "slideshow-\(UUID().uuidString).mp4"
            let dest = tempDir.appendingPathComponent(filename)

            // Asynchronous rendering with completion handler
            createSlideshowVideoAsync(from: images, to: dest, duration: totalDurationSeconds, fps: fps, progress: { prog in
                DispatchQueue.main.async {
                    renderProgress = prog
                }
            }) { success in
                DispatchQueue.main.async {
                    self.isRendering = false
                    if success {
                        self.outputURL = dest
                        self.tempURLsToCleanup.append(dest)
                        self.player = AVPlayer(url: dest)
                        self.player?.play()
                    } else {
                        // failed — leave outputURL nil
                    }
                }
            }
        }
    }

    // Async version of the slideshow creator — calls completion(success) when finished
    private func createSlideshowVideoAsync(from images: [UIImage], to outputURL: URL, duration: Double, fps: Int32, progress: @escaping (Double) -> Void, completion: @escaping (Bool) -> Void) {
        // Setup writer
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1080,
            AVVideoHeightKey: 1920
        ]

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else { completion(false); return }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: 1080,
            kCVPixelBufferHeightKey as String: 1920
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: sourceAttributes)

        guard writer.canAdd(input) else { completion(false); return }
        writer.add(input)

        let fpsValue = fps
        let totalFrames = Int(duration * Double(fpsValue))
        let framesPerImage = max(1, totalFrames / images.count)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let queue = DispatchQueue(label: "slideshow.writer")
        var currentFrame = 0

        input.requestMediaDataWhenReady(on: queue) {
            while input.isReadyForMoreMediaData && currentFrame < totalFrames {
                autoreleasepool {
                    let imageIndex = min(images.count - 1, currentFrame / framesPerImage)
                    let img = images[imageIndex]
                    guard let px = pixelBufferFromImage(img, size: CGSize(width: 1080, height: 1920), pixelBufferPool: adaptor.pixelBufferPool) else {
                        print("Failed to create pixel buffer for frame \(currentFrame)")
                        input.markAsFinished()
                        writer.finishWriting(completionHandler: {
                            completion(false)
                        })
                        return
                    }

                    let presentationTime = CMTime(value: CMTimeValue(currentFrame), timescale: fpsValue)
                    if !adaptor.append(px, withPresentationTime: presentationTime) {
                        print("Failed to append pixel buffer at frame \(currentFrame)")
                        input.markAsFinished()
                        writer.finishWriting(completionHandler: {
                            completion(false)
                        })
                        return
                    }

                    currentFrame += 1
                    if currentFrame % 10 == 0 {
                        let prog = Double(currentFrame) / Double(totalFrames)
                        progress(prog)
                    }
                }
            }

            if currentFrame >= totalFrames {
                input.markAsFinished()
                writer.finishWriting(completionHandler: {
                    if writer.status == .completed {
                        progress(1.0)
                        completion(true)
                    } else {
                        print("Writer finished with status: \(writer.status)")
                        completion(false)
                    }
                })
            }
        }
    }

    private func doCleanupAndDismiss() {
        cleanupTempFiles()
        onDismiss?()
    }

    private func cleanupTempFiles() {
        for url in tempURLsToCleanup {
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    print("Failed to remove temp slideshow file \(url): \(error.localizedDescription)")
                }
            }
        }
        tempURLsToCleanup.removeAll()
    }

    private func needsRerender() {
        // Reset and re-render
        player?.pause()
        player = nil
        outputURL = nil
        if let oldURL = tempURLsToCleanup.last {
            try? FileManager.default.removeItem(at: oldURL)
            tempURLsToCleanup.removeLast()
        }
        startRenderingIfNeeded()
    }

    private func shareVideo() {
        guard let url = outputURL else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Video creation
    private func pixelBufferFromImage(_ image: UIImage, size: CGSize, pixelBufferPool: CVPixelBufferPool?) -> CVPixelBuffer? {
        guard let pool = pixelBufferPool else { return nil }
        var px: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &px)
        guard status == kCVReturnSuccess, let pixelBuffer = px else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            return nil
        }

        // Fill background white
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Compute aspect fill rect
        let imgSize = image.size
        let scale = max(size.width / imgSize.width, size.height / imgSize.height)
        let scaledWidth = imgSize.width * scale
        let scaledHeight = imgSize.height * scale
        let x = (size.width - scaledWidth) / 2.0
        let y = (size.height - scaledHeight) / 2.0

        // Draw image
        if let cg = image.cgImage {
            context.draw(cg, in: CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight))
        } else if let ci = CIImage(image: image) {
            let ctx = CIContext(options: nil)
            if let cg = ctx.createCGImage(ci, from: ci.extent) {
                context.draw(cg, in: CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight))
            }
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        return pixelBuffer
    }
}
