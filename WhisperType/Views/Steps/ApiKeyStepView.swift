import SwiftUI

/*
 * Onboarding step that asks for the user's Groq API key, which transcription requires.
 * Saves the key to the Keychain on Continue; the same key can be changed later in Settings → API Key.
 */

struct ApiKeyStepView: View {
    let onBack: () -> Void
    let onContinue: () -> Void
    @State private var apiKey = ""

    private var trimmedApiKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                SetupTitle(title: "Groq API Key")

                Text("WhisperType transcribes your recordings with Groq, using your own API key.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                SecureField("gsk_…", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                    .padding(.horizontal)

                Link("Get an API key at console.groq.com", destination: URL(string: "https://console.groq.com/keys")!)
                    .font(.footnote)
            }
            .padding(.horizontal)

            Spacer()

            HStack {
                Button("Back", action: onBack)

                Spacer()

                ContinueButton(action: save, isDisabled: trimmedApiKey.isEmpty)
            }
            .padding(.horizontal)
        }
        .onAppear {
            apiKey = loadGroqApiKey() ?? ""
        }
    }

    private func save() {
        guard !trimmedApiKey.isEmpty else { return }
        saveGroqApiKey(trimmedApiKey)
        onContinue()
    }
}
