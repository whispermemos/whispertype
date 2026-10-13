//
//  ContentView.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 13/12/2024.
//

import SwiftUI

enum OnboardingStep {
    case welcome
    case micPermission
    case accessibility
    case apiKey
    case completion
}

struct WelcomeWindow: View {
    @AppStorage(UserDefaultsKeys.shortcutToggleRecording) private var shortcutString: String?
    @AppStorage(UserDefaultsKeys.hasSetup) private var hasSetup = false
    @State private var currentStep: OnboardingStep = .welcome
    @State private var micPermissionGranted = false
    @Environment(\.colorScheme) private var colorScheme

    private let steps: [OnboardingStep] = [.welcome, .micPermission, .accessibility, .apiKey, .completion]

    private func onContinue() {
        if let currentIndex = steps.firstIndex(of: currentStep), currentIndex + 1 < steps.count {
            currentStep = steps[currentIndex + 1]
        }
    }

    private func onBack() {
        if let currentIndex = steps.firstIndex(of: currentStep), currentIndex > 0 {
            currentStep = steps[currentIndex - 1]
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            if hasSetup {
                CompletionStepView(onBack: onBack)
            } else {
                switch currentStep {
                case .welcome:
                    WelcomeStepView(shortcutString: shortcutString, onContinue: onContinue)
                case .micPermission:
                    MicPermissionStepView(
                        micPermissionGranted: $micPermissionGranted,
                        onBack: onBack,
                        onContinue: onContinue
                    )
                case .accessibility:
                    AccessibilityPermissionStepView(
                        onBack: onBack,
                        onContinue: onContinue
                    )
                case .apiKey:
                    ApiKeyStepView(
                        onBack: onBack,
                        onContinue: onContinue
                    )
                case .completion:
                    CompletionStepView(onBack: onBack)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(colorScheme == .dark ? .windowBackgroundColor : .white))
    }
}
