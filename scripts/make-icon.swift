#!/usr/bin/env swift
import AppKit
import Foundation

let defaultOutput = "OpenRouterCredits/Resources/Assets.xcassets/AppIcon.appiconset"
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : defaultOutput
let outputDirectory = URL(fileURLWithPath: outputPath)

struct IconSpec {
    let filename: String
    let pixels: Int
    let size: String
    let scale: String
}

let specs: [IconSpec] = [
    IconSpec(filename: "icon_16x16.png", pixels: 16, size: "16x16", scale: "1x"),
    IconSpec(filename: "icon_16x16@2x.png", pixels: 32, size: "16x16", scale: "2x"),
    IconSpec(filename: "icon_32x32.png", pixels: 32, size: "32x32", scale: "1x"),
    IconSpec(filename: "icon_32x32@2x.png", pixels: 64, size: "32x32", scale: "2x"),
    IconSpec(filename: "icon_128x128.png", pixels: 128, size: "128x128", scale: "1x"),
    IconSpec(filename: "icon_128x128@2x.png", pixels: 256, size: "128x128", scale: "2x"),
    IconSpec(filename: "icon_256x256.png", pixels: 256, size: "256x256", scale: "1x"),
    IconSpec(filename: "icon_256x256@2x.png", pixels: 512, size: "256x256", scale: "2x"),
    IconSpec(filename: "icon_512x512.png", pixels: 512, size: "512x512", scale: "1x"),
    IconSpec(filename: "icon_512x512@2x.png", pixels: 1024, size: "512x512", scale: "2x"),
]

func makeIcon(pixels: Int) -> Data {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else {
        fatalError("Could not create bitmap for \(pixels)px icon")
    }

    let size = CGFloat(pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true

    // Rounded macOS-style tile with a blue gradient.
    let inset = size * 0.055
    let tileRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let tileRadius = size * 0.225
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: tileRadius, yRadius: tileRadius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.51, blue: 0.94, alpha: 1),
        NSColor(calibratedRed: 0.04, green: 0.16, blue: 0.40, alpha: 1),
    ])!
    gradient.draw(in: tilePath, angle: -90)

    // Subtle top highlight.
    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    let highlight = NSBezierPath(ovalIn: NSRect(
        x: -size * 0.15,
        y: size * 0.55,
        width: size * 1.3,
        height: size * 0.9
    ))
    NSColor.white.withAlphaComponent(0.10).setFill()
    highlight.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Credit card with a soft shadow.
    let cardRect = NSRect(
        x: size * 0.18,
        y: size * 0.29,
        width: size * 0.64,
        height: size * 0.43
    )
    let cardRadius = size * 0.055
    let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: cardRadius, yRadius: cardRadius)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = size * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
    shadow.set()
    NSColor.white.setFill()
    cardPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Magnetic stripe and chip, clipped to the card.
    NSGraphicsContext.saveGraphicsState()
    cardPath.addClip()

    NSColor(calibratedRed: 0.09, green: 0.28, blue: 0.62, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(
        x: cardRect.minX,
        y: cardRect.maxY - size * 0.145,
        width: cardRect.width,
        height: size * 0.065
    )).fill()

    NSColor(calibratedRed: 0.96, green: 0.72, blue: 0.26, alpha: 1).setFill()
    NSBezierPath(
        roundedRect: NSRect(
            x: cardRect.minX + size * 0.075,
            y: cardRect.minY + size * 0.095,
            width: size * 0.11,
            height: size * 0.072
        ),
        xRadius: size * 0.014,
        yRadius: size * 0.014
    ).fill()

    NSColor(calibratedRed: 0.12, green: 0.36, blue: 0.72, alpha: 1).setFill()
    NSBezierPath(
        roundedRect: NSRect(
            x: cardRect.minX + size * 0.075,
            y: cardRect.minY + size * 0.035,
            width: size * 0.20,
            height: size * 0.024
        ),
        xRadius: size * 0.012,
        yRadius: size * 0.012
    ).fill()

    let dollar = "$" as NSString
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.15, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.09, green: 0.28, blue: 0.62, alpha: 1),
    ]
    let textSize = dollar.size(withAttributes: attributes)
    dollar.draw(
        at: NSPoint(
            x: cardRect.maxX - textSize.width - size * 0.055,
            y: cardRect.minY + size * 0.035
        ),
        withAttributes: attributes
    )

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(pixels)px icon")
    }
    return png
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for spec in specs {
    let data = makeIcon(pixels: spec.pixels)
    try data.write(to: outputDirectory.appendingPathComponent(spec.filename))
}

let images = specs.map { spec in
    """
        {
          "filename" : "\(spec.filename)",
          "idiom" : "mac",
          "scale" : "\(spec.scale)",
          "size" : "\(spec.size)"
        }
    """
}

let contents = """
{
  "images" : [
\(images.joined(separator: ",\n"))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

try contents.write(
    to: outputDirectory.appendingPathComponent("Contents.json"),
    atomically: true,
    encoding: .utf8
)

print("Wrote \(specs.count) icons to \(outputDirectory.path)")
