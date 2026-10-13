import SwiftUI

struct ContinueButton: View {
    let action: () -> Void
    let isDisabled: Bool
    let label: String

    init(action: @escaping () -> Void, isDisabled: Bool = false, label: String = "Continue") {
        self.action = action
        self.isDisabled = isDisabled
        self.label = label
    }

    var body: some View {
        if isDisabled {
            Button(label) {}
            .disabled(true)
        } else {
            Button(label) {
                if !isDisabled {
                    action()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
