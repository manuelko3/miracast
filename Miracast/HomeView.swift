import SwiftUI

struct HomeView: View {
    @State private var showCastScreen = false

    let services: [HomeService] = [
        .init(icon: "airplayvideo", iconColor: Color(red: 1, green: 0.36, blue: 0.27), text: "Screen Cast"),
        .init(icon: "photo.on.rectangle", iconColor: Color(red: 0.22, green: 0.51, blue: 0.97), text: "Photos"),
        .init(icon: "video", iconColor: Color(red: 1, green: 0.27, blue: 0.56), text: "Videos"),
        .init(icon: "rectangle.on.rectangle.angled", iconColor: Color(red: 0.54, green: 0.27, blue: 0.97), text: "Slide - Show"),
        .init(icon: "youtube", text: "Youtube", isAsset: true),
        .init(icon: "tiktok", text: "Tik Tok", isAsset: true),
        .init(icon: "twitch", text: "Twitch", isAsset: true),
        .init(icon: "kick", text: "Kick", isAsset: true),
        .init(icon: "netflix", text: "Netflix", isAsset: true),
        .init(icon: "doc", text: "Documents", isAsset: true),
        .init(icon: "presentations", text: "Presentations", isAsset: true),
        .init(icon: "whiteboard", text: "Whiteboard", isAsset: true),
        .init(icon: "safari", iconColor: Color(red: 0.22, green: 0.51, blue: 0.97), text: "Browser"),
        .init(icon: "gamecontroller", iconColor: Color(red: 0.22, green: 0.51, blue: 0.97), text: "Games")
    ]
    var body: some View {
        ZStack {
            // Градиентный фон
            LinearGradient(gradient: Gradient(colors: [Color(red: 217/255, green: 233/255, blue: 255/255), Color.white]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                // Заголовок
                Text("Screen Mirroring")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                // Синяя карточка
                ConnectDeviceCard()
                    .padding(.top, 20)
                    .padding(.horizontal, 16)
                // Список сервисов
                List {
                    Section {
                        ForEach(services) { service in
                            HomeServiceRow(icon: service.icon, iconColor: service.iconColor, text: service.text, isAsset: service.isAsset)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if service.text == "Screen Cast" {
                                        showCastScreen = true
                                    }
                                }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.clear)
                .cornerRadius(16)
                .padding(.top, 24)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showCastScreen) {
            CastScreenView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct HomeService: Identifiable {
    let id = UUID()
    let icon: String
    var iconColor: Color?
    let text: String
    var isAsset: Bool

    init(icon: String, iconColor: Color? = nil, text: String, isAsset: Bool = false) {
        self.icon = icon
        self.iconColor = iconColor
        self.text = text
        self.isAsset = isAsset
    }
}

struct HomeServiceRow: View {
    let icon: String
    var iconColor: Color? = nil
    let text: String
    var isAsset: Bool = false
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 40, height: 40)
                if isAsset {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(iconColor ?? .black)
                }
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
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
