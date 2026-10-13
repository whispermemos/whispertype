//
//  TranscriptStore.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 12/02/2025.
//

import Foundation

enum TranscriptResult {
    case success(String)
    case error(String?)
}

class TranscriptStore {
    private var transcripts: [Int: TranscriptResult] = [:]
    var manualParagraphsAt: [Int] = []
    var finalNumber: Int?

    // MARK: - Lifecycle

    func reset() {
        transcripts = [:]
        manualParagraphsAt = []
        finalNumber = nil
    }

    // MARK: - Adding transcripts

    func addTranscript(number: Int, transcript: String?) {
        if let transcript = transcript {
            self.transcripts[number] = .success(transcript)
        } else {
            self.transcripts[number] = .error(nil)
        }
    }

    func addError(number: Int, error: String? = nil) {
        self.transcripts[number] = .error(error)
    }

    // MARK: - Adding paragraph indexes

    func addParagraphAt(_ index: Int) {
        manualParagraphsAt.append(index)
    }
    
    func hasParagraphAt(_ index: Int) -> Bool {
        return manualParagraphsAt.contains(index)
    }

    // MARK: - Getting results

    func hasAllResults() -> Bool {
        guard let finalNumber = finalNumber else {
            return false
        }

        // Check if we have a result for each number from 1 to finalNumber
        for number in 0..<finalNumber {
            if transcripts[number] == nil {
                return false
            }
        }

        return true
    }

    private var sortedTranscripts: [String] {
        return self.transcripts
            .sorted { $0.key < $1.key }
            .compactMap { key, result in
                if case .success(let transcript) = result {
                    return transcript
                }
                return nil
            }
    }

    private func getGroupedTranscripts() -> [[String]] {
        let transcripts = self.sortedTranscripts
        var paragraphs: [[String]] = []
        var currentParagraph: [String] = []

        for (index, transcript) in transcripts.enumerated() {
            currentParagraph.append(transcript)

            if manualParagraphsAt.contains(index) {
                paragraphs.append(currentParagraph)
                currentParagraph = []
            }
        }

        if currentParagraph.count > 0 {
            paragraphs.append(currentParagraph)
        }

        return paragraphs
    }

    func getParagraphs() -> [String] {
        let groups = self.getGroupedTranscripts()
        
        return groups.map { group in
            var merged = mergeAll(strings: group)
            
            // Capitalize first letter
            if let firstLetter = merged.first {
                merged = String(firstLetter).uppercased() + merged.dropFirst()
            }
            
            // Check if the string already ends with a sentence-ending punctuation
            // Using CharacterSet.punctuationCharacters to check for sentence endings
            if let lastChar = merged.last,
               !CharacterSet(charactersIn: String(lastChar))
                .isSubset(of: CharacterSet.punctuationCharacters) {
                merged += "."
            }
            
            return merged
        }
    }

    /** Returns paragraphs joined into string */
    func getText() -> String {
        let paragraphs = getParagraphs()
        return paragraphs.joined(separator: "\n\n")
    }

    var hasError: Bool {
        for result in transcripts.values {
            if case .error = result {
                return true
            }
        }
        return false
    }

    var lastError: String? {
        for result in transcripts.values {
            if case .error(let message) = result {
                return message
            }
        }
        return nil
    }
}
