//
//  SamplesStore.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 12/02/2025.
//

class SamplesStore {
    private var sampleRate: Double

    private var allSegments: [[Float]] = []
    private var currentSegmentSamples: [Float] = []

    private var blockRanges: [Range<Int>] = []

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func addToCurrent(_ samples: [Float]) {
        currentSegmentSamples.append(contentsOf: samples)
    }

    func finishSegment() {
        allSegments.append(currentSegmentSamples)

        // Create a new empty segment
        currentSegmentSamples = []
    }

    func finishBlock(extendingFromPrevious: Bool) -> (range: Range<Int>, index: Int) {
        var blockRange = currentBlockRange

        if extendingFromPrevious {
            blockRange = extendBlockWithSegmentFromPreviousBlock(blockRange)
        }

        blockRanges.append(blockRange)

        return (range: blockRange, index: blockRanges.count - 1)
    }

    func reset() {
        allSegments = []
        currentSegmentSamples = []
        blockRanges = []
    }

    func getDuration(_ range: Range<Int>) -> Double {
        let totalSamples = range.reduce(0) { sum, index in
            sum + allSegments[index].count
        }
        return Double(totalSamples) / sampleRate
    }

    func getBlockSamples(_ range: Range<Int>) -> [Float] {
        return range.flatMap { allSegments[$0] }
    }

    var currentBlockRange: Range<Int> {
        if let lastBlock = blockRanges.last {
            return lastBlock.upperBound..<allSegments.count
        } else {
            return 0..<allSegments.count
        }
    }

    var currentBlockDuration: Double {
        return getDuration(currentBlockRange)
    }
    
    var totalBlocks: Int {
        return blockRanges.count
    }
    
    var lastBlockIndex: Int? {
        return blockRanges.count > 0 ? blockRanges.count - 1 : nil
    }
    
    var totalDuration: Double {
        let totalRange = 0..<allSegments.count
        return getDuration(totalRange)
    }

    // This method should add a single segment from the previous block to the
    // current block. Only if there is a previous block and only if it's not a
    // 1-segment block.
    private func extendBlockWithSegmentFromPreviousBlock(_ blockRange: Range<Int>) -> Range<Int> {
        guard let lastBlock = blockRanges.last else {
            return blockRange
        }

        // If previous block has only 1 segment, then we don't want to use it
        if lastBlock.count <= 1 {
            return blockRange
        }

        let lastBlockEnd = lastBlock.upperBound
        let previousSegmentIndex = lastBlockEnd - 1

        let range = previousSegmentIndex..<(previousSegmentIndex + 1)
        let previousDuration = getDuration(range)

        // Don't extend if the leftover segment is too long
        if previousDuration >= 10 {
            return blockRange
        }

        // Return a range that includes the previous segment plus the current
        // block range
        return previousSegmentIndex..<blockRange.upperBound
    }
}
