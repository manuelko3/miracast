import SwiftUI
import PDFKit

struct PresentationDocumentCastView: View {
    let documentURL: URL
    var body: some View {
        PDFKitView(url: documentURL)
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.backgroundColor = .white
        return pdfView
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
