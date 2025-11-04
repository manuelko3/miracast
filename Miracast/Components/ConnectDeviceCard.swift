import SwiftUI

struct ConnectDeviceCard: View {
    var body: some View {
        HStack {
            // Чистая иконка из ассетов — без фоновых кружков и перекраски
            Image("ConnectionButton/connect_icon")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Connect Device")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Text("Not connected")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            ZStack {
                // Круглая подложка теперь с более прозрачным фоном
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: 42, height: 42)
                Image("ConnectionButton/arrow_icon")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 42, height: 42)
            }
        }
        .padding(16)
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.22, green: 0.51, blue: 0.97), Color(red: 0.11, green: 0.31, blue: 0.74)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(18)
    }
}
