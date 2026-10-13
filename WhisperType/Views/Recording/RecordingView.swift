//
//  RecordingView.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 20/12/2024.
//

import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @State private var state: RecordingState = .idle
    @State private var duration: TimeInterval = 0
    @State private var showFlash = false
    
    //    var red = Color(red: 1.0, green: 0.4, blue: 0.4)
    
    var body: some View {
        ZStack {
            Group {
                if state == .preparing || state == .recording {
                    SoundwaveView(soundwaveData: recordingManager.soundwaveData)
                        .padding(.vertical, 6)
                        .mask(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white, location: 0.1),
                                    .init(color: .white, location: 0.9),
                                    .init(color: .clear, location: 1)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
//                        .opacity(recordingManager.isSpeaking ? 1 : 0.2)
                } else if state == .transcribing {
                    IndicatorView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 25)
                        .padding(.vertical, 6)
                    //                    .transition(.identity)
                    //                    .animation(nil)
                }
            }
            .padding(.horizontal, 5)
            
            if showFlash {
                Color.white
                    .opacity(showFlash ? 0.8 : 0)
            }
        }
        .onChange(of: recordingManager.state) { newState in
            // We don't wanna show idle state in UI
            if newState != .idle {
                state = newState
            }
        }
        .onChange(of: recordingManager.duration) { newDuration in
            if newDuration > 0 {
                duration = newDuration
            }
        }
        .onChange(of: recordingManager.isStartingParagraph) { pressed in
            if pressed {
                withAnimation(.easeOut(duration: 0.03)) {
                    showFlash = true
                }
                // Start a timer to hide the flash and reset hasPressedReturn
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showFlash = false
                    }
                    recordingManager.isStartingParagraph = false
                }
            }
        }
    }
    
    private var stateText: String {
        switch state {
        case .preparing:
            return "Preparing..."
        case .recording:
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        case .transcribing:
            return "Transcribing..."
        case .idle:
            return "Ready"
        }
    }
}
