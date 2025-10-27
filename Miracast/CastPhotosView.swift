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
            // Градиентный фон как в HomeView
            LinearGradient(gradient: Gradient(colors: [Color(red: 217/255, green: 233/255, blue: 255/255), Color.white]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Верхняя область: заголовок с кнопками
                VStack(spacing: 0) {
                    ZStack {
                        // Центрированный заголовок
                        Text("Cast Photos")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)

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

                Spacer()

                // Основной контент: большое фото
                VStack(spacing: 32) {
                    if !selectedImages.isEmpty {
                        Image(uiImage: selectedImages[currentImageIndex])
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 400)
                    }

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
                                            .frame(width: 60, height: 60)
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

                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Кнопка Cast
            CastButton(isCasting: $isCasting)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(LinearGradient(gradient: Gradient(colors: [Color(red: 217/255, green: 233/255, blue: 255/255), Color.white]), startPoint: .top, endPoint: .bottom))
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
    }
}

struct CastPhotosView_Previews: PreviewProvider {
    static var previews: some View {
        CastPhotosView()
    }
}
