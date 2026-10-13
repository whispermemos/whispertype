//
//  SampleChunker.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 08/02/2025.
//

import Foundation

class SampleChunker {
    private var remainderSamples: [Float] = []
    private let chunkSize: Int
    
    init(chunkSize: Int) {
        self.chunkSize = chunkSize
    }
    
    func process(samples: [Float]) -> [[Float]] {
        var allSamples = samples
        
        // Prepend any remainder from last buffer
        if !remainderSamples.isEmpty {
            allSamples = remainderSamples + allSamples
            remainderSamples = []
        }

        // Break samples into chunks
        let numberOfCompleteChunks = allSamples.count / chunkSize
        let chunks = (0..<numberOfCompleteChunks).map { i in
            Array(allSamples[i * chunkSize..<(i + 1) * chunkSize])
        }
        
        // Store remainder for next buffer
        let remainderStartIndex = numberOfCompleteChunks * chunkSize
        if remainderStartIndex < allSamples.count {
            remainderSamples = Array(allSamples[remainderStartIndex..<allSamples.count])
        }
        
        return chunks
    }
}
