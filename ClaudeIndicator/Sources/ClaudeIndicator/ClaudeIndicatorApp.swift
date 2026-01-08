import SwiftUI
import AppKit

@main
struct ClaudeIndicatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        SwiftUI.Settings {
            SettingsView()
                .environmentObject(appDelegate.settings)
        }
    }
}
