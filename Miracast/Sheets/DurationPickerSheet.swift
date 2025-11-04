import SwiftUI

struct DurationPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDuration: Double
    @State private var tempDuration: Double = 30
    var onSave: () -> Void
    
    let durations: [Double] = [15, 30, 45, 60, 90, 120]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(durations, id: \.self) { duration in
                    Button(action: {
                        tempDuration = duration
                    }) {
                        HStack {
                            Text(formatDuration(duration))
                                .foregroundColor(.black)
                            Spacer()
                            if tempDuration == duration {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        selectedDuration = tempDuration
                        dismiss()
                        onSave()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            tempDuration = selectedDuration
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        if minutes > 0 && secs > 0 {
            return "\(minutes) min \(secs) sec"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(secs) sec"
        }
    }
}
