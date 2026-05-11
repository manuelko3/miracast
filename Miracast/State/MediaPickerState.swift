import Foundation
import Combine
import UIKit

/// Выбранные пользователем медиа-файлы, передаются между picker'ом и экранами кастинга.
final class MediaPickerState: ObservableObject {
    @Published var selectedPhotos: [UIImage] = []
    @Published var selectedVideoURLs: [URL] = []
}
