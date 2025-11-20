import SwiftUI
import WebKit
import Combine

/// Экран для просмотра YouTube и трансляции на TV
struct CastYouTubeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CastYouTubeViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                // YouTube WebView
                YouTubeWebView(
                    url: $viewModel.currentURL,
                    onURLChange: { url in
                        viewModel.currentURL = url
                        viewModel.detectYouTubeVideo(from: url)
                    }
                )
                .edgesIgnoringSafeArea(.all)

                // Floating cast button when YouTube video detected
                if viewModel.isYouTubeVideoDetected {
                    VStack {
                        Spacer()

                        HStack {
                            Spacer()

                            Button(action: {
                                viewModel.castToTV(appState: appState)
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "tv")
                                        .font(.system(size: 20, weight: .semibold))
                                    Text("Cast to TV")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(30)
                                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .disabled(!appState.isDeviceConnected || viewModel.isCasting)
                            .opacity(viewModel.isCasting ? 0.6 : 1.0)

                            Spacer()
                        }
                        .padding(.bottom, 40)
                    }
                }

                // Loading indicator
                if viewModel.isCasting {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)

                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text("Casting to TV...")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .medium))
                        }
                        .padding(40)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(.blue)
                    }
                }

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill")
                            .foregroundColor(.red)
                        Text("YouTube")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if appState.isDeviceConnected {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Connected")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("Not Connected")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("Cast Result", isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }
}

// MARK: - ViewModel
class CastYouTubeViewModel: ObservableObject {
    @Published var currentURL: URL = URL(string: "https://www.youtube.com")!
    @Published var isYouTubeVideoDetected: Bool = false
    @Published var detectedVideoURL: URL?
    @Published var isCasting: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""

    private var smartViewManager = SmartViewManager()

    /// Определяет, является ли текущий URL видео на YouTube
    func detectYouTubeVideo(from url: URL) {
        let urlString = url.absoluteString

        // Проверяем, содержит ли URL видео ID
        let isVideo = urlString.contains("/watch?v=") || urlString.contains("youtu.be/")

        if isVideo {
            isYouTubeVideoDetected = true
            detectedVideoURL = url
            print("🎥 Detected YouTube video: \(urlString)")
        } else {
            isYouTubeVideoDetected = false
            detectedVideoURL = nil
        }
    }

    /// Отправляет YouTube видео на TV
    func castToTV(appState: AppState) {
        guard appState.isDeviceConnected else {
            alertMessage = "Please connect to a TV first"
            showAlert = true
            return
        }

        guard let videoURL = detectedVideoURL else {
            alertMessage = "No YouTube video detected. Please navigate to a video."
            showAlert = true
            return
        }

        isCasting = true

        // Используем SmartViewManager для отправки на TV
        smartViewManager.connectedService = appState.connectedService
        smartViewManager.sendYouTubeVideo(videoURL) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isCasting = false

                if success {
                    self?.alertMessage = """
                    ✅ Video sent to TV!
                    
                    The TV browser will open with the YouTube video.
                    
                    Note: The video will play in the TV's browser, not the YouTube app.
                    """
                } else {
                    self?.alertMessage = """
                    ❌ Failed to cast video
                    
                    \(error?.localizedDescription ?? "Unknown error")
                    
                    Make sure:
                    • TV and iPhone are on the same Wi-Fi
                    • Smart View is enabled on TV
                    """
                }

                self?.showAlert = true
            }
        }
    }
}

// MARK: - YouTube WebView
struct YouTubeWebView: UIViewRepresentable {
    @Binding var url: URL
    let onURLChange: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Загружаем YouTube
        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Обновляем только если URL изменился и это не текущий URL
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: YouTubeWebView

        init(_ parent: YouTubeWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let currentURL = webView.url {
                parent.onURLChange(currentURL)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                parent.onURLChange(url)
            }
            decisionHandler(.allow)
        }
    }
}

// MARK: - Preview
struct CastYouTubeView_Previews: PreviewProvider {
    static var previews: some View {
        CastYouTubeView()
            .environmentObject(AppState())
    }
}
