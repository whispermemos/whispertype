import KeyboardShortcuts
import SwiftUI

struct WelcomeStepView: View {
    let shortcutString: String?
    let onContinue: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                SetupTitle(title: "Welcome to WhisperType!")
                
                if isDev() {
                    DevBadge()
                }

                Text("It lets you type by speaking by pressing a global keyboard shortcut.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Text("First, pick the shortcut you want to use. We suggest ⌥+Space.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.subtleGray)
                        .frame(height: 44)

                    KeyboardShortcuts.Recorder("", name: .toggleRecording)
                }
                .padding(.horizontal)
            }
            .padding(.horizontal)

            Spacer()
            Spacer()

            HStack {
                Spacer()

                ContinueButton(
                    action: onContinue,
                    isDisabled: shortcutString == nil
                )
            }
            .padding(.horizontal)
        }
    }
}
