import SwiftUI

struct HistoryPreferencesView: View {
    @EnvironmentObject private var historyManager: HistoryManager
    @EnvironmentObject private var recordingManager: RecordingManager
    @State private var selection: Set<String> = []

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack {
            Table(historyManager.entries, selection: $selection) {
                TableColumn("Time") { entry in
                    Text(timeFormatter.string(from: entry.timestamp))
                        .font(.system(size: 12))
                }
                .width(40)
                
//                TableColumn("Block count") { entry in
//                    Text(String(entry.blockCount))
//                        .font(.system(size: 12))
//                }
//                .width(40)

                TableColumn("Transcription") { entry in
                    if entry.state == .success {
                        Text(entry.transcription)
                            .font(.system(size: 12))
                            .lineLimit(2)
                    } else {
                        Text("(Failed)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }

                TableColumn("Actions") { entry in
                    HStack {
                        if entry.state == .success {
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(
                                    entry.transcription, forType: .string)
                            }) {
                                Text("Copy")
                                    .font(.system(size: 12))
                            }
                            .keyboardShortcut("c", modifiers: [.command])
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button(action: {
                                recordingManager.retryUpload(
                                    sessionId: entry.sessionId, lastBlockIndex: entry.blockCount)
                            }) {
                                Text("Retry")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }.width(60)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Button(action: {
                    for id in selection {
                        if let index = historyManager.entries.firstIndex(where: { $0.id == id }) {
                            historyManager.removeEntry(at: index)
                        }
                    }
                    selection.removeAll()
                }) {
                    Image(systemName: "minus")
                }
                .keyboardShortcut(.delete, modifiers: [])
                .controlSize(.small)
                .buttonStyle(.accessoryBarAction)
                .disabled(selection.isEmpty)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}
