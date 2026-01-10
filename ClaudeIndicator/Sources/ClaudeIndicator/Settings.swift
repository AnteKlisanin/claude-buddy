import SwiftUI
import AppKit

class Settings: ObservableObject {
    static let shared = Settings()

    private enum Keys {
        static let ringColor = "ringColor"
        static let ringStyle = "ringStyle"
        static let blinkingEnabled = "blinkingEnabled"
        static let blinkSpeed = "blinkSpeed"
        static let ringThickness = "ringThickness"
        static let ringOpacity = "ringOpacity"
        static let thicknessIncrement = "thicknessIncrement"
        static let autoDismissEnabled = "autoDismissEnabled"
        static let autoDismissDelay = "autoDismissDelay"
        static let ringEnabled = "ringEnabled"
        static let alertPanelEnabled = "alertPanelEnabled"
        static let soundEnabled = "soundEnabled"
        static let soundName = "soundName"
        static let panelPosition = "panelPosition"
    }

    enum PanelPosition: String, CaseIterable {
        case topRight = "topRight"
        case topLeft = "topLeft"
        case bottomRight = "bottomRight"
        case bottomLeft = "bottomLeft"

        var displayName: String {
            switch self {
            case .topRight: return "Top Right"
            case .topLeft: return "Top Left"
            case .bottomRight: return "Bottom Right"
            case .bottomLeft: return "Bottom Left"
            }
        }
    }

    enum RingStyle: String, CaseIterable {
        case solid = "solid"
        case siri = "siri"

        var displayName: String {
            switch self {
            case .solid: return "Solid Color"
            case .siri: return "Siri"
            }
        }
    }

    @Published var ringColor: Color {
        didSet { saveColor(ringColor, forKey: Keys.ringColor) }
    }

    @Published var ringStyle: RingStyle {
        didSet { UserDefaults.standard.set(ringStyle.rawValue, forKey: Keys.ringStyle) }
    }

    @Published var blinkingEnabled: Bool {
        didSet { UserDefaults.standard.set(blinkingEnabled, forKey: Keys.blinkingEnabled) }
    }

    @Published var blinkSpeed: Double {
        didSet { UserDefaults.standard.set(blinkSpeed, forKey: Keys.blinkSpeed) }
    }

    @Published var ringThickness: Double {
        didSet { UserDefaults.standard.set(ringThickness, forKey: Keys.ringThickness) }
    }

    @Published var ringOpacity: Double {
        didSet { UserDefaults.standard.set(ringOpacity, forKey: Keys.ringOpacity) }
    }

    @Published var thicknessIncrement: Double {
        didSet { UserDefaults.standard.set(thicknessIncrement, forKey: Keys.thicknessIncrement) }
    }

    @Published var autoDismissEnabled: Bool {
        didSet { UserDefaults.standard.set(autoDismissEnabled, forKey: Keys.autoDismissEnabled) }
    }

    @Published var autoDismissDelay: Double {
        didSet { UserDefaults.standard.set(autoDismissDelay, forKey: Keys.autoDismissDelay) }
    }

    @Published var ringEnabled: Bool {
        didSet { UserDefaults.standard.set(ringEnabled, forKey: Keys.ringEnabled) }
    }

    @Published var alertPanelEnabled: Bool {
        didSet { UserDefaults.standard.set(alertPanelEnabled, forKey: Keys.alertPanelEnabled) }
    }

    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: Keys.soundEnabled) }
    }

    @Published var soundName: String {
        didSet { UserDefaults.standard.set(soundName, forKey: Keys.soundName) }
    }

    @Published var panelPosition: PanelPosition {
        didSet { UserDefaults.standard.set(panelPosition.rawValue, forKey: Keys.panelPosition) }
    }

    // Available system sounds
    static let availableSounds = [
        "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]

    init() {
        // Load saved values or use defaults
        self.ringColor = Settings.loadColor(forKey: Keys.ringColor) ?? Color(red: 1.0, green: 0.23, blue: 0.19) // #FF3B30
        self.ringStyle = RingStyle(rawValue: UserDefaults.standard.string(forKey: Keys.ringStyle) ?? "") ?? .solid
        self.blinkingEnabled = UserDefaults.standard.object(forKey: Keys.blinkingEnabled) as? Bool ?? true
        self.blinkSpeed = UserDefaults.standard.object(forKey: Keys.blinkSpeed) as? Double ?? 1.0
        self.ringThickness = UserDefaults.standard.object(forKey: Keys.ringThickness) as? Double ?? 80.0
        self.ringOpacity = UserDefaults.standard.object(forKey: Keys.ringOpacity) as? Double ?? 0.6
        self.thicknessIncrement = UserDefaults.standard.object(forKey: Keys.thicknessIncrement) as? Double ?? 40.0
        self.autoDismissEnabled = UserDefaults.standard.object(forKey: Keys.autoDismissEnabled) as? Bool ?? true
        self.autoDismissDelay = UserDefaults.standard.object(forKey: Keys.autoDismissDelay) as? Double ?? 30.0
        self.ringEnabled = UserDefaults.standard.object(forKey: Keys.ringEnabled) as? Bool ?? true
        self.alertPanelEnabled = UserDefaults.standard.object(forKey: Keys.alertPanelEnabled) as? Bool ?? true
        self.soundEnabled = UserDefaults.standard.object(forKey: Keys.soundEnabled) as? Bool ?? false
        self.soundName = UserDefaults.standard.string(forKey: Keys.soundName) ?? "Glass"
        self.panelPosition = PanelPosition(rawValue: UserDefaults.standard.string(forKey: Keys.panelPosition) ?? "") ?? .topRight
    }

    var nsColor: NSColor {
        NSColor(ringColor)
    }

    private func saveColor(_ color: Color, forKey key: String) {
        let nsColor = NSColor(color)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadColor(forKey key: String) -> Color? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return nil
        }
        return Color(nsColor)
    }
}
