import SwiftUI
import PhotosUI

struct CastPhotosView: View {
    @State private var currentImageIndex: Int = 0
    @State private var isCasting = false
    @State private var selectedImages: [UIImage] = []
    @State private var showPhotoPicker = false
    var initialImages: [UIImage] = []
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Верхняя область: заголовок с кнопками
                VStack(spacing: 0) {
                    ZStack {
                        // Центрированный заголовок
                        Text("Cast Photos")
                            // SF Pro ~ system font; semibold approximates 590 weight
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.black)
                            .kerning(0) // letter-spacing 0%
                            .lineLimit(1)
                            .lineSpacing(0) // emulate 100% line-height
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Левая и правая кнопки - белые округлые
                        HStack {
                            Button(action: { onDismiss?() }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                .frame(width: 44, height: 44)
                            }
                            Spacer()
                            Button(action: { showPhotoPicker = true }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 44)
                }
                .padding(.top, 12)
                .padding(.bottom, 12)

                Spacer(minLength: 0)

                // Основной контент: большое фото
                if !selectedImages.isEmpty {
                    VStack(spacing: 0) {
                        // Отступ между навигацией и фото (18pt)
                        Spacer().frame(height: 18)

                        // Контейнер для фото: адаптивная высота (макс 496pt или 62% высоты экрана),
                        // изображение при меньшем размере «приклеено» к верхней границе
                        GeometryReader { geo in
                            let targetHeight = min(496, geo.size.height * 0.78)
                            let img = selectedImages[currentImageIndex]
                            // доступная ширина для фото — используем всю ширину контейнера (без боковых отступов)
                            let availableWidth = geo.size.width
                             VStack(spacing: 0) {
                                if img.size.width <= availableWidth && img.size.height <= targetHeight {
                                    // изображение меньше контейнера — показываем в натуральном размере, приклеенным к верху
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: min(img.size.width, availableWidth), height: min(img.size.height, targetHeight), alignment: .top)
                                        .clipped()
                                    Spacer()
                                } else {
                                    // изображение больше контейнера — заполняем и обрезаем сверху
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: availableWidth, height: targetHeight, alignment: .top)
                                        .clipped()
                                }
                            }
                            .frame(height: targetHeight)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: min(496, UIScreen.main.bounds.height * 0.78))

                        // Отступ между фото и кружками — 21pt
                        Spacer().frame(height: 21)

                        // Коллекция кружков с фотографиями
                        if selectedImages.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(selectedImages.indices, id: \.self) { index in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                currentImageIndex = index
                                            }
                                        }) {
                                            Image(uiImage: selectedImages[index])
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 72, height: 72)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle()
                                                        .stroke(
                                                            currentImageIndex == index ? Color(red: 62/255, green: 134/255, blue: 233/255) : Color.clear,
                                                            lineWidth: 3
                                                        )
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }

                // Фиксированный небольшой отступ между кружками и кнопкой
                Spacer().frame(height: 28)
                // --- КНОПКА ---
                CastButton(isCasting: $isCasting)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 35)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        // Photo picker sheet
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectionLimit: 0) { images in
                // Добавляем новые фото к уже выбранным
                selectedImages.append(contentsOf: images)
                showPhotoPicker = false
            }
        }
        .onAppear {
            selectedImages = initialImages
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color(red: 217/255, green: 233/255, blue: 255/255), Color.white]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

struct CastPhotosView_Previews: PreviewProvider {
    static var previews: some View {
        CastPhotosView()
    }
}
