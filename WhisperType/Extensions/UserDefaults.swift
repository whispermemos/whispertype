//
//  UserDefaults.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 24/01/2025.
//

//import Foundation

import Foundation

struct UserDefaultsKeys {
    // Key from shortcuts library
    static let shortcutToggleRecording = "KeyboardShortcuts_toggleRecording"
    static let hasSetup = "hasSetup"
    static let autoPasteText = "autoPasteText"
    static let keepTranscriptionInClipboard = "keepTranscriptionInClipboard"
    static let manualParagraphs = "manualParagraphs"
    static let useDarkIcon = "useDarkIcon"
    static let historyEntries = "historyEntries"
    static let customSpellings = "customSpellings"
    static let hideFailedSheet = "hideFailedSheet"
    static let selectedLanguageCode = "selectedLanguageCode"
    static let showMenuBarIcon = "showMenuBarIcon"
    static let lowerSystemVolumeWhileRecording = "lowerSystemVolumeWhileRecording"
}

extension UserDefaults {
    @objc dynamic var manualParagraphs: Bool {
        get { bool(forKey: UserDefaultsKeys.manualParagraphs) }
        set { set(newValue, forKey: UserDefaultsKeys.manualParagraphs) }
    }

    @objc dynamic var useDarkIcon: Bool {
        get { bool(forKey: UserDefaultsKeys.useDarkIcon) }
        set { set(newValue, forKey: UserDefaultsKeys.useDarkIcon) }
    }

    @objc dynamic var historyEntriesData: Data? {
        get { data(forKey: UserDefaultsKeys.historyEntries) }
        set { set(newValue, forKey: UserDefaultsKeys.historyEntries) }
    }

    dynamic var historyEntries: [HistoryEntry] {
        get {
            guard let data = historyEntriesData,
                let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data)
            else {
                return []
            }
            return entries
        }
        set {
            historyEntriesData = try? JSONEncoder().encode(newValue)
        }
    }

    @objc dynamic var customSpellings: [String] {
        get { array(forKey: UserDefaultsKeys.customSpellings) as? [String] ?? [] }
        set { set(newValue, forKey: UserDefaultsKeys.customSpellings) }
    }

    @objc dynamic var hideFailedSheet: Bool {
        get { bool(forKey: UserDefaultsKeys.hideFailedSheet) }
        set { set(newValue, forKey: UserDefaultsKeys.hideFailedSheet) }
    }

    @objc dynamic var showMenuBarIcon: Bool {
        get { bool(forKey: UserDefaultsKeys.showMenuBarIcon) }
        set { set(newValue, forKey: UserDefaultsKeys.showMenuBarIcon) }
    }
}
