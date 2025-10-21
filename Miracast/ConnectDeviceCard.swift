import SwiftUI

struct ConnectDeviceCard: View {
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: "tv")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.white)
            }
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
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: "arrow.right")
                    .foregroundColor(.white)
            }
        }
        .padding(16)
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.22, green: 0.51, blue: 0.97), Color(red: 0.11, green: 0.31, blue: 0.74)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(18)
    }
}
