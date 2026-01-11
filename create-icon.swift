#!/usr/bin/env swift

import AppKit
import Foundation

// Create icon at various sizes
let sizes: [(CGFloat, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x")
]

// Siri-style base colors
let siriBaseColors: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
    (1.0, 0.18, 0.57),   // Pink
    (0.61, 0.35, 0.71),  // Purple
    (0.0, 0.48, 1.0),    // Blue
    (0.35, 0.78, 0.98),  // Cyan
    (0.2, 0.78, 0.65),   // Teal
    (1.0, 0.58, 0.0),    // Orange
    (1.0, 0.23, 0.19),   // Red
]

// Interpolate between colors for smooth gradient
func interpolateColor(from: (r: CGFloat, g: CGFloat, b: CGFloat),
                      to: (r: CGFloat, g: CGFloat, b: CGFloat),
                      t: CGFloat) -> NSColor {
    let r = from.r + (to.r - from.r) * t
    let g = from.g + (to.g - from.g) * t
    let b = from.b + (to.b - from.b) * t
    return NSColor(red: r, green: g, blue: b, alpha: 1.0)
}

// Generate smooth gradient with many segments
let segmentCount = 72  // More segments = smoother gradient
var siriColors: [NSColor] = []
for i in 0..<segmentCount {
    let position = CGFloat(i) / CGFloat(segmentCount) * CGFloat(siriBaseColors.count)
    let colorIndex = Int(position) % siriBaseColors.count
    let nextColorIndex = (colorIndex + 1) % siriBaseColors.count
    let t = position - CGFloat(Int(position))

    let color = interpolateColor(from: siriBaseColors[colorIndex],
                                  to: siriBaseColors[nextColorIndex],
                                  t: t)
    siriColors.append(color)
}

func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let center = NSPoint(x: size / 2, y: size / 2)

    // Background - dark rounded square
    let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.05, dy: size * 0.05),
                               xRadius: size * 0.2, yRadius: size * 0.2)
    NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0).setFill()
    bgPath.fill()

    // Ring parameters
    let ringRadius = size * 0.32
    let ringWidth = size * 0.09

    // Draw glow effect for each color segment
    let colorCount = siriColors.count
    for glowLayer in stride(from: 4, through: 1, by: -1) {
        let glowAlpha = 0.15 / Double(glowLayer)
        let glowOffset = CGFloat(glowLayer) * ringWidth * 0.4

        for i in 0..<colorCount {
            let startAngle = CGFloat(i) / CGFloat(colorCount) * 360 - 90
            let endAngle = CGFloat(i + 1) / CGFloat(colorCount) * 360 - 90

            let path = NSBezierPath()
            path.appendArc(withCenter: center, radius: ringRadius + glowOffset, startAngle: startAngle, endAngle: endAngle)
            path.lineWidth = ringWidth * 0.6
            path.lineCapStyle = .round

            siriColors[i].withAlphaComponent(glowAlpha).setStroke()
            path.stroke()
        }
    }

    // Draw main Siri gradient ring
    for i in 0..<colorCount {
        let startAngle = CGFloat(i) / CGFloat(colorCount) * 360 - 90
        let endAngle = CGFloat(i + 1) / CGFloat(colorCount) * 360 - 90

        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: ringRadius, startAngle: startAngle, endAngle: endAngle)
        path.lineWidth = ringWidth
        path.lineCapStyle = .round

        siriColors[i].setStroke()
        path.stroke()
    }

    // Inner bright highlight ring
    for i in 0..<colorCount {
        let startAngle = CGFloat(i) / CGFloat(colorCount) * 360 - 90
        let endAngle = CGFloat(i + 1) / CGFloat(colorCount) * 360 - 90

        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: ringRadius - ringWidth * 0.25, startAngle: startAngle, endAngle: endAngle)
        path.lineWidth = ringWidth * 0.2
        path.lineCapStyle = .round

        siriColors[i].withAlphaComponent(0.6).setStroke()
        path.stroke()
    }

    // Center infinity symbol
    let infinityWidth = size * 0.18
    let infinityHeight = size * 0.09
    let lineWidth = size * 0.025

    let infinityPath = NSBezierPath()

    // Draw infinity symbol (two connected loops)
    // Left loop
    let leftCenter = NSPoint(x: center.x - infinityWidth * 0.25, y: center.y)
    let loopRadius = infinityHeight * 0.5

    // Right loop
    let rightCenter = NSPoint(x: center.x + infinityWidth * 0.25, y: center.y)

    // Create figure-8 path
    infinityPath.move(to: center)

    // Right loop (clockwise)
    infinityPath.appendArc(withCenter: rightCenter, radius: loopRadius,
                           startAngle: 180, endAngle: -180, clockwise: true)

    // Left loop (counter-clockwise)
    infinityPath.appendArc(withCenter: leftCenter, radius: loopRadius,
                           startAngle: 0, endAngle: 360, clockwise: false)

    infinityPath.lineWidth = lineWidth
    infinityPath.lineCapStyle = .round
    infinityPath.lineJoinStyle = .round

    // Draw with a nice purple/blue gradient color
    NSColor(red: 0.6, green: 0.5, blue: 0.95, alpha: 0.9).setStroke()
    infinityPath.stroke()

    image.unlockFocus()

    return image
}

// Create iconset directory
let iconsetPath = "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetPath)
try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Generate all sizes
for (size, name) in sizes {
    let image = createIcon(size: size)

    if let tiffData = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        let path = "\(iconsetPath)/\(name).png"
        try! pngData.write(to: URL(fileURLWithPath: path))
        print("Created \(path)")
    }
}

print("\nIconset created. Converting to .icns...")

// Convert to icns using iconutil
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath]
try! process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Successfully created AppIcon.icns")

    // Clean up iconset
    try? FileManager.default.removeItem(atPath: iconsetPath)
} else {
    print("Failed to create .icns file")
}
