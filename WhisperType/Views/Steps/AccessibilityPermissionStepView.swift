import ApplicationServices
import SwiftUI

struct AccessibilityPermissionStepView: View {
    @State private var accessibilityGranted = false
    @State private var timer: Timer?
    @State private var showingSkipWarning = false
    let onBack: () -> Void
    let onContinue: () -> Void

    private func checkAccessibilityAccess() -> Bool {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [checkOptPrompt: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary?)
    }

    private func openSystemPreferences() {
        let prefpaneUrl = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(prefpaneUrl)
    }

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                SetupTitle(title: "Accessibility Access")

                Text("WhisperType needs accessibility access to type text into other applications.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Text(
                    "Please click the button below to open System Settings and grant accessibility access."
                )
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.subtleGray)
                        .frame(height: 44)

                    Button(
                        accessibilityGranted
                            ? "✔︎ Accessibility access granted" : "Request accessibility access"
                    ) {
                        let granted = checkAccessibilityAccess()
                        if !granted {
                            //                            openSystemPreferences()
                            copyAndInsert("", shouldPaste: true)
                        }
                    }
                    .disabled(accessibilityGranted)
                }
                .padding(.horizontal)

                if !accessibilityGranted {
                    Button("Skip for now") {
                        showingSkipWarning = true
                    }
                    .buttonStyle(.link)
                    .foregroundColor(.secondary)
                    .font(.footnote)
                    .padding(.trailing, 8)
                }
            }
            .padding(.horizontal)

            Spacer()

            HStack {
                Button("Back", action: onBack)

                Spacer()

                ContinueButton(
                    action: onContinue,
                    isDisabled: !accessibilityGranted
                )
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingSkipWarning) {
            VStack(spacing: 20) {
                Text("Skip Accessibility Access")
                    .font(.headline)

                Text(
                    "Without Accessibility Access, WhisperType can only copy your recordings to the clipboard. You'll need to manually paste them into text fields."
                )
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    Button("Go Back") {
                        showingSkipWarning = false
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Skip Anyway") {
                        showingSkipWarning = false
                        onContinue()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(width: 400)
        }
        .onAppear {
            accessibilityGranted = checkAccessibilityAccess()

            // Start timer to check accessibility access
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                let granted = checkAccessibilityAccess()
                if granted {
                    accessibilityGranted = true
                    timer?.invalidate()
                    timer = nil
                }
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            timer?.invalidate()
            timer = nil
        }
    }
}
