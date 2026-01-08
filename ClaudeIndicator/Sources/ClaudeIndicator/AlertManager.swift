import Foundation
import AppKit

struct Alert: Hashable {
    let pid: pid_t
    let screenID: CGDirectDisplayID
    let timestamp: Date
    let suppressRing: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
        hasher.combine(screenID)
    }

    static func == (lhs: Alert, rhs: Alert) -> Bool {
        lhs.pid == rhs.pid && lhs.screenID == rhs.screenID
    }
}

class AlertManager: ObservableObject {
    static let shared = AlertManager()

    @Published private(set) var alerts: Set<Alert> = []
    private var dismissTimers: [Alert: Timer] = [:]
    private let settings = Settings.shared

    var hasActiveAlerts: Bool {
        !alerts.isEmpty
    }

    func alertCount(for screenID: CGDirectDisplayID) -> Int {
        alerts.filter { $0.screenID == screenID }.count
    }

    /// Count of alerts that should show the ring (not suppressed)
    func ringAlertCount(for screenID: CGDirectDisplayID) -> Int {
        alerts.filter { $0.screenID == screenID && !$0.suppressRing }.count
    }

    func ringThickness(for screenID: CGDirectDisplayID) -> CGFloat {
        let count = ringAlertCount(for: screenID)
        guard count > 0 else { return 0 }
        return CGFloat(settings.ringThickness) + CGFloat(max(0, count - 1)) * CGFloat(settings.thicknessIncrement)
    }

    func addAlert(pid: pid_t, screenID: CGDirectDisplayID, suppressRing: Bool = false) {
        let alert = Alert(pid: pid, screenID: screenID, timestamp: Date(), suppressRing: suppressRing)

        // If alert already exists, just reset its timer
        if let existingAlert = alerts.first(where: { $0.pid == pid && $0.screenID == screenID }) {
            dismissTimers[existingAlert]?.invalidate()
            dismissTimers.removeValue(forKey: existingAlert)
            // Remove old alert and add new one (in case suppressRing changed)
            alerts.remove(existingAlert)
            alerts.insert(alert)
        } else {
            alerts.insert(alert)
            // Play sound for new alerts only (but not if ring is suppressed - user is looking)
            if !suppressRing {
                playAlertSound()
            }
        }

        // Set up auto-dismiss if enabled
        if settings.autoDismissEnabled {
            let timer = Timer.scheduledTimer(withTimeInterval: settings.autoDismissDelay, repeats: false) { [weak self] _ in
                self?.removeAlert(alert)
            }
            dismissTimers[alert] = timer
        }

        NotificationCenter.default.post(name: .alertsDidChange, object: nil)
    }

    private func playAlertSound() {
        guard settings.soundEnabled else { return }
        NSSound(named: NSSound.Name(settings.soundName))?.play()
    }

    func removeAlert(_ alert: Alert) {
        dismissTimers[alert]?.invalidate()
        dismissTimers.removeValue(forKey: alert)
        alerts.remove(alert)
        NotificationCenter.default.post(name: .alertsDidChange, object: nil)
    }

    func dismissAlerts(for screenID: CGDirectDisplayID) {
        let screensAlerts = alerts.filter { $0.screenID == screenID }
        for alert in screensAlerts {
            removeAlert(alert)
        }
    }

    func dismissAllAlerts() {
        for alert in alerts {
            dismissTimers[alert]?.invalidate()
        }
        dismissTimers.removeAll()
        alerts.removeAll()
        NotificationCenter.default.post(name: .alertsDidChange, object: nil)
    }

    func screenIDs(withAlerts: Bool = true) -> Set<CGDirectDisplayID> {
        Set(alerts.map { $0.screenID })
    }

    /// Screen IDs that have alerts with ring enabled (not suppressed)
    func screenIDsWithRing() -> Set<CGDirectDisplayID> {
        Set(alerts.filter { !$0.suppressRing }.map { $0.screenID })
    }
}

extension Notification.Name {
    static let alertsDidChange = Notification.Name("alertsDidChange")
}
