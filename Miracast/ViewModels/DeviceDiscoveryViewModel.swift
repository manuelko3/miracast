import SwiftUI
import Network
import Combine
import SmartView

/// Поиск устройств для каста.
///
/// Несколько протоколов параллельно:
/// 1. Samsung SmartView SDK — оптимальный путь для Samsung Tizen (2015+).
/// 2. SSDP / UPnP MediaRenderer — DLNA, работает на старых Samsung (до 2015),
///    LG, Sony, Philips и т.д.
/// 3. SSDP / DIAL — Fire TV, Roku, Chromecast, многие Smart TV (запуск приложений).
/// 4. Bonjour / mDNS — AirPlay (Apple TV и AirPlay 2 TV), Google Cast (Chromecast/Android TV),
///    Fire TV (_amzn-wplay._tcp).
///
/// Одно физическое устройство может быть найдено несколькими протоколами (напр. Samsung Tizen 2018 —
/// SmartView + DLNA + AirPlay). Мы объединяем их по IP-адресу и агрегируем capabilities.
final class DeviceDiscoveryViewModel: ObservableObject {
    @Published var discoveredDevices: [CastDevice] = []
    @Published var isSearching: Bool = false
    @Published var selectedDevice: CastDevice?
    @Published var isConnected: Bool = false
    @Published var connectionError: String?
    @Published var showNetworkPermissionAlert: Bool = false

    private let smartView = SmartViewManager()
    private lazy var dlna: DLNADiscovery = {
        DLNADiscovery(
            onFound: { [weak self] renderer in self?.addDLNA(renderer) },
            onDIAL:  { [weak self] hit      in self?.addDIAL(hit) }
        )
    }()
    private lazy var bonjour: BonjourDiscovery = {
        BonjourDiscovery { [weak self] hit in self?.addBonjour(hit) }
    }()

    // Маппинги device.id → сервисы для реального подключения.
    private var smartViewServices: [UUID: Service] = [:]
    private var dlnaRenderers: [UUID: DLNARenderer] = [:]
    private var dialLocations: [UUID: URL] = [:]
    private var deviceHosts: [UUID: String] = [:]

    // Чтобы сгруппировать устройства, найденные разными способами, запоминаем IP.
    private var deviceIndexByIP: [String: UUID] = [:]
    // Имена, которые уже видели без IP — fallback для merge'а Chromecast'ов и т.д.
    private var deviceIndexByName: [String: UUID] = [:]

    private var stopTimer: DispatchSourceTimer?

    // MARK: - Public

    func getService(for id: UUID) -> Service? { smartViewServices[id] }
    func getRenderer(for id: UUID) -> DLNARenderer? { dlnaRenderers[id] }
    func getDIALLocation(for id: UUID) -> URL? { dialLocations[id] }
    func getHost(for id: UUID) -> String? { deviceHosts[id] }
    func getCapabilities(for id: UUID) -> CastDevice.Capabilities {
        discoveredDevices.first(where: { $0.id == id })?.capabilities ?? []
    }

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
        dialLocations.removeAll()
        deviceHosts.removeAll()
        deviceIndexByIP.removeAll()
        deviceIndexByName.removeAll()

        // Samsung SmartView SDK.
        smartView.startDiscovery { [weak self] services in
            guard let self = self else { return }
            for svc in services { self.addSmartView(svc) }
        }

        // DLNA + DIAL через SSDP.
        dlna.start()

        // Bonjour: AirPlay, Chromecast, Fire TV.
        bonjour.start()

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
        bonjour.stop()
        print("🛑 Discovery: stop, found \(discoveredDevices.count) device(s)")
    }

    func connectToDevice(_ device: CastDevice) {
        selectedDevice = device
        isSearching = true      // переиспользуем флаг для показа индикатора подключения
        connectionError = nil

        // Предпочтительный путь — SmartView (на Tizen даёт PhotoPlayer/VideoPlayer).
        if let service = smartViewServices[device.id] {
            smartView.connect(to: service) { [weak self] ok, err in
                DispatchQueue.main.async {
                    self?.handleConnect(success: ok, error: err, device: device)
                }
            }
            return
        }

        // DLNA / AirPlay / Chromecast / DIAL — "подключение" это просто сохранение выбора;
        // реальная отправка команд идёт при старте стрима.
        if device.capabilities.isEmpty == false {
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
        let model = [renderer.manufacturer, renderer.modelName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .ifEmpty("DLNA Media Renderer")
        let id = mergeOrCreate(ip: ip, name: renderer.friendlyName, modelName: model,
                               deviceType: .tv, cap: .dlna)
        dlnaRenderers[id] = renderer
        deviceHosts[id] = ip
    }

    private func addDIAL(_ hit: DLNADiscovery.DIALHit) {
        let model = [hit.manufacturer, hit.modelName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .ifEmpty("DIAL Device")
        let id = mergeOrCreate(ip: hit.host, name: hit.friendlyName, modelName: model,
                               deviceType: .tv, cap: .dial)
        dialLocations[id] = hit.location
        deviceHosts[id] = hit.host
    }

    private func addBonjour(_ hit: BonjourDiscovery.Hit) {
        let cap: CastDevice.Capabilities
        let model: String
        switch hit.kind {
        case .airplay:    cap = .airplay;    model = "AirPlay Receiver"
        case .chromecast: cap = .chromecast; model = "Google Cast"
        case .fireTV:     cap = .dial;       model = "Amazon Fire TV"
        }
        let id = mergeOrCreate(ip: hit.ipAddress, name: hit.name, modelName: model,
                               deviceType: .tv, cap: cap)
        if let ip = hit.ipAddress { deviceHosts[id] = ip }
    }

    /// Если устройство с таким IP (или именем, если IP неизвестен) уже найдено —
    /// добавляем capability. Иначе создаём новую запись.
    @discardableResult
    private func mergeOrCreate(ip: String?,
                               name: String,
                               modelName: String,
                               deviceType: CastDevice.DeviceType,
                               cap: CastDevice.Capabilities) -> UUID {
        // Пробуем найти по IP, потом по имени.
        if let ip = ip, let existingId = deviceIndexByIP[ip],
           let idx = discoveredDevices.firstIndex(where: { $0.id == existingId }) {
            discoveredDevices[idx].capabilities.insert(cap)
            return existingId
        }
        if let existingId = deviceIndexByName[name.lowercased()],
           let idx = discoveredDevices.firstIndex(where: { $0.id == existingId }) {
            discoveredDevices[idx].capabilities.insert(cap)
            if let ip = ip, discoveredDevices[idx].ipAddress == "?" {
                discoveredDevices[idx].ipAddress = ip
                deviceIndexByIP[ip] = existingId
            }
            return existingId
        }

        let device = CastDevice(
            name: name,
            modelName: modelName,
            ipAddress: ip ?? "?",
            signalStrength: 90,
            deviceType: deviceType,
            capabilities: cap
        )
        discoveredDevices.append(device)
        if let ip = ip { deviceIndexByIP[ip] = device.id }
        deviceIndexByName[name.lowercased()] = device.id
        return device.id
    }

    // Совместимая перегрузка — IP известен.
    @discardableResult
    private func mergeOrCreate(ip: String,
                               name: String,
                               modelName: String,
                               deviceType: CastDevice.DeviceType,
                               cap: CastDevice.Capabilities) -> UUID {
        mergeOrCreate(ip: Optional(ip), name: name, modelName: modelName,
                      deviceType: deviceType, cap: cap)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
