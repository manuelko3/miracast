import SwiftUI
import PencilKit

struct PencilKitCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var isDirty: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = UIColor.clear

        // Настраиваем панель инструментов
        context.coordinator.setupToolPicker()

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Убеждаемся что панель инструментов видна при каждом обновлении
        if !context.coordinator.toolPicker.isVisible {
            context.coordinator.setupToolPicker()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: PencilKitCanvasView
        let toolPicker = PKToolPicker()

        init(_ parent: PencilKitCanvasView) {
            self.parent = parent
            super.init()
        }

        func setupToolPicker() {
            // Добавляем небольшую задержку для надежного показа панели
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.toolPicker.setVisible(true, forFirstResponder: self.parent.canvasView)
                self.toolPicker.addObserver(self.parent.canvasView)
                self.parent.canvasView.becomeFirstResponder()
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.isDirty = true
        }
    }
}
