//
//  RecordingEngine.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 08/02/2025.
//

import AVFoundation

/** Wrapper around AVAudioEngine for our specific usecase */
class RecordingEngine {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var volumeNode: AVAudioMixerNode?
    private var converter: AVAudioConverter?
    
    var sampleRate: Double
    var bufferSize: Int
    var desiredFormat: AVAudioFormat?
    
    private var inputDevices: InputDeviceManager
    
    var onVolumeBuffer: ((AVAudioPCMBuffer) -> Void)?
    var onVadBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    // MARK: - Lifecycle
    
    init (inputDevices: InputDeviceManager, sampleRate: Double, bufferSize: Int) {
        
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.inputDevices = inputDevices
        
        audioEngine = AVAudioEngine()

        inputNode = audioEngine?.inputNode
        
        // Get the native recording format from the input node
        let recordingFormat = pickInputDevice()
        let inputSampleRate = recordingFormat.sampleRate
        print("Using sample rate: \(inputSampleRate) Hz")
        
        // Create a mixer node for volume monitoring
        volumeNode = AVAudioMixerNode()
        audioEngine!.attach(volumeNode!)
        audioEngine!.connect(audioEngine!.inputNode, to: volumeNode!, format: recordingFormat)

        let volumeBufferSize = AVAudioFrameCount(inputSampleRate * 0.02)  // 10ms buffer size
        print("ideal buffer size for soundwave: \(volumeBufferSize)")

        volumeNode?.installTap(
            onBus: 0, bufferSize: AVAudioFrameCount(SoundwaveData.bufferSize),
            format: recordingFormat
        ) {
            [weak self] buffer, time in

            buffer.frameLength = AVAudioFrameCount(SoundwaveData.bufferSize)

            DispatchQueue.main.async { [weak self] in
                self?.onVolumeBuffer?(buffer)
            }
        }
    
        // Create 16 kHz mono format for processing
        guard
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            )
        else { return }

        desiredFormat = format

        print("Input format: \(String(describing: recordingFormat))")

        // Create converter
        converter = AVAudioConverter(from: recordingFormat, to: format)

        // Install tap for processing
        let ratio = recordingFormat.sampleRate / sampleRate
        let processingBufferSize = AVAudioFrameCount(Double(bufferSize) * ratio)  // 30ms buffer size
        inputNode?.installTap(onBus: 0, bufferSize: processingBufferSize, format: recordingFormat) {
            [weak self] buffer, time in

            guard let this = self else { return }
            guard let converter = this.converter else { return }

            DispatchQueue.main.async {
                let pcmBuffer = convertSampleRate(
                    converter: converter,
                    inputSampleRate: inputSampleRate,
                    desiredSampleRate: this.sampleRate,
                    buffer: buffer
                )

                guard let pcmBuffer = pcmBuffer else { return }
                
                this.onVadBuffer?(pcmBuffer)
            }
        }
    }
    
    private func pickInputDevice() -> AVAudioFormat {
        guard let preferredDevice = inputDevices.getPreferredDevice() else {
            return audioEngine!.inputNode.inputFormat(forBus: 0)
        }
        
        print("--> setting preferred device: \(preferredDevice.id) (\(preferredDevice.name))")

        let audioUnit = audioEngine!.inputNode.audioUnit!
        var id = preferredDevice.id

        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        print("--> status setting preferred device: \(status), is success: \(status == noErr)")

        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: getSampleRate(for: preferredDevice.id),
            channels: 1,
            interleaved: false)!
    }
    
    // MARK: - Actions
    
    func start() throws {
        try audioEngine?.start()
    }
    
    func stop() {
        audioEngine?.stop()
        
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil
        converter = nil
        desiredFormat = nil
    }
    
}
