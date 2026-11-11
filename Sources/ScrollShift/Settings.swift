import Foundation

/// Speichert die Schalter dauerhaft. Standard: alle eingeschaltet.
/// „Minimieren ohne Genie-Effekt“ steht nicht hier: Das Dock speichert es selbst.
final class Settings {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let reverseMouseScroll = "reverseMouseScroll"
        static let capsLockAsShift = "capsLockAsShift"
        static let capsLockNoDelay = "capsLockNoDelay"
    }

    init() {
        defaults.register(defaults: [
            Keys.reverseMouseScroll: true,
            Keys.capsLockAsShift: true,
            Keys.capsLockNoDelay: true
        ])
    }

    var reverseMouseScroll: Bool {
        get { defaults.bool(forKey: Keys.reverseMouseScroll) }
        set { defaults.set(newValue, forKey: Keys.reverseMouseScroll) }
    }

    var capsLockAsShift: Bool {
        get { defaults.bool(forKey: Keys.capsLockAsShift) }
        set { defaults.set(newValue, forKey: Keys.capsLockAsShift) }
    }

    var capsLockNoDelay: Bool {
        get { defaults.bool(forKey: Keys.capsLockNoDelay) }
        set { defaults.set(newValue, forKey: Keys.capsLockNoDelay) }
    }
}
