import Foundation

/*
 * Picks which visualization the recording widget shows while recording.
 * RecordingManager feeds only the selected style's data, and RecordingView draws it.
 * Change `current` to switch; later this can become a user preference.
 */
enum SoundwaveStyle {
    /// Overlapping blue and purple waves (SoundwaveView).
    case waves
    /// Thin mirrored spectrum bars colored by height (SpectrumBarsView).
    case bars

    static let current: SoundwaveStyle = .bars
}
