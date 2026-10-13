import SwiftUI

struct ProcessingFailedSheet: View {
    let error: String
    let onDismiss: () -> Void
    let onOpenSettings: () -> Void

    @AppStorage(UserDefaultsKeys.hideFailedSheet) private var hideProcessingFailedSheet = false

    var body: some View {
        VStack(spacing: 16) {
            Image("about")
                .padding(.top)

            VStack(spacing: 8) {
                Text("Processing failed")
                    .font(.headline)

                Text(
                    "The recording failed to process, likely due to a networking issue. You can retry processing in Settings → History."
                        + (error.isEmpty ? "" : "\n\n\(error)")
                )
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            }

            Toggle(
                "Don't show this message again",
                isOn: $hideProcessingFailedSheet
            )

            HStack {
                Button("Close") {
                    onDismiss()
                }

                Spacer()

                ContinueButton(
                    action: {
                        onDismiss()
                        onOpenSettings()
                    },
                    label: "Open Settings"
                )
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 320)
    }
}
