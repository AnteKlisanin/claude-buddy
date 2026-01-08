import Foundation
import AppKit
import ApplicationServices

class WindowLocator {
    static let shared = WindowLocator()

    /// Check if the terminal window for the given PID is currently frontmost
    func isTerminalFocused(for pid: pid_t) -> Bool {
        // Find the terminal app for this process
        guard let terminalPID = findTerminalPID(for: pid) else {
            return false
        }

        // Check if this terminal app is the frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              frontmostApp.processIdentifier == terminalPID else {
            return false
        }

        return true
    }

    /// Find which screen contains the terminal window for a given PID
    func findScreen(for pid: pid_t) -> NSScreen? {
        // First, try to find the parent process (the terminal app)
        let terminalPID = findTerminalPID(for: pid)
        let targetPID = terminalPID ?? pid

        // Get the application element
        let app = AXUIElementCreateApplication(targetPID)

        // Get windows
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success,
              let windows = windowsRef as? [AXUIElement],
              !windows.isEmpty else {
            // If we can't find windows, fall back to main screen
            return NSScreen.main
        }

        // Get the first window's position
        if let windowFrame = getWindowFrame(windows[0]) {
            return screenContaining(point: windowFrame.center)
        }

        return NSScreen.main
    }

    /// Activate the terminal window/tab containing the given PID
    func activateWindow(for pid: pid_t) {
        // Get TTY for this process
        let tty = getTTY(for: pid)

        // Find terminal app
        let terminalPID = findTerminalPID(for: pid) ?? pid
        guard let app = NSRunningApplication(processIdentifier: terminalPID) else {
            return
        }

        // Try to activate specific tab based on terminal app
        if let bundleID = app.bundleIdentifier {
            switch bundleID {
            case "com.googlecode.iterm2":
                if let tty = tty {
                    activateiTerm2Tab(tty: tty)
                    return
                }
            case "com.apple.Terminal":
                if let tty = tty {
                    activateTerminalTab(tty: tty)
                    return
                }
            default:
                break
            }
        }

        // Fallback: just activate the app
        app.activate(options: [.activateIgnoringOtherApps])

        // Try to raise the specific window
        let appElement = AXUIElementCreateApplication(terminalPID)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement],
              !windows.isEmpty else {
            return
        }
        AXUIElementPerformAction(windows[0], kAXRaiseAction as CFString)
    }

    /// Get the TTY device for a process, walking up process tree if needed
    private func getTTY(for pid: pid_t) -> String? {
        var currentPID = pid
        var iterations = 0
        let maxIterations = 10

        while iterations < maxIterations {
            iterations += 1

            var info = kinfo_proc()
            var size = MemoryLayout<kinfo_proc>.size
            var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, currentPID]

            guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return nil }

            let devNumber = info.kp_eproc.e_tdev

            // If we have a valid TTY, return it
            if devNumber != -1 && devNumber != 0 {
                let minor = devNumber & 0xffffff
                return "/dev/ttys\(String(format: "%03d", minor))"
            }

            // Otherwise, try parent process
            let parentPID = info.kp_eproc.e_ppid
            if parentPID <= 1 {
                break
            }
            currentPID = parentPID
        }

        return nil
    }

    /// Activate iTerm2 tab with specific TTY
    private func activateiTerm2Tab(tty: String) {
        let script = """
        tell application "iTerm2"
            activate
            repeat with aWindow in windows
                repeat with aTab in tabs of aWindow
                    repeat with aSession in sessions of aTab
                        if tty of aSession is "\(tty)" then
                            select aTab
                            select aSession
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    /// Activate Terminal.app tab by TTY
    private func activateTerminalTab(tty: String) {
        let script = """
        tell application "Terminal"
            activate
            set targetTTY to "\(tty)"
            repeat with aWindow in windows
                repeat with aTab in tabs of aWindow
                    if tty of aTab is targetTTY then
                        set selected tab of aWindow to aTab
                        set frontmost of aWindow to true
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    /// Run AppleScript
    private func runAppleScript(_ source: String) {
        if let script = NSAppleScript(source: source) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
        }
    }

    /// Find the terminal application PID that contains the given shell PID (public for AlertPanel)
    func findTerminalPID(for shellPID: pid_t) -> pid_t? {
        var pid = shellPID
        var iterations = 0
        let maxIterations = 10 // Prevent infinite loops

        while iterations < maxIterations {
            iterations += 1

            // Get parent PID
            var info = kinfo_proc()
            var size = MemoryLayout<kinfo_proc>.size
            var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]

            guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else {
                break
            }

            let parentPID = info.kp_eproc.e_ppid

            // Check if this process is a known terminal app
            if isTerminalApp(pid: pid) {
                return pid
            }

            // Move up the process tree
            if parentPID <= 1 {
                break
            }
            pid = parentPID
        }

        return nil
    }

    /// Check if a PID belongs to a known terminal application
    private func isTerminalApp(pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }

        let terminalBundleIDs = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "io.alacritty",
            "com.github.wez.wezterm",
            "co.zeit.hyper",
            "com.microsoft.VSCode",
            "com.todesktop.230313mzl4w4u92",  // Cursor
            "dev.warp.Warp-Stable",
            "com.jetbrains.intellij",
            "org.vim.MacVim",
            "net.kovidgoyal.kitty"
        ]

        if let bundleID = app.bundleIdentifier {
            return terminalBundleIDs.contains(bundleID)
        }

        return false
    }

    /// Get the frame of an AXUIElement window
    private func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    /// Find which screen contains a given point
    private func screenContaining(point: CGPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        // If no screen contains the point, return the closest one
        return NSScreen.main
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
