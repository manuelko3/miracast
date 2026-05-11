import SwiftUI
import ReplayKit

/// Экран стриминга экрана iPhone на TV.
/// Ветвится по транспорту: DLNA (через extension), Chromecast (CASTV2 из main app),
/// AirPlay (AVPlayer + системный route picker).
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
                        routeSpecificCard
                        stepsCard
                        Spacer(minLength: 40)
                    }
                    .padding(16)
                }

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
            case .routeStarting:
                return ("Sending stream to TV…", .orange, "arrow.up.forward.circle")
            case .broadcasting(let route):
                return (broadcastingText(for: route), .green, "antenna.radiowaves.left.and.right")
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

    /// Если текущий route AirPlay — показываем пикер с выбором TV.
    @ViewBuilder
    private var routeSpecificCard: some View {
        // Показываем AirPlay-пикер пока маршрут стартует или уже играет.
        let isAirPlayFlow: Bool = {
            switch vm.state {
            case .broadcasting(.airplay): return true
            case .routeStarting, .preparing: return appState.connectedCapabilities.contains(.airplay)
                                                && !appState.connectedCapabilities.contains(.dlna)
                                                && !appState.connectedCapabilities.contains(.chromecast)
            default: return false
            }
        }()
        if isAirPlayFlow {
            VStack(alignment: .leading, spacing: 10) {
                Text("AirPlay")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                Text("Pick your TV from the list below — iOS will route the stream to it.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.black.opacity(0.7))
                HStack {
                    AirPlayPickerView(tintColor: .systemBlue, activeTintColor: .systemGreen)
                        .frame(width: 44, height: 44)
                    Text("Tap the AirPlay icon → select TV")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding(16)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
            .cornerRadius(12)
        }
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

    // MARK: - Broadcast / Stop button

    @ViewBuilder
    private var broadcastButton: some View {
        let isBroadcasting: Bool = {
            if case .broadcasting = vm.state { return true }
            return false
        }()

        ZStack(alignment: .center) {
            Button {
                if isBroadcasting {
                    vm.stopBroadcast()
                } else if appState.isDeviceConnected {
                    vm.prepareAndShowPicker(appState: appState)
                }
            } label: {
                HStack {
                    Image(systemName: isBroadcasting ? "stop.fill" : "play.fill")
                    Text(isBroadcasting ? "Stop Broadcast" : "Start Broadcast")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isBroadcasting ? Color.red : (appState.isDeviceConnected ? Color.blue : Color.gray))
                .cornerRadius(14)
            }
            .disabled(!appState.isDeviceConnected && !isBroadcasting)

            BroadcastPickerView(tint: .clear, size: 54)
                .frame(height: 54)
                .opacity(0.0)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Helpers

    private var transportLabel: String {
        let caps = appState.connectedCapabilities
        var parts: [String] = []
        if caps.contains(.dlna)       { parts.append("DLNA") }
        if caps.contains(.smartView)  { parts.append("SmartView") }
        if caps.contains(.chromecast) { parts.append("Cast") }
        if caps.contains(.airplay)    { parts.append("AirPlay") }
        if caps.contains(.dial)       { parts.append("DIAL") }
        if parts.isEmpty { return "Not connected" }
        return parts.joined(separator: " · ")
    }

    private func broadcastingText(for route: CastScreenViewModel.Route) -> String {
        switch route {
        case .dlna:             return "Streaming to TV via DLNA (video + audio)"
        case .chromecast:       return "Streaming to Chromecast"
        case .airplay:          return "HLS ready — pick AirPlay route below"
        }
    }
}
