import AppKit
import Combine

class OverlayWindowController {
    private var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    private var animationTimer: Timer?
    private var animationPhase: CGFloat = 0
    private let settings = Settings.shared
    private let alertManager = AlertManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Listen for screen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Listen for alert changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(alertsDidChange),
            name: .alertsDidChange,
            object: nil
        )

        // Create windows for all screens
        setupWindows()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopAnimation()
    }

    private func setupWindows() {
        // Remove old windows
        windows.values.forEach { $0.close() }
        windows.removeAll()

        // Create new windows for each screen
        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            windows[screen.displayID] = window
        }
    }

    @objc private func screensDidChange() {
        // Update existing windows and create new ones as needed
        let currentScreenIDs = Set(NSScreen.screens.map { $0.displayID })
        let existingIDs = Set(windows.keys)

        // Remove windows for disconnected screens
        for id in existingIDs.subtracting(currentScreenIDs) {
            windows[id]?.close()
            windows.removeValue(forKey: id)
        }

        // Add windows for new screens
        for screen in NSScreen.screens {
            if windows[screen.displayID] == nil {
                windows[screen.displayID] = OverlayWindow(screen: screen)
            } else {
                windows[screen.displayID]?.updateForScreen(screen)
            }
        }

        updateVisibility()
    }

    @objc private func alertsDidChange() {
        updateVisibility()
    }

    private func updateVisibility() {
        // If ring is disabled, hide all windows
        guard settings.ringEnabled else {
            stopAnimation()
            windows.values.forEach { $0.orderOut(nil) }
            return
        }

        // Only show ring for alerts that aren't suppressed (terminal not focused)
        let screensWithRingAlerts = alertManager.screenIDsWithRing()

        for (screenID, window) in windows {
            if screensWithRingAlerts.contains(screenID) {
                window.orderFront(nil)
                window.overlayView?.needsDisplay = true
            } else {
                window.orderOut(nil)
            }
        }

        // Start or stop animation based on ring alerts (not all alerts)
        if !screensWithRingAlerts.isEmpty {
            if settings.blinkingEnabled {
                startAnimation()
            } else {
                stopAnimation()
                setOpacity(1.0)
            }
        } else {
            stopAnimation()
        }
    }

    private func startAnimation() {
        guard animationTimer == nil else { return }

        animationPhase = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func updateAnimation() {
        // Calculate opacity using sine wave for smooth pulsing
        let speed = 1.0 / settings.blinkSpeed
        animationPhase += CGFloat(1.0 / 60.0) * CGFloat(speed) * .pi * 2

        // Oscillate between 0.3 and 1.0
        let opacity = 0.3 + 0.7 * (sin(animationPhase) + 1) / 2

        setOpacity(opacity)
    }

    private func setOpacity(_ opacity: CGFloat) {
        for (screenID, window) in windows {
            if alertManager.alertCount(for: screenID) > 0 {
                window.overlayView?.currentOpacity = opacity
            }
        }
    }

    func showAlert(on screenID: CGDirectDisplayID) {
        guard let window = windows[screenID] else { return }
        window.orderFront(nil)
        window.overlayView?.needsDisplay = true

        if settings.blinkingEnabled {
            startAnimation()
        }
    }

    func hideAll() {
        stopAnimation()
        windows.values.forEach { $0.orderOut(nil) }
    }
}
