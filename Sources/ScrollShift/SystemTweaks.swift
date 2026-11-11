import AppKit
import IOKit.hidsystem

/// Zwei einmalige Systemeinstellungen. Beide werden nur beim Umschalten bzw. beim
/// Start gesetzt. Danach läuft nichts mehr mit: kein Tap, kein Timer.
enum SystemTweaks {

    // MARK: - Caps Lock ohne Verzögerung

    /// Apples Standardverzögerung für Caps Lock in Millisekunden.
    /// Die eingebaute Tastatur meldet diesen Wert als "CapsLockDelay".
    private static let defaultCapsLockDelay = 75

    /// Setzt die Caps-Lock-Verzögerung für alle Tastaturen.
    /// macOS vergisst den Wert beim Neustart, deshalb setzt die App ihn bei jedem Start neu.
    static func setCapsLockDelayDisabled(_ disabled: Bool) {
        let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
        let value = (disabled ? 0 : defaultCapsLockDelay) as CFNumber
        if !IOHIDEventSystemClientSetProperty(client, kIOHIDKeyboardCapsLockDelayOverride as CFString, value) {
            NSLog("ScrollShift: Caps-Lock-Verzögerung konnte nicht gesetzt werden.")
        }
    }

    // MARK: - Minimieren ohne Genie-Effekt

    private static let dockDomain = "com.apple.dock" as CFString
    private static let minEffectKey = "mineffect" as CFString

    /// Liest die Einstellung direkt aus dem Dock. Das Dock speichert sie selbst,
    /// die App braucht deshalb keine eigene Kopie.
    static var isFastMinimizeEnabled: Bool {
        CFPreferencesAppSynchronize(dockDomain)
        let effect = CFPreferencesCopyAppValue(minEffectKey, dockDomain) as? String
        return effect == "scale"
    }

    /// "scale" = schlichtes Verkleinern, "genie" = Apples Standard-Animation.
    /// Das Dock übernimmt den Wert erst nach einem Neustart (wie `killall Dock`).
    static func setFastMinimize(_ enabled: Bool) {
        CFPreferencesSetAppValue(minEffectKey, (enabled ? "scale" : "genie") as CFString, dockDomain)
        CFPreferencesAppSynchronize(dockDomain)

        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["Dock"]
        do {
            try killall.run()
        } catch {
            NSLog("ScrollShift: Dock konnte nicht neu gestartet werden: \(error)")
        }
    }
}
