//
//  ErrorModal.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 15/01/2025.
//

import AppKit

func showErrorModal(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .critical
    alert.addButton(withTitle: "OK")
    
    alert.runModal()
}

func showConfirmationModal(title: String, message: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    
    let response = alert.runModal()
    return response == .alertFirstButtonReturn
}
