import AppKit
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private let alertManager = AlertManager.shared
    private let settings = Settings.shared

    // Menu items that need updating
    private var ringToggleItem: NSMenuItem!
    private var panelToggleItem: NSMenuItem!
    private var soundToggleItem: NSMenuItem!
    private var blinkToggleItem: NSMenuItem!
    private var dismissItem: NSMenuItem!

    var onSettingsClicked: (() -> Void)?

    init() {
        setupStatusItem()
        setupMenu()

        // Listen for alert changes to update icon
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(alertsDidChange),
            name: .alertsDidChange,
            object: nil
        )
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateIcon()
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupMenu() {
        menu = NSMenu()

        // Dismiss alerts
        dismissItem = NSMenuItem(title: "Dismiss All Alerts", action: #selector(dismissAlerts), keyEquivalent: "d")
        dismissItem.keyEquivalentModifierMask = [.command, .shift]
        dismissItem.target = self
        menu.addItem(dismissItem)

        menu.addItem(NSMenuItem.separator())

        // Quick toggles
        ringToggleItem = NSMenuItem(title: "Screen Ring", action: #selector(toggleRing), keyEquivalent: "")
        ringToggleItem.target = self
        menu.addItem(ringToggleItem)

        panelToggleItem = NSMenuItem(title: "Alert Panel", action: #selector(togglePanel), keyEquivalent: "")
        panelToggleItem.target = self
        menu.addItem(panelToggleItem)

        soundToggleItem = NSMenuItem(title: "Sound", action: #selector(toggleSound), keyEquivalent: "")
        soundToggleItem.target = self
        menu.addItem(soundToggleItem)

        blinkToggleItem = NSMenuItem(title: "Blinking", action: #selector(toggleBlink), keyEquivalent: "")
        blinkToggleItem.target = self
        menu.addItem(blinkToggleItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Claude Indicator", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        updateToggleStates()
    }

    private func updateToggleStates() {
        ringToggleItem.state = settings.ringEnabled ? .on : .off
        panelToggleItem.state = settings.alertPanelEnabled ? .on : .off
        soundToggleItem.state = settings.soundEnabled ? .on : .off
        blinkToggleItem.state = settings.blinkingEnabled ? .on : .off
    }

    @objc private func toggleRing() {
        settings.ringEnabled.toggle()
        updateToggleStates()
        NotificationCenter.default.post(name: .alertsDidChange, object: nil)
    }

    @objc private func togglePanel() {
        settings.alertPanelEnabled.toggle()
        updateToggleStates()
        NotificationCenter.default.post(name: .alertsDidChange, object: nil)
    }

    @objc private func toggleSound() {
        settings.soundEnabled.toggle()
        updateToggleStates()
    }

    @objc private func toggleBlink() {
        settings.blinkingEnabled.toggle()
        updateToggleStates()
        NotificationCenter.default.post(name: .alertsDidChange, object: nil)
    }

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right-click: show menu
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // Left-click: dismiss alerts if active, otherwise show menu
            if alertManager.hasActiveAlerts {
                dismissAlerts()
            } else {
                statusItem.menu = menu
                statusItem.button?.performClick(nil)
                statusItem.menu = nil
            }
        }
    }

    @objc private func dismissAlerts() {
        alertManager.dismissAllAlerts()
    }

    @objc private func openSettings() {
        onSettingsClicked?()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func alertsDidChange() {
        updateIcon()
        updateMenuState()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        let alertCount = alertManager.alerts.count

        if alertCount > 0 {
            // Show filled circle with badge count when alerts are active
            let image = createBadgedIcon(count: alertCount)
            button.image = image
            button.title = ""
            button.toolTip = alertCount == 1 ? "Claude Indicator — 1 alert" : "Claude Indicator — \(alertCount) alerts"
        } else {
            // Show outline circle when idle
            if let image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Claude Indicator") {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                button.image = image.withSymbolConfiguration(config)
                button.contentTintColor = nil
            }
            button.toolTip = "Claude Indicator — Watching"
        }
    }

    private func createBadgedIcon(count: Int) -> NSImage {
        let size = NSSize(width: count > 9 ? 32 : 26, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Draw the circle icon
            let circleRect = NSRect(x: 0, y: 2, width: 14, height: 14)
            let circlePath = NSBezierPath(ovalIn: circleRect)
            Settings.shared.nsColor.setFill()
            circlePath.fill()

            // Draw the badge count
            let countStr = count > 99 ? "99+" : "\(count)"
            let font = NSFont.systemFont(ofSize: 10, weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
            let textSize = countStr.size(withAttributes: attributes)
            let textRect = NSRect(
                x: 16,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            countStr.draw(in: textRect, withAttributes: attributes)

            return true
        }
        image.isTemplate = false
        return image
    }

    private func updateMenuState() {
        dismissItem.isEnabled = alertManager.hasActiveAlerts
        updateToggleStates()
    }
}
