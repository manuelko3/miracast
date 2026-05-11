import SwiftUI
import Foundation

struct WhiteboardModel: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var createdDate: Date
    var drawingData: Data?

    init(name: String) {
        self.name = name
        self.createdDate = Date()
        self.drawingData = nil
    }
}
