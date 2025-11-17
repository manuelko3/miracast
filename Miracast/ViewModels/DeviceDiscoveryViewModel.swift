import SwiftUI
import Network
import Combine

class DeviceDiscoveryViewModel: ObservableObject {
    @Published var discoveredDevices: [CastDevice] = []
    @Published var isSearching: Bool = false
    @Published var selectedDevice: CastDevice?
    @Published var isConnected: Bool = false
    @Published var connectionError: String?
    @Published var showPermissionAlert: Bool = false
    @Published var showNetworkPermissionAlert: Bool = false

    private var searchTimer: Timer?
    private var browsers: [NWBrowser] = []
    private var ssdpListener: NWListener?
    private var ssdpConnection: NWConnection?
    private var scanningQueue = DispatchQueue(label: "com.miracast.ipscanner", qos: .userInitiated, attributes: .concurrent)

    // SmartView SDK Manager для Samsung устройств
    private var smartViewManager: SmartViewManager?

    init() {
        // Инициализация SmartView SDK
        smartViewManager = SmartViewManager()
    }

    // Запрос разрешения на доступ к локальной сети
    func requestLocalNetworkPermission(completion: @escaping (Bool) -> Void) {
        // На iOS 14+ требуется разрешение на локальную сеть
        // Показываем alert с объяснением
        showPermissionAlert = true

        // Симулируем запрос разрешения через создание UDP соединения
        // Это триггерит системный алерт о разрешении доступа к локальной сети
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.triggerLocalNetworkPermission { granted in
                completion(granted)
            }
        }
    }

    private func triggerLocalNetworkPermission(completion: @escaping (Bool) -> Void) {
        print("🔐 Triggering local network permission request...")

        // Создаем несколько соединений для надежного триггера алерта
        let addresses = [
            ("224.0.0.251", 5353),  // mDNS multicast
            ("239.255.255.250", 1900), // SSDP multicast
        ]

        var completionCalled = false

        for (host, port) in addresses {
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: .udp
            )

            connection.stateUpdateHandler = { state in
                guard !completionCalled else { return }

                switch state {
                case .ready:
                    print("✅ Local network permission granted!")
                    completionCalled = true
                    connection.cancel()
                    completion(true)
                case .failed(let error):
                    print("⚠️ Connection failed: \(error)")
                    connection.cancel()
                case .waiting(let error):
                    print("⏳ Connection waiting: \(error)")
                default:
                    break
                }
            }

            connection.start(queue: .main)

            // Пробуем отправить данные для триггера
            if let data = "discovery".data(using: .utf8) {
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error = error {
                        print("⚠️ Send failed: \(error)")
                    }
                })
            }
        }

        // Timeout после 8 секунд
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            if !completionCalled {
                print("⏱️ Permission request timeout - assuming granted")
                completionCalled = true
                completion(true)
            }
        }
    }

    // Начать поиск устройств
    func startDiscovery() {
        isSearching = true
        discoveredDevices.removeAll()

        print("🚀 Starting device discovery...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📱 Device Info:")
        print("   - Model: \(UIDevice.current.model)")
        print("   - System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // 🆕 НОВОЕ: Запускаем SmartView SDK поиск для Samsung TV (самый надежный метод!)
        startSmartViewDiscovery()

        // Запускаем поиск по нескольким протоколам одновременно
        startMultiProtocolDiscovery()

        // ВАЖНО: Запускаем SSDP поиск для Samsung и других Smart TV
        startSSDPDiscovery()

        // НОВОЕ: Сканируем локальную подсеть напрямую (работает даже между 2.4 и 5 GHz)
        startDirectIPScan()

        // Останавливаем поиск через 30 секунд (даем время для полного IP сканирования)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            self.stopDiscovery()
        }
    }

    // 🆕 Поиск Samsung устройств через SmartView SDK
    private func startSmartViewDiscovery() {
        print("🔍 Starting SmartView SDK discovery for Samsung devices...")

        smartViewManager?.startDiscovery { [weak self] services in
            guard let self = self else { return }

            DispatchQueue.main.async {
                for service in services {
                    // Создаем CastDevice из Service
                    let deviceName = service.name

                    // Получаем IP адрес из URI строки
                    var ipAddress = "Unknown"
                    if let url = URL(string: service.uri) {
                        ipAddress = url.host ?? "Unknown"
                    }

                    let device = CastDevice(
                        name: deviceName,
                        modelName: "Samsung Smart TV (SmartView SDK)",
                        ipAddress: ipAddress,
                        signalStrength: Int.random(in: 80...100),
                        deviceType: .tv
                    )

                    // Добавляем только уникальные устройства
                    if !self.discoveredDevices.contains(where: { $0.name == device.name }) {
                        self.discoveredDevices.append(device)
                        print("✅ Added Samsung device via SmartView SDK: \(deviceName) - IP: \(ipAddress)")
                    }
                }
            }
        }
    }

    private func startMultiProtocolDiscovery() {
        // Ищем устройства через проверенные протоколы (только те, что работают без NoAuth)
        let serviceTypes = [
            // Google & Chromecast
            ("_googlecast._tcp", CastDevice.DeviceType.chromecast),

            // Apple AirPlay & Apple TV (эти работают!)
            ("_airplay._tcp", CastDevice.DeviceType.appleTV),
            ("_raop._tcp", CastDevice.DeviceType.appleTV),
        ]

        for (serviceType, deviceType) in serviceTypes {
            startBonjourBrowser(for: serviceType, deviceType: deviceType)
        }

        print("🔍 Starting Bonjour discovery for \(serviceTypes.count) protocols")
        print("🌐 Starting SSDP/UPnP discovery for Samsung TV and other Smart TVs")
        print("⚠️ Note: Discovery will run for 20 seconds, please wait...")
    }

    private func startBonjourBrowser(for serviceType: String, deviceType: CastDevice.DeviceType) {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)

        browser.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                print("✅ Browser ready for \(serviceType)")
            case .failed(let error):
                print("❌ Browser failed for \(serviceType): \(error)")
            case .waiting(let error):
                print("⏳ Browser waiting for \(serviceType): \(error)")
            default:
                break
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self else { return }

            if results.count > 0 {
                print("📡 Found \(results.count) device(s) for \(serviceType)")
            }

            DispatchQueue.main.async {
                for result in results {
                    if case let .service(name, type, domain, interface) = result.endpoint {
                        print("🔍 Discovered: \(name) | Type: \(type) | Domain: \(domain)")

                        let lowercasedName = name.lowercased()

                        // ФИЛЬТР: Пропускаем Mac, iPhone, iPad и другие не-TV устройства
                        let skipKeywords = ["macbook", "imac", "mac mini", "iphone", "ipad",
                                           "airpods", "homepod", "printer", "scanner"]

                        let shouldSkip = skipKeywords.contains { keyword in
                            lowercasedName.contains(keyword)
                        }

                        // Также пропускаем устройства с типом _workstation если это не TV
                        if shouldSkip {
                            print("⏭️ Skipping non-TV device: \(name)")
                            continue
                        }

                        // Если это HTTP/HTTPS сервис, фильтруем только по явным TV производителям
                        if serviceType == "_http._tcp" || serviceType == "_https._tcp" {
                            let isTVBrand = lowercasedName.contains("samsung") ||
                                          lowercasedName.contains("lg") ||
                                          lowercasedName.contains("sony") ||
                                          lowercasedName.contains("tv") ||
                                          lowercasedName.contains("smart")

                            if !isTVBrand {
                                print("⏭️ Skipping HTTP service from non-TV: \(name)")
                                continue
                            }
                        }

                        // Получаем дополнительную информацию об устройстве
                        var modelName = "Smart Device"
                        var detectedDeviceType = deviceType

                        // Определяем модель и тип по имени и сервису
                        if lowercasedName.contains("samsung") || lowercasedName.contains("[tv]") ||
                           serviceType.contains("samsung") || serviceType.contains("smartview") {
                            modelName = "Samsung Smart TV"
                            detectedDeviceType = .tv
                            print("🎯 Identified as Samsung TV!")
                        } else if lowercasedName.contains("lg") {
                            modelName = "LG Smart TV"
                            detectedDeviceType = .tv
                        } else if lowercasedName.contains("sony") || lowercasedName.contains("bravia") {
                            modelName = "Sony BRAVIA"
                            detectedDeviceType = .tv
                        } else if lowercasedName.contains("chromecast") || serviceType == "_googlecast._tcp" {
                            modelName = "Chromecast"
                            detectedDeviceType = .chromecast
                        } else if lowercasedName.contains("apple tv") ||
                                 (serviceType == "_raop._tcp" && lowercasedName.contains("apple")) {
                            modelName = "Apple TV"
                            detectedDeviceType = .appleTV
                        } else if lowercasedName.contains("roku") || serviceType == "_roku._tcp" {
                            modelName = "Roku"
                            detectedDeviceType = .roku
                        } else {
                            // Определяем по типу сервиса
                            switch serviceType {
                            case "_googlecast._tcp":
                                modelName = "Chromecast"
                                detectedDeviceType = .chromecast
                            case "_airplay._tcp":
                                modelName = "AirPlay Device"
                                detectedDeviceType = .appleTV
                            case "_raop._tcp":
                                modelName = "Apple TV"
                                detectedDeviceType = .appleTV
                            case "_roku._tcp":
                                modelName = "Roku"
                                detectedDeviceType = .roku
                            case "_samsung._tcp", "_smartview._tcp", "_dial-multiscreen._tcp", "_samsungtv._tcp":
                                modelName = "Samsung Smart TV"
                                detectedDeviceType = .tv
                            case "_ssdp._tcp", "_ssdp._udp":
                                modelName = "DLNA Device"
                                detectedDeviceType = .tv
                            default:
                                // Если не можем определить, пропускаем
                                if !lowercasedName.contains("tv") {
                                    print("⏭️ Skipping unknown device: \(name)")
                                    continue
                                }
                                modelName = "Smart TV"
                                detectedDeviceType = .tv
                            }
                        }

                        // Создаем устройство
                        let device = CastDevice(
                            name: self.cleanDeviceName(name),
                            modelName: modelName,
                            ipAddress: "Discovering...",
                            signalStrength: Int.random(in: 70...100),
                            deviceType: detectedDeviceType
                        )

                        // Добавляем только уникальные устройства
                        if !self.discoveredDevices.contains(where: { $0.name == device.name }) {
                            self.discoveredDevices.append(device)
                            print("✅ Added device: \(device.name) (\(modelName))")
                        }
                    }
                }
            }
        }

        browser.start(queue: .main)
        browsers.append(browser)
    }

    // SSDP Discovery для Samsung TV и других UPnP устройств
    private func startSSDPDiscovery() {
        print("📡 Starting SSDP discovery for Smart TVs...")
        print("🔍 Network diagnostic: Checking WiFi connectivity...")

        // Создаем listener для получения SSDP ответов
        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true

            let listener = try NWListener(using: params)

            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("✅ SSDP Listener ready on port: \(listener.port ?? 0)")
                    self.sendSSDPSearch()
                case .failed(let error):
                    print("❌ SSDP Listener failed: \(error)")
                case .waiting(let error):
                    print("⏳ SSDP Listener waiting: \(error)")
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                print("📥 New SSDP connection received")
                connection.start(queue: .main)
                self?.receiveSSDP(on: connection)
            }

            listener.start(queue: .main)
            self.ssdpListener = listener

        } catch {
            print("❌ Failed to create SSDP listener: \(error)")
            // Fallback - пробуем простой UDP broadcast
            self.sendSSDPSearch()
        }
    }

    private func sendSSDPSearch() {
        print("📤 Sending SSDP M-SEARCH broadcast...")

        // Несколько вариантов SSDP запросов для разных типов устройств
        let searches = [
            "ssdp:all",
            "upnp:rootdevice",
            "urn:dial-multiscreen-org:service:dial:1",
            "urn:samsung.com:device:RemoteControlReceiver:1"
        ]

        for searchTarget in searches {
            let ssdpRequest = """
            M-SEARCH * HTTP/1.1\r
            HOST: 239.255.255.250:1900\r
            MAN: "ssdp:discover"\r
            MX: 5\r
            ST: \(searchTarget)\r
            USER-AGENT: iOS/15.0 UPnP/1.1 Miracast/1.0\r
            \r
            
            """

            guard let requestData = ssdpRequest.data(using: .utf8) else { continue }

            // Пробуем несколько адресов для broadcast
            let addresses = [
                ("239.255.255.250", 1900),  // SSDP multicast
                ("255.255.255.255", 1900),  // Broadcast
            ]

            for (host, port) in addresses {
                let connection = NWConnection(
                    host: NWEndpoint.Host(host),
                    port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                    using: .udp
                )

                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        print("✅ Connected to \(host):\(port), sending \(searchTarget)")
                        connection.send(content: requestData, completion: .contentProcessed { error in
                            if let error = error {
                                print("❌ Send failed to \(host): \(error)")
                            } else {
                                print("✅ Sent M-SEARCH for \(searchTarget) to \(host)")
                            }
                        })

                        // Слушаем ответы
                        self.receiveSSDP(on: connection)

                    case .failed(let error):
                        print("❌ Connection failed to \(host): \(error)")
                    case .waiting(let error):
                        print("⏳ Waiting for \(host): \(error)")
                    default:
                        break
                    }
                }

                connection.start(queue: .main)

                // Сохраняем соединение
                if self.ssdpConnection == nil {
                    self.ssdpConnection = connection
                }

                // Повторяем отправку
                for i in 1...3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i * 2)) {
                        if connection.state == .ready {
                            connection.send(content: requestData, completion: .contentProcessed { _ in
                                print("📤 Retry #\(i) to \(host) for \(searchTarget)")
                            })
                        }
                    }
                }
            }
        }
    }

    private func receiveSSDP(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            if let data = data {
                if let response = String(data: data, encoding: .utf8) {
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    print("📥 SSDP Response received (\(data.count) bytes):")
                    print(response)
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                    // Парсим SSDP ответ
                    self?.parseSSDP(response: response)
                } else {
                    print("⚠️ Received \(data.count) bytes but couldn't decode as UTF-8")
                }
            }

            if let error = error {
                print("❌ SSDP receive error: \(error)")
            } else if data == nil {
                print("ℹ️ No data received (connection might be establishing)")
            }

            // Продолжаем слушать
            self?.receiveSSDP(on: connection)
        }
    }

    private func parseSSDP(response: String) {
        // Ищем основные поля в SSDP ответе
        var deviceName: String?
        var modelName = "Smart TV"
        var deviceType = CastDevice.DeviceType.tv
        var location: String?
        var server: String?
        var usn: String?

        let lines = response.components(separatedBy: "\r\n")

        for line in lines {
            let lowercased = line.lowercased()

            // Извлекаем Location (URL устройства)
            if lowercased.starts(with: "location:") {
                location = line.replacingOccurrences(of: "location:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                print("   📍 Location: \(location ?? "nil")")
            }

            // Извлекаем Server
            if lowercased.starts(with: "server:") {
                server = line.replacingOccurrences(of: "server:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                print("   🖥️ Server: \(server ?? "nil")")
            }

            // Извлекаем USN (Unique Service Name)
            if lowercased.starts(with: "usn:") {
                usn = line.replacingOccurrences(of: "usn:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                print("   🆔 USN: \(usn ?? "nil")")
            }

            // Ищем информацию о производителе в разных полях
            let searchLine = line.lowercased()

            if searchLine.contains("samsung") {
                modelName = "Samsung Smart TV"
                deviceType = .tv
                deviceName = "Samsung TV"
                print("   🎯 Detected: Samsung TV")
            } else if searchLine.contains("lg") {
                modelName = "LG Smart TV"
                deviceType = .tv
                deviceName = "LG TV"
                print("   🎯 Detected: LG TV")
            } else if searchLine.contains("sony") || searchLine.contains("bravia") {
                modelName = "Sony BRAVIA"
                deviceType = .tv
                deviceName = "Sony TV"
                print("   🎯 Detected: Sony TV")
            } else if searchLine.contains("roku") {
                modelName = "Roku"
                deviceType = .roku
                deviceName = "Roku Device"
                print("   🎯 Detected: Roku")
            } else if searchLine.contains("chromecast") || searchLine.contains("googlecast") {
                modelName = "Chromecast"
                deviceType = .chromecast
                deviceName = "Chromecast"
                print("   🎯 Detected: Chromecast")
            }
        }

        // Если нашли устройство с location
        if let location = location {
            let ip = self.extractIP(from: location)

            // Если не определили имя, используем информацию из Server или IP
            if deviceName == nil {
                if let server = server {
                    deviceName = "Smart TV (\(server.components(separatedBy: "/").first ?? "Unknown"))"
                } else {
                    deviceName = "Smart TV (\(ip))"
                }
                print("   ℹ️ Using fallback name: \(deviceName ?? "nil")")
            }

            print("🎯 Found UPnP device: \(deviceName ?? "Unknown") at \(location)")

            DispatchQueue.main.async {
                let device = CastDevice(
                    name: deviceName ?? "Unknown Device",
                    modelName: modelName,
                    ipAddress: ip,
                    signalStrength: Int.random(in: 70...100),
                    deviceType: deviceType
                )

                // Добавляем только уникальные устройства
                if !self.discoveredDevices.contains(where: { $0.ipAddress == device.ipAddress && device.ipAddress != "Unknown" }) {
                    self.discoveredDevices.append(device)
                    print("✅ Added SSDP device: \(device.name) (\(modelName)) - IP: \(ip)")
                } else {
                    print("⏭️ Skipping duplicate device at IP: \(ip)")
                }
            }
        } else {
            print("⚠️ SSDP response without Location header - ignoring")
        }
    }

    private func extractIP(from location: String) -> String {
        // Извлекаем IP адрес из URL (например: http://192.168.1.100:8080/...)
        if let url = URL(string: location), let host = url.host {
            return host
        }
        return "Unknown"
    }

    // Очищаем имя устройства от служебных символов
    private func cleanDeviceName(_ name: String) -> String {
        // Убираем лишние символы и делаем имя читаемым
        var cleanName = name
            .replacingOccurrences(of: "\\032", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)

        // Если имя пустое, используем дефолтное
        if cleanName.isEmpty {
            cleanName = "Unknown Device"
        }

        return cleanName
    }

    // НОВОЕ: Прямое сканирование IP адресов в локальной подсети
    private func startDirectIPScan() {
        print("🔍 Starting direct IP subnet scan...")

        // Получаем IP адрес iPhone
        guard let localIP = getLocalIPAddress() else {
            print("❌ Cannot get local IP address")
            return
        }

        print("📱 Local IP: \(localIP)")

        // Извлекаем базу подсети (например, 192.168.31.x -> 192.168.31)
        let ipComponents = localIP.components(separatedBy: ".")
        guard ipComponents.count == 4 else {
            print("❌ Invalid IP format")
            return
        }

        let subnet = "\(ipComponents[0]).\(ipComponents[1]).\(ipComponents[2])"
        print("🌐 Scanning subnet: \(subnet).0/24")

        // ОПТИМИЗАЦИЯ: Сканируем в приоритетном порядке
        // Сначала наиболее вероятные адреса для TV
        let priorityRanges = [
            80...120,    // Средний диапазон (обычно TV здесь) - ПРИОРИТЕТ!
            1...79,      // Нижний диапазон
            121...200,   // Верхний средний
            201...254    // Высокий диапазон
        ]

        var scannedCount = 0
        let totalToScan = priorityRanges.reduce(0) { $0 + $1.count }

        for range in priorityRanges {
            for i in range {
                let ip = "\(subnet).\(i)"

                // Пропускаем собственный IP
                if ip == localIP {
                    continue
                }

                // Сканируем ВСЕ популярные TV порты
                scanningQueue.async {
                    // Samsung Smart TV порты
                    self.probeTVPort(ip: ip, port: 8001)  // Samsung Smart View
                    self.probeTVPort(ip: ip, port: 8002)  // Samsung Smart View SSL
                    self.probeTVPort(ip: ip, port: 55000) // Samsung Remote
                    self.probeTVPort(ip: ip, port: 9197)  // Samsung AirPlay

                    // Общие TV порты
                    self.probeTVPort(ip: ip, port: 8080)  // HTTP альтернативный
                    self.probeTVPort(ip: ip, port: 7000)  // AirPlay
                    self.probeTVPort(ip: ip, port: 3000)  // LG WebOS
                    self.probeTVPort(ip: ip, port: 1900)  // UPnP/SSDP
                }

                scannedCount += 1

                // Логируем прогресс каждые 10 адресов
                if scannedCount % 10 == 0 {
                    DispatchQueue.main.async {
                        print("📊 IP Scan progress: \(scannedCount)/\(totalToScan) addresses")
                    }
                }
            }
        }

        print("🚀 Launched priority scan for \(totalToScan) IP addresses across 8 ports each")
        print("⏱️ This may take 10-15 seconds...")
    }

    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }

            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                // IPv4
                let name = String(cString: interface.ifa_name)

                // Ищем активное Wi-Fi соединение (en0 обычно)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }

        return address
    }

    private func probeTVPort(ip: String, port: UInt16) {
        let connection = NWConnection(
            host: NWEndpoint.Host(ip),
            port: NWEndpoint.Port(integerLiteral: port),
            using: .tcp
        )

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ Found open port at \(ip):\(port)")
                connection.cancel()

                // Устройство ответило - добавляем его
                DispatchQueue.main.async {
                    self?.addDiscoveredIPDevice(ip: ip, port: port)
                }

            case .failed(let error):
                // Порт закрыт или устройство не отвечает - это нормально
                connection.cancel()

            case .cancelled:
                // Уже отменено
                break

            case .waiting(let error):
                // Timeout - устройство не ответило
                connection.cancel()

            default:
                break
            }
        }

        connection.start(queue: scanningQueue)

        // Увеличиваем timeout до 2 секунд для медленных TV
        scanningQueue.asyncAfter(deadline: .now() + 2.0) {
            if connection.state != .ready && connection.state != .cancelled {
                connection.cancel()
            }
        }
    }

    private func addDiscoveredIPDevice(ip: String, port: UInt16) {
        // Определяем тип устройства по порту
        var deviceName = "Smart TV"
        var modelName = "Smart TV"
        var deviceType = CastDevice.DeviceType.tv

        switch port {
        case 8001, 8002:
            deviceName = "Samsung TV"
            modelName = "Samsung Smart TV"
            deviceType = .tv
            print("🎯 Identified Samsung Smart View at \(ip):\(port)")

        case 55000:
            deviceName = "Samsung TV"
            modelName = "Samsung Smart TV (Remote)"
            deviceType = .tv
            print("🎯 Identified Samsung Remote Control at \(ip):\(port)")

        case 9197:
            deviceName = "Samsung TV"
            modelName = "Samsung Smart TV (AirPlay)"
            deviceType = .tv
            print("🎯 Identified Samsung AirPlay at \(ip):\(port)")

        case 3000:
            deviceName = "LG TV"
            modelName = "LG WebOS TV"
            deviceType = .tv
            print("🎯 Identified LG WebOS TV at \(ip):\(port)")

        case 7000:
            deviceName = "Smart TV"
            modelName = "AirPlay Device"
            deviceType = .appleTV
            print("🎯 Found AirPlay device at \(ip):\(port)")

        case 8080, 1900:
            deviceName = "Smart TV"
            modelName = "Smart TV"
            deviceType = .tv
            print("🎯 Found Smart TV at \(ip):\(port)")

        default:
            deviceName = "Network Device"
            modelName = "Unknown Device"
        }

        let device = CastDevice(
            name: "\(deviceName) (\(ip))",
            modelName: modelName,
            ipAddress: ip,
            signalStrength: Int.random(in: 70...100),
            deviceType: deviceType
        )

        // Проверяем что такого устройства еще нет
        if !self.discoveredDevices.contains(where: { $0.ipAddress == ip }) {
            self.discoveredDevices.append(device)
            print("✅ Added device from IP scan: \(deviceName) at \(ip) (port \(port))")
        } else {
            print("ℹ️ Device at \(ip) already added, skipping duplicate")
        }
    }

    func stopDiscovery() {
        isSearching = false

        // Останавливаем SmartView SDK поиск
        smartViewManager?.stopDiscovery()

        // Останавливаем все браузеры
        for browser in browsers {
            browser.cancel()
        }
        browsers.removeAll()

        // Останавливаем SSDP соединение
        ssdpConnection?.cancel()
        ssdpConnection = nil
        ssdpListener?.cancel()
        ssdpListener = nil

        print("🛑 Discovery stopped. Found \(discoveredDevices.count) device(s)")

        if discoveredDevices.isEmpty {
            print("⚠️ No devices found. Make sure:")
            print("   1. Your TV is ON and connected to Wi-Fi")
            print("   2. iPhone and TV are on the SAME Wi-Fi network")
            print("   3. You granted Local Network permission")
            print("   4. TV might be on 2.4GHz while iPhone on 5GHz (router may block multicast)")
        }
    }

    // Подключиться к выбранному устройству
    func connectToDevice(_ device: CastDevice) {
        selectedDevice = device
        isSearching = true

        // Симуляция подключения
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Обновляем устройство как подключенное
            if let index = self.discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                self.discoveredDevices[index].isConnected = true
            }
            self.isConnected = true
            self.isSearching = false
        }
    }

    func disconnect() {
        if let device = selectedDevice,
           let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index].isConnected = false
        }
        selectedDevice = nil
        isConnected = false
    }
}
