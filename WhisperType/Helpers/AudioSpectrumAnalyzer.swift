//
//  AudioSpectrumAnalyzer.swift
//  WhisperType (copied from Whisper Memos AudioSpectrumAnalyzerV2)
//

import Accelerate
import Foundation

/// Converts live mono PCM into stable, voice-focused frequency bands.
///
/// Works like a speech front end: overlapping 64 ms Hann frames, a mel
/// filterbank from 100 Hz to 7 kHz, and a +6 dB/octave tilt in place of
/// pre-emphasis so the upper bands aren't dead. Each band is shown relative
/// to its own adaptive noise floor, so steady background noise stays flat.
///
/// Each call returns the loudest frame of the buffer it was given. Meter
/// ballistics (attack and release) are SpectrumBarsView's job.
/// Not thread-safe: SpectrumData calls it under its lock.
final class AudioSpectrumAnalyzer {
    static let bandCount = 28

    /// Fixed so one FFT setup serves every sample rate; shorter windows are
    /// zero padded (1024 samples at 16 kHz, 3072 at 48 kHz).
    private static let fftSize = 4_096
    private static let windowSeconds = 0.064
    private static let hopsPerWindow = 4
    private static let minimumFrequency = 100.0
    /// Stays below 8 kHz, where a 16 kHz stream's anti-alias filter rolls off.
    private static let maximumFrequency = 7_000.0
    private static let tiltDecibelsPerOctave: Float = 6
    private static let tiltPivotFrequency = 1_000.0
    /// Keeps silence finite after the dB conversion (-120 dB).
    private static let silencePower: Float = 1e-12

    /// Lowest floor a band can have, so near-silence doesn't fill the bars.
    private static let minimumFloorDecibels: Float = -75
    private static let floorRiseDecibelsPerSecond: Float = 6
    /// Headroom above the floor that still reads as silence, covering the
    /// noise's own flicker. The floor follows each buffer's quietest frame
    /// and the bars its loudest, so this spans that spread too.
    private static let floorMarginDecibels: Float = 12
    /// Decibels above floor plus margin that fill a bar.
    private static let displayRangeDecibels: Float = 32

    private let fftSetup: vDSP_DFT_Setup

    private var layout: FrameLayout?
    /// Samples not yet covered by a full frame, carried to the next call.
    private var pendingSamples: [Float] = []
    /// Per-band floor in dB, empty until the first frame arrives.
    private var noiseFloor: [Float] = []
    private var bands = [Float](repeating: 0, count: bandCount)

    // scratch buffers reused across calls, so the audio thread doesn't
    // allocate per frame
    private var windowedSamples = [Float](repeating: 0, count: fftSize)
    private var realInput = [Float](repeating: 0, count: fftSize / 2)
    private var imaginaryInput = [Float](repeating: 0, count: fftSize / 2)
    private var realOutput = [Float](repeating: 0, count: fftSize / 2)
    private var imaginaryOutput = [Float](repeating: 0, count: fftSize / 2)
    private var powers = [Float](repeating: 0, count: fftSize / 2)
    private var peakBandPowers = [Float](repeating: 0, count: bandCount)
    private var quietestBandPowers = [Float](repeating: 0, count: bandCount)

    init?() {
        guard let fftSetup = vDSP_DFT_zrop_CreateSetup(
            nil,
            vDSP_Length(Self.fftSize),
            .FORWARD
        ) else {
            return nil
        }

        self.fftSetup = fftSetup
    }

    deinit {
        vDSP_DFT_DestroySetup(fftSetup)
    }

    /// Returns the bars (0...1) for this buffer. Until a full frame has
    /// arrived, returns the previous bars.
    func analyze(samples: [Float], sampleRate: Double) -> [Float] {
        let layout = frameLayout(sampleRate: sampleRate)
        pendingSamples.append(contentsOf: samples)

        vDSP.fill(&peakBandPowers, with: 0)
        vDSP.fill(&quietestBandPowers, with: .greatestFiniteMagnitude)
        var frameStart = 0
        while frameStart + layout.windowLength <= pendingSamples.count {
            addFrame(at: frameStart, layout: layout)
            frameStart += layout.hopLength
        }
        pendingSamples.removeFirst(frameStart)

        guard frameStart > 0 else { return bands }

        // the floor follows the quietest frame, so the gaps between syllables
        // keep it under speech; the bars show the loudest
        updateNoiseFloor(
            levels: bandLevels(of: quietestBandPowers, layout: layout),
            elapsedSeconds: Double(frameStart) / sampleRate
        )
        bands = normalizedBands(levels: bandLevels(of: peakBandPowers, layout: layout))
        return bands
    }

    // MARK: - Layout

    /// Rebuilds the layout when the sample rate changes, dropping samples
    /// buffered at the old rate.
    private func frameLayout(sampleRate: Double) -> FrameLayout {
        if let layout, layout.sampleRate == sampleRate {
            return layout
        }

        let newLayout = Self.makeLayout(sampleRate: sampleRate)
        layout = newLayout
        pendingSamples.removeAll(keepingCapacity: true)
        vDSP.fill(&windowedSamples, with: 0)

        return newLayout
    }

    private static func makeLayout(sampleRate: Double) -> FrameLayout {
        let windowLength = min(fftSize, Int((sampleRate * windowSeconds).rounded()))
        let upperFrequency = min(maximumFrequency, sampleRate * 0.45)
        let edges = melBandEdges(upperFrequency: upperFrequency)
        let binWidth = sampleRate / Double(fftSize)

        let filters = (0..<bandCount).map { band in
            melFilter(
                lower: edges[band],
                center: edges[band + 1],
                upper: edges[band + 2],
                binWidth: binWidth
            )
        }
        let tiltDecibels = (0..<bandCount).map { band in
            tiltDecibelsPerOctave * Float(log2(edges[band + 1] / tiltPivotFrequency))
        }

        return FrameLayout(
            sampleRate: sampleRate,
            windowLength: windowLength,
            hopLength: windowLength / hopsPerWindow,
            window: vDSP.window(
                ofType: Float.self,
                usingSequence: .hanningDenormalized,
                count: windowLength,
                isHalfWindow: false
            ),
            filters: filters,
            tiltDecibels: tiltDecibels,
            // a full-scale sine inside one band reads as 0 dB
            zeroReference: 0.375 * Float(fftSize) * Float(windowLength)
        )
    }

    /// `bandCount + 2` frequencies evenly spaced on the mel scale; band `i`
    /// spans edges `i...i + 2` and peaks at `i + 1`.
    private static func melBandEdges(upperFrequency: Double) -> [Double] {
        let lowerMel = mel(fromHertz: minimumFrequency)
        let melStep = (mel(fromHertz: upperFrequency) - lowerMel) / Double(bandCount + 1)

        return (0...(bandCount + 1)).map { edge in
            hertz(fromMel: lowerMel + melStep * Double(edge))
        }
    }

    private static func mel(fromHertz hertz: Double) -> Double {
        2_595 * log10(1 + hertz / 700)
    }

    private static func hertz(fromMel mel: Double) -> Double {
        700 * (pow(10, mel / 2_595) - 1)
    }

    /// Triangular weights over the FFT bins between `lower` and `upper`.
    private static func melFilter(
        lower: Double,
        center: Double,
        upper: Double,
        binWidth: Double
    ) -> MelFilter {
        let firstBin = Int(ceil(lower / binWidth))
        let lastBin = max(firstBin, Int(floor(upper / binWidth)))

        let weights = (firstBin...lastBin).map { bin -> Float in
            let frequency = Double(bin) * binWidth
            let weight = frequency <= center
                ? (frequency - lower) / (center - lower)
                : (upper - frequency) / (upper - center)
            return Float(max(0, weight))
        }
        return MelFilter(firstBin: firstBin, weights: weights)
    }

    // MARK: - Frames

    /// Analyzes one frame and keeps each band's loudest and quietest power in
    /// this buffer.
    private func addFrame(at start: Int, layout: FrameLayout) {
        pendingSamples.withUnsafeBufferPointer { samples in
            vDSP_vmul(
                samples.baseAddress! + start,
                1,
                layout.window,
                1,
                &windowedSamples,
                1,
                vDSP_Length(layout.windowLength)
            )
        }

        computePowers()

        for (band, filter) in layout.filters.enumerated() {
            var power: Float = 0
            powers.withUnsafeBufferPointer { buffer in
                vDSP_dotpr(
                    buffer.baseAddress! + filter.firstBin,
                    1,
                    filter.weights,
                    1,
                    &power,
                    vDSP_Length(filter.weights.count)
                )
            }
            peakBandPowers[band] = max(peakBandPowers[band], power)
            quietestBandPowers[band] = min(quietestBandPowers[band], power)
        }
    }

    /// Fills `powers` with the squared magnitude per FFT bin of `windowedSamples`.
    private func computePowers() {
        let halfSize = Self.fftSize / 2
        for index in 0..<halfSize {
            realInput[index] = windowedSamples[index * 2]
            imaginaryInput[index] = windowedSamples[index * 2 + 1]
        }

        vDSP_DFT_Execute(
            fftSetup,
            realInput,
            imaginaryInput,
            &realOutput,
            &imaginaryOutput
        )

        realOutput.withUnsafeMutableBufferPointer { realBuffer in
            imaginaryOutput.withUnsafeMutableBufferPointer { imaginaryBuffer in
                var splitComplex = DSPSplitComplex(
                    realp: realBuffer.baseAddress!,
                    imagp: imaginaryBuffer.baseAddress!
                )
                vDSP_zvmags(
                    &splitComplex,
                    1,
                    &powers,
                    1,
                    vDSP_Length(halfSize)
                )
            }
        }
    }

    // MARK: - Levels

    /// Band levels in dB, tilted toward the upper bands.
    private func bandLevels(of bandPowers: [Float], layout: FrameLayout) -> [Float] {
        let powers = vDSP.add(Self.silencePower * layout.zeroReference, bandPowers)
        var levels = [Float](repeating: 0, count: Self.bandCount)
        vDSP.convert(power: powers, toDecibels: &levels, zeroReference: layout.zeroReference)
        return vDSP.add(levels, layout.tiltDecibels)
    }

    /// Follows each band's quietest level: drops to it at once and otherwise
    /// rises slowly. Steady noise becomes the floor within a few seconds,
    /// while the pauses between words keep pulling it back under speech.
    private func updateNoiseFloor(levels: [Float], elapsedSeconds: Double) {
        guard !noiseFloor.isEmpty else {
            noiseFloor = levels.map { max($0, Self.minimumFloorDecibels) }
            return
        }

        let rise = Self.floorRiseDecibelsPerSecond * Float(elapsedSeconds)
        for band in noiseFloor.indices {
            noiseFloor[band] = max(
                Self.minimumFloorDecibels,
                min(levels[band], noiseFloor[band] + rise)
            )
        }
    }

    private func normalizedBands(levels: [Float]) -> [Float] {
        zip(levels, noiseFloor).map { level, floor in
            let aboveFloor = level - floor - Self.floorMarginDecibels
            return min(1, max(0, aboveFloor / Self.displayRangeDecibels))
        }
    }
}

/// Everything that depends on the sample rate, built once per rate.
private struct FrameLayout {
    let sampleRate: Double
    let windowLength: Int
    let hopLength: Int
    let window: [Float]
    let filters: [MelFilter]
    let tiltDecibels: [Float]
    let zeroReference: Float
}

/// A triangular mel filter: weights for the FFT bins from `firstBin` on.
private struct MelFilter {
    let firstBin: Int
    let weights: [Float]
}
