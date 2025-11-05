import SwiftUI
import UniformTypeIdentifiers

struct WordDocumentScreen: View {
    @Binding var isPresented: Bool
    @State private var documentURLs: [URL] = []
    @State private var selectedDocumentIndex: Int = 0
    @State private var showDocumentPicker = false
    @State private var isCasting: Bool = false // состояние для CastButton

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    ZStack {
                        Color.white
                        if !documentURLs.isEmpty {
                            WordDocumentCastView(documentURL: documentURLs[selectedDocumentIndex])
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            VStack {
                                Spacer()
                                Text("Добавьте Word-документ")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(documentURLs.indices, id: \ .self) { idx in
                                let url = documentURLs[idx]
                                Button(action: {
                                    selectedDocumentIndex = idx
                                }) {
                                    VStack {
                                        Image(systemName: "doc.text")
                                            .resizable()
                                            .frame(width: 40, height: 48)
                                            .foregroundColor(selectedDocumentIndex == idx ? .blue : .gray)
                                        Text(url.lastPathComponent)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .frame(width: 60)
                                    }
                                    .padding(4)
                                    .background(selectedDocumentIndex == idx ? Color.blue.opacity(0.1) : Color.clear)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemGray6))
                    Spacer(minLength: 80) // отступ для кнопки
                }
                VStack {
                    Spacer()
                    CastButton(isCasting: $isCasting) {
                        // TODO: добавить логику старта трансляции
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .background(Color.white)
            .navigationTitle("Cast Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showDocumentPicker = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
            }
            .toolbarBackground(Color(red: 0.93, green: 0.97, blue: 1.0), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { urls in
                documentURLs.append(contentsOf: urls)
                if !urls.isEmpty {
                    selectedDocumentIndex = documentURLs.count - urls.count
                }
            }
        }
    }
}

// DocumentPicker — SwiftUI wrapper for UIDocumentPickerViewController
struct DocumentPicker: UIViewControllerRepresentable {
    var completion: ([URL]) -> Void
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [
            UTType(filenameExtension: "doc")!,
            UTType(filenameExtension: "docx")!
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var completion: ([URL]) -> Void
        init(completion: @escaping ([URL]) -> Void) {
            self.completion = completion
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            completion(urls)
        }
    }
}
