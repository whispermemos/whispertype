import Combine
import Testing
@testable import WhisperType

/*
 * Checks that installing an update cannot interrupt recording or transcription.
 * Exercises the busy-to-idle transitions and the clipboard restoration grace period.
 */
@MainActor
struct UpdateManagerTests {
    @Test func idleDoesNotPostponeTermination() {
        let state = CurrentValueSubject<RecordingState, Never>(.idle)
        let updates = UpdateManager(recordingState: state.eraseToAnyPublisher())
        var hasCalledHandler = false

        #expect(!updates.postponeTerminationIfBusy { hasCalledHandler = true })
        // When not postponed, AppKit terminates the app without waiting for a reply.
        #expect(!hasCalledHandler)
    }

    @Test func waitsForRecordingAndTranscriptionThenRepliesOnce() async throws {
        let state = CurrentValueSubject<RecordingState, Never>(.recording)
        let updates = UpdateManager(recordingState: state.eraseToAnyPublisher())
        var installCount = 0

        #expect(updates.postponeTerminationIfBusy { installCount += 1 })
        state.send(.transcribing)
        try await Task.sleep(for: .milliseconds(700))
        #expect(installCount == 0)

        state.send(.idle)
        #expect(installCount == 0)
        try await Task.sleep(for: .milliseconds(700))
        #expect(installCount == 1)

        state.send(.idle)
        try await Task.sleep(for: .milliseconds(700))
        #expect(installCount == 1)
    }

    @Test func newRecordingDuringGracePeriodKeepsTerminationPending() async throws {
        let state = CurrentValueSubject<RecordingState, Never>(.transcribing)
        let updates = UpdateManager(recordingState: state.eraseToAnyPublisher())
        var hasInstalled = false

        #expect(updates.postponeTerminationIfBusy { hasInstalled = true })
        state.send(.idle)
        state.send(.recording)
        try await Task.sleep(for: .milliseconds(700))
        #expect(!hasInstalled)

        state.send(.idle)
        try await Task.sleep(for: .milliseconds(700))
        #expect(hasInstalled)
    }

    @Test func requiresFullGracePeriodAfterTheLatestIdleTransition() async throws {
        let state = CurrentValueSubject<RecordingState, Never>(.recording)
        let updates = UpdateManager(recordingState: state.eraseToAnyPublisher())
        var hasInstalled = false

        #expect(updates.postponeTerminationIfBusy { hasInstalled = true })
        try await Task.sleep(for: .milliseconds(400))
        state.send(.idle)
        try await Task.sleep(for: .milliseconds(300))
        #expect(!hasInstalled)
        try await Task.sleep(for: .milliseconds(400))
        #expect(hasInstalled)
    }

    @Test func terminationRequestedDuringClipboardRestorationStillWaits() async throws {
        let state = CurrentValueSubject<RecordingState, Never>(.transcribing)
        let updates = UpdateManager(recordingState: state.eraseToAnyPublisher())
        var hasInstalled = false

        state.send(.idle)
        #expect(updates.postponeTerminationIfBusy { hasInstalled = true })
        #expect(!hasInstalled)
        try await Task.sleep(for: .milliseconds(700))
        #expect(hasInstalled)
    }
}
