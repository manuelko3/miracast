import SwiftUI
import WebKit
import Combine
import UIKit

struct CastWebServiceView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var webViewModel = WebViewModel()
    let url: URL
    let title: String

    var body: some View {
        ZStack {
            // Градиентный фон как в других экранах
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 217/255, green: 233/255, blue: 255/255),
                    Color.white
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Верхняя панель с навигацией
                VStack(spacing: 0) {
                    ZStack {
                        // Центрированный заголовок
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)

                        // Кнопка назад слева
                        HStack {
                            Button(action: { dismiss() }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 245/255, green: 246/255, blue: 248/255))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                            }
                            Spacer()
                        }
                    }
                    .frame(height: 44)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 21)
                .padding(.bottom, 20) // увеличиваем отступ между верхней панелью и WebView
                .background(Color.clear)

                // WebView с YouTube
                WebView(viewModel: webViewModel)
                    .ignoresSafeArea(edges: .bottom)
                    .onAppear {
                        webViewModel.open(url)
                    }

                // Нижняя панель с навигацией (как на скрине)
                HStack {
                    // Левая кнопка (anchored к левому краю)
                    Button(action: { webViewModel.goBack() }) {
                        SymbolIcon(name: "chevron.left")
                            .frame(width: 25, height: 25)
                            .frame(width: 44, height: 60)
                    }
                    .disabled(!webViewModel.canGoBack)
                    .opacity(webViewModel.canGoBack ? 1.0 : 0.3)
                    .contentShape(Rectangle())

                    // Фиксированный небольшой отступ между левой и средней стрелками.
                    // При ширине интерактивных зон 44pt и боковом padding 21pt это даёт center-to-center = 56pt.
                    Spacer().frame(width: 12)

                    // Средняя кнопка
                    Button(action: { webViewModel.goForward() }) {
                        SymbolIcon(name: "chevron.right")
                            .frame(width: 25, height: 25)
                            .frame(width: 44, height: 60)
                    }
                    .disabled(!webViewModel.canGoForward)
                    .opacity(webViewModel.canGoForward ? 1.0 : 0.3)
                    .contentShape(Rectangle())

                    // Гибкий отступ между средней и правой кнопкой
                    Spacer()

                    // Правая кнопка (anchored к правому краю)
                    Button(action: { dismiss() }) {
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
                    // Пилл-индикатор посередине панели (как на скрине)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black)
                        .frame(width: 140, height: 6)
                        .offset(y: -18),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

// WebView wrapper для UIKit WKWebView
struct WebView: UIViewRepresentable {
    @ObservedObject var viewModel: WebViewModel

    func makeUIView(context: Context) -> WKWebView {
        // Use a default configuration without injecting JS to avoid interfering with
        // complex site scripts (YouTube). Let WKUIDelegate/decidePolicy handle
        // navigation behavior where appropriate.
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Привязываем созданный WKWebView к viewModel, чтобы можно было управлять навигацией напрямую
        viewModel.webView = webView

        // Синхронизируем начальное состояние доступности навигации
        DispatchQueue.main.async {
            self.viewModel.canGoBack = webView.canGoBack
            self.viewModel.canGoForward = webView.canGoForward
        }

        // Настраиваем KVO-наблюдение в Coordinator, чтобы надёжно отслеживать canGoBack/canGoForward
        context.coordinator.observe(webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Navigation is handled directly by WebViewModel via the weak `webView` reference.
        // Coordinator updates `canGoBack`/`canGoForward` on navigation events.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        private var canGoBackObservation: NSKeyValueObservation?
        private var canGoForwardObservation: NSKeyValueObservation?

        init(_ parent: WebView) {
            self.parent = parent
        }

        deinit {
            canGoBackObservation?.invalidate()
            canGoForwardObservation?.invalidate()
        }

        func observe(_ webView: WKWebView) {
            // Observe canGoBack and canGoForward KVO to update state immediately
            canGoBackObservation = webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.viewModel.canGoBack = wv.canGoBack
                }
            }

            canGoForwardObservation = webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.viewModel.canGoForward = wv.canGoForward
                }
            }
        }

        // MARK: - WKUIDelegate helpers to handle target=_blank and new window requests
        // This ensures links that try to open a new window are loaded in the same webView,
        // so navigation history is preserved and canGoBack/canGoForward update correctly.

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // We don't create a new web view here. Return nil to let the app decide in
            // decidePolicyFor navigationAction. Avoid loading the request here to prevent
            // re-entrant policy handling that can break sites like YouTube.
            return nil
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            // Simple JS alert handling: just dismiss
            completionHandler()
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            completionHandler(true)
        }

        // Also handle navigationAction policy: if targetFrame is nil (open in new window), load in same webView
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Мы уже исправляем window.open/target=_blank через injected JS,
            // поэтому тут просто разрешаем навигацию и не делаем дополнительной загрузки,
            // чтобы избежать re-entrancy и ошибок WebKit.
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // При старте навигации обновим состояние (например, при редиректах)
            DispatchQueue.main.async {
                self.parent.viewModel.canGoBack = webView.canGoBack
                self.parent.viewModel.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.canGoBack = webView.canGoBack
                self.parent.viewModel.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.viewModel.canGoBack = webView.canGoBack
                self.parent.viewModel.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.viewModel.canGoBack = webView.canGoBack
                self.parent.viewModel.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.viewModel.canGoBack = webView.canGoBack
                self.parent.viewModel.canGoForward = webView.canGoForward
            }
        }
    }
}

// ViewModel для управления WebView
class WebViewModel: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false

    // Ссылка на реальный WKWebView. Устанавливается в makeUIView(_:)
    weak var webView: WKWebView?

    // Навигационные методы — вызывают WKWebView напрямую
    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }

    // Открыть URL (опционально)
    func open(_ url: URL) {
        webView?.load(URLRequest(url: url))
    }
}

struct CastWebServiceView_Previews: PreviewProvider {
    static var previews: some View {
        CastWebServiceView(url: URL(string: "https://www.youtube.com")!, title: "YouTube")
    }
}

// Вспомогательная Shape для скругления только верхних углов
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Вспомогательный компонент: гарантирует точный визуальный размер SF Symbol через UIImage.SymbolConfiguration
struct SymbolIcon: View {
    let name: String
    var body: some View {
        // Визуальный размер 25×25, чуть жирнее для читаемости
        let cfg = UIImage.SymbolConfiguration(pointSize: 25, weight: .medium, scale: .small)
        if let ui = UIImage(systemName: name, withConfiguration: cfg) {
            Image(uiImage: ui)
                .renderingMode(.template)
                .foregroundColor(.black)
                .frame(width: 25, height: 25)
                .fixedSize()
        } else {
            Image(systemName: name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 25, height: 25)
                .foregroundColor(.black)
                .fixedSize()
        }
    }
}
