import AppKit
import SwiftUI

class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private let alertManager = AlertManager.shared
    private let settings = Settings.shared
    private let stats = StatsManager.shared
    private let resources = ResourcesManager.shared

    // Menu items that need updating
    private var ringToggleItem: NSMenuItem!
    private var panelToggleItem: NSMenuItem!
    private var soundToggleItem: NSMenuItem!
    private var blinkToggleItem: NSMenuItem!
    private var dismissItem: NSMenuItem!

    // Stats menu items
    private var statsTodayItem: NSMenuItem!
    private var statsWeekItem: NSMenuItem!
    private var statsStreakItem: NSMenuItem!

    // Resources menu items
    private var resourcesHeaderItem: NSMenuItem!
    private var resourcesSubmenu: NSMenu!

    var onSettingsClicked: (() -> Void)?

    override init() {
        super.init()
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
        menu.delegate = self

        // Stats section (will be updated when menu opens)
        statsTodayItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statsTodayItem.isEnabled = false
        menu.addItem(statsTodayItem)

        statsWeekItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statsWeekItem.isEnabled = false
        menu.addItem(statsWeekItem)

        statsStreakItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statsStreakItem.isEnabled = false
        menu.addItem(statsStreakItem)

        menu.addItem(NSMenuItem.separator())

        // Resources section
        resourcesHeaderItem = NSMenuItem(title: "Resources", action: nil, keyEquivalent: "")
        resourcesHeaderItem.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)
        resourcesSubmenu = NSMenu()
        resourcesHeaderItem.submenu = resourcesSubmenu
        menu.addItem(resourcesHeaderItem)

        menu.addItem(NSMenuItem.separator())

        // Dismiss pings
        dismissItem = NSMenuItem(title: "Dismiss All", action: #selector(dismissAlerts), keyEquivalent: "d")
        dismissItem.keyEquivalentModifierMask = [.command, .shift]
        dismissItem.target = self
        menu.addItem(dismissItem)

        menu.addItem(NSMenuItem.separator())

        // Quick toggles
        ringToggleItem = NSMenuItem(title: "Screen Ring", action: #selector(toggleRing), keyEquivalent: "")
        ringToggleItem.target = self
        menu.addItem(ringToggleItem)

        panelToggleItem = NSMenuItem(title: "Ping Panel", action: #selector(togglePanel), keyEquivalent: "")
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
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Claude Pings", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        updateToggleStates()
        updateStatsDisplay()
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        updateStatsDisplay()
        updateResourcesDisplay()
    }

    private func updateStatsDisplay() {
        let today = stats.todayStats
        let todayAlerts = today?.alertCount ?? 0

        // Today stats with icon
        statsTodayItem.title = "Today: \(todayAlerts) pings"
        statsTodayItem.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: nil)

        // Week stats
        let weekAlerts = stats.thisWeekAlerts
        statsWeekItem.title = "This week: \(weekAlerts) pings"
        statsWeekItem.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)

        // Streak
        let streak = stats.streakDays
        if streak > 0 {
            statsStreakItem.title = "Streak: \(streak) day\(streak == 1 ? "" : "s")"
            statsStreakItem.image = NSImage(systemSymbolName: "flame", accessibilityDescription: nil)
            statsStreakItem.isHidden = false
        } else {
            statsStreakItem.isHidden = true
        }
    }

    private func updateResourcesDisplay() {
        resources.loadResources()
        resourcesSubmenu.removeAllItems()

        let totalCount = resources.totalResourceCount

        if totalCount == 0 {
            resourcesHeaderItem.title = "Resources"
            let emptyItem = NSMenuItem(title: "No active resources", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            resourcesSubmenu.addItem(emptyItem)
            return
        }

        resourcesHeaderItem.title = "Resources (\(totalCount))"

        // Ports section
        if !resources.ports.isEmpty {
            let portsHeader = NSMenuItem(title: "Ports", action: nil, keyEquivalent: "")
            portsHeader.isEnabled = false
            portsHeader.image = NSImage(systemSymbolName: "network", accessibilityDescription: nil)
            resourcesSubmenu.addItem(portsHeader)

            for port in resources.ports {
                let isActive = resources.isPortInUse(port.port)
                let item = NSMenuItem(title: "  :\(port.port) — \(port.project)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                if isActive {
                    item.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
                        .withSymbolConfiguration(.init(pointSize: 8, weight: .regular))
                    item.image?.isTemplate = false
                }
                resourcesSubmenu.addItem(item)
            }
        }

        // Databases section
        if !resources.databases.isEmpty {
            if !resources.ports.isEmpty {
                resourcesSubmenu.addItem(NSMenuItem.separator())
            }

            let dbHeader = NSMenuItem(title: "Databases", action: nil, keyEquivalent: "")
            dbHeader.isEnabled = false
            dbHeader.image = NSImage(systemSymbolName: "cylinder", accessibilityDescription: nil)
            resourcesSubmenu.addItem(dbHeader)

            for db in resources.databases {
                var title = "  \(db.name) — \(db.project)"
                if let port = db.port {
                    title += " (:\(port))"
                }
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                resourcesSubmenu.addItem(item)
            }
        }

        // Simulators section
        if !resources.simulators.isEmpty {
            if !resources.ports.isEmpty || !resources.databases.isEmpty {
                resourcesSubmenu.addItem(NSMenuItem.separator())
            }

            let simHeader = NSMenuItem(title: "Simulators", action: nil, keyEquivalent: "")
            simHeader.isEnabled = false
            simHeader.image = NSImage(systemSymbolName: "iphone", accessibilityDescription: nil)
            resourcesSubmenu.addItem(simHeader)

            for sim in resources.simulators {
                let item = NSMenuItem(title: "  \(sim.name) — \(sim.project)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                item.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)?
                    .withSymbolConfiguration(.init(pointSize: 10, weight: .regular))
                resourcesSubmenu.addItem(item)
            }
        }

        // Clean action
        resourcesSubmenu.addItem(NSMenuItem.separator())
        let cleanItem = NSMenuItem(title: "Clean Stale Entries", action: #selector(cleanResources), keyEquivalent: "")
        cleanItem.target = self
        resourcesSubmenu.addItem(cleanItem)
    }

    @objc private func cleanResources() {
        resources.cleanStaleEntries()
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
            button.toolTip = alertCount == 1 ? "Claude Pings — 1 ping" : "Claude Pings — \(alertCount) pings"
        } else {
            // Show outline circle when idle
            if let image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Claude Pings") {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                button.image = image.withSymbolConfiguration(config)
                button.contentTintColor = nil
            }
            button.toolTip = "Claude Pings — Watching"
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
