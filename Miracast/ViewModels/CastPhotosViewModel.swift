import SwiftUI
import Combine

class CastPhotosViewModel: ObservableObject {
    @Published var selectedImages: [UIImage] = []
    @Published var isCasting = false
    
    func startCast() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isCasting = true
        }
        // TODO: Добавить логику запуска трансляции фото
    }
    
    func stopCast() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isCasting = false
        }
        // TODO: Добавить логику остановки трансляции
    }
}
