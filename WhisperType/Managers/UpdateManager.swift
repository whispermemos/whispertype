import Combine
import Sparkle

/*
 * Gives WhisperType's menus and settings access to Sparkle updates.
 * Watches recording activity so an update restart waits until transcription finishes.
 * Sparkle owns its update preferences; development builds never start the updater.
 */
final class UpdateManager: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var wantsAutomaticChecks = false
    @Published private(set) var wantsAutomaticUpdates = false
    @Published private(set) var hasUpdateAvailable = false
    @Published private(set) var isBusy = false

    private var subscriptions = Set<AnyCancellable>()
    private var pendingTerminationReply: (() -> Void)?
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self
    )

    var isEnabled: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }

    init(recordingState: AnyPublisher<RecordingState, Never>) {
        super.init()

        recordingState
            .handleEvents(receiveOutput: { [weak self] state in
                if state != .idle {
                    self?.isBusy = true
                }
            })
            // @Published emits before RecordingManager finishes setting its state.
            // Stay idle long enough for the clipboard's 0.5-second restoration.
            .debounce(for: .milliseconds(600), scheduler: DispatchQueue.main)
            .sink { [weak self] state in
                guard state == .idle else { return }
                self?.isBusy = false
                self?.finishPendingTerminationIfIdle()
            }
            .store(in: &subscriptions)
    }

    func start() {
        guard isEnabled else { return }

        let updater = controller.updater
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        updater.publisher(for: \.automaticallyChecksForUpdates)
            .assign(to: &$wantsAutomaticChecks)
        updater.publisher(for: \.automaticallyDownloadsUpdates)
            .assign(to: &$wantsAutomaticUpdates)

        do {
            try updater.start()
        } catch {
            NSLog("Could not start updater: %@", error.localizedDescription)
        }
    }

    func checkForUpdates() {
        guard isEnabled, canCheckForUpdates, !isBusy else { return }
        controller.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ wantsChecks: Bool) {
        controller.updater.automaticallyChecksForUpdates = wantsChecks
    }

    func setAutomaticUpdates(_ wantsUpdates: Bool) {
        controller.updater.automaticallyDownloadsUpdates = wantsUpdates
    }

    func postponeTerminationIfBusy(_ reply: @escaping () -> Void) -> Bool {
        guard isBusy else { return false }
        pendingTerminationReply = reply
        return true
    }

    private func finishPendingTerminationIfIdle() {
        guard !isBusy, let reply = pendingTerminationReply else { return }
        pendingTerminationReply = nil
        reply()
    }

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        hasUpdateAvailable = true
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        hasUpdateAvailable = false
    }

    func standardUserDriverWillFinishUpdateSession() {
        hasUpdateAvailable = false
    }
}
