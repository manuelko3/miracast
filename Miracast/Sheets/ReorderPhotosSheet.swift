import SwiftUI
import UniformTypeIdentifiers

struct ReorderPhotosSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var images: [UIImage]

    struct PhotoItem: Identifiable, Equatable {
        let id: UUID
        var image: UIImage
    }

    @State private var editableItems: [PhotoItem] = []
    @State private var showDeleteAlert: Bool = false
    @State private var indexToDelete: Int? = nil
    @State private var draggedItem: PhotoItem?
    var onSave: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if editableItems.isEmpty {
                    Text("No photos to reorder")
                        .foregroundColor(.gray)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(editableItems.indices, id: \.self) { index in
                                let item = editableItems[index]
                                GridCell(item: item.image, index: index) {
                                    // on delete tapped
                                    indexToDelete = index
                                    showDeleteAlert = true
                                }
                                .onDrag {
                                    self.draggedItem = item
                                    return NSItemProvider(object: item.id.uuidString as NSString)
                                }
                                .onDrop(of: [UTType.plainText], delegate: PhotoDropDelegate(
                                    destinationItem: item,
                                    items: $editableItems,
                                    draggedItem: $draggedItem
                                ))
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .navigationTitle("Reorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Manage Photos") {
                            // placeholder
                        }
                        Button("Photo duration") {
                            // placeholder
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    Button(action: {
                        // persist order back to images
                        images = editableItems.map { $0.image }
                        dismiss()
                        onSave()
                    }) {
                        Text("Save")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .onAppear {
                // initialize editableItems from images preserving identity
                editableItems = images.map { PhotoItem(id: UUID(), image: $0) }
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Delete photo?"),
                    message: Text("Are you sure you want to delete this photo?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let idx = indexToDelete, editableItems.indices.contains(idx) {
                            editableItems.remove(at: idx)
                            indexToDelete = nil
                        }
                    },
                    secondaryButton: .cancel {
                        indexToDelete = nil
                    }
                )
            }
        }
    }
}

private struct GridCell: View {
    let item: UIImage
    let index: Int
    var onDelete: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                Image(uiImage: item)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .cornerRadius(10)
                    .overlay(
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .padding(6), alignment: .topLeading
                    )

                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

fileprivate struct PhotoDropDelegate: DropDelegate {
    let destinationItem: ReorderPhotosSheet.PhotoItem
    @Binding var items: [ReorderPhotosSheet.PhotoItem]
    @Binding var draggedItem: ReorderPhotosSheet.PhotoItem?

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [UTType.plainText])
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = self.draggedItem,
              let fromIndex = items.firstIndex(where: { $0.id == draggedItem.id }),
              let toIndex = items.firstIndex(where: { $0.id == destinationItem.id }),
              fromIndex != toIndex else { return }

        withAnimation(.default) {
            let movedItem = items.remove(at: fromIndex)
            items.insert(movedItem, at: toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        self.draggedItem = nil
        return true
    }
}
