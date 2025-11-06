import SwiftUI
import Foundation
import Combine
import PencilKit

class WhiteboardViewModel: ObservableObject {
    @Published var savedWhiteboards: [WhiteboardModel] = []
    @Published var showCreateNewAlert = false
    @Published var showNoBoardsAlert = false
    @Published var showWhiteboardList = false
    @Published var showWhiteboardCanvas = false
    @Published var selectedWhiteboard: WhiteboardModel?
    @Published var newBoardName = ""

    // PencilKit properties
    @Published var canvasView = PKCanvasView()
    @Published var isDirty = false

    init() {
        loadWhiteboards()
        setupCanvasView()
    }

    private func setupCanvasView() {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = UIColor.clear
        // Включаем стандартную панель инструментов PencilKit
        canvasView.showsVerticalScrollIndicator = false
        canvasView.showsHorizontalScrollIndicator = false
    }

    func handleWhiteboardTap() {
        if savedWhiteboards.isEmpty {
            showNoBoardsAlert = true
        } else {
            showWhiteboardList = true
        }
    }

    func showCreateBoardAlert() {
        showNoBoardsAlert = false
        showCreateNewAlert = true
    }

    func createNewBoard() {
        guard !newBoardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let newBoard = WhiteboardModel(name: newBoardName)
        savedWhiteboards.append(newBoard)
        selectedWhiteboard = newBoard
        newBoardName = ""
        showCreateNewAlert = false
        showWhiteboardList = false

        canvasView.drawing = PKDrawing()
        isDirty = false

        showWhiteboardCanvas = true
        saveWhiteboards()
    }

    func selectWhiteboard(_ whiteboard: WhiteboardModel) {
        selectedWhiteboard = whiteboard
        showWhiteboardList = false
        showWhiteboardCanvas = true
        loadDrawingData(for: whiteboard)
    }

    func deleteWhiteboard(_ whiteboard: WhiteboardModel) {
        savedWhiteboards.removeAll { $0.id == whiteboard.id }

        if selectedWhiteboard?.id == whiteboard.id {
            selectedWhiteboard = nil
            showWhiteboardCanvas = false
        }

        saveWhiteboards()
    }

    func renameWhiteboard(_ whiteboard: WhiteboardModel, newName: String) {
        if let index = savedWhiteboards.firstIndex(where: { $0.id == whiteboard.id }) {
            savedWhiteboards[index].name = newName
            saveWhiteboards()
        }
    }

    func clearBoard() {
        canvasView.drawing = PKDrawing()
        isDirty = true
        saveCurrentDrawing()
    }

    func saveCurrentDrawing() {
        guard let whiteboard = selectedWhiteboard else { return }

        if let index = savedWhiteboards.firstIndex(where: { $0.id == whiteboard.id }) {
            let drawingData = canvasView.drawing.dataRepresentation()
            savedWhiteboards[index].drawingData = drawingData
            saveWhiteboards()
            isDirty = false
        }
    }

    func startCasting() {
        print("Starting cast...")
    }

    func stopCasting() {
        print("Stopping cast...")
    }

    private func loadWhiteboards() {
        if let data = UserDefaults.standard.data(forKey: "SavedWhiteboards"),
           let boards = try? JSONDecoder().decode([WhiteboardModel].self, from: data) {
            savedWhiteboards = boards
        } else {
            savedWhiteboards = []
        }
    }

    private func saveWhiteboards() {
        if let data = try? JSONEncoder().encode(savedWhiteboards) {
            UserDefaults.standard.set(data, forKey: "SavedWhiteboards")
        }
    }

    private func loadDrawingData(for whiteboard: WhiteboardModel) {
        if let drawingData = whiteboard.drawingData,
           let drawing = try? PKDrawing(data: drawingData) {
            canvasView.drawing = drawing
        } else {
            canvasView.drawing = PKDrawing()
        }
        isDirty = false
    }
}
