import SwiftUI
import UniformTypeIdentifiers

struct PresentationPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var completion: ([URL]) -> Void
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, completion: completion, showErrorAlert: $showErrorAlert, errorMessage: $errorMessage)
    }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [UTType.pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeSwiftUIView() -> some View {
        EmptyView()
            .alert(isPresented: $showErrorAlert) {
                Alert(title: Text("Ошибка импорта PDF"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
    }
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var completion: ([URL]) -> Void
        var isPresented: Binding<Bool>
        var showErrorAlert: Binding<Bool>
        var errorMessage: Binding<String>
        init(isPresented: Binding<Bool>, completion: @escaping ([URL]) -> Void, showErrorAlert: Binding<Bool>, errorMessage: Binding<String>) {
            self.isPresented = isPresented
            self.completion = completion
            self.showErrorAlert = showErrorAlert
            self.errorMessage = errorMessage
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            var copiedURLs: [URL] = []
            let fileManager = FileManager.default
            let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            for url in urls {
                var didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess { url.stopAccessingSecurityScopedResource() }
                }
                let destURL = documentsDir.appendingPathComponent(url.lastPathComponent)
                do {
                    if fileManager.fileExists(atPath: destURL.path) {
                        try fileManager.removeItem(at: destURL)
                    }
                    try fileManager.copyItem(at: url, to: destURL)
                    copiedURLs.append(destURL)
                } catch {
                    print("Ошибка копирования файла: \(error)")
                    errorMessage.wrappedValue = "Не удалось импортировать PDF. Возможно, файл защищён или открыт в Preview/Files. Попробуйте выбрать другой источник или дождитесь обновления приложения."
                    showErrorAlert.wrappedValue = true
                }
            }
            completion(copiedURLs)
            isPresented.wrappedValue = false
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            isPresented.wrappedValue = false
        }
    }
}
