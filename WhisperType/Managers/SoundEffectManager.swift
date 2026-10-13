//
//  SoundEffectManager.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 02/01/2025.
//

import AVFoundation

class SoundEffectManager {
    static let shared = SoundEffectManager()

    private var startSound: AVAudioPlayer?
    private var endSound: AVAudioPlayer?
    private var newlineSound: AVAudioPlayer?

    private init() {
    }

    func prepare() {
        guard let startSoundUrl = Bundle.main.url(forResource: "start2", withExtension: "wav"),
            let endSoundUrl = Bundle.main.url(forResource: "end", withExtension: "wav"),
            let newlineSoundUrl = Bundle.main.url(forResource: "newline", withExtension: "wav")
        else {
            print("Error: Could not find sound effect files in bundle")
            return
        }

        do {
            startSound = try AVAudioPlayer(contentsOf: startSoundUrl)
            endSound = try AVAudioPlayer(contentsOf: endSoundUrl)
            newlineSound = try AVAudioPlayer(contentsOf: newlineSoundUrl)

            startSound?.prepareToPlay()
            endSound?.prepareToPlay()
            newlineSound?.prepareToPlay()
        } catch {
            print("Error loading sound effects: \(error.localizedDescription)")
        }
    }

    func playStartSound() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.startSound?.play()
        }
    }

    func playEndSound() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.endSound?.play()
        }
    }

    func playNewlineSound() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.newlineSound?.play()
        }
    }
}
