import AppKit

class OverlayView: NSView {
    var screenID: CGDirectDisplayID = 0
    var currentOpacity: CGFloat = 1.0 {
        didSet { needsDisplay = true }
    }

    private let settings = Settings.shared
    private let alertManager = AlertManager.shared

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

        // Get color from settings
        let color = settings.nsColor.withAlphaComponent(CGFloat(settings.ringOpacity) * currentOpacity)

        // Draw the ring effect from all four edges
        drawEdgeGradients(context: context, thickness: thickness, color: color)
    }

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
