import AppKit

/*
 * Draws the background picture for the DMG installer window (scripts/build-dmg.sh).
 * Paints a soft gradient, an arrow from the app icon spot to the Applications spot,
 * and a short hint below. Writes background.png (660×400) and background@2x.png (1320×800)
 * next to this file. Icon centers here must match the positions in build-dmg.sh.
 *
 * Run: swift scripts/dmg/draw-background.swift
 */

let width: CGFloat = 660
let height: CGFloat = 400
let iconY: CGFloat = 180 // From the top, like Finder positions.
let appX: CGFloat = 170
let applicationsX: CGFloat = 490
let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

func drawBackground(in context: CGContext) {
    // Flip so y grows downward, matching Finder icon coordinates.
    context.translateBy(x: 0, y: height)
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

    let colors = [
        NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.99, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.91, green: 0.92, blue: 0.95, alpha: 1).cgColor,
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])

    // Arrow between the two icons.
    let arrowColor = NSColor(calibratedWhite: 0.55, alpha: 1).cgColor
    let startX = appX + 75
    let endX = applicationsX - 75
    let headLength: CGFloat = 18
    context.setStrokeColor(arrowColor)
    context.setLineWidth(5)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: startX, y: iconY))
    context.addLine(to: CGPoint(x: endX - headLength + 2, y: iconY))
    context.strokePath()

    context.setFillColor(arrowColor)
    context.move(to: CGPoint(x: endX, y: iconY))
    context.addLine(to: CGPoint(x: endX - headLength, y: iconY - 13))
    context.addLine(to: CGPoint(x: endX - headLength, y: iconY + 13))
    context.closePath()
    context.fillPath()

    // Hint text. The flipped graphics context keeps it upright.
    let hint = NSAttributedString(string: "Drag WhisperType to Applications to install", attributes: [
        .font: NSFont.systemFont(ofSize: 15, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.4, alpha: 1),
    ])
    let size = hint.size()
    hint.draw(at: CGPoint(x: (width - size.width) / 2, y: 320))
}

func render(scale: CGFloat, name: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: width, height: height)
    // The bitmap context already maps points to pixels from rep.size, so no extra scaling here.
    let context = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    drawBackground(in: context)
    try! rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name))
}

render(scale: 1, name: "background.png")
render(scale: 2, name: "background@2x.png")
print("Wrote background.png and background@2x.png to \(folder.path)")
