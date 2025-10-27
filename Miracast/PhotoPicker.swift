import SwiftUI
import PhotosUI

// Simple PHPicker wrapper that returns selected UIImages via completion handler
struct PhotoPicker: UIViewControllerRepresentable {
    var selectionLimit: Int = 0 // 0 = unlimited
    var didFinishPicking: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.filter = .images
        config.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // no-op
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true, completion: nil)
            guard !results.isEmpty else {
                parent.didFinishPicking([])
                return
            }
            var images: [UIImage] = []
            let group = DispatchGroup()

            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { (obj, error) in
                        defer { group.leave() }
                        if let err = error {
                            print("PhotoPicker load error:", err.localizedDescription)
                            return
                        }
                        if let image = obj as? UIImage {
                            images.append(image)
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                self.parent.didFinishPicking(images)
            }
        }
    }
}
