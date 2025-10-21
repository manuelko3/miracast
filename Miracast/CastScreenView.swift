import SwiftUI

struct CastScreenView: View {
    @Environment(\.dismiss) var dismiss
    @State private var autoRotate = false
    @State private var sound = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.white
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Верхняя панель с кнопкой закрытия
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            // Кастомная кнопка закрытия: одна серая окружность и тёмный крестик
                            ZStack {
                                Circle()
                                    .fill(Color(red: 245/255, green: 246/255, blue: 248/255)) // светлый серый фон
                                    .frame(width: 44, height: 44)
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold)) // увеличил размер крестика с 16 -> 18
                                    .foregroundColor(Color(red: 153/255, green: 153/255, blue: 153/255))
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                            .accessibilityLabel("Close")
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Заголовок
                    Text("Cast Screen")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Описание
                            Text("Everything on your screen, including notifications, will be recorded")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.top, 8)

                            // Настройки
                            Text("Settings")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)

                            // Auto-Rotate
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.22, green: 0.51, blue: 0.97))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "arrow.clockwise")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Auto-Rotate")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                    Text("Content on your TV Will be in horizontal orientation")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Toggle("", isOn: $autoRotate)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)

                            // Sound
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.22, green: 0.51, blue: 0.97))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "speaker.wave.2.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sound")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                    Text("Sound will be on your TV Device")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Toggle("", isOn: $sound)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)

                            // Шаги
                            VStack(spacing: 12) {
                                // Step 1
                                StepCard(number: 1, text: "Tap the \"Start\" button below")

                                // Step 2
                                StepCard(number: 2, text: "Tap the \"Start Broadcast\" button")

                                // Step 3
                                StepCard(number: 3, text: "Screen cast will begin in 3 seconds", highlightText: "begin in 3 seconds")
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            Spacer(minLength: 100)
                        }
                    }

                    // Кнопка Start Cast
                    Button(action: {
                        // Действие для начала трансляции
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "record.circle")
                                .font(.system(size: 20))
                            Text("Start Cast")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(red: 0.22, green: 0.51, blue: 0.97))
                        .cornerRadius(28)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct StepBadge: View {
    let number: Int
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 243/255, green: 247/255, blue: 255/255))
                .frame(width: 94, height: 36)
            HStack(alignment: .center, spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(Color(red: 79/255, green: 135/255, blue: 243/255).opacity(0.2), lineWidth: 2)
                        .background(
                            Circle().fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 87/255, green: 148/255, blue: 253/255),
                                        Color(red: 28/255, green: 63/255, blue: 189/255)
                                    ]),
                                    startPoint: .top, endPoint: .bottom)
                            )
                        )
                        .frame(width: 32, height: 32)
                    Text("\(number)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.leading, 0)
                Text("Step")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.black)
                    .padding(.leading, 8)
            }
            .frame(width: 94, height: 36, alignment: .leading)
        }
    }
}

struct StepCard: View {
    let number: Int
    let text: String
    var highlightText: String?
    var highlightColor: Color = Color(red: 0.22, green: 0.51, blue: 0.97)

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                StepBadge(number: number)
                Spacer()
            }
            if let highlightText = highlightText, let range = text.range(of: highlightText) {
                let beforeText = String(text[..<range.lowerBound])
                let highlighted = String(text[range])
                let afterText = String(text[range.upperBound...])
                (
                    Text(beforeText)
                        .foregroundColor(.gray)
                        .font(.system(size: 15))
                    + Text(highlighted)
                        .foregroundColor(highlightColor)
                        .font(.system(size: 15, weight: .semibold))
                    + Text(afterText)
                        .foregroundColor(.gray)
                        .font(.system(size: 15))
                )
                .multilineTextAlignment(.center)
            } else {
                Text(text)
                    .foregroundColor(.gray)
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 95)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                .foregroundColor(Color.gray.opacity(0.3))
        )
    }
}

struct CastScreenView_Previews: PreviewProvider {
    static var previews: some View {
        CastScreenView()
    }
}
