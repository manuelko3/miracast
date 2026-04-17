import SwiftUI
import ReplayKit

/// Экран стриминга экрана iPhone на TV через Broadcast Upload Extension.
struct CastScreenView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = CastScreenViewModel()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.1)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        deviceCard
                        statusCard
                        stepsCard
                        Spacer(minLength: 40)
                    }
                    .padding(16)
                }

                // Системный Broadcast Picker. Это наш главный триггер — тап здесь
                // показывает лист выбора extension'а. Мы подсовываем свой.
                broadcastButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }
        }
        .onDisappear { vm.stopPolling() }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Screen Cast")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
            HStack {
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 245/255, green: 246/255, blue: 248/255))
                            .frame(width: 36, height: 36)
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 150/255, green: 150/255, blue: 150/255))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 52)
    }

    // MARK: - Cards

    private var deviceCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: appState.isDeviceConnected ? "tv.fill" : "tv.slash")
                    .foregroundColor(appState.isDeviceConnected ? .blue : .gray)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(appState.isDeviceConnected ? appState.connectedDeviceName : "No device connected")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                Text(transportLabel)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
            if !appState.isDeviceConnected {
                Button("Connect") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        appState.showDeviceDiscovery = true
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(Color(red: 243/255, green: 247/255, blue: 255/255))
        .cornerRadius(14)
    }

    private var statusCard: some View {
        let (text, color, symbol): (String, Color, String) = {
            switch vm.state {
            case .idle:
                return ("Tap Start Broadcast to begin", .gray, "circle")
            case .preparing:
                return ("Waiting for broadcast to start…", .orange, "hourglass")
            case .broadcasting:
                return ("Broadcasting to TV (video + system audio)", .green,
                        "antenna.radiowaves.left.and.right")
            case .error(let m):
                return (m, .red, "exclamationmark.triangle.fill")
            }
        }()

        return HStack(spacing: 10) {
            Image(systemName: symbol).foregroundColor(color)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How it works")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
            step(1, "Tap Start Broadcast below. iOS will show a system sheet — choose \"Miracast\" and tap Start Broadcast.")
            step(2, "A 3-second countdown starts. You can switch to Safari or any app — the stream keeps going with picture and sound.")
            step(3, "To stop, tap the red indicator at the top of the screen or open this app and press Stop.")
            Text("Note: DRM-protected content (Netflix, Disney+, etc.) appears black — iOS protects those frames system-wide.")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .padding(.top, 4)
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(Color.blue).frame(width: 22, height: 22)
                Text("\(n)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color.black.opacity(0.75))
        }
    }

    // MARK: - Broadcast button

    private var broadcastButton: some View {
        let enabled = appState.isDeviceConnected

        return ZStack(alignment: .center) {
            // Визуальная кнопка, которая запускает пикер через programmatic tap.
            Button {
                if enabled { vm.prepareAndShowPicker(appState: appState) }
            } label: {
                HStack {
                    Image(systemName: vm.state == .broadcasting ? "stop.fill" : "play.fill")
                    Text(vm.state == .broadcasting ? "Broadcasting…" : "Start Broadcast")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(vm.state == .broadcasting ? Color.red : (enabled ? Color.blue : Color.gray))
                .cornerRadius(14)
            }
            .disabled(!enabled)

            // Невидимая обёртка над RPSystemBroadcastPickerView поверх кнопки —
            // она всё равно реагирует на тап, если programmatic вызов отключён системой.
            BroadcastPickerView(tint: .clear, size: 54)
                .frame(height: 54)
                .opacity(0.0)
                .allowsHitTesting(false)
        }
    }

    private var transportLabel: String {
        var parts: [String] = []
        if appState.connectedService != nil  { parts.append("SmartView") }
        if appState.connectedRenderer != nil { parts.append("DLNA") }
        if parts.isEmpty { return "Not connected" }
        return parts.joined(separator: " · ")
    }
}
