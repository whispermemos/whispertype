//
//  WhisperTypeApp.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 13/12/2024.
//

import AppKit
import KeyboardShortcuts
import SimplyCoreAudio
import SwiftUI

let defaultWidth = 350.0
let defaultHeight = 420.0

var globalAppDelegate: AppDelegate?

let globalSimplyCA = SimplyCoreAudio()
let globalInputDeviceManager = InputDeviceManager(simplyCA: globalSimplyCA)
let globalRecordingManager = RecordingManager(
    inputDeviceManager: globalInputDeviceManager,
    historyManager: globalHistoryManager
)
let globalWindowManager = WindowManager()
let globalAnimationManager = AnimationManager()
let globalHistoryManager = HistoryManager()

class AppDelegate: NSObject, NSApplicationDelegate {
    var welcomeWindow: NSWindow?
    private var darkIconObserver: NSKeyValueObservation?
    private var menuBarIconObserver: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        globalAppDelegate = self

        UserDefaults.standard.register(defaults: [
            UserDefaultsKeys.hasSetup: false,
            UserDefaultsKeys.manualParagraphs: true,
            UserDefaultsKeys.useDarkIcon: false,
            UserDefaultsKeys.hideFailedSheet: false,
            UserDefaultsKeys.autoPasteText: true,
            UserDefaultsKeys.showMenuBarIcon: false,
            UserDefaultsKeys.lowerSystemVolumeWhileRecording: true,
        ])

        setupMenuBarIconObserver()
        setupDarkIconObserver()
        
        // Always create the welcome window
        createWelcomeWindow()
        
        // Only show welcome window if not launched automatically at login
        if !NSApplication.shared.launchedAtLogin {
            showWelcomeWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up observers to prevent memory leaks
        darkIconObserver?.invalidate()
        menuBarIconObserver?.invalidate()
    }

    private func setupDarkIconObserver() {
        darkIconObserver = UserDefaults.standard.observe(
            \.useDarkIcon, options: [.initial, .new]
        ) { _, change in
            if let useDarkIcon = change.newValue {

                if useDarkIcon {
                    NSApp.applicationIconImage = NSImage(named: "AppIconDark")
                } else {
                    NSApp.applicationIconImage = nil
                }
            }
        }
    }

    private func setupMenuBarIconObserver() {
        menuBarIconObserver = UserDefaults.standard.observe(
            \.showMenuBarIcon, options: [.initial, .new]
        ) { [weak self] _, change in
            if change.newValue != nil {
                self?.updateMenubarIcon()
            }
        }
    }

    private func updateMenubarIcon() {
        let showMenubar = UserDefaults.standard.showMenuBarIcon

        NSApplication.shared.setActivationPolicy(showMenubar ? .accessory : .regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWelcomeWindow() {
        let welcomeView = WelcomeWindow()
            .environmentObject(globalRecordingManager)
            .environmentObject(globalWindowManager)
            .environmentObject(globalAnimationManager)

        welcomeWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        welcomeWindow?.titlebarAppearsTransparent = true
        welcomeWindow?.titleVisibility = .hidden
        welcomeWindow?.contentView = NSHostingView(rootView: welcomeView)
        welcomeWindow?.setContentSize(NSSize(width: defaultWidth, height: defaultHeight))
        welcomeWindow?.center()
        welcomeWindow?.isReleasedWhenClosed = false
    }
    
    private func showWelcomeWindow() {
        welcomeWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showWelcomeWindow()
        return true
    }

    func activateAfterError() {
        if UserDefaults.standard.hideFailedSheet {
            return
        }

        showWelcomeWindow()
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct WhisperTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage(UserDefaultsKeys.showMenuBarIcon) private var showMenuBarIcon = false

    var body: some Scene {
        Group {
            Settings {
                PreferencesWindow()
                    .environmentObject(globalInputDeviceManager)
                            .environmentObject(globalHistoryManager)
                    .environmentObject(globalRecordingManager)
            }

            MenuBarExtra(isInserted: $showMenuBarIcon) {
                MenubarView().environmentObject(globalRecordingManager)
            } label: {
                Image("MenubarTemplate").renderingMode(.template)
            }
            .menuBarExtraStyle(.menu)
        }
        .commands {
            // Add default application commands
            CommandGroup(replacing: .appInfo) {
                Button("About WhisperType") {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(replacing: .systemServices) {}
            CommandGroup(replacing: .newItem) {}

            // Add preferences command
            //                CommandGroup(after: .appSettings) {
            //                    Button("Preferences...") {
            //                        appDelegate.openPreferences()
            //                    }
            //                    .keyboardShortcut(",", modifiers: .command)
            //                }

            // Add window management commands
            CommandGroup(replacing: .windowSize) {}
            CommandGroup(replacing: .windowList) {
                Button("Show Main Window") {
                    appDelegate.welcomeWindow?.makeKeyAndOrderFront(nil)
                }
            }

            // Add standard file menu commands
            CommandGroup(replacing: .windowArrangement) {
                Button("Close") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            // // Add quit command
            // CommandGroup(replacing: .appTermination) {
            //     Button("Quit WhisperType") {
            //         NSApplication.shared.terminate(nil)
            //     }
            //     .keyboardShortcut("q", modifiers: .command)
            // }
        }
    }
}

struct MenubarView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var recordingManager: RecordingManager
    @State private var currentShortcut: KeyboardShortcuts.Shortcut?

    var body: some View {
        Group {
            Button(action: {
                if recordingManager.state == .recording {
                    recordingManager.stopRecording()
                } else if recordingManager.state == .idle {
                    recordingManager.startRecording()
                }
            }) {
                Text(recordingButtonLabel)
            }

            Divider()

            Button("Open Setup…") {
                globalAppDelegate?.welcomeWindow?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Open Settings…") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .onAppear {
            updateShortcut()
        }
    }

    private var recordingButtonLabel: String {
        let baseLabel = recordingManager.state == .recording ? "Stop Recording" : "Start Recording"

        if let shortcut = currentShortcut {
            return "\(baseLabel) (\(shortcut.description))"
        } else {
            return baseLabel
        }
    }

    private func updateShortcut() {
        currentShortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording)
    }
}
