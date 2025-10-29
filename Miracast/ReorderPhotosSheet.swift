import SwiftUI

struct ReorderPhotosSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var images: [UIImage]
    @State private var editableImages: [UIImage] = []
    var onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                if editableImages.isEmpty {
                    Text("No photos to reorder")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List {
                        ForEach(editableImages.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                Image(uiImage: editableImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Text("Photo \(index + 1)")
                                    .font(.system(size: 17))
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .onMove { source, destination in
                            editableImages.move(fromOffsets: source, toOffset: destination)
                        }
                    }
                    .environment(\.editMode, .constant(.active))
                }
            }
            .navigationTitle("Reorder Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        images = editableImages
                        dismiss()
                        onSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(editableImages.isEmpty)
                }
            }
        }
        .onAppear {
            editableImages = images
        }
    }
}
