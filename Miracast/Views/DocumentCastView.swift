import SwiftUI
import PDFKit

struct DocumentCastView: View {
    let documentURL: URL
    @State private var selectedPageIndex: Int = 0
    @State private var pageThumbnails: [UIImage] = []
    @State private var pageCount: Int = 0
    @State private var isCasting: Bool = false // добавлено состояние для CastButton

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Основная часть экрана — страница документа
                if let pdfDocument = PDFDocument(url: documentURL), pageCount > 0 {
                    PDFPageView(pdfDocument: pdfDocument, pageIndex: selectedPageIndex)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Не удалось открыть документ")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                // Коллекция миниатюр страниц
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(0..<pageThumbnails.count, id: \ .self) { idx in
                            let thumbnail = pageThumbnails[idx]
                            Button(action: {
                                selectedPageIndex = idx
                            }) {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 64)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedPageIndex == idx ? Color.blue : Color.clear, lineWidth: 2)
                                    )
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
        .onAppear {
            loadThumbnails()
        }
        .edgesIgnoringSafeArea(.all)
    }

    private func loadThumbnails() {
        guard let pdfDocument = PDFDocument(url: documentURL) else { return }
        pageCount = pdfDocument.pageCount
        pageThumbnails = (0..<pdfDocument.pageCount).compactMap { idx in
            pdfDocument.page(at: idx)?.thumbnail(of: CGSize(width: 48, height: 64), for: .artBox)
        }
    }
}

struct PDFPageView: View {
    let pdfDocument: PDFDocument
    let pageIndex: Int

    var body: some View {
        if let page = pdfDocument.page(at: pageIndex) {
            PDFPageRepresentedView(page: page)
        } else {
            Text("Страница не найдена")
        }
    }
}

struct PDFPageRepresentedView: UIViewRepresentable {
    let page: PDFPage

    func makeUIView(context: Context) -> PDFPageViewContainer {
        let container = PDFPageViewContainer()
        container.page = page
        return container
    }

    func updateUIView(_ uiView: PDFPageViewContainer, context: Context) {
        uiView.page = page
    }
}

class PDFPageViewContainer: UIView {
    var page: PDFPage? {
        didSet {
            setNeedsDisplay()
        }
    }
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let page = page, let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(rect)
        let pdfRect = page.bounds(for: .mediaBox)
        let scale = min(rect.width / pdfRect.width, rect.height / pdfRect.height)
        ctx.translateBy(x: (rect.width - pdfRect.width * scale) / 2, y: (rect.height - pdfRect.height * scale) / 2)
        ctx.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: ctx)
        ctx.restoreGState()
    }
}
