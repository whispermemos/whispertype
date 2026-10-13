import Combine
import Foundation

// MARK: - Entry

struct HistoryEntry: Codable, Identifiable {
    var id: String { sessionId }
    let sessionId: String
    let blockCount: Int
    let transcription: String
    let state: TranscriptionState
    let timestamp: Date
    let duration: TimeInterval

    enum TranscriptionState: String, Codable {
        case success
        case failed
    }
}

// MARK: - History Manager

class HistoryManager: ObservableObject {
    private let maxEntries = 20

    @Published private(set) var entries: [HistoryEntry] = []
    private var entriesObserver: NSKeyValueObservation?

    init() {
        entries = UserDefaults.standard.historyEntries

        // Observe changes to UserDefaults
        entriesObserver = UserDefaults.standard.observe(
            \.historyEntriesData,
            options: [.initial, .new]
        ) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.entries = UserDefaults.standard.historyEntries
            }
        }
    }

    // MARK: - Public Methods

    func setEntry(_ entry: HistoryEntry) {
        var entries = self.entries

        // Check if entry with same sessionId exists and remove it
        if let existingIndex = entries.firstIndex(where: { $0.sessionId == entry.sessionId }) {
            entries.remove(at: existingIndex)
        }

        entries.insert(entry, at: 0)  // Add new entry at the beginning

        // Keep only the last maxEntries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        UserDefaults.standard.historyEntries = entries
    }

    func removeEntry(at index: Int) {
        var entries = self.entries
        guard index >= 0 && index < entries.count else { return }

        entries.remove(at: index)
        UserDefaults.standard.historyEntries = entries
    }

    func removeAllEntries() {
        UserDefaults.standard.historyEntries = []
    }
}
