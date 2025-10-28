import SwiftUI

struct CastButton: View {
    @Binding var isCasting: Bool
    var onTap: (() -> Void)? = nil
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) {
                isCasting.toggle()
            }
            onTap?()
        }) {
            HStack(spacing: 8) {
                Image(systemName: isCasting ? "stop.circle.fill" : "record.circle")
                    .font(.system(size: 20))
                Text(isCasting ? "Stop Cast" : "Start Cast")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if isCasting {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 255/255, green: 74/255, blue: 74/255),
                                Color(red: 255/255, green: 0/255, blue: 0/255)
                            ]),
                            startPoint: .trailing, endPoint: .leading
                        )
                    } else {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 62/255, green: 134/255, blue: 233/255),
                                Color(red: 0/255, green: 88/255, blue: 211/255)
                            ]),
                            startPoint: .trailing, endPoint: .leading
                        )
                    }
                }
            )
            .cornerRadius(28)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CastButton_Previews: PreviewProvider {
    @State static var isCasting = false
    static var previews: some View {
        VStack {
            CastButton(isCasting: $isCasting)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
        }
        .background(Color.gray.opacity(0.1))
    }
}
