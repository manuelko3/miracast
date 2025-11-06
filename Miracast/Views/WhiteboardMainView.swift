import SwiftUI

struct WhiteboardMainView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = WhiteboardViewModel()

    var body: some View {
        Group {
            if viewModel.showWhiteboardCanvas {
                WhiteboardCanvasView(
                    viewModel: viewModel,
                    isPresented: $viewModel.showWhiteboardCanvas
                )
                .onDisappear {
                    // Когда закрываем canvas, возвращаемся к списку досок если есть доски
                    if !viewModel.showWhiteboardCanvas {
                        if !viewModel.savedWhiteboards.isEmpty {
                            viewModel.showWhiteboardList = true
                        } else {
                            isPresented = false
                        }
                    }
                }
            } else if viewModel.showWhiteboardList {
                WhiteboardListView(
                    viewModel: viewModel,
                    isPresented: $viewModel.showWhiteboardList
                )
                .onDisappear {
                    // Когда закрываем список, возвращаемся к главному экрану только если не переходим к Canvas
                    if !viewModel.showWhiteboardList && !viewModel.showWhiteboardCanvas {
                        isPresented = false
                    }
                }
            } else {
                // Проверяем наличие досок при появлении экрана
                Color.clear
            }
        }
        .onAppear {
            // Проверяем доски при каждом появлении экрана
            viewModel.handleWhiteboardTap()
        }
        .alert("No Boards found", isPresented: $viewModel.showNoBoardsAlert) {
            Button("Create board") {
                viewModel.showCreateBoardAlert()
            }
            Button("Cancel", role: .cancel) {
                isPresented = false
            }
        } message: {
            Text("To cast whiteboard you have to create your first board")
        }
        .alert("Name your board", isPresented: $viewModel.showCreateNewAlert) {
            TextField("Board name", text: $viewModel.newBoardName)
            Button("Create") {
                viewModel.createNewBoard()
            }
            Button("Cancel", role: .cancel) {
                viewModel.newBoardName = ""
                // Если отменили создание и нет других досок, закрываем весь whiteboard
                if viewModel.savedWhiteboards.isEmpty {
                    isPresented = false
                }
            }
        }
    }
}
