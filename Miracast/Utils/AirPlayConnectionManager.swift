import Foundation
import SwiftUI
import AVFoundation
import AVKit
import MediaPlayer
import Combine

// Менеджер для отслеживания статуса AirPlay подключения
class AirPlayConnectionManager: ObservableObject {
    static let shared = AirPlayConnectionManager()

    @Published var isConnected: Bool = false
    @Published var connectedDeviceName: String = ""

    private var routeChangeObserver: NSObjectProtocol?

    init() {
        setupRouteChangeNotification()
        checkCurrentRoute()
    }

    private func setupRouteChangeNotification() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.checkCurrentRoute()
        }
    }

    func checkCurrentRoute() {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute

        // Проверяем, есть ли AirPlay подключение
        let airPlayConnected = currentRoute.outputs.contains { output in
            output.portType == .airPlay
        }

        DispatchQueue.main.async {
            self.isConnected = airPlayConnected

            if airPlayConnected {
                // Получаем имя устройства
                if let airPlayOutput = currentRoute.outputs.first(where: { $0.portType == .airPlay }) {
                    self.connectedDeviceName = airPlayOutput.portName
                    print("✅ Connected to AirPlay device: \(airPlayOutput.portName)")
                }
            } else {
                self.connectedDeviceName = ""
                print("ℹ️ No AirPlay connection")
            }
        }
    }

    deinit {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// View для интеграции системного AirPlay пикера
struct SystemAirPlayButton: UIViewRepresentable {
    var onConnectionChange: ((Bool, String) -> Void)?

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = .systemBlue
        picker.activeTintColor = .systemBlue
        picker.prioritizesVideoDevices = true

        // Настраиваем аудио сессию для AirPlay
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
        
        // Добавляем observer для программного показа picker
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowAirPlayPicker"),
            object: nil,
            queue: .main
        ) { _ in
            // Программно "нажимаем" на кнопку AirPlay
            for view in picker.subviews {
                if let button = view as? UIButton {
                    button.sendActions(for: .touchUpInside)
                    print("📺 AirPlay picker opened programmatically")
                }
            }
        }

        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // Обновление не требуется
    }
}
