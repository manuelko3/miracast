import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var appState: AppState
    // store picked images if needed
    @State private var pickedImages: [UIImage] = []

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
                        ForEach(viewModel.services.indices, id: \.self) { idx in
                            let service = viewModel.services[idx]
                            HomeServiceRow(icon: service.icon, iconColor: service.iconColor, text: service.text, isAsset: service.isAsset, showDivider: idx != viewModel.services.count - 1)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.handleServiceTap(service)
                                }
                        }
                    }
                }
                .scrollIndicators(.hidden) // скрываем индикатор прокрутки (iOS 16+)
                .listStyle(PlainListStyle())
                .background(Color.clear)
                .cornerRadius(16)
                .padding(.top, 24)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $viewModel.showCastScreen) {
            CastScreenView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        // Photo picker sheet
        .sheet(isPresented: $viewModel.showPhotoPicker) {
            PhotoPicker(selectionLimit: 0) { images in
                // store picked images and dismiss
                self.pickedImages = images
                self.appState.selectedPhotos = images
                self.viewModel.showPhotoPicker = false
                // show cast photos view after selection
                self.appState.showCastPhotos = true
            }
        }
        // Alert directing user to Settings when access denied
        .alert(isPresented: $viewModel.showPhotoSettingsAlert) {
            Alert(
                title: Text("Photos Access Needed"),
                message: Text("Please enable access to photos for this app in your device's privacy settings."),
                primaryButton: .default(Text("Go to Settings"), action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }),
                secondaryButton: .cancel()
            )
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
    var showDivider: Bool = true
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ZStack {
                    // Крупный круг 50x50
                    Circle()
                        .fill(Color.white)
                        .frame(width: 50, height: 50)

                    if isAsset {
                        // Если картинка из ассетов — заполняем весь круг и обрезаем по форме
                        Image(icon)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } else {
                        // Для SF Symbol оставляем внутри круга центрированную иконку
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

            if showDivider {
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.horizontal, 8) // уменьшил отступы, чтобы разделитель был длиннее
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
