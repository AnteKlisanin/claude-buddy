import AppKit

class OverlayView: NSView {
    var screenID: CGDirectDisplayID = 0
    var currentOpacity: CGFloat = 1.0 {
        didSet { needsDisplay = true }
    }
    var colorPhase: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    private let settings = Settings.shared
    private let alertManager = AlertManager.shared

    // Siri-style colors (pink, purple, blue, cyan, teal, green, orange, red)
    private let siriColors: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
        (1.0, 0.18, 0.57),   // Pink #FF2D92
        (0.61, 0.35, 0.71),  // Purple #9B59B6
        (0.0, 0.48, 1.0),    // Blue #007AFF
        (0.35, 0.78, 0.98),  // Cyan #5AC8FA
        (0.2, 0.78, 0.65),   // Teal #34C7A5
        (1.0, 0.58, 0.0),    // Orange #FF9500
        (1.0, 0.23, 0.19),   // Red #FF3B30
    ]

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Get ring thickness for this screen
        let thickness = alertManager.ringThickness(for: screenID)
        guard thickness > 0 else { return }

        if settings.ringStyle == .siri {
            drawSiriGradients(context: context, thickness: thickness)
        } else {
            // Get color from settings
            let color = settings.nsColor.withAlphaComponent(CGFloat(settings.ringOpacity) * currentOpacity)
            drawEdgeGradients(context: context, thickness: thickness, color: color)
        }
    }

    // MARK: - Siri Style Drawing

    private func drawSiriGradients(context: CGContext, thickness: CGFloat) {
        let rect = bounds
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let baseOpacity = CGFloat(settings.ringOpacity) * currentOpacity

        // Calculate perimeter segments for color distribution
        let perimeter = 2 * (rect.width + rect.height)

        // Draw each edge with flowing gradient colors
        // Top edge (left to right)
        drawSiriEdgeGradient(
            context: context,
            colorSpace: colorSpace,
            startPos: 0,
            endPos: rect.width,
            perimeter: perimeter,
            thickness: thickness,
            opacity: baseOpacity,
            edge: .top,
            rect: rect
        )

        // Right edge (top to bottom)
        drawSiriEdgeGradient(
            context: context,
            colorSpace: colorSpace,
            startPos: rect.width,
            endPos: rect.width + rect.height,
            perimeter: perimeter,
            thickness: thickness,
            opacity: baseOpacity,
            edge: .right,
            rect: rect
        )

        // Bottom edge (right to left)
        drawSiriEdgeGradient(
            context: context,
            colorSpace: colorSpace,
            startPos: rect.width + rect.height,
            endPos: 2 * rect.width + rect.height,
            perimeter: perimeter,
            thickness: thickness,
            opacity: baseOpacity,
            edge: .bottom,
            rect: rect
        )

        // Left edge (bottom to top)
        drawSiriEdgeGradient(
            context: context,
            colorSpace: colorSpace,
            startPos: 2 * rect.width + rect.height,
            endPos: perimeter,
            perimeter: perimeter,
            thickness: thickness,
            opacity: baseOpacity,
            edge: .left,
            rect: rect
        )

        // Draw corners with blended colors
        drawSiriCorners(context: context, colorSpace: colorSpace, thickness: thickness, opacity: baseOpacity, rect: rect, perimeter: perimeter)
    }

    private enum Edge {
        case top, bottom, left, right
    }

    private func drawSiriEdgeGradient(
        context: CGContext,
        colorSpace: CGColorSpace,
        startPos: CGFloat,
        endPos: CGFloat,
        perimeter: CGFloat,
        thickness: CGFloat,
        opacity: CGFloat,
        edge: Edge,
        rect: CGRect
    ) {
        let startColor = colorAtPosition(startPos, perimeter: perimeter)
        let endColor = colorAtPosition(endPos, perimeter: perimeter)

        // Create gradient along the edge (for the color flow)
        let edgeColors: [CGColor] = [
            CGColor(colorSpace: colorSpace, components: [startColor.r, startColor.g, startColor.b, opacity])!,
            CGColor(colorSpace: colorSpace, components: [endColor.r, endColor.g, endColor.b, opacity])!
        ]

        guard let edgeGradient = CGGradient(colorsSpace: colorSpace, colors: edgeColors as CFArray, locations: [0.0, 1.0]) else { return }

        context.saveGState()

        switch edge {
        case .top:
            context.clip(to: CGRect(x: 0, y: rect.height - thickness, width: rect.width, height: thickness))
            // Draw horizontal gradient for color flow
            context.drawLinearGradient(
                edgeGradient,
                start: CGPoint(x: 0, y: rect.height - thickness / 2),
                end: CGPoint(x: rect.width, y: rect.height - thickness / 2),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            // Overlay fade gradient
            drawFadeOverlay(context: context, colorSpace: colorSpace, edge: edge, rect: rect, thickness: thickness)

        case .bottom:
            context.clip(to: CGRect(x: 0, y: 0, width: rect.width, height: thickness))
            context.drawLinearGradient(
                edgeGradient,
                start: CGPoint(x: rect.width, y: thickness / 2),
                end: CGPoint(x: 0, y: thickness / 2),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            drawFadeOverlay(context: context, colorSpace: colorSpace, edge: edge, rect: rect, thickness: thickness)

        case .left:
            context.clip(to: CGRect(x: 0, y: 0, width: thickness, height: rect.height))
            context.drawLinearGradient(
                edgeGradient,
                start: CGPoint(x: thickness / 2, y: 0),
                end: CGPoint(x: thickness / 2, y: rect.height),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            drawFadeOverlay(context: context, colorSpace: colorSpace, edge: edge, rect: rect, thickness: thickness)

        case .right:
            context.clip(to: CGRect(x: rect.width - thickness, y: 0, width: thickness, height: rect.height))
            context.drawLinearGradient(
                edgeGradient,
                start: CGPoint(x: rect.width - thickness / 2, y: rect.height),
                end: CGPoint(x: rect.width - thickness / 2, y: 0),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            drawFadeOverlay(context: context, colorSpace: colorSpace, edge: edge, rect: rect, thickness: thickness)
        }

        context.restoreGState()
    }

    private func drawFadeOverlay(context: CGContext, colorSpace: CGColorSpace, edge: Edge, rect: CGRect, thickness: CGFloat) {
        // Create a mask gradient from white (keep) to black (transparent)
        let maskColors: [CGColor] = [
            CGColor(colorSpace: CGColorSpaceCreateDeviceGray(), components: [1.0, 1.0])!,
            CGColor(colorSpace: CGColorSpaceCreateDeviceGray(), components: [1.0, 0.0])!
        ]
        guard let maskGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(), colors: maskColors as CFArray, locations: [0.0, 1.0]) else { return }

        context.saveGState()
        context.setBlendMode(.destinationIn)

        switch edge {
        case .top:
            context.drawLinearGradient(
                maskGradient,
                start: CGPoint(x: rect.midX, y: rect.height),
                end: CGPoint(x: rect.midX, y: rect.height - thickness),
                options: []
            )
        case .bottom:
            context.drawLinearGradient(
                maskGradient,
                start: CGPoint(x: rect.midX, y: 0),
                end: CGPoint(x: rect.midX, y: thickness),
                options: []
            )
        case .left:
            context.drawLinearGradient(
                maskGradient,
                start: CGPoint(x: 0, y: rect.midY),
                end: CGPoint(x: thickness, y: rect.midY),
                options: []
            )
        case .right:
            context.drawLinearGradient(
                maskGradient,
                start: CGPoint(x: rect.width, y: rect.midY),
                end: CGPoint(x: rect.width - thickness, y: rect.midY),
                options: []
            )
        }

        context.restoreGState()
    }

    private func drawSiriCorners(context: CGContext, colorSpace: CGColorSpace, thickness: CGFloat, opacity: CGFloat, rect: CGRect, perimeter: CGFloat) {
        // Top-left corner (where left meets top)
        let topLeftPos = perimeter - thickness / 2 // Near the end/start
        drawSiriCornerGradient(context: context, colorSpace: colorSpace, center: CGPoint(x: 0, y: rect.height), thickness: thickness, opacity: opacity, position: topLeftPos, perimeter: perimeter)

        // Top-right corner
        let topRightPos = rect.width
        drawSiriCornerGradient(context: context, colorSpace: colorSpace, center: CGPoint(x: rect.width, y: rect.height), thickness: thickness, opacity: opacity, position: topRightPos, perimeter: perimeter)

        // Bottom-right corner
        let bottomRightPos = rect.width + rect.height
        drawSiriCornerGradient(context: context, colorSpace: colorSpace, center: CGPoint(x: rect.width, y: 0), thickness: thickness, opacity: opacity, position: bottomRightPos, perimeter: perimeter)

        // Bottom-left corner
        let bottomLeftPos = 2 * rect.width + rect.height
        drawSiriCornerGradient(context: context, colorSpace: colorSpace, center: CGPoint(x: 0, y: 0), thickness: thickness, opacity: opacity, position: bottomLeftPos, perimeter: perimeter)
    }

    private func drawSiriCornerGradient(context: CGContext, colorSpace: CGColorSpace, center: CGPoint, thickness: CGFloat, opacity: CGFloat, position: CGFloat, perimeter: CGFloat) {
        let color = colorAtPosition(position, perimeter: perimeter)

        let colors: [CGColor] = [
            CGColor(colorSpace: colorSpace, components: [color.r, color.g, color.b, opacity])!,
            CGColor(colorSpace: colorSpace, components: [color.r, color.g, color.b, 0])!
        ]

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) else { return }

        context.saveGState()

        let cornerRect = CGRect(
            x: center.x - thickness,
            y: center.y - thickness,
            width: thickness * 2,
            height: thickness * 2
        ).intersection(bounds)

        context.clip(to: cornerRect)
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: thickness,
            options: []
        )

        context.restoreGState()
    }

    private func colorAtPosition(_ position: CGFloat, perimeter: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        // Normalize position to 0-1 range and add phase offset
        let normalizedPos = fmod((position / perimeter) + colorPhase, 1.0)
        let adjustedPos = normalizedPos < 0 ? normalizedPos + 1.0 : normalizedPos

        // Map to color array with smooth interpolation
        let colorCount = CGFloat(siriColors.count)
        let scaledPos = adjustedPos * colorCount
        let index1 = Int(scaledPos) % siriColors.count
        let index2 = (index1 + 1) % siriColors.count
        let t = scaledPos - floor(scaledPos)

        let c1 = siriColors[index1]
        let c2 = siriColors[index2]

        return (
            r: c1.r + (c2.r - c1.r) * t,
            g: c1.g + (c2.g - c1.g) * t,
            b: c1.b + (c2.b - c1.b) * t
        )
    }

    // MARK: - Solid Style Drawing

    private func drawEdgeGradients(context: CGContext, thickness: CGFloat, color: NSColor) {
        let rect = bounds

        // Convert color to RGBA components
        guard let rgbColor = color.usingColorSpace(.sRGB) else { return }
        let red = rgbColor.redComponent
        let green = rgbColor.greenComponent
        let blue = rgbColor.blueComponent
        let alpha = rgbColor.alphaComponent

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors: [CGColor] = [
            CGColor(colorSpace: colorSpace, components: [red, green, blue, alpha])!,
            CGColor(colorSpace: colorSpace, components: [red, green, blue, 0])!
        ]
        let locations: [CGFloat] = [0.0, 1.0]

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
            return
        }

        // Top edge
        context.saveGState()
        context.clip(to: CGRect(x: 0, y: rect.height - thickness, width: rect.width, height: thickness))
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.height),
            end: CGPoint(x: rect.midX, y: rect.height - thickness),
            options: []
        )
        context.restoreGState()

        // Bottom edge
        context.saveGState()
        context.clip(to: CGRect(x: 0, y: 0, width: rect.width, height: thickness))
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: 0),
            end: CGPoint(x: rect.midX, y: thickness),
            options: []
        )
        context.restoreGState()

        // Left edge
        context.saveGState()
        context.clip(to: CGRect(x: 0, y: 0, width: thickness, height: rect.height))
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: rect.midY),
            end: CGPoint(x: thickness, y: rect.midY),
            options: []
        )
        context.restoreGState()

        // Right edge
        context.saveGState()
        context.clip(to: CGRect(x: rect.width - thickness, y: 0, width: thickness, height: rect.height))
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.width, y: rect.midY),
            end: CGPoint(x: rect.width - thickness, y: rect.midY),
            options: []
        )
        context.restoreGState()

        // Corners - draw radial gradients for smooth corners
        drawCornerGradient(context: context, center: CGPoint(x: 0, y: rect.height), thickness: thickness, gradient: gradient)
        drawCornerGradient(context: context, center: CGPoint(x: rect.width, y: rect.height), thickness: thickness, gradient: gradient)
        drawCornerGradient(context: context, center: CGPoint(x: 0, y: 0), thickness: thickness, gradient: gradient)
        drawCornerGradient(context: context, center: CGPoint(x: rect.width, y: 0), thickness: thickness, gradient: gradient)
    }

    private func drawCornerGradient(context: CGContext, center: CGPoint, thickness: CGFloat, gradient: CGGradient) {
        context.saveGState()

        // Clip to corner quadrant
        let cornerRect = CGRect(
            x: center.x - thickness,
            y: center.y - thickness,
            width: thickness * 2,
            height: thickness * 2
        ).intersection(bounds)

        context.clip(to: cornerRect)
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: thickness,
            options: []
        )

        context.restoreGState()
    }
}
