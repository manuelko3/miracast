import Foundation

/// DIAL (Discovery and Launch) — стандарт от Netflix/YouTube для запуска
/// зарегистрированных приложений на Smart TV.
///
/// Поддерживается большинством стриминг-устройств: Chromecast, Fire TV / Fire Stick,
/// Roku, Nvidia Shield, многие Smart TV.
///
/// **Ограничения**: DIAL не умеет стримить произвольный контент — только запускать
/// конкретные приложения (YouTube, Netflix, Prime Video). Для AirPlay-отсутствующих
/// Chromecast/Fire TV устройств мы используем DIAL как *фолбэк* для запуска YouTube
/// с конкретным video ID.
///
/// Discovery DIAL-устройств уже происходит в `DLNADiscovery` через SSDP M-SEARCH с
/// `urn:dial-multiscreen-org:service:dial:1`. Здесь — только вызовы DIAL REST API.
final class DIALController {

    /// Запустить YouTube на DIAL-устройстве с конкретным video ID.
    /// Обнаружение DIAL REST endpoint'а идёт через GET на корень device description —
    /// сервер возвращает заголовок `Application-URL`, по которому потом делаем POST.
    func launchYouTube(videoID: String,
                       deviceHost: String,
                       dialLocation: URL,
                       completion: @escaping (Result<Void, Error>) -> Void) {
        fetchApplicationURL(from: dialLocation) { [weak self] result in
            switch result {
            case .failure(let e):
                completion(.failure(e))
            case .success(let appsURL):
                let target = appsURL.appendingPathComponent("YouTube")
                self?.post(url: target,
                           body: "v=\(videoID)",
                           contentType: "application/x-www-form-urlencoded",
                           completion: completion)
            }
        }
    }

    // MARK: - Private

    private func fetchApplicationURL(from description: URL,
                                     completion: @escaping (Result<URL, Error>) -> Void) {
        var req = URLRequest(url: description, timeoutInterval: 4)
        req.httpMethod = "GET"
        URLSession.shared.dataTask(with: req) { _, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "DIAL", code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: "Bad response"])))
                return
            }
            // Регистронезависимый поиск заголовка.
            var appsURLString: String?
            for (k, v) in http.allHeaderFields {
                if let key = k as? String, key.lowercased() == "application-url" {
                    appsURLString = v as? String
                    break
                }
            }
            guard let s = appsURLString, let url = URL(string: s) else {
                completion(.failure(NSError(domain: "DIAL", code: -2,
                                            userInfo: [NSLocalizedDescriptionKey: "No Application-URL header"])))
                return
            }
            completion(.success(url))
        }.resume()
    }

    private func post(url: URL,
                      body: String,
                      contentType: String,
                      completion: @escaping (Result<Void, Error>) -> Void) {
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = "POST"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
        URLSession.shared.dataTask(with: req) { _, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }; return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "DIAL", code: -3,
                                               userInfo: [NSLocalizedDescriptionKey: "Bad response"])))
                }; return
            }
            if (200..<300).contains(http.statusCode) {
                DispatchQueue.main.async { completion(.success(())) }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "DIAL", code: http.statusCode,
                                               userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])))
                }
            }
        }.resume()
    }
}
