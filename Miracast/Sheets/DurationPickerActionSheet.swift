import SwiftUI

struct DurationPickerActionSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedDuration: Double
    var onSet: (Double) -> Void

    let durations: [Double] = Array(0...30).map { Double($0) } // 0–30 сек
    @State private var tempDuration: Double = 30

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    Picker(selection: $tempDuration, label: EmptyView()) {
                        ForEach(durations, id: \.self) { value in
                            Text("\(Int(value)) sec").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 160)
                    .clipped()

                    Divider()

                    VStack(spacing: 10) {
                        Button(action: {
                            selectedDuration = tempDuration
                            isPresented = false
                            onSet(tempDuration)
                        }) {
                            Text("Set duration")
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color(red: 118/255, green: 118/255, blue: 128/255, opacity: 0.12))
                                .cornerRadius(24)
                        }

                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel")
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color(red: 118/255, green: 118/255, blue: 128/255, opacity: 0.12))
                                .cornerRadius(24)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
                .cornerRadius(22)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            tempDuration = selectedDuration
        }
    }
}
