import SwiftUI
import MediaPlayer

struct MusicView: View {
    @State private var showAppleMusicAlert = false
    @State private var showSettingsAlert = false
    @State private var appleMusicAuthStatus: MPMediaLibraryAuthorizationStatus = MPMediaLibrary.authorizationStatus()

    var body: some View {
        ZStack {
            // Градиентный фон
            LinearGradient(gradient: Gradient(colors: [Color(red: 217/255, green: 233/255, blue: 255/255), Color.white]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                // Верхняя панель
                HStack {
                    Text("Music")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Cast")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                // Синяя карточка
                ConnectDeviceCard()
                    .padding(.top, 20)
                    .padding(.horizontal, 16)
                // Список сервисов
                VStack(spacing: 0) {
                    MusicServiceRow(icon: "applelogo", iconColor: .black, text: "Apple Music") {
                        handleAppleMusicTap()
                    }
                    Divider().padding(.leading, 56)
                    MusicServiceRow(icon: "safari", iconColor: Color(red: 0.22, green: 0.51, blue: 0.97), text: "Safari")
                    Divider().padding(.leading, 56)
                    MusicServiceRow(icon: "play.rectangle.fill", iconColor: Color(red: 1, green: 0.27, blue: 0.23), text: "YouTube Music")
                }
                .background(Color.white.opacity(0.2))
                .cornerRadius(16)
                .padding(.top, 24)
                .padding(.horizontal, 16)
                Spacer()
            }
        }
        .alert(isPresented: $showAppleMusicAlert) {
            Alert(
                title: Text("\"App Name\" Would Like to Access the Apple Music"),
                message: Text("The app uses your \"Apple Music\" account data."),
                primaryButton: .default(Text("Allow"), action: {
                    requestAppleMusicAuth()
                }),
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showSettingsAlert) {
            Alert(
                title: Text("\"App Name\" Would Like to Access the Apple Music"),
                message: Text("Go to settings and allow the app to access your \"Apple Music\" account data."),
                primaryButton: .default(Text("Go to Settings"), action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }),
                secondaryButton: .cancel()
            )
        }
    }

    private func handleAppleMusicTap() {
        let status = MPMediaLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            showAppleMusicAlert = true
        case .denied, .restricted:
            showSettingsAlert = true
        case .authorized:
            // Здесь можно добавить действие при успешном доступе
            break
        @unknown default:
            break
        }
    }

    private func requestAppleMusicAuth() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                self.appleMusicAuthStatus = status
                if status == .denied || status == .restricted {
                    self.showSettingsAlert = true
                }
            }
        }
    }
}

struct MusicServiceRow: View {
    let icon: String
    let iconColor: Color
    let text: String
    var onTap: (() -> Void)? = nil
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(iconColor)
                }
                .padding(.leading, 8)
                Text(text)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.leading, 12)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.gray.opacity(0.6))
                    .padding(.trailing, 8)
            }
            .frame(height: 82)
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MusicView_Previews: PreviewProvider {
    static var previews: some View {
        MusicView()
    }
}
