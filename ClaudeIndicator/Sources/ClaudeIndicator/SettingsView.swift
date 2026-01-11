import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @StateObject private var resourcesManager = ResourcesManager.shared
    @State private var showingPreview = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(0)

            behaviorTab
                .tabItem {
                    Label("Behavior", systemImage: "gearshape")
                }
                .tag(1)

            resourcesTab
                .tabItem {
                    Label("Resources", systemImage: "server.rack")
                }
                .tag(2)

            integrationTab
                .tabItem {
                    Label("Integration", systemImage: "link")
                }
                .tag(3)
        }
        .frame(width: 440, height: 480)
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
        ScrollView {
            VStack(spacing: 1) {
                // Screen Ring Section
                SettingsSection(title: "Screen Ring", icon: "circle.circle") {
                    SettingsRow {
                        HStack {
                            Text("Show screen ring")
                            Spacer()
                            Toggle("", isOn: $settings.ringEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }

                    if settings.ringEnabled {
                        SettingsRow {
                            HStack {
                                Text("Style")
                                Spacer()
                                Picker("", selection: $settings.ringStyle) {
                                    ForEach(Settings.RingStyle.allCases, id: \.self) { style in
                                        Text(style.displayName).tag(style)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 130)
                            }
                        }

                        if settings.ringStyle == .solid {
                            SettingsRow {
                                HStack {
                                    Text("Color")
                                    Spacer()
                                    ColorPicker("", selection: $settings.ringColor, supportsOpacity: false)
                                        .labelsHidden()
                                }
                            }
                        }

                        SettingsRow {
                            HStack {
                                Text("Opacity")
                                Spacer()
                                Text("\(Int(settings.ringOpacity * 100))%")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                                    .frame(width: 44, alignment: .trailing)
                                Slider(value: $settings.ringOpacity, in: 0.1...1.0, step: 0.1)
                                    .frame(width: 120)
                            }
                        }

                        SettingsRow {
                            HStack {
                                Text("Thickness")
                                Spacer()
                                Text("\(Int(settings.ringThickness))px")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                                    .frame(width: 44, alignment: .trailing)
                                Slider(value: $settings.ringThickness, in: 20...200, step: 10)
                                    .frame(width: 120)
                            }
                        }

                        SettingsRow {
                            HStack {
                                Text("Stack increment")
                                Spacer()
                                Text("+\(Int(settings.thicknessIncrement))px")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                                    .frame(width: 44, alignment: .trailing)
                                Slider(value: $settings.thicknessIncrement, in: 10...100, step: 10)
                                    .frame(width: 120)
                            }
                        }

                        SettingsRow {
                            HStack {
                                Text("Blinking animation")
                                Spacer()
                                if settings.blinkingEnabled {
                                    Text("\(settings.blinkSpeed, specifier: "%.1f")s")
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                        .frame(width: 44, alignment: .trailing)
                                    Slider(value: $settings.blinkSpeed, in: 0.5...3.0, step: 0.25)
                                        .frame(width: 100)
                                }
                                Toggle("", isOn: $settings.blinkingEnabled)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }
                        }
                    }
                }

                // Ping Panel Section
                SettingsSection(title: "Ping Panel", icon: "bell.badge") {
                    SettingsRow {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Show ping panel")
                                Text("Displays a clickable notification in the corner")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.alertPanelEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }

                    if settings.alertPanelEnabled {
                        SettingsRow {
                            HStack {
                                Text("Position")
                                Spacer()
                                Picker("", selection: $settings.panelPosition) {
                                    ForEach(Settings.PanelPosition.allCases, id: \.self) { position in
                                        Text(position.displayName).tag(position)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 130)
                            }
                        }
                    }
                }

                // Sound Section
                SettingsSection(title: "Sound", icon: "speaker.wave.2") {
                    SettingsRow {
                        HStack {
                            Text("Play sound")
                            Spacer()
                            if settings.soundEnabled {
                                Picker("", selection: $settings.soundName) {
                                    ForEach(Settings.availableSounds, id: \.self) { sound in
                                        Text(sound).tag(sound)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 100)

                                Button(action: previewSound) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                            Toggle("", isOn: $settings.soundEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }
                }

                // Test Section
                SettingsSection(title: "Preview", icon: "play.rectangle") {
                    SettingsRow {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Test ping")
                                Text("Shows ping effect for 3 seconds")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: previewAlert) {
                                Text("Preview")
                            }
                            .controlSize(.regular)
                            .disabled(showingPreview)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Behavior Tab

    private var behaviorTab: some View {
        ScrollView {
            VStack(spacing: 1) {
                SettingsSection(title: "Auto-Dismiss", icon: "timer") {
                    SettingsRow {
                        HStack {
                            Text("Auto-dismiss pings")
                            Spacer()
                            if settings.autoDismissEnabled {
                                Text("\(Int(settings.autoDismissDelay))s")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                                    .frame(width: 36, alignment: .trailing)
                                Slider(value: $settings.autoDismissDelay, in: 5...120, step: 5)
                                    .frame(width: 120)
                            }
                            Toggle("", isOn: $settings.autoDismissEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }
                }

                SettingsSection(title: "Keyboard Shortcuts", icon: "keyboard") {
                    SettingsRow {
                        HStack {
                            Text("Dismiss all pings")
                            Spacer()
                            HStack(spacing: 4) {
                                KeyCapView(symbol: "command")
                                KeyCapView(symbol: "shift")
                                KeyCapView(letter: "D")
                            }
                        }
                    }
                }

                SettingsSection(title: "Smart Detection", icon: "eye") {
                    SettingsRow {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Focus detection")
                                Text("Detect when terminal is already in focus")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.focusDetectionEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }

                    if settings.focusDetectionEnabled {
                        SettingsRow {
                            HStack {
                                Text("Suppress ring when focused")
                                Spacer()
                                Toggle("", isOn: $settings.suppressRingWhenFocused)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }
                        }

                        SettingsRow {
                            HStack {
                                Text("Suppress panel when focused")
                                Spacer()
                                Toggle("", isOn: $settings.suppressPanelWhenFocused)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Resources Tab

    private var resourcesTab: some View {
        ScrollView {
            VStack(spacing: 1) {
                // Summary
                SettingsSection(title: "Active Resources", icon: "server.rack") {
                    SettingsRow {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(resourcesManager.summaryText)
                                    .fontWeight(.medium)
                                if let lastUpdated = resourcesManager.lastUpdated {
                                    Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button(action: { resourcesManager.loadResources() }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SettingsRow {
                        HStack {
                            Text("Clean stale entries")
                            Spacer()
                            Button("Clean") {
                                resourcesManager.cleanStaleEntries()
                            }
                            .controlSize(.small)
                        }
                    }
                }

                // Ports
                if !resourcesManager.ports.isEmpty {
                    SettingsSection(title: "Ports", icon: "network") {
                        ForEach(resourcesManager.ports) { port in
                            SettingsRow {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(":\(port.port)")
                                                .font(.system(.body, design: .monospaced))
                                                .fontWeight(.medium)
                                            Text(port.project)
                                                .foregroundColor(.secondary)
                                        }
                                        if let path = port.path {
                                            Text(path)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                    }
                                    Spacer()
                                    Circle()
                                        .fill(resourcesManager.isPortInUse(port.port) ? Color.green : Color.orange)
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                    }
                }

                // Databases
                if !resourcesManager.databases.isEmpty {
                    SettingsSection(title: "Databases", icon: "cylinder") {
                        ForEach(resourcesManager.databases) { db in
                            SettingsRow {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(db.name)
                                            .fontWeight(.medium)
                                        Text(db.project)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if let port = db.port {
                                        Text(":\(port)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                // Simulators
                if !resourcesManager.simulators.isEmpty {
                    SettingsSection(title: "Simulators", icon: "iphone") {
                        ForEach(resourcesManager.simulators) { sim in
                            SettingsRow {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sim.name)
                                            .fontWeight(.medium)
                                        HStack(spacing: 4) {
                                            Text(sim.project)
                                            if let deviceType = sim.deviceType {
                                                Text("•")
                                                Text(deviceType)
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }

                // Empty state
                if resourcesManager.totalResourceCount == 0 {
                    SettingsSection(title: "No Resources", icon: "tray") {
                        SettingsRow {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No shared resources are currently registered.")
                                    .foregroundColor(.secondary)
                                Text("Claude agents can register ports, databases, and simulators in ~/.claude/shared-resources.json")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Integration Tab

    private var integrationTab: some View {
        ScrollView {
            VStack(spacing: 1) {
                SettingsSection(title: "Claude Code Hooks", icon: "terminal") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add this to ~/.claude/settings.json")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(hookConfigText)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )

                        HStack {
                            Spacer()
                            Button(action: copyConfig) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .controlSize(.regular)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }

                SettingsSection(title: "How It Works", icon: "info.circle") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(number: 1, text: "Claude Code triggers the hook when waiting for input")
                        InfoRow(number: 2, text: "The hook writes to a trigger file")
                        InfoRow(number: 3, text: "This app detects the change and shows a ping")
                        InfoRow(number: 4, text: "Click the ping to jump to the correct terminal tab")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
    }

    private var hookConfigText: String {
        """
        {
          "hooks": {
            "Stop": [{
              "type": "command",
              "command": "echo $PPID >> ~/.claude/claude-indicator-trigger"
            }],
            "Notification": [{
              "type": "command",
              "command": "echo $PPID >> ~/.claude/claude-indicator-trigger"
            }]
          }
        }
        """
    }

    private func copyConfig() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hookConfigText, forType: .string)
    }

    private func previewSound() {
        NSSound(named: NSSound.Name(settings.soundName))?.play()
    }

    private func previewAlert() {
        showingPreview = true
        if let mainScreen = NSScreen.main {
            AlertManager.shared.addAlert(pid: ProcessInfo.processInfo.processIdentifier, screenID: mainScreen.displayID)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            AlertManager.shared.dismissAllAlerts()
            showingPreview = false
        }
    }
}

// MARK: - Reusable Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            VStack(spacing: 0) {
                content
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            )
        }
        .padding(.bottom, 16)
    }
}

struct SettingsRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }
}

struct KeyCapView: View {
    var symbol: String?
    var letter: String?

    var body: some View {
        Group {
            if let symbol = symbol {
                Image(systemName: symbol)
            } else if let letter = letter {
                Text(letter)
                    .fontWeight(.medium)
            }
        }
        .font(.system(size: 11))
        .frame(minWidth: 24, minHeight: 20)
        .padding(.horizontal, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

struct InfoRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(Settings.shared)
}
