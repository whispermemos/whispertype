import SwiftUI

struct PreferencesWindow: View {
    enum Tab {
        case general
        case paragraphs
        case spelling
        case history
        case apiKey
        case updates
    }

    @State private var selectedTab: Tab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralPreferencesView()
                .tabItem {
                    Label("General", image: "general")
                }
                .tag(Tab.general)

            ParagraphsPreferencesView()
                .tabItem {
                    Label("Paragraphs", image: "paragraphs")
                }
                .tag(Tab.paragraphs)

            SpellingPreferencesView()
                .tabItem {
                    Label("Spelling", image: "spelling")
                }
                .tag(Tab.spelling)

            HistoryPreferencesView()
                .tabItem {
                    Label("History", image: "history")
                }
                .tag(Tab.history)

            ApiKeyPreferencesView()
                .tabItem {
                    Label("API Key", image: "apikey")
                }
                .tag(Tab.apiKey)

            UpdatesPreferencesView(updates: globalUpdateManager)
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(Tab.updates)
        }
        .frame(width: 460, height: 420)
    }
}
