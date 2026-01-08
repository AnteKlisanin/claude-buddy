import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = Settings.shared
    private var statusBarController: StatusBarController!
    private var overlayController: OverlayWindowController!
    private var alertPanelController: AlertPanelController!
    private var fileWatcher: FileWatcher!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Request permissions if needed
        checkAccessibilityPermissions()
        requestAutomationPermissions()

        // Initialize components
        statusBarController = StatusBarController()
        statusBarController.onSettingsClicked = { [weak self] in
            self?.showSettingsWindow()
        }

        overlayController = OverlayWindowController()
        alertPanelController = AlertPanelController()

        fileWatcher = FileWatcher()
        fileWatcher.onTrigger = { [weak self] pid in
            self?.handleTrigger(pid: pid)
        }
        fileWatcher.start()

        // Register global hotkey for dismiss (Cmd+Shift+D)
        registerGlobalHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        fileWatcher?.stop()
    }

    private func handleTrigger(pid: pid_t) {
        // Check if the terminal is already focused
        let terminalIsFocused = WindowLocator.shared.isTerminalFocused(for: pid)

        // Find which screen the terminal window is on
        let screen = WindowLocator.shared.findScreen(for: pid)
        let screenID = screen?.displayID ?? NSScreen.main?.displayID ?? 0

        // Add alert for this PID and screen
        // Pass whether terminal is focused so ring can be suppressed but panel still shown
        AlertManager.shared.addAlert(pid: pid, screenID: screenID, suppressRing: terminalIsFocused)
    }

    private func showSettingsWindow() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(settings)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 460),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Claude Indicator"
            window.contentView = NSHostingView(rootView: settingsView)
            window.center()
            window.isReleasedWhenClosed = false

            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !trusted {
            print("Accessibility permissions are required for screen-specific alerts.")
            print("Please grant permission in System Settings > Privacy & Security > Accessibility")
        }
    }

    private func requestAutomationPermissions() {
        // Request permission to control Terminal.app
        // Running AppleScript targeting Terminal triggers the permission dialog
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let script = NSAppleScript(source: """
                tell application "Terminal" to return name
            """)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
            // -1743 = not authorized, which prompts the permission dialog
        }
    }

    private func registerGlobalHotkey() {
        // Register Cmd+Shift+D as global hotkey to dismiss all alerts
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // Check for Cmd+Shift+D
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 2 { // 2 = D key
                DispatchQueue.main.async {
                    AlertManager.shared.dismissAllAlerts()
                }
            }
        }
    }
}
