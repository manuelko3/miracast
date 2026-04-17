import SwiftUI
import ReplayKit

/// Обёртка над `RPSystemBroadcastPickerView`. Показывает системную кнопку старта трансляции,
/// по нажатию открывается лист выбора Broadcast Upload Extension'а; мы подсказываем системе
/// наш собственный extension через `preferredExtension`.
struct BroadcastPickerView: UIViewRepresentable {
    /// Bundle ID нашего Broadcast Upload Extension.
    /// Должен совпадать с `PRODUCT_BUNDLE_IDENTIFIER` таргета MiracastBroadcast.
    static let extensionBundleID = "miracast.Miracast.MiracastBroadcast"

    /// Размер кнопки и цвет иконки.
    var tint: UIColor = .systemBlue
    var size: CGFloat = 72

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        picker.preferredExtension = Self.extensionBundleID
        picker.showsMicrophoneButton = false

        // Перекрашиваем системную иконку — она внутри UIButton.
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.imageView?.tintColor = tint
            }
        }
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

/// Программный триггер кнопки Broadcast Picker — имитируем тап, чтобы
/// пользователю не приходилось прицеливаться в маленькую системную иконку.
enum BroadcastPickerTrigger {
    static func programmaticallyTap() {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        picker.preferredExtension = BroadcastPickerView.extensionBundleID
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
                return
            }
        }
    }
}
