//
//  SoundwaveData.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 18/01/2025.
//

import AVFoundation
import Accelerate
import Combine

class SoundwaveData: ObservableObject {
    @Published var magnitudes: [Float] = []
    static let bufferSize = 1024
    static let magnitudeLimit: Float = 20.0
    static let bandCount = 32
    
    private var fftSetup: OpaquePointer?
    
    init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(Self.bufferSize),
            vDSP_DFT_Direction.FORWARD
        )
    }
    
    deinit {
        // Destroy the setup so it doesn't leak
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

//    var fftSetup: vDSP_DFT_Setup? {
//        return vDSP_DFT_zop_CreateSetup(
//            nil,
//            UInt(Self.bufferSize),
//            vDSP_DFT_Direction.FORWARD
//        )
//    }

    private func getMagnitudesRange(start: Int, end: Int) -> [Float] {
        guard magnitudes.count >= end else { return [] }
        let values = Array(magnitudes[start..<end])
        let dampening = 2  // Number of values to dampen on each side
        return values.enumerated().map { index, value in
            if index < dampening {
                // Left side dampening
                return value * Float(index) / Float(dampening)
            } else if index >= values.count - dampening {
                // Right side dampening
                return value * Float(values.count - 1 - index) / Float(dampening)
            }
            return value
        }
    }

    var magnitudes1: [Float] {
        let bandSize = Self.bandCount / 3  // Increased size for overlap
        return getMagnitudesRange(start: 0, end: bandSize)
    }

    var magnitudes2: [Float] {
        let bandSize = Self.bandCount / 3
        let start = bandSize / 2  // Start halfway through previous band
        return getMagnitudesRange(start: start, end: start + bandSize)
    }

    var magnitudes3: [Float] {
        let bandSize = Self.bandCount / 3
        let start = bandSize  // Start at end of first band
        return getMagnitudesRange(start: start, end: start + bandSize)
    }

    var magnitudes4: [Float] {
        let bandSize = Self.bandCount / 3
        let start = (3 * bandSize) / 2  // Start halfway through third band
        return getMagnitudesRange(start: start, end: start + bandSize)
    }

    func setBuffer(_ buffer: AVAudioPCMBuffer) {
        let channelData = buffer.floatChannelData?[0]

        //        print("number of values in channel data: \(channelData!.count)")

        let fftMagnitudes = fft(data: channelData!, setup: fftSetup!)

        // Cap values and normalize to -0.1...1 range
        let normalizedMagnitudes = fftMagnitudes.map { magnitude in
            let cappedValue = min(magnitude, Self.magnitudeLimit)
            return (cappedValue / Self.magnitudeLimit) * 1.1 - 0.1
        }

        updateMagnitudesWithAnimation(newValues: normalizedMagnitudes)
    }

    private func updateMagnitudesWithAnimation(newValues: [Float]) {
        // If magnitudes array is empty, initialize it with new values
        if magnitudes.isEmpty {
            self.magnitudes = newValues
            return
        }

        // Ensure arrays have the same size
        let count = min(magnitudes.count, newValues.count)
        var updatedMagnitudes = magnitudes

        // Update each value with animation
        for i in 0..<count {
            if newValues[i] > magnitudes[i] {
                // For higher values, update immediately
                updatedMagnitudes[i] = newValues[i]
            } else {
                // For lower values, decrease gradually
                updatedMagnitudes[i] = max(newValues[i], magnitudes[i] - 0.04)
            }
        }

        self.magnitudes = updatedMagnitudes
    }

    func fft(data: UnsafeMutablePointer<Float>, setup: OpaquePointer) -> [Float] {
        var realIn = [Float](repeating: 0, count: Self.bufferSize)
        var imagIn = [Float](repeating: 0, count: Self.bufferSize)
        var realOut = [Float](repeating: 0, count: Self.bufferSize)
        var imagOut = [Float](repeating: 0, count: Self.bufferSize)

        for i in 0..<Self.bufferSize {
            realIn[i] = data[i]
        }

        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)

        var magnitudes = [Float](repeating: 0, count: Self.bandCount)

        realOut.withUnsafeMutableBufferPointer { realBP in
            imagOut.withUnsafeMutableBufferPointer { imagBP in
                var complex = DSPSplitComplex(
                    realp: realBP.baseAddress!, imagp: imagBP.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, UInt(Self.bandCount))
            }
        }

        var normalizedMagnitudes = [Float](repeating: 0.0, count: Self.bandCount)
        var scalingFactor = Float(1)
        vDSP_vsmul(&magnitudes, 1, &scalingFactor, &normalizedMagnitudes, 1, UInt(Self.bandCount))

        return normalizedMagnitudes
    }

    private func dampenEdges(_ values: [Float]) -> [Float] {
        let dampening = 4  // Number of values to dampen on each side
        return values.enumerated().map { index, value in
            if index < dampening {
                // Left side dampening
                return value * Float(index) / Float(dampening)
            } else if index >= values.count - dampening {
                // Right side dampening
                return value * Float(values.count - 1 - index) / Float(dampening)
            }
            return value
        }
    }
}
