//
//  AudioDevices.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 02/01/2025.
//

import Foundation
import AVFoundation
import CoreAudio

func getSampleRate(for deviceID: AudioDeviceID) -> Float64 {
    var propertySize = UInt32(MemoryLayout<Float64>.size)
    var sampleRate: Float64 = 0
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyNominalSampleRate,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: 0
    )

    AudioObjectGetPropertyData(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &propertySize,
        &sampleRate
    )

    return sampleRate
}
