import SwiftUI
import Foundation

struct WhiteboardModel: Identifiable, Codable {
    let id = UUID()
    var name: String
    var createdDate: Date
    var drawingData: Data? // Для сохранения данных рисования

    init(name: String) {
        self.name = name
        self.createdDate = Date()
        self.drawingData = nil
    }
}
