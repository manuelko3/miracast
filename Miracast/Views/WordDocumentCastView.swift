import SwiftUI
import QuickLook

struct WordDocumentCastView: UIViewControllerRepresentable {
    let documentURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.currentPreviewItemIndex = 0
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // nothing to update
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: WordDocumentCastView
        init(_ parent: WordDocumentCastView) {
            self.parent = parent
        }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            parent.documentURL as NSURL
        }
    }
}
