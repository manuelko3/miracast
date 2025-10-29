import SwiftUI

struct SlideshowOptionsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var showPhotoPicker: Bool
    @Binding var showReorderSheet: Bool
    @Binding var showDurationPicker: Bool
    @Binding var showMusicPicker: Bool
    var onShare: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator area
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Menu items
            VStack(spacing: 0) {
                MenuItemButton(icon: "photo.badge.plus", title: "Add") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPhotoPicker = true
                    }
                }
                
                Divider()
                    .padding(.leading, 60)
                
                MenuItemButton(icon: "arrow.up.arrow.down", title: "Reorder") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showReorderSheet = true
                    }
                }
                
                Divider()
                    .padding(.leading, 60)
                
                MenuItemButton(icon: "clock", title: "Duration") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showDurationPicker = true
                    }
                }
                
                Divider()
                    .padding(.leading, 60)
                
                MenuItemButton(icon: "music.note", title: "Music") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showMusicPicker = true
                    }
                }
                
                Divider()
                    .padding(.leading, 60)
                
                MenuItemButton(icon: "square.and.arrow.up", title: "Share") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onShare()
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(Color(UIColor.systemBackground))
    }
}

struct MenuItemButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                
                Spacer()
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
