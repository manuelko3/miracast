import SwiftUI
import PencilKit

struct WhiteboardListView: View {
    @ObservedObject var viewModel: WhiteboardViewModel
    @Binding var isPresented: Bool
    @State private var showingRenameAlert = false
    @State private var renamingBoard: WhiteboardModel?
    @State private var newName = ""
    @State private var showingDeleteAlert = false
    @State private var deletingBoard: WhiteboardModel?

    var body: some View {
        NavigationView {
            ZStack {
                // Градиентный фон как в основном экране
                LinearGradient(gradient: Gradient(colors: [Color(red: 217/255, green: 233/255, blue: 255/255), Color.white]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Заголовок
                    ZStack {
                        // Центрированный заголовок
                        Text("Cast Whiteboard")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Левая и правая кнопки - белые округлые
                        HStack {
                            Button(action: {
                                isPresented = false
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
                                viewModel.showCreateNewAlert = true
                            }) {
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Список whiteboard'ов
                    if viewModel.savedWhiteboards.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Text("No boards found")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)

                            Text("To cast whiteboard you have to create your first board")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)

                            Button("Create board") {
                                viewModel.showCreateNewAlert = true
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 32)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(viewModel.savedWhiteboards) { board in
                                    WhiteboardCardView(
                                        board: board,
                                        onTap: {
                                            viewModel.selectWhiteboard(board)
                                        },
                                        onRename: {
                                            renamingBoard = board
                                            newName = board.name
                                            showingRenameAlert = true
                                        },
                                        onDelete: {
                                            deletingBoard = board
                                            showingDeleteAlert = true
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                        }
                    }
                }
            }
        }
        .alert("Name your board", isPresented: $viewModel.showCreateNewAlert) {
            TextField("Board name", text: $viewModel.newBoardName)
            Button("Create") {
                viewModel.createNewBoard()
            }
            Button("Cancel", role: .cancel) {
                viewModel.newBoardName = ""
            }
        }
        .alert("Rename Board", isPresented: $showingRenameAlert) {
            TextField("Board name", text: $newName)
            Button("Save") {
                if let board = renamingBoard {
                    viewModel.renameWhiteboard(board, newName: newName)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Do you want to delete board?", isPresented: $showingDeleteAlert) {
            Button("Yes") {
                if let board = deletingBoard {
                    viewModel.deleteWhiteboard(board)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

struct WhiteboardCardView: View {
    let board: WhiteboardModel
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    @State private var showingOptions = false
    @State private var thumbnailImage: UIImage?

    var body: some View {
        VStack(spacing: 8) {
            // Превью доски (белый прямоугольник с реальным рисунком)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .frame(height: 120)
                    .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)

                // Реальная миниатюра рисунка
                if let thumbnail = thumbnailImage {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // Placeholder для пустой доски
                    VStack(spacing: 4) {
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 24))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("Empty board")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }

                // Кнопка опций в правом нижнем углу
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingOptions = true
                        }) {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 10, weight: .medium))
                                )
                                .shadow(color: .gray.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                    }
                }
            }
            .onTapGesture {
                onTap()
            }
            .onAppear {
                generateThumbnail()
            }

            // Название доски
            Text(board.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .confirmationDialog("", isPresented: $showingOptions, titleVisibility: .hidden) {
            Button(action: onRename) {
                Label("Rename Board", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete Board", systemImage: "trash")
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func generateThumbnail() {
        guard let drawingData = board.drawingData,
              let drawing = try? PKDrawing(data: drawingData) else {
            thumbnailImage = nil
            return
        }

        // Проверяем, есть ли вообще что-то нарисовано
        if drawing.bounds.isEmpty {
            thumbnailImage = nil
            return
        }

        // Создаем миниатюру с подходящим размером
        let targetSize = CGSize(width: 300, height: 200)
        let bounds = drawing.bounds

        // Вычисляем масштаб для вписывания рисунка в целевой размер
        let scale = min(targetSize.width / bounds.width, targetSize.height / bounds.height)

        // Генерируем изображение из рисунка
        let image = drawing.image(from: bounds, scale: scale)
        thumbnailImage = image
    }
}
