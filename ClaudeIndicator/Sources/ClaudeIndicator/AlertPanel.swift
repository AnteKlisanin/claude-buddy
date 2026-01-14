import AppKit
import SwiftUI

class AlertPanelController {
    private var window: NSWindow?
    private var hostingView: NSHostingView<DynamicIslandContainer>?
    private let alertManager = AlertManager.shared
    private let settings = Settings.shared

    // Animation state
    private var isExpanded = false
    private var isAnimating = false

    // Notch dimensions (MacBook Pro 14"/16" notch is ~180pt wide, ~32pt tall)
    // Corner radius of the notch bottom corners is approximately 10pt
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    private let notchCornerRadius: CGFloat = 10

    // Expanded dimensions
    private let expandedWidth: CGFloat = 380
    private let expandedCornerRadius: CGFloat = 28

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(alertsDidChange),
            name: .alertsDidChange,
            object: nil
        )
    }

    @objc private func alertsDidChange() {
        guard settings.alertPanelEnabled else {
            hidePanel()
            return
        }

        if alertManager.hasPanelAlerts {
            showPanel()
        } else {
            hidePanel()
        }
    }

    private func showPanel() {
        let alerts = alertManager.panelAlerts
        let alertCount = max(1, alerts.count)
        let expandedHeight = calculateExpandedHeight(alertCount: alertCount)

        if window == nil {
            createWindow()
        }

        guard let window = window else { return }

        if !isExpanded && !isAnimating {
            // Position at notch, start collapsed
            let containerView = DynamicIslandContainer(
                alerts: alerts,
                isExpanded: false,
                notchWidth: notchWidth,
                notchHeight: notchHeight,
                notchCornerRadius: notchCornerRadius,
                expandedWidth: expandedWidth,
                expandedHeight: expandedHeight,
                expandedCornerRadius: expandedCornerRadius,
                onAlertClicked: { [weak self] alert in
                    self?.activateAndDismiss(alert: alert)
                },
                onDismissAll: { [weak self] in
                    self?.alertManager.dismissAllAlerts()
                }
            )

            if let hostingView = hostingView {
                hostingView.rootView = containerView
            } else {
                let hosting = NSHostingView(rootView: containerView)
                hosting.frame = window.contentView?.bounds ?? .zero
                hosting.autoresizingMask = [.width, .height]
                window.contentView?.addSubview(hosting)
                hostingView = hosting
            }

            // Set initial window size to fit expanded content (SwiftUI handles the visual morph)
            setWindowFrame(expanded: true, height: expandedHeight)
            window.alphaValue = 1
            window.orderFront(nil)

            // Trigger expansion animation via SwiftUI
            isAnimating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.updateContent(expanded: true)
                self?.isAnimating = false
                self?.isExpanded = true
            }
        } else if isExpanded {
            updateContent(expanded: true)
            setWindowFrame(expanded: true, height: expandedHeight)
        }
    }

    private func hidePanel() {
        guard isExpanded, !isAnimating else {
            if !isExpanded {
                window?.orderOut(nil)
            }
            return
        }

        isAnimating = true

        // Trigger collapse animation
        updateContent(expanded: false)

        // Hide window after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.window?.orderOut(nil)
            self?.isAnimating = false
            self?.isExpanded = false
        }
    }

    private func createWindow() {
        // Create large enough window to contain expanded view
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: expandedWidth, height: 300),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false  // SwiftUI handles shadow
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false

        window = panel
    }

    private func setWindowFrame(expanded: Bool, height: CGFloat) {
        guard let window = window, let screen = NSScreen.main else { return }

        let width = expandedWidth
        let x = screen.frame.midX - (width / 2)
        let y = screen.frame.maxY - height

        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func calculateExpandedHeight(alertCount: Int) -> CGFloat {
        let notchSafeArea: CGFloat = 38  // Space for the notch
        let headerHeight: CGFloat = 50   // Header area
        let alertHeight: CGFloat = 52    // Height per alert
        let maxAlerts = 4
        let visibleAlerts = min(alertCount, maxAlerts)
        return notchSafeArea + headerHeight + CGFloat(visibleAlerts) * alertHeight
    }

    private func updateContent(expanded: Bool) {
        let alerts = alertManager.panelAlerts
        let alertCount = max(1, alerts.count)
        let expandedHeight = calculateExpandedHeight(alertCount: alertCount)

        let containerView = DynamicIslandContainer(
            alerts: alerts,
            isExpanded: expanded,
            notchWidth: notchWidth,
            notchHeight: notchHeight,
            notchCornerRadius: notchCornerRadius,
            expandedWidth: expandedWidth,
            expandedHeight: expandedHeight,
            expandedCornerRadius: expandedCornerRadius,
            onAlertClicked: { [weak self] alert in
                self?.activateAndDismiss(alert: alert)
            },
            onDismissAll: { [weak self] in
                self?.alertManager.dismissAllAlerts()
            }
        )

        hostingView?.rootView = containerView
    }

    private func activateAndDismiss(alert: Alert) {
        WindowLocator.shared.activateWindow(for: alert.pid)
        alertManager.clickAlert(alert)
    }
}

// MARK: - Dynamic Island Shape
// Simple shape: flat top, rounded bottom corners

struct DynamicIslandShape: Shape {
    var cornerRadius: CGFloat

    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: 0
        ).path(in: rect)
    }
}

// MARK: - Dynamic Island Container (handles the morphing animation)

struct DynamicIslandContainer: View {
    let alerts: [Alert]
    let isExpanded: Bool
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let notchCornerRadius: CGFloat
    let expandedWidth: CGFloat
    let expandedHeight: CGFloat
    let expandedCornerRadius: CGFloat
    let onAlertClicked: (Alert) -> Void
    let onDismissAll: () -> Void

    // Animated properties
    @State private var animatedExpanded: Bool = false

    // The notch is about 32pt tall, content should start below it
    private let notchSafeAreaHeight: CGFloat = 38

    private var currentWidth: CGFloat {
        animatedExpanded ? expandedWidth : notchWidth
    }

    private var currentHeight: CGFloat {
        animatedExpanded ? expandedHeight : notchHeight
    }

    private var currentCornerRadius: CGFloat {
        animatedExpanded ? expandedCornerRadius : notchCornerRadius
    }

    var body: some View {
        VStack(spacing: 0) {
            // The morphing island
            ZStack(alignment: .top) {
                // Background shape: flat top, rounded bottom
                DynamicIslandShape(cornerRadius: currentCornerRadius)
                    .fill(Color.black)
                    .frame(width: currentWidth, height: currentHeight)
                    .shadow(color: .black.opacity(animatedExpanded ? 0.5 : 0), radius: 30, x: 0, y: 15)

                // Content (only visible when expanded)
                if animatedExpanded {
                    DynamicIslandContent(
                        alerts: alerts,
                        topPadding: notchSafeAreaHeight,
                        onAlertClicked: onAlertClicked,
                        onDismissAll: onDismissAll
                    )
                    .frame(width: currentWidth, height: currentHeight)
                    .clipped()  // Clip content to shape bounds
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
            .frame(width: expandedWidth, height: expandedHeight, alignment: .top)
            .clipped()  // Ensure no background bleeds outside

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: isExpanded) { newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)) {
                animatedExpanded = newValue
            }
        }
        .onAppear {
            // Sync initial state
            if isExpanded && !animatedExpanded {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)) {
                    animatedExpanded = true
                }
            }
        }
    }
}

// MARK: - Dynamic Island Content

struct DynamicIslandContent: View {
    let alerts: [Alert]
    let topPadding: CGFloat  // Space to avoid notch clipping
    let onAlertClicked: (Alert) -> Void
    let onDismissAll: () -> Void

    private var headerText: String {
        if alerts.count == 1, let alert = alerts.first, let projectName = alert.projectName {
            return projectName
        }
        return alerts.count == 1 ? "Claude" : "Claude (\(alerts.count))"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Spacer to push content below the notch
            Spacer()
                .frame(height: topPadding)

            // Header
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)

                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(headerText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(alerts.count == 1 ? "Needs attention" : "\(alerts.count) notifications")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Button(action: onDismissAll) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)

            // Alerts list
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(alerts.sorted(by: { $0.timestamp > $1.timestamp }), id: \.self) { alert in
                        DynamicIslandAlertRow(alert: alert) {
                            onAlertClicked(alert)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
    }
}

// MARK: - Alert Row

struct DynamicIslandAlertRow: View {
    let alert: Alert
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(alert.projectName ?? "Terminal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(timeAgo)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(isHovered ? 0.7 : 0.3))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())  // Makes entire area clickable
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())  // Ensures button hit area covers full bounds
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var timeAgo: String {
        let seconds = Int(-alert.timestamp.timeIntervalSinceNow)
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else {
            return "\(seconds / 3600)h ago"
        }
    }
}
