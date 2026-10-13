import SwiftUI

struct CustomWord: Identifiable, Hashable {
    let word: String
    var id: String { word }

    init(_ word: String) {
        self.word = word
    }
}

struct SpellingPreferencesView: View {
    @State private var customWords: [CustomWord] = []
    @State private var selectedWords: Set<String> = []
    @State private var isAddingWord = false
    @State private var newWord: String = ""

    init() {
        // Load initial words from UserDefaults
        let savedWords = UserDefaults.standard.customSpellings
        _customWords = State(initialValue: savedWords.map { CustomWord($0) })
    }

    private func save() {
        UserDefaults.standard.customSpellings = customWords.map { $0.word }
    }

    private func deleteSelectedWords() {
        for id in selectedWords {
            customWords.removeAll { $0.id == id }
        }
        selectedWords.removeAll()
        save()
    }

    var body: some View {
        VStack {
            Table(customWords, selection: $selectedWords) {
                TableColumn("Custom spelling") { word in
                    Text(word.word)
                        .font(.system(size: 12))
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Button(action: {
                    isAddingWord = true
                }) {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .controlSize(.small)
                .buttonStyle(.accessoryBarAction)

                Button(action: deleteSelectedWords) {
                    Image(systemName: "minus")
                }
                .keyboardShortcut(.delete, modifiers: [])
                .controlSize(.small)
                .buttonStyle(.accessoryBarAction)
                .disabled(selectedWords.isEmpty)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $isAddingWord) {
            AddCustomWordView(
                onConfirm: { word in
                    if !customWords.contains(where: { $0.word == word }) {
                        customWords.append(CustomWord(word))
                        save()
                    }
                    isAddingWord = false
                },
                onCancel: {
                    isAddingWord = false
                }
            )
        }
    }
}
