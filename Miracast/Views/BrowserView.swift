import SwiftUI
import WebKit
import Combine

struct BrowserView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    @State private var selectedService: BrowserService?
    @State private var showWebView: Bool = false
    @State private var isCasting: Bool = false
    @StateObject private var webViewModel = WebViewModel()

    let popularServices: [BrowserService] = [
        BrowserService(name: "Apple", icon: "apple_browser", urlString: "https://www.apple.com"),
        BrowserService(name: "Dribbble", icon: "dribbble_browser", urlString: "https://www.dribbble.com"),
        BrowserService(name: "Youtube", icon: "Main/youtube_icon", urlString: "https://www.youtube.com"),
        BrowserService(name: "Twitter", icon: "twitter_browser", urlString: "https://www.twitter.com"),
        BrowserService(name: "Linkedin", icon: "linkedin_browser", urlString: "https://www.linkedin.com"),
        BrowserService(name: "Spotify", icon: "spotify_browser", urlString: "https://www.spotify.com"),
        BrowserService(name: "Edge", icon: "edge_browser", urlString: "https://www.bing.com"),
        BrowserService(name: "Yahoo", icon: "yahoo_browser", urlString: "https://www.yahoo.com")
    ]

    var body: some View {
        NavigationView {
            ZStack {
                // Используем общий градиент приложения для экранов без WebView,
                // а при показе WebView оставляем белый фон (чтобы WebView выглядел корректно).
                if showWebView {
                    Color.white.ignoresSafeArea()
                } else {
                    LinearGradient(gradient: Gradient(colors: [Color(red: 217/255, green: 233/255, blue: 255/255), Color.white]), startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: {
                            if showWebView {
                                showWebView = false
                            } else {
                                dismiss()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.black)
                        }

                        Spacer()

                        Text("Browser")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)

                        Spacer()

                        // Пустой элемент для баланса
                        Color.clear.frame(width: 24, height: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search", text: $searchText)
                            .font(.system(size: 16))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onSubmit {
                                performSearch()
                            }
                    }
                    .padding(12)
                    .background(Color(red: 242/255, green: 242/255, blue: 247/255))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    if showWebView {
                        // Ведём WebView по образцу `CastWebServiceView`: рабочая зона + нижняя выдвигающаяся панель
                        VStack(spacing: 0) {
                            // WebView (используем существующий WebView из CastWebServiceView)
                            WebView(viewModel: webViewModel)
                                .ignoresSafeArea(edges: .bottom)
                                .onAppear {
                                    if let service = selectedService, let url = URL(string: service.urlString) {
                                        webViewModel.open(url)
                                    }
                                }

                            // Нижняя панель: навигационная строка (стрелки, крестик),
                            // а под ней отдельная карточка с CastButton (как в скриншоте).
                            VStack(spacing: 12) {
                                // Верхняя линия панели: навигация и закрытие
                                HStack {
                                    Button(action: { webViewModel.goBack() }) {
                                        SymbolIcon(name: "chevron.left")
                                            .frame(width: 25, height: 25)
                                            .frame(width: 44, height: 60)
                                    }
                                    .disabled(!webViewModel.canGoBack)
                                    .opacity(webViewModel.canGoBack ? 1.0 : 0.3)
                                    .contentShape(Rectangle())

                                    Spacer().frame(width: 12)

                                    Button(action: { webViewModel.goForward() }) {
                                        SymbolIcon(name: "chevron.right")
                                            .frame(width: 25, height: 25)
                                            .frame(width: 44, height: 60)
                                    }
                                    .disabled(!webViewModel.canGoForward)
                                    .opacity(webViewModel.canGoForward ? 1.0 : 0.3)
                                    .contentShape(Rectangle())

                                    Spacer()

                                    Button(action: { showWebView = false; selectedService = nil }) {
                                        SymbolIcon(name: "xmark")
                                            .frame(width: 25, height: 25)
                                            .frame(width: 44, height: 60)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .padding(.horizontal, 21)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(Color.white)
                                .clipShape(RoundedCorner(radius: 20, corners: [.topLeft, .topRight]))
                                .overlay(
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 1),
                                    alignment: .top
                                )
                                .overlay(
                                    // Пилл-индикатор посередине панели
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.black)
                                        .frame(width: 140, height: 6)
                                        .offset(y: -18),
                                    alignment: .top
                                )

                                // Полноширинная CastButton без белого фона по бокам (как в других экранах)
                                CastButton(isCasting: $isCasting) {
                                    // start/stop cast
                                }
                                .frame(height: 56)
                                .padding(.horizontal, 16)
                                // Опускаем кнопку ниже, чтобы был отступ до индикатора (как в CastSlideshowView)
                                .padding(.bottom, 35)
                             }
                         }
                    } else {
                        // Popular section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Popular")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)

                            // Grid of services
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 24) {
                                ForEach(popularServices) { service in
                                    VStack(spacing: 8) {
                                        Button(action: {
                                            selectedService = service
                                            showWebView = true
                                        }) {
                                            Image(service.icon)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 60, height: 60)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }

                                        Text(service.name)
                                            .font(.system(size: 12))
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)

                            Spacer()

                            // Privacy Reports
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Privacy Reports")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)

                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.black)

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                                            Text("In the last seven days, Safari has prevented")
                                                .font(.system(size: 14))
                                                .foregroundColor(.black)
                                            Text("4")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.black)
                                        }
                                        Text("trackers from profiling you and hidden your IP address from unknown trackers.")
                                            .font(.system(size: 14))
                                            .foregroundColor(.black)
                                    }
                                }
                                .padding(16)
                                .background(Color(red: 242/255, green: 242/255, blue: 247/255))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                            // Start Cast button
                            CastButton(isCasting: $isCasting) {
                                // Start casting action
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // Функция для поиска через Google
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        let searchQuery = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let googleSearchURL = "https://www.google.com/search?q=\(searchQuery)"

        selectedService = BrowserService(
            name: "Google Search",
            icon: "magnifyingglass.circle.fill",
            urlString: googleSearchURL
        )
        showWebView = true
        if let url = URL(string: googleSearchURL) {
            webViewModel.open(url)
        }
    }
}

struct BrowserService: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let urlString: String
}
