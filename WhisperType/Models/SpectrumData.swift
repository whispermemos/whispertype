import AVFoundation

/*
 * Holds the latest spectrum bands for SpectrumBarsView.
 * The audio tap calls `process` on its own thread a few times per second; the view's
 * display link reads `magnitudes` on the main thread every frame. A lock guards both
 * the analyzer and the latest bands, so the two threads never race.
 */
final class SpectrumData: @unchecked Sendable {
    private static let silence = [Float](repeating: 0, count: AudioSpectrumAnalyzer.bandCount)

    private let lock = NSLock()
    private var analyzer = AudioSpectrumAnalyzer()
    private var latestMagnitudes = silence

    /// The latest bands (0...1), lowest frequency first.
    var magnitudes: [Float] {
        lock.withLock { latestMagnitudes }
    }

    /// Analyzes the first channel of a tap buffer. Call from the audio tap.
    func process(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        let sampleRate = buffer.format.sampleRate

        lock.withLock {
            guard let analyzer else { return }
            latestMagnitudes = analyzer.analyze(samples: samples, sampleRate: sampleRate)
        }
    }

    /// Starts over with silence and a fresh noise floor, for a new recording.
    func reset() {
        lock.withLock {
            analyzer = AudioSpectrumAnalyzer()
            latestMagnitudes = Self.silence
        }
    }
}
