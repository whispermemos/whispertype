import SwiftUI

/*
 * Lets users control automatic checks and installation through Sparkle's preferences.
 * Offers a manual update check and explains when downloaded updates are installed.
 */
struct UpdatesPreferencesView: View {
    @ObservedObject var updates: UpdateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Automatically check for updates", isOn: Binding(
                get: { updates.wantsAutomaticChecks }, set: { updates.setAutomaticChecks($0) }
            ))

            Toggle("Automatically download and install updates", isOn: Binding(
                get: { updates.wantsAutomaticUpdates }, set: { updates.setAutomaticUpdates($0) }
            ))
            .disabled(!updates.wantsAutomaticChecks)

            Text("Downloaded updates install when WhisperType quits. Update restarts wait until recording and transcription finish.")
                .font(.callout)
                .foregroundStyle(.secondary)

            CheckForUpdatesButton(updates: updates)

            if !updates.isEnabled {
                Text("Updates are disabled in development builds.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(!updates.isEnabled)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}
