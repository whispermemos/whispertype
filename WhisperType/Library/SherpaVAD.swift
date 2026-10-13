//
//  SherpaVAD.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 25/01/2025.
//

import Foundation

class SherpaVAD {

    enum VADError: Error {
        case initializationFailed
        case processingFailed
        case invalidModelPath
        case tensorCreationFailed
    }

    struct SpeechProbabilities {
        let isSpeech: Float
        let notSpeech: Float
    }

    var vad: SherpaOnnxVoiceActivityDetectorWrapper?
    private var sileroConfig: SherpaOnnxSileroVadModelConfig?
    private var vadConfig: SherpaOnnxVadModelConfig?

    var onFinishSpeaking: (() -> Void)?

    init() throws {
        self.prepare()
    }

    private func prepare() {
        let modelPath = Bundle.main.path(forResource: "silero_vad_v5", ofType: "onnx")!

        self.sileroConfig = sherpaOnnxSileroVadModelConfig(
            model: modelPath,
            threshold: 0.5,  // How clear it needs to be that we're speaking
            minSilenceDuration: 0.25,  // Minimum silence duration in seconds
            minSpeechDuration: 0.5,  // Minimum speech duration in seconds
            windowSize: 512,  // Window size for processing
            maxSpeechDuration: 9999.0  // Maximum speech duration in seconds
        )

        self.vadConfig = sherpaOnnxVadModelConfig(
            sileroVad: sileroConfig!,
            sampleRate: 16000,
            numThreads: 2,
            provider: "cpu"
        )

        self.vad = SherpaOnnxVoiceActivityDetectorWrapper(
            config: &vadConfig!,
            buffer_size_in_seconds: 5.0
        )
    }

    func finish() {
        prepare()
    }

    func process(audioFrame: [Float]) {
        guard let vad = self.vad else {
            assertionFailure("expected vad instance")
            return
        }

        // Accept the waveform
        vad.acceptWaveform(samples: audioFrame)

        // Process any available segments
        while !vad.isEmpty() {
            let segment = vad.front()

            // Process the speech segment
            // let speechSamples = segment.samples
            // let startIndex = segment.start
            // let numSamples = segment.n

            //            print("Speech segment detected: start=\(startIndex), samples=\(numSamples)")
            self.onFinishSpeaking?()

            // Remove the processed segment from the queue
            vad.pop()
        }
    }
}
