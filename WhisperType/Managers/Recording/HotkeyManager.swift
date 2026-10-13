//
//  HotkeyManager.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 17/02/2025.
//

import Foundation
import HotKey
import KeyboardShortcuts

class HotkeyManager {
    private var escHotkey: HotKey
    private var returnHotkey: HotKey

    private var manualParagraphsObserver: NSKeyValueObservation?

    var onToggleRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?
    var onCancelRecording: (() -> Void)?
    var onNewParagraph: (() -> Void)?

    var isRecording: Bool = false {
        didSet {
            self.update()
        }
    }

    init() {
        escHotkey = HotKey(key: .escape, modifiers: [])
        returnHotkey = HotKey(key: .return, modifiers: [])

        escHotkey.keyDownHandler = { [weak self] in
            self?.onCancelRecording?()
        }

        returnHotkey.keyDownHandler = { [weak self] in
            self?.onNewParagraph?()
        }

        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            self?.onToggleRecording?()
        }

        manualParagraphsObserver = UserDefaults.standard.observe(
            \.manualParagraphs, options: [.initial, .new]
        ) { [weak self] _, change in
            self?.update()
        }

        update()
    }

    func update() {
        // Since we're already observing manualParagraphs using KVO, we can access it directly
        let manualParagraphsEnabled = UserDefaults.standard.manualParagraphs
        print("manual paragraphs enabled: \(manualParagraphsEnabled)")

        // Escape key is enabled only when recording
        escHotkey.isPaused = !isRecording

        // Return key is enabled when both recording is active and manual paragraphs are enabled
        returnHotkey.isPaused = !isRecording || !manualParagraphsEnabled
        
        print("return paused: \(returnHotkey.isPaused)")
    }
}
