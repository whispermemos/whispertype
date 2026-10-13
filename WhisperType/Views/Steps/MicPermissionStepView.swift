import AVFoundation
import SwiftUI

struct MicPermissionStepView: View {
    @Binding var micPermissionGranted: Bool
    let onBack: () -> Void
    let onContinue: () -> Void
    @State private var showingPermissionDeniedAlert = false

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                SetupTitle(title: "Microphone Access")

                Text("WhisperType needs access to your microphone to convert speech to text.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Text("Please click the button below and grant microphone access when prompted.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.subtleGray)
                        .frame(height: 44)

                    Button(
                        micPermissionGranted
                            ? "✔︎ Microphone access granted"
                            : "Request microphone access"
                    ) {
                        if !micPermissionGranted {
                            DispatchQueue.main.async {
                                AVCaptureDevice.requestAccess(for: .audio) { granted in
                                    DispatchQueue.main.async {
                                        micPermissionGranted = granted
                                        if !granted {
                                            showingPermissionDeniedAlert = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .disabled(micPermissionGranted)
                }
                .padding(.horizontal)
            }
            .padding(.horizontal)
            .alert("Microphone Access Denied", isPresented: $showingPermissionDeniedAlert) {
                Button("Open System Preferences") {
                    NSWorkspace.shared.open(
                        URL(
                            string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
                        )!)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "WhisperType needs microphone access to work. Please enable it in System Preferences."
                )
            }

            Spacer()
            Spacer()

            HStack {
                Button("Back", action: onBack)

                Spacer()

                ContinueButton(
                    action: onContinue,
                    isDisabled: !micPermissionGranted
                )
            }
            .padding(.horizontal)
        }
        .onAppear {
            micPermissionGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
    }
}
