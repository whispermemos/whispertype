import SwiftUI

struct AddCustomWordView: View {
    @State private var newWord: String = ""
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    private func submit() {
        guard !newWord.isEmpty else { return }
        onConfirm(newWord)
        newWord = ""
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add custom spelling")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(
                    "Add words with unusual spellings to help the AI recognize them correctly in your speech. This is useful for names, places, or other uncommon words."
                )
                .multilineTextAlignment(.leading)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }

            TextField("Enter word", text: $newWord)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)

            HStack {
                Button("Cancel") {
                    newWord = ""
                    onCancel()
                }

                Spacer()

                ContinueButton(
                    action: submit,
                    isDisabled: newWord.isEmpty,
                    label: "Add"
                )
            }
        }
        .padding()
        .frame(width: 380)
    }
}
