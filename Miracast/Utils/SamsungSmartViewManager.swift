import Foundation
import SmartView
import Combine

/// Менеджер для реального подключения к Samsung Smart TV через Smart View SDK
class SamsungSmartViewManager: NSObject, ObservableObject {
    static let shared = SamsungSmartViewManager()

    @Published var isConnected: Bool = false
    @Published var connectedDevice: Service?
    @Published var discoveredDevices: [Service] = []
    @Published var connectionError: String?

    private var serviceSearch: ServiceSearch?
    private var application: Application?
    private var channelClient: ChannelClient?

    override init() {
        super.init()
        setupSearch()
    }

    // MARK: - Device Discovery

    private func setupSearch() {
        // Создаем поиск устройств Samsung Smart TV
        serviceSearch = Service.search()
        serviceSearch?.delegate = self
    }

    func startDiscovery() {
        print("🔍 Starting Samsung Smart TV discovery...")
        serviceSearch?.start()
    }

    func stopDiscovery() {
        print("🛑 Stopping Samsung Smart TV discovery...")
        serviceSearch?.stop()
    }

    // MARK: - Connection

    /// Подключиться к Samsung TV
    func connect(to service: Service, appName: String = "Miracast App", completion: @escaping (Bool, String?) -> Void) {
        print("🔌 Connecting to Samsung TV: \(service.name)")

        // Создаем приложение для подключения
        let channelURI = "com.miracast.channel"

        // Если у вас есть веб-приложение на TV, используйте его URL
        // Если нет - можно использовать пустой словарь args
        let appURL = NSURL(string: "http://miracast.app")!

        application = service.createApplication(appURL, channelURI: channelURI, args: nil)
        application?.connectionTimeout = 10.0
        application?.delegate = self

        // Подключаемся к приложению (оно запустится автоматически если не запущено)
        application?.connect(nil) { [weak self] (client, error) in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let client = client {
                    self.isConnected = true
                    self.connectedDevice = service
                    self.channelClient = client
                    print("✅ Successfully connected to Samsung TV: \(service.name)")
                    completion(true, nil)
                } else {
                    let errorMessage = error?.localizedDescription ?? "Unknown error"
                    self.connectionError = errorMessage
                    self.isConnected = false
                    print("❌ Connection error: \(errorMessage)")
                    completion(false, errorMessage)
                }
            }
        }
    }

    /// Отключиться от Samsung TV
    func disconnect() {
        print("🔌 Disconnecting from Samsung TV...")

        application?.disconnect(leaveHostRunning: false) { (client, error) in
            if let error = error {
                print("⚠️ Disconnect error: \(error.localizedDescription)")
            }
        }

        application = nil
        channelClient = nil

        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedDevice = nil
        }
    }

    // MARK: - Media Control

    // Для воспроизведения медиа используйте специальные классы Samsung SDK:
    // - AudioPlayer для аудио
    // - VideoPlayer для видео
    // - PhotoPlayer для фото
    //
    // Пример:
    // let videoPlayer = service.createVideoPlayer()
    // videoPlayer.playContent(videoURL, title: "My Video", thumbnailURL: thumbURL) { error in
    //     if let error = error {
    //         print("Error: \(error)")
    //     }
    // }
}

// MARK: - ServiceSearchDelegate

extension SamsungSmartViewManager: ServiceSearchDelegate {
    func onServiceFound(_ service: Service) {
        DispatchQueue.main.async {
            print("📺 Samsung TV found: \(service.name)")

            // Добавляем устройство, если его еще нет
            if !self.discoveredDevices.contains(where: { $0.id == service.id }) {
                self.discoveredDevices.append(service)
            }
        }
    }

    func onServiceLost(_ service: Service) {
        DispatchQueue.main.async {
            print("📺 Samsung TV lost: \(service.name)")
            self.discoveredDevices.removeAll(where: { $0.id == service.id })
        }
    }
}

// MARK: - ChannelDelegate

extension SamsungSmartViewManager: ChannelDelegate {
    func onConnect(_ client: ChannelClient?, error: NSError?) {
        if let error = error {
            print("❌ Channel connection error: \(error.localizedDescription)")
        } else if let client = client {
            print("✅ Channel connected: \(client.description)")
        }
    }

    func onDisconnect(_ client: ChannelClient?, error: NSError?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedDevice = nil
            print("🔌 Channel disconnected")
        }
    }

    func onMessage(_ message: Message) {
        print("📥 Received message from TV: \(message)")
    }

    func onError(_ error: NSError) {
        print("❌ Channel error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.connectionError = error.localizedDescription
        }
    }
}

// MARK: - Helper Extensions

extension Service {
    var displayName: String {
        return name
    }

    var ipAddress: String? {
        // Попробуем извлечь IP адрес из URI
        if let url = URL(string: uri) {
            return url.host
        }
        return nil
    }
}
