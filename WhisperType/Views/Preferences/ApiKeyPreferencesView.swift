import SwiftUI

/*
 * Settings tab where the user enters their own Groq API key, which WhisperType uses to transcribe recordings.
 * The key lives in the Keychain (see Keychain.swift); this view loads it on appear and saves it on demand.
 */

struct ApiKeyPreferencesView: View {
    @State private var apiKey = ""
    @State private var isSaved = false

    private let labelWidth: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Groq API key:")
                    .frame(width: labelWidth, alignment: .leading)

                SecureField("gsk_…", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                    .onChange(of: apiKey) { isSaved = false }
            }

            HStack {
                Text("").frame(width: labelWidth, alignment: .leading)

                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)

                if isSaved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("WhisperType sends your recordings directly to Groq for transcription, using your own API key. Groq bills your account for usage.")
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Link("Get an API key at console.groq.com", destination: URL(string: "https://console.groq.com/keys")!)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
        .onAppear {
            apiKey = loadGroqApiKey() ?? ""
        }
    }

    private func save() {
        saveGroqApiKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        isSaved = true
    }
}

#Preview {
    ApiKeyPreferencesView()
}
