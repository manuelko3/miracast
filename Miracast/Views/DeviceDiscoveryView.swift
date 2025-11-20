import SwiftUI

struct DeviceDiscoveryView: View {
    @StateObject private var viewModel = DeviceDiscoveryViewModel()
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            ZStack {
                // Градиентный фон
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
                    // Заголовок
                    HStack {
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.gray)
                                .frame(width: 32, height: 32)
                                .background(Color.white)
                                .clipShape(Circle())
                        }

                        Spacer()

                        Text("Connect device")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)

                        Spacer()

                        // Placeholder для баланса
                        Color.clear
                            .frame(width: 32, height: 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Описание
                    Text("Make sure your TV is turned\non and connected to the same Wi-Fi network")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                        .padding(.horizontal, 40)

                    // Поисковая строка
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        Text("Search in Progress")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    // Список устройств
                    if viewModel.discoveredDevices.isEmpty && viewModel.isSearching {
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                            Text("Searching for devices...")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    } else if viewModel.discoveredDevices.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "tv.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No devices found")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)
                            Text("Make sure your TV is on and\nconnected to the same network")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.8))
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding()
                    } else {
                        ZStack {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.discoveredDevices) { device in
                                        DeviceRow(
                                            device: device,
                                            isConnecting: viewModel.selectedDevice?.id == device.id && viewModel.isSearching
                                        ) {
                                            viewModel.connectToDevice(device)
                                            // Сохраняем информацию о подключении в AppState
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                appState.isDeviceConnected = true
                                                appState.connectedDeviceName = device.name
                                                // Сохраняем Service объект для использования в других экранах (YouTube и т.д.)
                                                appState.connectedService = viewModel.getService(for: device.id)
                                                isPresented = false
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 40)
                            }

                            // Overlay для процесса подключения
                            if viewModel.isSearching && viewModel.selectedDevice != nil {
                                Color.black.opacity(0.3)
                                    .ignoresSafeArea()

                                VStack(spacing: 20) {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))

                                    Text("Connecting to \(viewModel.selectedDevice?.name ?? "device")...")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .padding(30)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(16)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Local Network Access Needed", isPresented: $viewModel.showNetworkPermissionAlert) {
                Button("Go to Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
            } message: {
                Text("Please enable access to photos for this app in your device's privacy settings.")
            }
        }
        .onAppear {
            // Запрашиваем разрешение и начинаем поиск
            viewModel.requestLocalNetworkPermission { granted in
                if granted {
                    viewModel.startDiscovery()
                } else {
                    viewModel.showNetworkPermissionAlert = true
                }
            }
        }
        .onDisappear {
            viewModel.stopDiscovery()
        }
    }
}

struct DeviceRow: View {
    let device: CastDevice
    var isConnecting: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Иконка устройства
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)

                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        Image(systemName: device.deviceType.iconName)
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                }

                // Информация об устройстве
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)

                    Text(isConnecting ? "Connecting..." : device.modelName)
                        .font(.system(size: 14))
                        .foregroundColor(isConnecting ? .blue : .gray)
                }

                Spacer()

                // Индикатор сигнала
                if !isConnecting {
                    SignalStrengthIndicator(strength: device.signalStrength)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            .opacity(isConnecting ? 0.7 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isConnecting)
    }
}

struct SignalStrengthIndicator: View {
    let strength: Int

    private var barCount: Int {
        switch strength {
        case 0..<25: return 1
        case 25..<50: return 2
        case 50..<75: return 3
        default: return 4
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < barCount ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 3, height: CGFloat(4 + index * 3))
            }
        }
    }
}

// Preview
struct DeviceDiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceDiscoveryView(isPresented: .constant(true))
    }
}
