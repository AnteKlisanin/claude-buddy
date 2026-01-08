import AppKit

class OverlayWindow: NSWindow {
    let screenID: CGDirectDisplayID

    init(screen: NSScreen) {
        self.screenID = screen.displayID

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Configure as overlay window
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Set up the overlay view
        let overlayView = OverlayView(frame: screen.frame)
        overlayView.screenID = screenID
        self.contentView = overlayView

        // Position on the correct screen
        self.setFrame(screen.frame, display: true)
    }

    var overlayView: OverlayView? {
        contentView as? OverlayView
    }

    func updateForScreen(_ screen: NSScreen) {
        setFrame(screen.frame, display: true)
        if let contentView = contentView {
            overlayView?.frame = contentView.bounds
        }
        overlayView?.needsDisplay = true
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey(rawValue: "NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}
