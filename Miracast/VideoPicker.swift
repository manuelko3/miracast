import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// PHPicker wrapper that returns selected video file URLs via completion handler
struct VideoPicker: UIViewControllerRepresentable {
    var selectionLimit: Int = 0 // 0 = unlimited
    var didFinishPicking: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.filter = .videos
        config.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // no-op
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker
        init(_ parent: VideoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true, completion: nil)
            guard !results.isEmpty else {
                parent.didFinishPicking([])
                return
            }

            var urls: [URL] = []
            let group = DispatchGroup()

            for result in results {
                let provider = result.itemProvider
                // use movie UTType
                let typeId = UTType.movie.identifier
                if provider.hasItemConformingToTypeIdentifier(typeId) {
                    group.enter()
                    provider.loadFileRepresentation(forTypeIdentifier: typeId) { (url, error) in
                        defer { group.leave() }
                        if let err = error {
                            print("VideoPicker load error:", err.localizedDescription)
                            return
                        }
                        guard let url = url else { return }
                        // copy to temporary directory because the provided url may be a security-scoped temp
                        let filename = UUID().uuidString + "-" + (url.lastPathComponent)
                        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                        do {
                            if FileManager.default.fileExists(atPath: dest.path) {
                                try FileManager.default.removeItem(at: dest)
                            }
                            try FileManager.default.copyItem(at: url, to: dest)
                            urls.append(dest)
                        } catch {
                            print("VideoPicker copy error:", error.localizedDescription)
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                self.parent.didFinishPicking(urls)
            }
        }
    }
}
