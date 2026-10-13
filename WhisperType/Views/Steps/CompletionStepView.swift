import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

struct CompletionStepView: View {
    let onBack: () -> Void
    @AppStorage(UserDefaultsKeys.hasSetup) private var hasSetup = false
    @AppStorage(UserDefaultsKeys.hideFailedSheet) private var hideProcessingFailedSheet = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.openSettings) var openSettings
    @EnvironmentObject private var recordingManager: RecordingManager
    @State private var failureError: String?

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                SetupTitle(title: "You're all set!")

                if isDev() {
                    DevBadge()
                }

                Text("You can now start using WhisperType by pressing your keyboard shortcut:")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                ShortcutView()
            }
            .padding(.horizontal)

            LaunchAtLogin.Toggle()
                .padding(.vertical)

            Spacer()
            Spacer()

            HStack {
                Button("Settings", action: { openSettings() })

                Spacer()

                ContinueButton(
                    action: {
                        dismiss()
                    },
                    isDisabled: false,
                    label: hasSetup ? "Close" : "Finish setup"
                )
            }
            .padding(.horizontal)
        }
        .onAppear {
            hasSetup = true
        }
        .onChange(of: recordingManager.lastError) { error in
            if let error = error, !hideProcessingFailedSheet {
                failureError = error
                recordingManager.lastError = nil
            }
        }
        .sheet(
            isPresented: Binding(
                get: { failureError != nil },
                set: { if !$0 { failureError = nil } }
            )
        ) {
            ProcessingFailedSheet(
                error: failureError ?? "",
                onDismiss: {
                    failureError = nil
                },
                onOpenSettings: {
                    openSettings()
                }
            )
        }
    }
}

struct ShortcutView: View {
    @State private var currentShortcut: KeyboardShortcuts.Shortcut?

    var body: some View {
        Group {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.subtleGray)
                    .frame(height: 44)

                Text(currentShortcut?.description ?? "")
                    .font(.title2)
            }
            .padding(.horizontal)
        }
        .onAppear {
            updateShortcut()
        }
    }

    private func updateShortcut() {
        currentShortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording)
    }
}
