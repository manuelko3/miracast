import SwiftUI

struct SlideshowOptionsPopover: View {
    @Binding var showPhotoPicker: Bool
    @Binding var showReorderSheet: Bool
    @Binding var showDurationPicker: Bool
    @Binding var showMusicPicker: Bool
    var onShare: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PopoverMenuItem(icon: "photo.badge.plus", title: "Add") {
                showPhotoPicker = true
            }
            Divider().padding(.leading, 44)
            PopoverMenuItem(icon: "arrow.up.arrow.down", title: "Reorder") {
                showReorderSheet = true
            }
            Divider().padding(.leading, 44)
            PopoverMenuItem(icon: "clock", title: "Duration") {
                showDurationPicker = true
            }
            Divider().padding(.leading, 44)
            PopoverMenuItem(icon: "music.note", title: "Music") {
                showMusicPicker = true
            }
            Divider().padding(.leading, 44)
            PopoverMenuItem(icon: "square.and.arrow.up", title: "Share") {
                onShare()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.13), radius: 16, x: 0, y: 4)
        )
        .padding(.vertical, 8)
        .padding(.horizontal, 0)
    }
}

struct PopoverMenuItem: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .frame(width: 28, height: 28)
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.black)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
