import Foundation
import Combine
import SmartView

/// Менеджер для работы с Samsung SmartView SDK
class SmartViewManager: NSObject, ObservableObject, ServiceSearchDelegate {
    @Published var isSearching: Bool = false
    @Published var discoveredDevices: [Service] = []
    @Published var connectedService: Service?
    @Published var isConnected: Bool = false

    private var search: ServiceSearch?
    private var discoveryCompletion: (([Service]) -> Void)?
    private var currentApplication: Application?

    override init() {
        super.init()
    }

    /// Начать поиск Samsung устройств
    func startDiscovery(completion: @escaping ([Service]) -> Void) {
        print("🔍 Starting SmartView SDK discovery...")
        isSearching = true
        discoveredDevices.removeAll()
        discoveryCompletion = completion

        // Создаем поиск с использованием SmartView SDK
        search = Service.search()
        search?.delegate = self

        // Запускаем поиск
        search?.start()

        // Останавливаем поиск через 15 секунд
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            self.stopDiscovery()
        }
    }

    /// Остановить поиск устройств
    func stopDiscovery() {
        print("🛑 Stopping SmartView SDK discovery...")
        search?.stop()
        search = nil
        isSearching = false
    }

    /// Подключиться к устройству Samsung
    func connect(to service: Service, completion: @escaping (Bool, Error?) -> Void) {
        print("🔗 Connecting to Samsung device: \(service.name)...")
        print("📱 Establishing connection with TV...")
        
        // Сохраняем сервис
        self.connectedService = service
        
        // ВАЖНО: Service готов к использованию сразу после обнаружения!
        // Для проверки соединения создадим тестовый канал
        let testChannel = service.createChannel("com.miracast.test")
        
        print("🚀 Testing connection to TV...")
        
        // Подключаемся к каналу для проверки связи
        testChannel.connect(nil) { [weak self] client, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to connect to TV: \(error.localizedDescription)")
                    print("   Make sure:")
                    print("   1. TV and iPhone are on the same Wi-Fi network")
                    print("   2. TV has Smart View enabled")
                    print("   3. No firewall blocking the connection")
                    self?.isConnected = false
                    self?.connectedService = nil
                    completion(false, error)
                    return
                }
                
                self?.isConnected = true
                print("✅ Successfully connected to Samsung TV!")
                print("📺 TV is ready to receive content")
                print("💡 You can now cast photos, videos, and browse web content")
                completion(true, nil)
            }
        }
    }

    /// Отключиться от устройства
    func disconnect() {
        print("🔌 Disconnecting from Samsung device...")

        // Очищаем ссылку на приложение
        // Note: Application не имеет явного метода disconnect
        // Освобождение ресурсов произойдет автоматически при обнулении ссылки
        currentApplication = nil
        connectedService = nil
        isConnected = false

        print("✅ Disconnected successfully")
    }

    /// Запустить приложение на Samsung TV
    func launchApplication(_ appId: String, channelURI: String = "com.miracast.app", completion: @escaping (Bool, Error?) -> Void) {
        guard let service = connectedService else {
            completion(false, NSError(domain: "SmartView", code: -1,
                                     userInfo: [NSLocalizedDescriptionKey: "Not connected to device"]))
            return
        }

        // Создаем приложение с правильными параметрами
        guard let application = service.createApplication(appId as AnyObject, channelURI: channelURI, args: nil) else {
            completion(false, NSError(domain: "SmartView", code: -1,
                                     userInfo: [NSLocalizedDescriptionKey: "Failed to create application"]))
            return
        }

        // Подключаемся к приложению
        application.connect(nil) { client, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to launch app: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }

                print("✅ Successfully launched application!")
                completion(true, nil)
            }
        }
    }

    /// Отправить URL на Samsung TV через канал
    func sendURL(_ urlString: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let service = connectedService else {
            completion(false, NSError(domain: "SmartView", code: -1,
                                     userInfo: [NSLocalizedDescriptionKey: "Not connected to device"]))
            return
        }

        guard URL(string: urlString) != nil else {
            completion(false, NSError(domain: "SmartView", code: -1,
                                     userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        // Создаем канал для отправки данных
        let channel = service.createChannel("com.miracast.browser")

        // Подключаемся к каналу
        channel.connect(nil) { client, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to connect to channel: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }

                // Отправляем URL через канал
                channel.publish(event: "openURL", message: ["url": urlString] as AnyObject)
                print("✅ Successfully sent URL to TV!")
                completion(true, nil)
            }
        }
    }

    /// Отправить фото на Samsung TV
    func sendPhoto(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        guard let service = connectedService else {
            completion(false, NSError(domain: "SmartView", code: -1,
                                     userInfo: [NSLocalizedDescriptionKey: "Not connected to device"]))
            return
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(false, NSError(domain: "SmartView", code: -1,
                                     userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"]))
            return
        }

        // Создаем временный URL для изображения
        let tempDir = FileManager.default.temporaryDirectory
        let imageURL = tempDir.appendingPathComponent("temp_image_\(UUID().uuidString).jpg")

        do {
            try imageData.write(to: imageURL)

            // Создаем PhotoPlayer для отправки фото
            let photoPlayer = service.createPhotoPlayer("Miracast")

            // Подключаемся к PhotoPlayer
            photoPlayer.standbyConnect(nil) { error in
                if let error = error {
                    // Удаляем временный файл
                    try? FileManager.default.removeItem(at: imageURL)
                    print("❌ Failed to connect PhotoPlayer: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }

                // Отправляем фото на TV
                photoPlayer.playContent(imageURL) { error in
                    DispatchQueue.main.async {
                        // Удаляем временный файл
                        try? FileManager.default.removeItem(at: imageURL)

                        if let error = error {
                            print("❌ Failed to send photo: \(error.localizedDescription)")
                            completion(false, error)
                            return
                        }

                        print("✅ Successfully sent photo to TV!")
                        completion(true, nil)
                    }
                }
            }
        } catch {
            print("❌ Failed to write image: \(error.localizedDescription)")
            completion(false, error)
        }
    }

    /// Отправить видео на Samsung TV
    func sendVideo(_ videoURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        guard let service = connectedService else {
            completion(false, NSError(domain: "SmartView", code: -1,
                                     userInfo: [NSLocalizedDescriptionKey: "Not connected to device"]))
            return
        }

        // Создаем VideoPlayer для отправки видео
        let videoPlayer = service.createVideoPlayer("Miracast")

        // Подключаемся к VideoPlayer
        videoPlayer.standbyConnect(nil) { error in
            if let error = error {
                print("❌ Failed to connect VideoPlayer: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            // Отправляем видео на TV
            videoPlayer.playContent(videoURL) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Failed to send video: \(error.localizedDescription)")
                        completion(false, error)
                        return
                    }

                    print("✅ Successfully sent video to TV!")
                    completion(true, nil)
                }
            }
        }
    }
}

// MARK: - ServiceSearchDelegate
extension SmartViewManager {
    /// Вызывается когда найдено новое устройство
    func onServiceFound(_ service: Service) {
        print("📱 SmartView found device: \(service.name)")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Добавляем устройство в список, если его там еще нет
            if !self.discoveredDevices.contains(where: { $0.id == service.id }) {
                self.discoveredDevices.append(service)
                self.discoveryCompletion?(self.discoveredDevices)
            }
        }
    }

    /// Вызывается когда устройство потеряно
    func onServiceLost(_ service: Service) {
        print("📴 SmartView lost device: \(service.name)")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.discoveredDevices.removeAll { $0.id == service.id }
            self.discoveryCompletion?(self.discoveredDevices)
        }
    }

    /// Вызывается когда поиск запущен
    func onStart() {
        print("🔍 SmartView search started")
    }

    /// Вызывается когда поиск остановлен
    func onStop() {
        print("🛑 SmartView search stopped")
    }
}
