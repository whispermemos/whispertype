//
//  UploadingManager.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 17/02/2025.
//

import Foundation

enum UploadResult {
    case success(transcript: String?, blockNumber: Int)
    case failure(Error)
}

class UploadingManager {
    private var activeTasks = Set<Task<Void, Never>>()

    func uploadRecording(blockNumber: Int, audioData: NSData) async -> UploadResult {
        let selectedLanguage =
            UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedLanguageCode) ?? "auto"

        // Get custom spellings and join them with commas
        let customSpellings = UserDefaults.standard.customSpellings
        let prompt = customSpellings.isEmpty ? nil : "Glossary: " + customSpellings.joined(separator: ", ")

        let options = UploadOptions(
            audioData: audioData,
            language: selectedLanguage,
            prompt: prompt
        )

        do {
            let result = try await WhisperType.uploadRecording(options: options)
            return .success(transcript: result.segmentTranscript, blockNumber: blockNumber)
        } catch {
            return .failure(error)
        }
    }

    func cancelUpload() {
        activeTasks.forEach { $0.cancel() }
        activeTasks.removeAll()
    }
}
