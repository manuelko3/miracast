import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            // Градиентный фон, как на главном экране
            LinearGradient(gradient: Gradient(colors: [Color(red: 217/255, green: 233/255, blue: 255/255), Color.white]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                // Заголовок
                HStack {
                    Text("Settings")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 16)
                        .padding(.leading, 16)
                    Spacer()
                }
                .padding(.bottom, 16)
                // Список настроек
                VStack(spacing: 0) {
                    SettingsRow(icon: "Settings/privacy_icon", text: "Privacy Policy", isAsset: true)
                    Divider()
                    SettingsRow(icon: "Settings/terms_icon", text: "Terms of Use", isAsset: true)
                    Divider()
                    SettingsRow(icon: "Settings/rate_icon", text: "Rate Us", isAsset: true)
                    Divider()
                    SettingsRow(icon: "Settings/share_icon", text: "Share app with friends", isAsset: true)
                    Divider()
                    SettingsRow(icon: "Settings/feedback_icon", text: "Feedback", isAsset: true)
                }
                .background(Color.white.opacity(0.2))
                .cornerRadius(16)
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
                // Красная ссылка
                Button(action: {
                    // Действие по нажатию
                }) {
                    Text("Need assistance with cancelling subscription?")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.red)
                        .underline()
                        .padding(.top, 16)
                }
                Spacer()
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let text: String
    let isAsset: Bool
    var body: some View {
        HStack {
            if isAsset {
                Image(icon)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .padding(.leading, 8)
            } else {
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .foregroundColor(.white)
                    .padding(.leading, 8)
            }
            Text(text)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.black)
                .padding(.leading, 8)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Color.gray.opacity(0.6))
                .padding(.trailing, 8)
        }
        .frame(height: 82)
        .background(Color.clear)
    }
}

// Для предпросмотра
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
