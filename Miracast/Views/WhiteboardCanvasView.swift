import SwiftUI
import PencilKit

struct WhiteboardCanvasView: View {
    @ObservedObject var viewModel: WhiteboardViewModel
    @Binding var isPresented: Bool
    @State private var isCasting = false
    @State private var showingOptionsMenu = false
    @State private var showingClearAlert = false
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?

    var body: some View {
        NavigationView {
            ZStack {
                // Градиентный фон как во всем приложении
                LinearGradient(gradient: Gradient(colors: [Color(red: 217/255, green: 233/255, blue: 255/255), Color.white]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Верхняя панель с градиентным фоном
                    ZStack {
                        // Центрированный заголовок
                        Text(viewModel.selectedWhiteboard?.name ?? "Whiteboard")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Левая и правая кнопки - белые округлые
                        HStack {
                            Button(action: {
                                // Сохраняем рисунок перед возвратом
                                viewModel.saveCurrentDrawing()
                                viewModel.showWhiteboardCanvas = false
                                viewModel.showWhiteboardList = true
                            }) {
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

                            Button(action: {
                                showingOptionsMenu = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                .frame(width: 44, height: 44)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .confirmationDialog("", isPresented: $showingOptionsMenu, titleVisibility: .hidden) {
                        Button(action: {
                            // Генерируем изображение из канваса
                            let drawing = viewModel.canvasView.drawing
                            if !drawing.bounds.isEmpty {
                                shareImage = drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)
                                showingShareSheet = true
                            }
                        }) {
                            Label("Share Image", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive, action: {
                            showingClearAlert = true
                        }) {
                            Label("Clear Board", systemImage: "trash")
                        }
                        Button("Cancel", role: .cancel) { }
                    }

                    // Основная область для рисования с PencilKit
                    PencilKitCanvasView(canvasView: $viewModel.canvasView, isDirty: $viewModel.isDirty)
                        .background(Color.white)
                        .padding(.top, 8)

                    Spacer()

                    // Кнопка трансляции (посередине между доской и панелью PencilKit)
                    CastButton(isCasting: $isCasting) {
                        if isCasting {
                            viewModel.stopCasting()
                        } else {
                            viewModel.startCasting()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 70) // Увеличенный отступ, чтобы кнопка не накрывалась панелью
                }
                .alert(isPresented: $showingClearAlert) {
                    Alert(
                        title: Text("Clear Board"),
                        message: Text("Are you sure you want to clear the entire board?"),
                        primaryButton: .destructive(Text("Clear")) {
                            viewModel.clearBoard()
                        },
                        secondaryButton: .cancel()
                    )
                }
                .sheet(isPresented: $showingShareSheet) {
                    if let image = shareImage {
                        ShareSheet(items: [image])
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// UIActivityViewController wrapper для SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
