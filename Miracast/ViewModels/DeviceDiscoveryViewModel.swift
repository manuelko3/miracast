import SwiftUI
import Network
import Combine
import SmartView

/// Поиск устройств для каста.
///
/// Two protocols in parallel:
/// 1. Samsung SmartView SDK — оптимальный путь для Samsung Tizen (2015+).
/// 2. SSDP / UPnP MediaRenderer — DLNA, работает на старых Samsung (до 2015),
///    LG, Sony, Philips и т.д.
///
/// Одно физическое устройство может быть найдено обоими протоколами (напр. Samsung Tizen).
/// В таком случае мы объединяем их в одну запись с capabilities `[smartView, dlna]`.
final class DeviceDiscoveryViewModel: ObservableObject {
    @Published var discoveredDevices: [CastDevice] = []
    @Published var isSearching: Bool = false
    @Published var selectedDevice: CastDevice?
    @Published var isConnected: Bool = false
    @Published var connectionError: String?
    @Published var showNetworkPermissionAlert: Bool = false

    private let smartView = SmartViewManager()
    private lazy var dlna: DLNADiscovery = {
        DLNADiscovery { [weak self] renderer in
            self?.addDLNA(renderer)
        }
    }()

    // Маппинги device.id → сервисы для реального подключения.
    private var smartViewServices: [UUID: Service] = [:]
    private var dlnaRenderers: [UUID: DLNARenderer] = [:]

    // Чтобы сгруппировать Samsung найденный обоими способами, запоминаем IP.
    private var deviceIndexByIP: [String: UUID] = [:]

    private var stopTimer: DispatchSourceTimer?

    // MARK: - Public

    func getService(for id: UUID) -> Service? { smartViewServices[id] }
    func getRenderer(for id: UUID) -> DLNARenderer? { dlnaRenderers[id] }

    func requestLocalNetworkPermission(completion: @escaping (Bool) -> Void) {
        // Тригерим системный алерт, устанавливая UDP-соединение к multicast-адресу.
        let conn = NWConnection(
            host: NWEndpoint.Host("239.255.255.250"),
            port: NWEndpoint.Port(integerLiteral: 1900),
            using: .udp
        )

        var finished = false
        conn.stateUpdateHandler = { state in
            guard !finished else { return }
            switch state {
            case .ready:
                finished = true
                conn.cancel()
                completion(true)
            case .failed, .cancelled:
                finished = true
                completion(true) // Разрешение не требуется / уже есть — всё равно пробуем.
            default: break
            }
        }
        conn.start(queue: .main)

        // Таймаут на случай, если пользователь не ответил на алерт.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if !finished { finished = true; conn.cancel(); completion(true) }
        }
    }

    func startDiscovery() {
        guard !isSearching else { return }
        print("🔍 Discovery: start")
        isSearching = true
        discoveredDevices.removeAll()
        smartViewServices.removeAll()
        dlnaRenderers.removeAll()
        deviceIndexByIP.removeAll()

        // Samsung SmartView SDK.
        smartView.startDiscovery { [weak self] services in
            guard let self = self else { return }
            for svc in services { self.addSmartView(svc) }
        }

        // DLNA SSDP.
        dlna.start()

        // Автостоп через 20 секунд.
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 20)
        timer.setEventHandler { [weak self] in self?.stopDiscovery() }
        timer.resume()
        stopTimer = timer
    }

    func stopDiscovery() {
        guard isSearching else { return }
        isSearching = false
        stopTimer?.cancel()
        stopTimer = nil
        smartView.stopDiscovery()
        dlna.stop()
        print("🛑 Discovery: stop, found \(discoveredDevices.count) device(s)")
    }

    func connectToDevice(_ device: CastDevice) {
        selectedDevice = device
        isSearching = true      // переиспользуем флаг для показа индикатора подключения
        connectionError = nil

        // Предпочтительный путь — SmartView (на Tizen работает стабильнее и даёт PhotoPlayer/VideoPlayer).
        if let service = smartViewServices[device.id] {
            smartView.connect(to: service) { [weak self] ok, err in
                DispatchQueue.main.async {
                    self?.handleConnect(success: ok, error: err, device: device)
                }
            }
            return
        }

        // DLNA-устройства — "подключение" это просто выбор рендерера, SOAP идёт позже.
        if dlnaRenderers[device.id] != nil {
            DispatchQueue.main.async {
                self.handleConnect(success: true, error: nil, device: device)
            }
            return
        }

        // Не должно случаться, но на всякий случай.
        DispatchQueue.main.async {
            self.handleConnect(success: false,
                               error: NSError(domain: "Miracast", code: -1,
                                              userInfo: [NSLocalizedDescriptionKey: "Unsupported device"]),
                               device: device)
        }
    }

    func disconnect() {
        smartView.disconnect()
        selectedDevice = nil
        isConnected = false
        connectionError = nil
    }

    // MARK: - Merging

    private func handleConnect(success: Bool, error: Error?, device: CastDevice) {
        isSearching = false
        if success {
            if let idx = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                discoveredDevices[idx].isConnected = true
            }
            isConnected = true
        } else {
            isConnected = false
            connectionError = error?.localizedDescription ?? "Connection failed"
        }
    }

    private func addSmartView(_ service: Service) {
        let ip = URL(string: service.uri)?.host ?? "?"
        let name = service.name
        let id = mergeOrCreate(ip: ip, name: name, modelName: "Samsung Smart TV",
                               deviceType: .tv, cap: .smartView)
        smartViewServices[id] = service
    }

    private func addDLNA(_ renderer: DLNARenderer) {
        let ip = renderer.host
        let deviceType: CastDevice.DeviceType = .tv
        let model = [renderer.manufacturer, renderer.modelName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .ifEmpty("DLNA Media Renderer")
        let id = mergeOrCreate(ip: ip, name: renderer.friendlyName, modelName: model,
                               deviceType: deviceType, cap: .dlna)
        dlnaRenderers[id] = renderer
    }

    /// Если устройство с таким IP уже найдено — добавляем capability к нему.
    /// Иначе создаём новую запись.
    private func mergeOrCreate(ip: String,
                               name: String,
                               modelName: String,
                               deviceType: CastDevice.DeviceType,
                               cap: CastDevice.Capabilities) -> UUID {
        if let existingId = deviceIndexByIP[ip],
           let idx = discoveredDevices.firstIndex(where: { $0.id == existingId }) {
            discoveredDevices[idx].capabilities.insert(cap)
            return existingId
        }

        let device = CastDevice(
            name: name,
            modelName: modelName,
            ipAddress: ip,
            signalStrength: 90,
            deviceType: deviceType,
            capabilities: cap
        )
        discoveredDevices.append(device)
        deviceIndexByIP[ip] = device.id
        return device.id
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
