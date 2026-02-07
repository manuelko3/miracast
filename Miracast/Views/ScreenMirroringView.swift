import SwiftUI
import ReplayKit
import AVFoundation
import Combine

struct ScreenMirroringView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ScreenMirroringViewModel()

    var body: some View {
        VStack {
            Text("Screen Mirroring to Smart TV")
                .font(.title)
                .padding()

            if viewModel.isStreaming {
                Text("Streaming...")
                    .foregroundColor(.green)
            } else {
                Text("Not streaming")
                    .foregroundColor(.red)
            }

            Spacer()

            Button(action: {
                if viewModel.isStreaming {
                    viewModel.stopStreaming()
                } else {
                    viewModel.startStreaming(appState: appState)
                }
            }) {
                Text(viewModel.isStreaming ? "Stop Streaming" : "Start Streaming")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(viewModel.isStreaming ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()

            Spacer()

            if viewModel.showErrorAlert {
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 10)
                    .padding()
            }
        }
        .alert(isPresented: $viewModel.showErrorAlert) {
            Alert(title: Text("Error"), message: Text(viewModel.errorMessage), dismissButton: .default(Text("OK")))
        }
    }
}

class ScreenMirroringViewModel: NSObject, ObservableObject {
    private let smartViewManager: SmartViewManager
    private var recorder: RPScreenRecorder?

    @Published var isStreaming = false
    @Published var errorMessage = ""
    @Published var showErrorAlert = false

    init(smartViewManager: SmartViewManager = SmartViewManager()) {
        self.smartViewManager = smartViewManager
        super.init()
    }

    func startStreaming(appState: AppState) {
        guard !isStreaming else { return }

        guard appState.connectedService != nil else {
            errorMessage = "Please connect to a TV first"
            showErrorAlert = true
            return
        }

        smartViewManager.connectedService = appState.connectedService

        recorder = RPScreenRecorder.shared()
        recorder?.delegate = self

        recorder?.startCapture(handler: { [weak self] sampleBuffer, bufferType, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Capture error: \(error.localizedDescription)"
                    self.showErrorAlert = true
                    self.stopStreaming()
                }
                return
            }

        }) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Failed to start: \(error.localizedDescription)"
                    self?.showErrorAlert = true
                } else {
                    self?.isStreaming = true
                    print("✅ Screen recording started")
                }
            }
        }
    }

    func stopStreaming() {
        recorder?.stopCapture { [weak self] error in
            DispatchQueue.main.async {
                self?.isStreaming = false
                self?.recorder = nil
                if let error = error {
                    print("⚠️ Stop capture error: \(error.localizedDescription)")
                }
            }
        }
    }
}

extension ScreenMirroringViewModel: RPScreenRecorderDelegate {
    func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWithError error: Error, previewViewController: RPPreviewViewController?) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = "Recording stopped: \(error.localizedDescription)"
            self?.showErrorAlert = true
            self?.isStreaming = false
        }
    }

    func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        print("Screen recorder availability changed")
    }
}

struct ScreenMirroringView_Previews: PreviewProvider {
    static var previews: some View {
        ScreenMirroringView()
            .environmentObject(AppState())
    }
}
