//
//  Clipboard.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 26/12/2024.
//

import AppKit
import Accessibility
import Carbon

/// Represents saved clipboard content that can be restored later
private struct SavedClipboardContent {
    let items: [NSPasteboardItem]
    
    init?(from pasteboard: NSPasteboard) {
        guard let pasteboardItems = pasteboard.pasteboardItems, !pasteboardItems.isEmpty else {
            return nil
        }
        
        // Create copies of all pasteboard items with their data
        var copiedItems: [NSPasteboardItem] = []
        for item in pasteboardItems {
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            copiedItems.append(newItem)
        }
        
        self.items = copiedItems
    }
    
    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }
}

func copyAndInsert(_ text: String, shouldPaste: Bool) {
    // Check if auto-pasting is enabled
    let defaults = UserDefaults.standard
    let autoPasteText = defaults.object(forKey: UserDefaultsKeys.autoPasteText) as? Bool ?? true
    let willPaste = shouldPaste && autoPasteText
    
    // Save current clipboard contents if we're going to paste
    let savedClipboard: SavedClipboardContent? = willPaste ? SavedClipboardContent(from: NSPasteboard.general) : nil
    
    // Copy text to clipboard
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    
    if !willPaste {
        return
    }

    let commandKeyDown = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue)

    // Create 'v' key events (down and up), using whichever key types 'v'
    // in the current keyboard layout (e.g. Dvorak, AdnW)
    let vKeyCode = keyCode(for: "v") ?? CGKeyCode(kVK_ANSI_V)
    guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true)
    else { return }
    guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false) else {
        return
    }

    // Add Command modifier to both events
    keyDown.flags = commandKeyDown
    keyUp.flags = commandKeyDown

    // Post the events to simulate Command-V
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
    
    // Restore clipboard contents after a short delay to ensure paste completes
    // (unless user wants to keep transcription in clipboard)
    let keepTranscriptionInClipboard = defaults.bool(forKey: UserDefaultsKeys.keepTranscriptionInClipboard)
    if let savedClipboard = savedClipboard, !keepTranscriptionInClipboard {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            savedClipboard.restore(to: NSPasteboard.general)
        }
    }

    let options = [
        kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true as CFBoolean
    ]
    guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
        return
    }

    // Get system wide element
    let systemWide = AXUIElementCreateSystemWide()

    // Get focused element
    var focusedElement: AnyObject?
    guard
        AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
        let focusedElement = focusedElement
    else {
        return
    }

    let element = focusedElement as! AXUIElement

    // Check if we can set the value
    var isSettable: DarwinBoolean = false
    guard
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isSettable)
            == .success,
        isSettable.boolValue
    else {
        return
    }

    // Set the value
    let error = AXUIElementSetAttributeValue(
        element, kAXValueAttribute as CFString, text as CFTypeRef)
    guard error == .success else {
        return
    }
}

/// Finds the virtual keycode that produces `character` in the current keyboard layout.
/// Checks with the Command modifier held first, since layouts like "Dvorak - QWERTY ⌘"
/// map keys differently while Command is pressed.
private func keyCode(for character: Character) -> CGKeyCode? {
    let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
    let layoutSource: TISInputSource?
    if let source, TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) != nil {
        layoutSource = source
    } else {
        layoutSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
    }

    guard let layoutSource,
        let layoutDataPointer = TISGetInputSourceProperty(layoutSource, kTISPropertyUnicodeKeyLayoutData)
    else {
        return nil
    }

    let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPointer).takeUnretainedValue() as Data
    let target = String(character)

    return layoutData.withUnsafeBytes { rawBuffer -> CGKeyCode? in
        guard let layout = rawBuffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
            return nil
        }

        let modifierStates: [UInt32] = [UInt32((cmdKey >> 8) & 0xFF), 0]
        for modifierState in modifierStates {
            for code in 0..<128 {
                var deadKeyState: UInt32 = 0
                var chars = [UniChar](repeating: 0, count: 4)
                var length = 0
                let status = UCKeyTranslate(
                    layout,
                    UInt16(code),
                    UInt16(kUCKeyActionDown),
                    modifierState,
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysMask),
                    &deadKeyState,
                    chars.count,
                    &length,
                    &chars
                )
                if status == noErr, length > 0,
                    String(utf16CodeUnits: chars, count: length).lowercased() == target
                {
                    return CGKeyCode(code)
                }
            }
        }
        return nil
    }
}
