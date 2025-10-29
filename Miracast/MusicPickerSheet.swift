import SwiftUI
import MediaPlayer

struct MusicPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedMusicURL: URL?
    @State private var tempMusicURL: URL? = nil
    @State private var showMusicPicker: Bool = false
    var onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let url = tempMusicURL {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Music selected")
                            .font(.headline)
                        
                        Text(url.lastPathComponent)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .padding(.horizontal)
                        
                        Button("Remove") {
                            tempMusicURL = nil
                        }
                        .foregroundColor(.red)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No music selected")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            requestMusicAccess()
                        }) {
                            Text("Choose Music")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        selectedMusicURL = tempMusicURL
                        dismiss()
                        onSave()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            tempMusicURL = selectedMusicURL
        }
    }
    
    private func requestMusicAccess() {
        let status = MPMediaLibrary.authorizationStatus()
        
        switch status {
        case .authorized:
            showMusicPicker = true
        case .notDetermined:
            MPMediaLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized {
                    DispatchQueue.main.async {
                        showMusicPicker = true
                    }
                }
            }
        default:
            // Show alert to go to settings
            print("Music library access denied")
        }
    }
}
