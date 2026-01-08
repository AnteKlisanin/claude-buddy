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

    // Outer ring (red glow effect)
    let ringRadius = size * 0.35
    let ringWidth = size * 0.08

    // Glow
    for i in stride(from: 5, through: 1, by: -1) {
        let glowPath = NSBezierPath()
        let glowRadius = ringRadius + CGFloat(i) * ringWidth * 0.3
        glowPath.appendArc(withCenter: center, radius: glowRadius, startAngle: 0, endAngle: 360)
        glowPath.lineWidth = ringWidth * 0.5
        NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 0.1).setStroke()
        glowPath.stroke()
    }

    // Main ring
    let ringPath = NSBezierPath()
    ringPath.appendArc(withCenter: center, radius: ringRadius, startAngle: 0, endAngle: 360)
    ringPath.lineWidth = ringWidth

    // Gradient stroke effect - draw multiple rings
    for i in 0..<3 {
        let offset = CGFloat(i) * ringWidth * 0.3
        let alpha = 1.0 - Double(i) * 0.3
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: ringRadius + offset, startAngle: 0, endAngle: 360)
        path.lineWidth = ringWidth * 0.4
        NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: alpha).setStroke()
        path.stroke()
    }

    // Inner bright ring
    let innerRing = NSBezierPath()
    innerRing.appendArc(withCenter: center, radius: ringRadius - ringWidth * 0.2, startAngle: 0, endAngle: 360)
    innerRing.lineWidth = ringWidth * 0.3
    NSColor(red: 1.0, green: 0.4, blue: 0.35, alpha: 0.8).setStroke()
    innerRing.stroke()

    // Center dot
    let dotRadius = size * 0.06
    let dotPath = NSBezierPath(ovalIn: NSRect(x: center.x - dotRadius, y: center.y - dotRadius,
                                               width: dotRadius * 2, height: dotRadius * 2))
    NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0).setFill()
    dotPath.fill()

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
