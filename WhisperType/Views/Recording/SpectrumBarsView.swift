import AppKit
import SwiftUI

/*
 * The "bars" recording visualization: a stationary, mirrored spectrum of thin bars,
 * lowest frequencies in the middle. Ported from Whisper Memos' WaveformView.
 *
 * Each bar is one solid color picked by its own level: blue when quiet, purple when loud.
 * A display link eases the bars toward the latest SpectrumData values every frame
 * (fast attack, slower release), redraws them, and skips work once they've settled.
 */
struct SpectrumBarsView: NSViewRepresentable {
    let spectrumData: SpectrumData

    func makeNSView(context: Context) -> SpectrumBarsNSView {
        SpectrumBarsNSView(spectrumData: spectrumData)
    }

    func updateNSView(_ nsView: SpectrumBarsNSView, context: Context) {}
}

final class SpectrumBarsNSView: NSView {
    private static let barWidth: CGFloat = 2
    private static let barSpacing: CGFloat = 2
    private static let minimumBarHeight: CGFloat = 2
    /// Height limit of the outermost bars relative to the middle ones (0...1).
    private static let edgeDamping: CGFloat = 0.4
    private static let attackSeconds = 0.025
    private static let releaseSeconds = 0.13

    /// Colors for silent and full bars, as sRGB components so blending them is cheap.
    private static let quietColor = NSColor.systemBlue.usingColorSpace(.sRGB)!
    private static let loudColor = NSColor.systemPurple.usingColorSpace(.sRGB)!

    private let spectrumData: SpectrumData
    private var displayLink: CADisplayLink?
    private var hasDrawn = false
    private var displayedMagnitudes = [Float](repeating: 0, count: AudioSpectrumAnalyzer.bandCount)

    init(spectrumData: SpectrumData) {
        self.spectrumData = spectrumData
        super.init(frame: .zero)

        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Runs the display link only while the view is in a window.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        displayLink?.invalidate()
        displayLink = nil

        guard window != nil else { return }

        let link = displayLink(target: self, selector: #selector(step(_:)))
        // the source bands only update ~10x/sec; easing doesn't need 120 Hz
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func step(_ link: CADisplayLink) {
        let target = spectrumData.magnitudes

        // once the bars have settled on the target (e.g. in silence), skip the
        // per-frame redraw until new audio arrives
        let hasSettled = hasDrawn && zip(displayedMagnitudes, target)
            .allSatisfy { abs($0 - $1) < 0.001 }
        if hasSettled {
            return
        }

        // time-based, so the bars move the same at 30 and 60 fps
        let frameSeconds = link.targetTimestamp - link.timestamp
        let attack = Float(1 - exp(-frameSeconds / Self.attackSeconds))
        let release = Float(1 - exp(-frameSeconds / Self.releaseSeconds))

        for index in displayedMagnitudes.indices {
            let coefficient = target[index] > displayedMagnitudes[index] ? attack : release
            displayedMagnitudes[index] += (target[index] - displayedMagnitudes[index]) * coefficient
        }

        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 0, let context = NSGraphicsContext.current?.cgContext else { return }
        hasDrawn = true
        let bars = Array(displayedMagnitudes.reversed()) + displayedMagnitudes

        let totalBarWidth = CGFloat(bars.count) * Self.barWidth
        let spacing = min(
            Self.barSpacing,
            max(1, (bounds.width - totalBarWidth) / CGFloat(bars.count - 1))
        )
        let contentWidth = totalBarWidth + CGFloat(bars.count - 1) * spacing
        let startX = max(0, (bounds.width - contentWidth) / 2)

        for (index, magnitude) in bars.enumerated() {
            let height = max(
                Self.minimumBarHeight,
                CGFloat(magnitude) * bounds.height * Self.envelope(at: index, of: bars.count)
            )
            let rect = CGRect(
                x: startX + CGFloat(index) * (Self.barWidth + spacing),
                y: (bounds.height - height) / 2,
                width: Self.barWidth,
                height: height
            )
            context.setFillColor(Self.color(for: magnitude))
            context.addPath(CGPath(
                roundedRect: rect,
                cornerWidth: Self.barWidth / 2,
                cornerHeight: Self.barWidth / 2,
                transform: nil
            ))
            context.fillPath()
        }
    }

    /// Blends from `quietColor` at 0 to `loudColor` at 1.
    private static func color(for magnitude: Float) -> CGColor {
        let amount = CGFloat(min(1, max(0, magnitude)))
        func blend(_ quiet: CGFloat, _ loud: CGFloat) -> CGFloat {
            quiet + (loud - quiet) * amount
        }
        return CGColor(
            srgbRed: blend(quietColor.redComponent, loudColor.redComponent),
            green: blend(quietColor.greenComponent, loudColor.greenComponent),
            blue: blend(quietColor.blueComponent, loudColor.blueComponent),
            alpha: 1
        )
    }

    /// Scales bar heights from 1 in the middle down to `edgeDamping` at the
    /// outer edges along a half-cosine, shaping the bars into a gentle dome.
    private static func envelope(at index: Int, of count: Int) -> CGFloat {
        let center = CGFloat(count - 1) / 2
        let distance = abs(CGFloat(index) - center) / center
        return edgeDamping + (1 - edgeDamping) * cos(distance * .pi / 2)
    }
}
