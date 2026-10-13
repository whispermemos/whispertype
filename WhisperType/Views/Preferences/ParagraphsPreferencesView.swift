import SwiftUI

struct ParagraphsPreferencesView: View {
    @AppStorage(UserDefaultsKeys.manualParagraphs) private var manualParagraphs = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Manual paragraphs", isOn: $manualParagraphs)
                    Text("Create a new paragraph by pressing the Return key while recording")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
            }
            .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
    }
} 
