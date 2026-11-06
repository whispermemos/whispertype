import SwiftUI

/*
 * Shares the update action between WhisperType's app menu, menu bar, and settings.
 * Reflects Sparkle availability and prevents checks during recording or transcription.
 */
struct CheckForUpdatesButton: View {
    @ObservedObject var updates: UpdateManager

    var body: some View {
        Button(updates.hasUpdateAvailable ? "Update Available…" : "Check for Updates…") {
            updates.checkForUpdates()
        }
        .disabled(!updates.canCheckForUpdates || updates.isBusy)
    }
}
