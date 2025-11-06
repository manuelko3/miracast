import SwiftUI
import UniformTypeIdentifiers

struct PresentationScreen: View {
    @Binding var isPresented: Bool
    @State private var documentURLs: [URL] = []
    @State private var showDocumentPicker = false
    @State private var isCasting: Bool = false
    @State private var showDocumentSheet = false
    @State private var selectedDocumentURL: URL? = nil

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    if documentURLs.isEmpty {
                        Spacer()
                        Text("Добавьте PDF-презентацию")
                            .foregroundColor(.secondary)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(documentURLs.indices, id: \ .self) { idx in
                                    let url = documentURLs[idx]
                                    Button(action: {
                                        selectedDocumentURL = url
                                        showDocumentSheet = true
                                    }) {
                                        HStack {
                                            Image(systemName: "doc.richtext")
                                                .resizable()
                                                .frame(width: 32, height: 40)
                                                .foregroundColor(.blue)
                                            Text(url.lastPathComponent)
                                                .font(.body)
                                                .lineLimit(1)
                                                .padding(.leading, 8)
                                            Spacer()
                                        }
                                        .padding(8)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.vertical)
                        }
                        .background(Color(.systemGray6))
                    }
                    Spacer(minLength: 80)
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
            .navigationTitle("Cast Presentation")
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
            PresentationPicker(isPresented: $showDocumentPicker) { urls in
                print("Picked URLs: \(urls)")
                let validPDFs = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
                documentURLs.append(contentsOf: validPDFs)
                print("Current documentURLs: \(documentURLs)")
            }
        }
        .sheet(isPresented: $showDocumentSheet) {
            if let url = selectedDocumentURL {
                PresentationDocumentCastView(documentURL: url)
            }
        }
    }
}
