#!/usr/bin/env swift

// Renders Resources/AppIcon.png at 1024x1024.
//
// Design notes:
// - Squircle background fills almost the full canvas (~32px shadow margin)
//   so the icon doesn't look small in the Dock like the previous one did.
// - Indigo→navy diagonal gradient — saturated enough to read on white and
//   black Dock backgrounds.
// - Two opposing chevrons (>< ) in chunky white strokes with rounded caps,
//   echoing the multi-agent "facing each other" debate metaphor.

import AppKit
import CoreGraphics
import Foundation

let canvasSize: CGFloat = 1024
let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    fputs("Failed to get current CGContext\n", stderr)
    exit(1)
}

// 1. Squircle background.
let shadowMargin: CGFloat = 36
let bgRect = CGRect(
    x: shadowMargin,
    y: shadowMargin,
    width: canvasSize - 2 * shadowMargin,
    height: canvasSize - 2 * shadowMargin
)
let cornerRadius = bgRect.width * 0.2237  // ~Apple squircle approximation
let bgPath = CGPath(
    roundedRect: bgRect,
    cornerWidth: cornerRadius,
    cornerHeight: cornerRadius,
    transform: nil
)

let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradientColors = [
    CGColor(red: 0.34, green: 0.22, blue: 0.66, alpha: 1.0),  // top-left royal violet
    CGColor(red: 0.07, green: 0.09, blue: 0.28, alpha: 1.0),  // bottom-right deep indigo
] as CFArray
guard let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: gradientColors,
    locations: [0, 1]
) else {
    fputs("Failed to build gradient\n", stderr)
    exit(1)
}

ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: bgRect.minX, y: bgRect.maxY),
    end: CGPoint(x: bgRect.maxX, y: bgRect.minY),
    options: []
)
ctx.restoreGState()

// 2. Subtle inner rim light so the squircle has depth at small sizes.
ctx.saveGState()
ctx.setStrokeColor(CGColor(gray: 1.0, alpha: 0.14))
ctx.setLineWidth(3)
ctx.addPath(bgPath)
ctx.strokePath()
ctx.restoreGState()

// 3. Two opposing chevrons in the center: > <
// Stroke is thin enough and gap wide enough that the rounded line caps
// at the tips don't fuse into an X — they have to read as two marks.
let strokeWidth = canvasSize * 0.062
let chevronHalfWidth = canvasSize * 0.105
let chevronHalfHeight = canvasSize * 0.165
let gap = canvasSize * 0.155
let centerX = canvasSize * 0.5
let centerY = canvasSize * 0.5

let leftTipX = centerX - gap / 2
let leftBaseX = leftTipX - chevronHalfWidth
let leftChevron = CGMutablePath()
leftChevron.move(to: CGPoint(x: leftBaseX, y: centerY + chevronHalfHeight))
leftChevron.addLine(to: CGPoint(x: leftTipX, y: centerY))
leftChevron.addLine(to: CGPoint(x: leftBaseX, y: centerY - chevronHalfHeight))

let rightTipX = centerX + gap / 2
let rightBaseX = rightTipX + chevronHalfWidth
let rightChevron = CGMutablePath()
rightChevron.move(to: CGPoint(x: rightBaseX, y: centerY + chevronHalfHeight))
rightChevron.addLine(to: CGPoint(x: rightTipX, y: centerY))
rightChevron.addLine(to: CGPoint(x: rightBaseX, y: centerY - chevronHalfHeight))

ctx.setStrokeColor(CGColor(gray: 1.0, alpha: 1.0))
ctx.setLineWidth(strokeWidth)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.addPath(leftChevron)
ctx.strokePath()
ctx.addPath(rightChevron)
ctx.strokePath()

image.unlockFocus()

guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Failed to extract CGImage\n", stderr)
    exit(1)
}
let rep = NSBitmapImageRep(cgImage: cgImage)
rep.size = NSSize(width: canvasSize, height: canvasSize)
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: "Resources/AppIcon.png")
try pngData.write(to: outputURL)
print("✓ \(outputURL.path) (\(Int(canvasSize))x\(Int(canvasSize)))")
