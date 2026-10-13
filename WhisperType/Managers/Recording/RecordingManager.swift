//
//  RecordingManager.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 13/12/2024.
//

import AVFoundation
import Accessibility
import AppKit
import AudioKit
import Combine
import SimplyCoreAudio

enum RecordingState {
    case idle
    case preparing
    case recording
    case transcribing
}

let SAMPLE_RATE: Double = 16000
let VAD_FRAME_SIZE = 512

class RecordingManager: ObservableObject {
    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var duration: TimeInterval = 0

    @Published var isStartingParagraph = false
    @Published var isSpeaking = false
    @Published var lastError: String?

    // Session
    internal var sessionId: String?
    var soundwaveData = SoundwaveData()
    internal var samplesStore = SamplesStore(sampleRate: SAMPLE_RATE)
    private var transcriptStore = TranscriptStore()
    private var durationTimer: Timer?

    // Other managers
    private let inputDeviceManager: InputDeviceManager
    private let hotkeyManager: HotkeyManager
    private let historyManager: HistoryManager
    private let uploadingManager: UploadingManager

    // Audio stuff
    private var engine: RecordingEngine?
    private let vadSampleChunker: SampleChunker
    private var vad: SherpaVAD?
    private let systemAudioVolumeController = SystemAudioVolumeController()

    // Threads
    private let processingQueue = DispatchQueue(
        label: "com.whispermemos.WhisperType.processingQueue",
        qos: .background)

    // MARK: - Lifecycle

    init(
        inputDeviceManager: InputDeviceManager,
        historyManager: HistoryManager
    ) {
        self.inputDeviceManager = inputDeviceManager
        self.historyManager = historyManager

        self.vadSampleChunker = SampleChunker(chunkSize: VAD_FRAME_SIZE)
        self.uploadingManager = UploadingManager()

        self.hotkeyManager = HotkeyManager()

        self.hotkeyManager.onToggleRecording = { [weak self] in
            self?.toggleRecording()
        }

        self.hotkeyManager.onStopRecording = { [weak self] in
            self?.stopRecording()
        }

        self.hotkeyManager.onCancelRecording = { [weak self] in
            self?.stopRecording(discard: true)
        }

        self.hotkeyManager.onNewParagraph = { [weak self] in
            self?.startNewParagraph()
        }

        self.vad = try? SherpaVAD()

        self.vad?.onFinishSpeaking = { [weak self] in
            self?.handleFinishedSpeaking()
        }

        SoundEffectManager.shared.prepare()
    }

    // MARK: - Actions

    private func toggleRecording() {
        // Only handle recording if setup is complete
        guard UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSetup) else {
            return
        }

        if state == .recording {
            stopRecording()
        } else if state == .idle {
            startRecording()
        } else if state == .transcribing {
            uploadingManager.cancelUpload()
        }
    }

    // MARK: - Starting recording

    func startRecording() {
        state = .recording
        globalWindowManager.showRecordingWindow()
        SoundEffectManager.shared.playStartSound()
        if UserDefaults.standard.bool(forKey: UserDefaultsKeys.lowerSystemVolumeWhileRecording) {
            systemAudioVolumeController.lowerSystemVolumeForRecording()
        }

        hotkeyManager.isRecording = true
        self.doStartRecording()
    }

    func doStartRecording() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        sessionId = dateFormatter.string(from: Date())
        samplesStore.reset()
        transcriptStore.reset()

        // Setup audio engine before recording
        setupAudioEngine()

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.engine?.start()

                DispatchQueue.main.async {
                    self.state = .recording
                    self.startDurationTimer()
                }
            } catch {
                DispatchQueue.main.async {
                    print("Could not start recording: \(error)")
                    self.systemAudioVolumeController.restoreSystemVolume()
                    self.state = .idle
                    globalWindowManager.hideRecordingWindow()
                }
            }
        }
    }

    func startDurationTimer() {
        self.duration = 0
        self.durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            self?.duration += 0.1
        }
    }

    // MARK: - Stopping recording

    func stopRecording(discard: Bool = false) {
        systemAudioVolumeController.restoreSystemVolume()
        guard let sessionId = sessionId else { return }

        durationTimer?.invalidate()
        durationTimer = nil

        vad?.finish()
        engine?.stop()

        SoundEffectManager.shared.playEndSound()

        samplesStore.finishSegment()
        _ = finishBlock(sessionId: sessionId, isFinal: true, discard: discard)

        if discard {
            self.setIdleState()
            return
        }

        self.state = .transcribing
    }

    // MARK: - Audio stuff

    private func setupAudioEngine() {
        let engine = RecordingEngine(
            inputDevices: inputDeviceManager,
            sampleRate: SAMPLE_RATE,
            bufferSize: VAD_FRAME_SIZE
        )

        engine.onVolumeBuffer = { [weak self] buffer in
            self?.soundwaveData.setBuffer(buffer)
        }

        engine.onVadBuffer = { [weak self] buffer in
            self?.handleBuffer(buffer)
        }

        self.engine = engine
    }

    internal func handleBuffer(_ buffer: AVAudioPCMBuffer) {
        let samples = getSamples(buffer: buffer)

        // Append samples to the current segment
        samplesStore.addToCurrent(samples)

        // Split sample into chunks for VAD
        let chunks = vadSampleChunker.process(samples: samples)

        guard let vad = vad else { return }

        for chunk in chunks {
            vad.process(audioFrame: chunk)
        }
    }

    // MARK: - Splitting into blocks

    private func handleFinishedSpeaking() {
        print("⚠️ Break in speech was detected!")
        guard let sessionId = sessionId else { return }

        samplesStore.finishSegment()

        if samplesStore.currentBlockDuration > 30 {
            finishBlock(sessionId: sessionId, isFinal: false)
        }

        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    @discardableResult
    internal func finishBlock(sessionId: String, isFinal: Bool, discard: Bool = false) -> Int {

        let startedManually = isCurrentBlockStartedManually()

        let (range, index) = samplesStore.finishBlock(extendingFromPrevious: !startedManually)
        let finalDuration = samplesStore.getDuration(range)

        print(
            "⏱️ Finished block \(index). duration: \(finalDuration) isFinal: \(isFinal), startedManually: \(startedManually)"
        )

        if discard {
            return index
        }

        Task {
            await uploadBlock(sessionId: sessionId, number: index, range: range, isFinal: isFinal)
        }

        return index
    }

    private func isCurrentBlockStartedManually() -> Bool {
        if let lastIndex = samplesStore.lastBlockIndex, transcriptStore.hasParagraphAt(lastIndex) {
            return true
        } else {
            return false
        }
    }

    // MARK: - Uploading

    private func uploadBlock(sessionId: String, number: Int, range: Range<Int>, isFinal: Bool) async
    {
        if isFinal {
            print("🎯 Setting final block number to \(number)")
            transcriptStore.finalNumber = number
        }

        let blockSamples = samplesStore.getBlockSamples(range)
        let compressedBlockUrl = createAudioURL(sessionId, number, compressed: true)

        do {
            try writeAudioSamplesToAACFile(
                samples: blockSamples, sampleRate: SAMPLE_RATE, outputURL: compressedBlockUrl)
        } catch {
            print("failed to write the file: \(error)")
            setIdleState()

        }

        await uploadBlockFile(
            sessionId: sessionId,
            number: number,
            url: compressedBlockUrl,
            isFinal: isFinal,
            shouldPaste: true
        )
    }

    private func uploadBlockFile(
        sessionId: String, number: Int, url: URL, isFinal: Bool, shouldPaste: Bool
    ) async {
        guard let data = NSData(contentsOf: url) else { return }

        print("📦 Uploading block \(number) at \(url) with size: \(data.length / 1024) KB")

        let result = await uploadingManager.uploadRecording(blockNumber: number, audioData: data)

        handleUploadFinished(
            result, sessionId: sessionId, blockNumber: number, shouldPaste: shouldPaste)
    }

    private func handleUploadFinished(
        _ result: UploadResult, sessionId: String, blockNumber: Int, shouldPaste: Bool
    ) {
        switch result {
        case .success(let transcript, blockNumber: _):
            transcriptStore.addTranscript(number: blockNumber, transcript: transcript)

            print("🎯 Block #\(blockNumber): \(transcript ?? "nil")")

            break

        case .failure(let error):
            transcriptStore.addError(number: blockNumber, error: error.localizedDescription)

            print("Upload error: \(error)")

            break
        }

        // Check if we have all transcripts now
        print("--> hasAllResults: \(transcriptStore.hasAllResults())")
        if transcriptStore.hasAllResults() {
            Task {
                await handleAllUploaded(sessionId: sessionId, shouldPaste: shouldPaste)
            }
        }
    }

    private func handleAllUploaded(sessionId: String, shouldPaste: Bool) async {
        let duration = samplesStore.totalDuration

        // Get paragraphs from transcript store
        let joined = transcriptStore.getText()

        let success = !transcriptStore.hasError

        // Add to history, there should be the number of the final block
        if let finalNumber = transcriptStore.finalNumber {
            let entry = HistoryEntry(
                sessionId: sessionId,
                blockCount: finalNumber,
                transcription: joined,
                state: success ? .success : .failed,
                timestamp: Date(),
                duration: duration
            )

            historyManager.setEntry(entry)
        }

        if success {
            print("🎉 All transcripts have been received and processed!")
        } else {
            print("❌ All transcripts received but some failed to process")

            DispatchQueue.main.async { [weak self] in
                self?.lastError =
                    self?.transcriptStore.lastError ?? "Some transcripts failed to process"

                globalAppDelegate?.activateAfterError()
            }
        }

        // Reset the state and copy to clipboard
        DispatchQueue.main.async { [weak self] in
            print("success: \(success)")
            print("shouldPaste: \(shouldPaste)")

            if success {
                copyAndInsert(joined, shouldPaste: shouldPaste)
            }

            self?.setIdleState()
        }
    }

    // MARK: - Paragraphs

    internal func startNewParagraph() {
        if state != .recording {
            return
        }

        guard let sessionId = self.sessionId else {
            return
        }

        samplesStore.finishSegment()

        let index = finishBlock(sessionId: sessionId, isFinal: false)
        self.isStartingParagraph = true
        transcriptStore.addParagraphAt(index)

        // Play newline sound when starting a new paragraph
        SoundEffectManager.shared.playNewlineSound()
    }

    private func setIdleState() {
        self.state = .idle
        globalWindowManager.hideRecordingWindow()

        hotkeyManager.isRecording = false
    }

    // MARK: - Retrying

    func retryUpload(sessionId: String, lastBlockIndex: Int) {
        print("block count: \(lastBlockIndex)")

        guard state == .idle else {
            print("Cannot retry upload - recording manager is not idle")
            return
        }

        // Construct paths for all audio files
        var audioPaths: [URL] = []
        for i in 0...lastBlockIndex {
            let url = createAudioURL(sessionId, i)
            print("reading: \(url)")
            if FileManager.default.fileExists(atPath: url.path) {
                audioPaths.append(url)
            }
        }

        // Return if no files found
        guard !audioPaths.isEmpty else {
            print("No audio files found for session \(sessionId)")
            return
        }

        // Print the paths
        print("Found audio files:")
        for path in audioPaths {
            print("- \(path.path)")
        }

        self.state = .transcribing
        globalWindowManager.showRecordingWindow()

        transcriptStore.reset()
        transcriptStore.finalNumber = lastBlockIndex

        Task {
            await withTaskGroup(of: Void.self) { group in
                for (index, path) in audioPaths.enumerated() {
                    let isLast = index == audioPaths.count - 1
                    group.addTask {
                        await self.uploadBlockFile(
                            sessionId: sessionId, number: index, url: path, isFinal: isLast,
                            shouldPaste: false)
                    }
                }
            }
        }
    }
}
