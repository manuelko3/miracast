import SwiftUI
import Combine

class CastScreenViewModel: ObservableObject {
    @Published var autoRotate = false
    @Published var sound = false
    @Published var isCasting = false
    // Здесь можно добавить бизнес-логику для трансляции, работы с настройками и т.д.
}
