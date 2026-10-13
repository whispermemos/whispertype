//
//  Audio.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 01/01/2025.
//

import AVFoundation

func convertSampleRate(
    converter: AVAudioConverter,
    inputSampleRate: Double,
    desiredSampleRate: Double,
    buffer: AVAudioPCMBuffer
) -> AVAudioPCMBuffer? {
    let ratio = desiredSampleRate / inputSampleRate

    guard
        let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * ratio))
    else {
        return nil
    }

    let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
        outStatus.pointee = AVAudioConverterInputStatus.haveData
        return buffer
    }

    var error: NSError? = nil
    converter.convert(to: pcmBuffer, error: &error, withInputFrom: inputBlock)

    return pcmBuffer
}

func getSamples(buffer: AVAudioPCMBuffer) -> [Float] {
    let channelData = buffer.floatChannelData?[0]
    let framesCount = Int(buffer.frameLength)

    var samples: [Float] = []
    samples.reserveCapacity(framesCount)
    for frame in 0..<framesCount {
        samples.append(channelData![frame])
    }

    return samples
}

func createAudioURL(_ basename: String, _ counter: Int, compressed: Bool = true) -> URL {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[
        0]
    let ext = compressed ? "m4a" : "wav"
    return documentsPath.appendingPathComponent(
        "\(basename)_\(counter).\(ext)")
}
