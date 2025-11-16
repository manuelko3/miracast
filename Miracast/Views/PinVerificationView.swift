import SwiftUI

struct PinVerificationView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var pinCode: String = ""
    @State private var isVerifying: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    let deviceName: String
    let onVerify: (String) -> Void
    
    var body: some View {
        ZStack {
            // Градиентный фон
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 217/255, green: 233/255, blue: 255/255),
                    Color.white
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Заголовок
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: 32, height: 32)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Connect device")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Основной контент
                VStack(spacing: 24) {
                    // Иконка устройства
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "tv")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }
                    
                    // Название устройства
                    Text(deviceName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    
                    // Описание
                    VStack(spacing: 8) {
                        Text("Verify PIN-code")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                        
                        Text("To pair your iPhone/iPad, enter\nthe code shown on your TV")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    
                    // Поле ввода PIN
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ForEach(0..<6, id: \.self) { index in
                                PinDigitView(
                                    digit: index < pinCode.count ? String(pinCode[pinCode.index(pinCode.startIndex, offsetBy: index)]) : "",
                                    isActive: index == pinCode.count
                                )
                            }
                        }
                        
                        if showError {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.top, 24)
                    
                    // Кастомная клавиатура
                    PinKeyboard(pinCode: $pinCode, maxLength: 6)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Кнопки
                VStack(spacing: 12) {
                    Button(action: {
                        verifyPin()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(pinCode.count == 6 ? Color.blue : Color.blue.opacity(0.5))
                                .frame(height: 50)
                            
                            if isVerifying {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Verify")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .disabled(pinCode.count != 6 || isVerifying)
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(height: 50)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
    }
    
    private func verifyPin() {
        guard pinCode.count == 6 else { return }
        
        isVerifying = true
        showError = false
        
        // Симулируем проверку PIN (в реальности будет запрос к TV)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Для демонстрации: любой 6-значный код принимается
            // В реальном приложении здесь будет запрос к Samsung TV API
            
            let isValid = true // Здесь будет реальная проверка
            
            if isValid {
                onVerify(pinCode)
                isPresented = false
            } else {
                isVerifying = false
                showError = true
                errorMessage = "Invalid PIN code. Please try again."
                pinCode = ""
            }
        }
    }
}

struct PinDigitView: View {
    let digit: String
    let isActive: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 45, height: 55)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                )
            
            Text(digit)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.black)
        }
    }
}

struct PinKeyboard: View {
    @Binding var pinCode: String
    let maxLength: Int
    
    let numbers = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(numbers, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear
                                .frame(width: 70, height: 50)
                        } else {
                            Button(action: {
                                handleKeyPress(key)
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white)
                                        .frame(width: 70, height: 50)
                                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    
                                    if key == "⌫" {
                                        Image(systemName: "delete.left")
                                            .font(.system(size: 20))
                                            .foregroundColor(.black)
                                    } else {
                                        Text(key)
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func handleKeyPress(_ key: String) {
        if key == "⌫" {
            if !pinCode.isEmpty {
                pinCode.removeLast()
            }
        } else if pinCode.count < maxLength {
            pinCode += key
        }
    }
}

// Preview
struct PinVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        PinVerificationView(
            isPresented: .constant(true),
            deviceName: "Samsung TV",
            onVerify: { pin in
                print("PIN entered: \(pin)")
            }
        )
        .environmentObject(AppState())
    }
}
