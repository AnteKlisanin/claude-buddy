import AppKit
import SwiftUI

class AlertPanelController {
    private var window: NSWindow?
    private var hostingView: NSHostingView<AlertPanelView>?
    private let alertManager = AlertManager.shared
    private let settings = Settings.shared

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(alertsDidChange),
            name: .alertsDidChange,
            object: nil
        )
    }

    @objc private func alertsDidChange() {
        // If alert panel is disabled, always hide
        guard settings.alertPanelEnabled else {
            hidePanel()
            return
        }

        if alertManager.hasActiveAlerts {
            showPanel()
        } else {
            hidePanel()
        }
    }

    private func showPanel() {
        if window == nil {
            createWindow()
        }
        updateContent()
        window?.orderFront(nil)
    }

    private func hidePanel() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 100),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true

        // Position in bottom-right corner
        positionWindow(panel)

        window = panel
    }

    private func positionWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let padding: CGFloat = 16
        let windowFrame = window.frame

        let x: CGFloat
        let y: CGFloat

        switch settings.panelPosition {
        case .topRight:
            x = screenFrame.maxX - windowFrame.width - padding
            y = screenFrame.maxY - windowFrame.height - padding
        case .topLeft:
            x = screenFrame.minX + padding
            y = screenFrame.maxY - windowFrame.height - padding
        case .bottomRight:
            x = screenFrame.maxX - windowFrame.width - padding
            y = screenFrame.minY + padding
        case .bottomLeft:
            x = screenFrame.minX + padding
            y = screenFrame.minY + padding
        }

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func updateContent() {
        let alerts = Array(alertManager.alerts)
        let view = AlertPanelView(alerts: alerts) { [weak self] alert in
            self?.activateAndDismiss(alert: alert)
        }

        if let hostingView = hostingView {
            hostingView.rootView = view
        } else {
            let hosting = NSHostingView(rootView: view)
            hosting.frame = window?.contentView?.bounds ?? .zero
            hosting.autoresizingMask = [.width, .height]
            window?.contentView?.addSubview(hosting)
            hostingView = hosting
        }

        // Resize window to fit content
        let alertCount = alerts.count
        let height = CGFloat(50 + alertCount * 44 + 10)
        if let window = window {
            var frame = window.frame
            frame.size.height = min(height, 400)
            window.setFrame(frame, display: true)
            // Reposition after resize to maintain correct corner
            positionWindow(window)
        }
    }

    private func activateAndDismiss(alert: Alert) {
        // Activate the terminal window
        WindowLocator.shared.activateWindow(for: alert.pid)

        // Record click and dismiss this specific alert
        alertManager.clickAlert(alert)
    }
}

struct AlertPanelView: View {
    let alerts: [Alert]
    let onAlertClicked: (Alert) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "hand.wave.fill")
                    .foregroundColor(.orange)
                Text("Claude pinged you")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Divider()

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(alerts.sorted(by: { $0.timestamp < $1.timestamp }), id: \.self) { alert in
                        AlertButton(alert: alert) {
                            onAlertClicked(alert)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct AlertButton: View {
    let alert: Alert
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(terminalName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    Text(timeAgo)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.accentColor)
                    .opacity(isHovered ? 1 : 0.6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var terminalName: String {
        if let app = NSRunningApplication(processIdentifier: alert.pid) {
            return app.localizedName ?? "Terminal"
        }
        // Try to find parent terminal app
        if let terminalPID = WindowLocator.shared.findTerminalPID(for: alert.pid),
           let app = NSRunningApplication(processIdentifier: terminalPID) {
            return app.localizedName ?? "Terminal"
        }
        return "Terminal (PID: \(alert.pid))"
    }

    private var timeAgo: String {
        let seconds = Int(-alert.timestamp.timeIntervalSinceNow)
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}
