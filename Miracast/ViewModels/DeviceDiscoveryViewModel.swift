import SwiftUI
import Network
import Combine
import SmartView

/// Поиск устройств для каста.
///
/// Несколько протоколов параллельно:
/// 1. Samsung SmartView SDK — Samsung Tizen (2015+).
/// 2. SSDP / UPnP MediaRenderer — DLNA: старые Samsung, LG, Sony, Philips и т.д.
/// 3. SSDP / DIAL — Fire TV, Roku, Chromecast (запуск приложений).
/// 4. Bonjour / mDNS — AirPlay, Google Cast, Fire TV.
///
/// Одно физическое устройство может найтись несколькими способами. Их merge'им по IP/имени
/// и агрегируем в один `CastDevice` с набором `Capabilities`.
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

    /// Транспортные данные устройств по UUID.
    private var connectables: [UUID: ConnectableDevice] = [:]
    /// Индекс по IP-адресу для merge.
    private var deviceIndexByIP: [String: UUID] = [:]
    /// Индекс по имени — fallback merge для устройств без резолва IP.
    private var deviceIndexByName: [String: UUID] = [:]

    private var stopTimer: DispatchSourceTimer?

    // MARK: - Public

    func getService(for id: UUID) -> Service? { connectables[id]?.smartViewService }
    func getRenderer(for id: UUID) -> DLNARenderer? { connectables[id]?.dlnaRenderer }
    func getDIALLocation(for id: UUID) -> URL? { connectables[id]?.dialLocation }
    func getHost(for id: UUID) -> String? { connectables[id]?.host }
    func getCapabilities(for id: UUID) -> CastDevice.Capabilities {
        discoveredDevices.first(where: { $0.id == id })?.capabilities ?? []
    }

    func requestLocalNetworkPermission(completion: @escaping (Bool) -> Void) {
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
                finished = true; conn.cancel(); completion(true)
            case .failed, .cancelled:
                finished = true; completion(true)
            default: break
            }
        }
        conn.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if !finished { finished = true; conn.cancel(); completion(true) }
        }
    }

    func startDiscovery() {
        guard !isSearching else { return }
        Log.discovery.info("start")
        isSearching = true
        discoveredDevices.removeAll()
        connectables.removeAll()
        deviceIndexByIP.removeAll()
        deviceIndexByName.removeAll()

        smartView.startDiscovery { [weak self] services in
            guard let self = self else { return }
            for svc in services { self.addSmartView(svc) }
        }
        dlna.start()
        bonjour.start()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 20)
        timer.setEventHandler { [weak self] in self?.stopDiscovery() }
        timer.resume()
        stopTimer = timer
    }

    func stopDiscovery() {
        guard isSearching else { return }
        isSearching = false
        stopTimer?.cancel(); stopTimer = nil
        smartView.stopDiscovery()
        dlna.stop()
        bonjour.stop()
        Log.discovery.info("stop, found \(self.discoveredDevices.count, privacy: .public) device(s)")
    }

    func connectToDevice(_ device: CastDevice) {
        selectedDevice = device
        isSearching = true
        connectionError = nil

        // Предпочтительный путь подключения — SmartView (на Tizen даёт PhotoPlayer/VideoPlayer).
        if let service = connectables[device.id]?.smartViewService {
            smartView.connect(to: service) { [weak self] ok, err in
                DispatchQueue.main.async {
                    self?.handleConnect(success: ok, error: err, device: device)
                }
            }
            return
        }

        // DLNA / AirPlay / Chromecast / DIAL — "подключение" это просто сохранение выбора.
        if !device.capabilities.isEmpty {
            DispatchQueue.main.async { self.handleConnect(success: true, error: nil, device: device) }
            return
        }

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
        let id = mergeOrCreate(ip: ip, name: service.name, modelName: "Samsung Smart TV",
                               deviceType: .tv, cap: .smartView)
        connectables[id, default: ConnectableDevice(deviceID: id)].smartViewService = service
        connectables[id]?.host = ip
    }

    private func addDLNA(_ renderer: DLNARenderer) {
        let ip = renderer.host
        let model = [renderer.manufacturer, renderer.modelName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .ifEmpty("DLNA Media Renderer")
        let id = mergeOrCreate(ip: ip, name: renderer.friendlyName, modelName: model,
                               deviceType: .tv, cap: .dlna)
        connectables[id, default: ConnectableDevice(deviceID: id)].dlnaRenderer = renderer
        connectables[id]?.host = ip
    }

    private func addDIAL(_ hit: DLNADiscovery.DIALHit) {
        let model = [hit.manufacturer, hit.modelName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .ifEmpty("DIAL Device")
        let id = mergeOrCreate(ip: hit.host, name: hit.friendlyName, modelName: model,
                               deviceType: .tv, cap: .dial)
        connectables[id, default: ConnectableDevice(deviceID: id)].dialLocation = hit.location
        connectables[id]?.host = hit.host
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
        if let ip = hit.ipAddress {
            connectables[id, default: ConnectableDevice(deviceID: id)].host = ip
        }
    }

    /// Если устройство с таким IP (или именем, если IP неизвестен) уже найдено —
    /// добавляем capability. Иначе создаём новую запись.
    @discardableResult
    private func mergeOrCreate(ip: String?,
                               name: String,
                               modelName: String,
                               deviceType: CastDevice.DeviceType,
                               cap: CastDevice.Capabilities) -> UUID {
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
        connectables[device.id] = ConnectableDevice(deviceID: device.id, host: ip)
        if let ip = ip { deviceIndexByIP[ip] = device.id }
        deviceIndexByName[name.lowercased()] = device.id
        return device.id
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
