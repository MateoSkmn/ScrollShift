# ScrollShift – Vorgehensplan für eine Mac-Menüleisten-App

Nov 10, 2026 · @Mateo

## Überblick und Ziele

ScrollShift ist eine kleine Menüleisten-App für macOS 13 oder neuer mit zwei Schaltern: Das Mausrad scrollt umgekehrt, während das Trackpad „natürlich“ bleibt, und Caps Lock wirkt auch auf Zahlen und Sonderzeichen. Die Umsetzung übernimmt ein Claude-Agent. Dieses Dokument ist sein Auftrag und gleichzeitig deine Erklärung, was passiert.

**Anforderungen**

- **Einfache Bedienung:** ein Symbol in der Menüleiste, ein Klick öffnet das Menü mit Häkchen zum An- und Ausschalten. Kein Fenster, kein Dock-Symbol, keine Einstellungsseite.
- **Ressourcenarm:** 0 % CPU im Leerlauf, unter 40 MB Arbeitsspeicher, kein Hintergrund-Polling. Sind beide Funktionen aus, läuft gar nichts mit.
- **Ohne Xcode-Oberfläche baubar:** reines Swift-Paket und ein Build-Skript, damit der Agent alles im Terminal erledigen kann.
- **Zielgruppe:** zuerst du selbst. Der Code kommt aber so auf GitHub, dass andere ihn kostenlos nutzen können.

**Was du selbst tun musst:** Der Agent kann fast alles allein. Nur die Berechtigung unter *Bedienungshilfen* musst du einmal per Klick in den Systemeinstellungen erteilen. Diesen Schritt erlaubt macOS keinem Programm.

## Feature 1: Mausrad umkehren, Trackpad bleibt natürlich

macOS kennt nur eine Scrollrichtung für alle Geräte. Die App dreht deshalb gezielt nur die Scroll-Events der Maus um und lässt die des Trackpads unverändert.

**So funktioniert es**

1. Ein *Event-Tap* (`CGEventTap`) klinkt sich in den Eingabestrom ein, bevor ein Scroll-Event bei einer App ankommt.
2. Jedes Scroll-Event trägt das Merkmal `scrollWheelEventIsContinuous`. Trackpads und die Magic Mouse liefern stufenlose Bewegungen (Wert 1), klassische Mausräder rasten in Schritten ein (Wert 0).
3. Bei Wert 0 kehrt die App die drei Bewegungswerte um (Zeilen, Pixel und Festkomma), jeweils für vertikal und horizontal. Bei Wert 1 bleibt alles, wie es ist.
4. Das veränderte Event läuft normal weiter zur App unter dem Mauszeiger.

**Einstellung in macOS dazu:** Unter *Systemeinstellungen → Trackpad* bleibt „Natürliches Scrollen“ eingeschaltet. Die App sorgt dann dafür, dass die Maus sich klassisch verhält.

**Aufwand im Code:** etwa 20 Zeilen. Pro Scroll-Schritt kostet das wenige Mikrosekunden.

## Feature 2: Caps Lock für Zahlen und Sonderzeichen

Mit Caps Lock werden unter macOS normalerweise nur Buchstaben groß. Die App ergänzt bei aktivem Caps Lock die Shift-Taste für alle Zeichentasten. So wirkt Caps Lock wie eine Schreibmaschinen-„Shift-Feststellung“.

**So funktioniert es**

1. Derselbe Event-Tap empfängt auch Tastendrücke.
2. Ist Caps Lock an (`maskAlphaShift`) und die gedrückte Taste eine Zeichentaste aus der Liste unten, setzt die App zusätzlich das Shift-Flag.
3. Damit jede App das richtige Zeichen bekommt, berechnet die App außerdem das Shift-Zeichen für das gerade aktive Tastaturlayout (`UCKeyTranslate`) und hängt es an das Event. Das Ergebnis wird pro Taste zwischengespeichert und beim Layoutwechsel verworfen.
4. Bei Tottasten (z. B. \` und ^) bleibt nur das Shift-Flag gesetzt, damit Akzente weiter funktionieren.

**Ausnahmen:** Ist ⌘, Ctrl oder ⌥ gedrückt, greift die App nicht ein. Kurzbefehle wie ⌘+1 und Zeichen wie ⌥+L (@) bleiben so unverändert. Ziffernblock, Pfeil- und Funktionstasten werden ebenfalls nicht verändert.

**Betroffene Tasten (deutsches Mac-Layout, ISO)**

| Taste ohne Shift | Mit Caps Lock | Keycode |
| --- | --- | --- |
| 1 2 3 4 5 6 7 8 9 0 | ! " § $ % & / ( ) = | 18 19 20 21 23 22 26 28 25 29 |
| ß | ? | 27 |
| ´ (Tottaste) | \` (Tottaste) | 24 |
| ^ (Tottaste) | ° | 10 |
| < | > | 50 |
| + | \* | 30 |
| # | ' | 42 |
| , . - | ; : \_ | 43 47 44 |
| ü ö ä | Ü Ö Ä | 33 41 39 |

Die Keycodes beschreiben die Position der Taste, nicht das Zeichen. Deshalb funktioniert die App auch mit anderen Layouts: Es kommt jeweils das Shift-Zeichen des aktiven Layouts heraus.

## Architektur, Bedienung und Ressourcen

Beide Funktionen laufen über einen einzigen Event-Tap. Alles andere sind wenige Zeilen Menü und Einstellungen.

&#91;embedded content: Aufbau der App · 1 Event-Tap, 2 Funktionen\]

Eingaben laufen von links durch den Tap zur Ziel-App. Die Menüleiste baut den Tap nur beim Umschalten neu auf.

**Bedienung**

- Symbol (Maus) in der Menüleiste, ein Klick zeigt das Menü.
- Zwei Häkchen: „Mausrad umkehren“ und „Caps Lock für Zahlen & Zeichen“. Beide sind beim ersten Start an.
- „Bei Anmeldung starten“ für den Autostart, „ScrollShift beenden“ (⌘Q).
- Fehlt die Berechtigung, erscheint ein zusätzlicher Menüpunkt, der direkt zur richtigen Systemeinstellung führt.

**Ressourcen-Prinzipien**

- Kein Fenster, kein Dock-Symbol, keine SwiftUI: nur AppKit-Menü, rund 15 bis 25 MB Arbeitsspeicher.
- Der Tap hört nur auf die gerade benötigten Event-Arten. Sind beide Funktionen aus, gibt es gar keinen Tap.
- Einstellungen werden im Callback nicht gelesen, sondern beim Umschalten in Variablen kopiert.
- Das Shift-Zeichen jeder Taste wird einmal berechnet und zwischengespeichert.
- Kein Polling: Häkchen werden erst beim Öffnen des Menüs aktualisiert. Der einzige Timer prüft beim ersten Start die Berechtigung und beendet sich danach.

## Vorgehensplan für den Claude-Agent

Der Agent arbeitet die Phasen in dieser Reihenfolge ab. Phase 4 braucht einmal deinen Klick, alles andere läuft im Terminal.

1. **Voraussetzungen prüfen**
   - macOS-Version prüfen (`sw_vers`), mindestens 13.0.
   - Command Line Tools prüfen (`xcode-select -p`), fehlen sie: `xcode-select --install`. Ein vollständiges Xcode ist nicht nötig.
   - Optional, aber empfohlen: ein eigenes Signierzertifikat anlegen (siehe Abschnitt Einschränkungen). Sonst muss die Berechtigung nach jedem Neubau neu erteilt werden.
2. **Projekt anlegen**
   - Ordner `ScrollShift` mit genau der Dateistruktur aus dem Abschnitt Quellcode anlegen.
   - In `Resources/Info.plist` die Bundle-ID `de.example.scrollshift` durch eine eigene ersetzen, z. B. `io.github.<benutzername>.scrollshift`.
3. **Bauen**
   - `chmod +x build.sh && ./build.sh` ausführen. Das Ergebnis liegt in `build/ScrollShift.app`.
   - Compilerfehler beheben, ohne die Architektur (ein Event-Tap, Menü ohne Fenster) zu verändern.
4. **Installieren und Berechtigung erteilen**
   - App nach `/Applications` kopieren und starten (`open /Applications/ScrollShift.app`).
   - macOS fragt nach der Bedienungshilfen-Berechtigung. **Du** schaltest ScrollShift unter *Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen* ein. Die App erkennt das innerhalb von 2 Sekunden selbst.
5. **Testen**
   - Alle Punkte aus dem Abschnitt Tests und Abnahmekriterien durchgehen. Der Agent kann die Ressourcenwerte selbst messen, die Eingabetests machst du.
6. **Autostart einschalten**
   - Im Menü „Bei Anmeldung starten“ anhaken.
7. **Veröffentlichen (optional)**
   - Repository mit README, Lizenz und `.gitignore` anlegen und hochladen, wie im Abschnitt GitHub beschrieben.

**Geschätzter Aufwand:** Phase 1 bis 3 erledigt der Agent in unter einer Stunde. Mit Tests und GitHub kommst du auf etwa einen Nachmittag.

## Quellcode

Die App besteht aus sieben Dateien und rund 250 Zeilen. Sie nutzt nur Apple-Frameworks, keine Fremdbibliotheken. Der Code ist ungetestet geschrieben. Der Agent baut ihn in Phase 3 und behebt eventuelle Compilerfehler.

```text
ScrollShift/
├── Package.swift
├── build.sh
├── .gitignore
├── Resources/
│   └── Info.plist
└── Sources/ScrollShift/
    ├── main.swift
    ├── AppDelegate.swift
    ├── EventTap.swift
    └── Settings.swift
```

### Package.swift

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScrollShift",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ScrollShift", path: "Sources/ScrollShift")
    ]
)
```

### Sources/ScrollShift/main.swift

```swift
import AppKit

// Startpunkt: Menüleisten-App ohne Dock-Symbol und ohne Fenster.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

### Sources/ScrollShift/Settings.swift

```swift
import Foundation

/// Speichert die beiden Schalter dauerhaft. Standard: beide eingeschaltet.
final class Settings {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let reverseMouseScroll = "reverseMouseScroll"
        static let capsLockAsShift = "capsLockAsShift"
    }

    init() {
        defaults.register(defaults: [
            Keys.reverseMouseScroll: true,
            Keys.capsLockAsShift: true
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
}
```

### Sources/ScrollShift/EventTap.swift

```swift
import AppKit
import Carbon.HIToolbox

/// Ein einziger Event-Tap für beide Funktionen.
/// Er existiert nur, solange mindestens eine Funktion eingeschaltet ist,
/// und hört nur auf die Event-Arten, die gerade gebraucht werden.
final class EventTap {
    private let settings: Settings
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Kopien der Einstellungen: Im Callback wird nichts aus UserDefaults gelesen.
    fileprivate var reverseScroll = false
    fileprivate var capsAsShift = false

    // Shift-Zeichen pro Keycode für das aktive Layout ([] = keins bzw. Tottaste).
    fileprivate var shiftedCharCache: [UInt16: [UniChar]] = [:]

    init(settings: Settings) {
        self.settings = settings
        // Bei Layoutwechsel (z. B. Deutsch -> Englisch) Zwischenspeicher leeren.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.shiftedCharCache.removeAll()
        }
    }

    /// Liest die Einstellungen neu ein und baut den Tap passend auf oder ab.
    func update() {
        stop()
        reverseScroll = settings.reverseMouseScroll
        capsAsShift = settings.capsLockAsShift

        var mask: CGEventMask = 0
        if reverseScroll {
            mask |= CGEventMask(1) << CGEventType.scrollWheel.rawValue
        }
        if capsAsShift {
            mask |= CGEventMask(1) << CGEventType.keyDown.rawValue
            mask |= CGEventMask(1) << CGEventType.keyUp.rawValue
        }
        // Beide Funktionen aus oder keine Berechtigung: kein Tap, null Last.
        guard mask != 0, AXIsProcessTrusted() else { return }

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("ScrollShift: Event-Tap konnte nicht erstellt werden.")
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        tap = newTap
        runLoopSource = source
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    /// macOS schaltet einen Tap ab, wenn er zu langsam war. Dann sofort wieder an.
    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }
}

// MARK: - Callback
// Muss eine freie Funktion sein, sofort zurückkehren und darf nie blockieren.

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let owner = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        owner.reenable()
    case .scrollWheel:
        if owner.reverseScroll { reverseIfMouse(event) }
    case .keyDown, .keyUp:
        if owner.capsAsShift { owner.applyCapsShift(event) }
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}

// MARK: - Feature 1: Mausrad umkehren

/// Je Achse (vertikal, horizontal): Zeilen-, Pixel- und Festkomma-Wert.
private let scrollAxes: [(CGEventField, CGEventField, CGEventField)] = [
    (.scrollWheelEventDeltaAxis1, .scrollWheelEventPointDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1),
    (.scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2)
]

private func reverseIfMouse(_ event: CGEvent) {
    // Trackpad und Magic Mouse liefern kontinuierliche Events: unverändert lassen.
    guard event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 else { return }
    for (lines, points, fixed) in scrollAxes {
        // Erst alle Werte lesen, dann schreiben.
        let l = event.getIntegerValueField(lines)
        let p = event.getIntegerValueField(points)
        let f = event.getDoubleValueField(fixed)
        event.setIntegerValueField(lines, value: -l)
        event.setDoubleValueField(fixed, value: -f)
        event.setIntegerValueField(points, value: -p)
    }
}

// MARK: - Feature 2: Caps Lock als Shift-Feststellung

/// Zeichentasten nach Position (nicht Zeichen), Mac-ISO-Tastatur.
private let shiftableKeyCodes: Set<UInt16> = [
    18, 19, 20, 21, 23, 22, 26, 28, 25, 29, // 1 bis 0
    27, 24, 10, 50,                         // ß  ´  ^  <
    33, 30, 41, 39, 42,                     // ü  +  ö  ä  #
    43, 47, 44                              // ,  .  -
]

/// Ist eine dieser Tasten gedrückt, greift die App nicht ein (Kurzbefehle, ⌥-Zeichen).
private let untouchedModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]

/// Shift-Flag plus geräteabhängiges Bit "linke Shift-Taste" (NX_DEVICELSHIFTKEYMASK).
private let shiftFlags: CGEventFlags = [.maskShift, CGEventFlags(rawValue: 0x0000_0002)]

extension EventTap {
    fileprivate func applyCapsShift(_ event: CGEvent) {
        let flags = event.flags
        guard flags.contains(.maskAlphaShift),
              flags.isDisjoint(with: untouchedModifiers) else { return }
        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        guard shiftableKeyCodes.contains(keyCode) else { return }

        event.flags = flags.union(shiftFlags)
        if let chars = shiftedCharacters(for: keyCode) {
            event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
        }
    }

    private func shiftedCharacters(for keyCode: UInt16) -> [UniChar]? {
        if let cached = shiftedCharCache[keyCode] {
            return cached.isEmpty ? nil : cached
        }
        let chars = translateWithShift(keyCode) ?? []
        shiftedCharCache[keyCode] = chars
        return chars.isEmpty ? nil : chars
    }
}

/// Zeichen, das die Taste mit Shift im aktiven Layout erzeugt.
/// nil bei Tottasten oder wenn das Layout keine Tabelle hat (z. B. manche Eingabemethoden).
private func translateWithShift(_ keyCode: UInt16) -> [UniChar]? {
    guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
          let rawData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    else { return nil }
    let layoutData = Unmanaged<CFData>.fromOpaque(rawData).takeUnretainedValue() as Data

    let maxLength = 4
    var chars = [UniChar](repeating: 0, count: maxLength)
    var length = 0
    var deadKeyState: UInt32 = 0
    let modifiers = UInt32(((shiftKey | alphaLock) >> 8) & 0xFF)

    let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
        guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
        return UCKeyTranslate(
            layout, keyCode, UInt16(kUCKeyActionDown), modifiers,
            UInt32(LMGetKbdType()), 0, &deadKeyState,
            maxLength, &length, &chars
        )
    }
    guard status == OSStatus(noErr), deadKeyState == 0, length > 0 else { return nil }
    return Array(chars.prefix(length))
}
```

### Sources/ScrollShift/AppDelegate.swift

```swift
import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings()
    private lazy var eventTap = EventTap(settings: settings)
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?

    private lazy var reverseItem = makeItem("Mausrad umkehren", #selector(toggleReverseScroll))
    private lazy var capsItem = makeItem("Caps Lock für Zahlen & Zeichen", #selector(toggleCapsLock))
    private lazy var loginItem = makeItem("Bei Anmeldung starten", #selector(toggleLaunchAtLogin))
    private lazy var permissionItem = makeItem("Berechtigung fehlt – hier erteilen …", #selector(openAccessibilitySettings))

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "ScrollShift")

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(reverseItem)
        menu.addItem(capsItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(permissionItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "ScrollShift beenden",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item

        waitForPermission(prompt: true)
        eventTap.update()
        refreshMenu()
    }

    /// Häkchen werden erst beim Öffnen des Menüs aktualisiert: kein Polling.
    func menuWillOpen(_ menu: NSMenu) {
        refreshMenu()
    }

    private func refreshMenu() {
        reverseItem.state = settings.reverseMouseScroll ? .on : .off
        capsItem.state = settings.capsLockAsShift ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        permissionItem.isHidden = AXIsProcessTrusted()
    }

    @objc private func toggleReverseScroll() {
        settings.reverseMouseScroll.toggle()
        eventTap.update()
    }

    @objc private func toggleCapsLock() {
        settings.capsLockAsShift.toggle()
        eventTap.update()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("ScrollShift: Autostart konnte nicht geändert werden: \(error)")
        }
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        waitForPermission(prompt: false)
    }

    /// Fragt bei Bedarf nach der Berechtigung und prüft dann alle 2 s,
    /// aber nur, bis sie erteilt ist. Danach läuft kein Timer mehr.
    private func waitForPermission(prompt: Bool) {
        guard permissionTimer == nil else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        guard !AXIsProcessTrustedWithOptions(options) else { return }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            self?.permissionTimer = nil
            self?.eventTap.update()
            self?.refreshMenu()
        }
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }
}
```

### Resources/Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                <string>ScrollShift</string>
    <key>CFBundleDisplayName</key>         <string>ScrollShift</string>
    <key>CFBundleIdentifier</key>          <string>de.example.scrollshift</string>
    <key>CFBundleExecutable</key>          <string>ScrollShift</string>
    <key>CFBundlePackageType</key>         <string>APPL</string>
    <key>CFBundleShortVersionString</key>  <string>1.0</string>
    <key>CFBundleVersion</key>             <string>1</string>
    <key>LSMinimumSystemVersion</key>      <string>13.0</string>
    <!-- Kein Dock-Symbol, nur Menüleiste -->
    <key>LSUIElement</key>                 <true/>
</dict>
</plist>
```

### build.sh

```bash
#!/bin/bash
# Baut build/ScrollShift.app
# Mit eigenem Zertifikat: SIGN_IDENTITY="ScrollShift Dev" ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="build/ScrollShift.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/ScrollShift" "$APP/Contents/MacOS/ScrollShift"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# "-" = Ad-hoc-Signatur. Ein eigenes Zertifikat hält die Berechtigung über Neubauten hinweg.
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "Fertig: $APP"
```

### .gitignore

```text
.build/
build/
.swiftpm/
.DS_Store
```

## Tests und Abnahmekriterien

Die App ist fertig, wenn alle zwölf Prüfungen bestehen. Die Ressourcenwerte misst der Agent, die Eingabetests machst du.

| # | Prüfung | Vorgehen | Erwartet |
| --- | --- | --- | --- |
| 1 | Mausrad | In Safari mit dem Mausrad nach unten drehen | Seite bewegt sich klassisch (Inhalt nach oben) |
| 2 | Trackpad | Mit zwei Fingern nach oben wischen | Unverändert „natürlich“ |
| 3 | Horizontal | Shift + Mausrad in einer breiten Tabelle | Richtung ebenfalls umgekehrt |
| 4 | Zahlen | Caps Lock an, `1234567890` tippen | `!"§$%&/()=` |
| 5 | Satzzeichen | Caps Lock an, `ß , . - + # <` tippen | `? ; : _ * ' >` |
| 6 | Buchstaben | Caps Lock an, `abc äöü` tippen | `ABC ÄÖÜ` |
| 7 | Kurzbefehle | Caps Lock an, ⌘+C, ⌘+V, ⌥+L drücken | Kopieren, Einfügen, `@` wie gewohnt |
| 8 | Tottasten | Caps Lock an, ´ dann e tippen | `è` (Akzent funktioniert) |
| 9 | Schalter | Beide Menüpunkte aus- und wieder einschalten | Wirkung sofort weg bzw. sofort da |
| 10 | CPU | `ps -o %cpu= -p $(pgrep -x ScrollShift)` im Leerlauf | 0,0 % |
| 11 | Speicher | `ps -o rss= -p $(pgrep -x ScrollShift)` | unter 40.000 KB |
| 12 | Autostart | Haken setzen, ab- und wieder anmelden | Symbol erscheint von selbst |

Zusatzprüfung für den Agent: In `EventTap.swift` darf im Callback nichts stehen, was auf Datei, Netzwerk oder `UserDefaults` zugreift oder wartet.

## Veröffentlichung auf GitHub

Ja, du kannst den Code öffentlich und kostenlos auf GitHub stellen. Er ist vollständig dein eigener und nutzt nur Apple-Frameworks, die jedes Mac-Programm verwenden darf. Ein Apple-Developer-Account ist dafür nicht nötig. (Hinweis: Das ist keine Rechtsberatung.)

**Was ins Repository gehört**

- Der Quellcode aus dem Abschnitt oben, inklusive `.gitignore`.
- `LICENSE` mit der **MIT-Lizenz**: Andere dürfen die App frei nutzen und verändern, du haftest nicht. GitHub bietet sie beim Anlegen des Repositorys zur Auswahl an.
- `README.md` mit: was die App tut, Screenshot des Menüs, Installationsweg, Hinweis auf die Bedienungshilfen-Berechtigung.
- Bundle-ID passend zu deinem Konto, z. B. `io.github.<benutzername>.scrollshift`.

**Zwei Wege für andere Nutzer**

| Weg | Für wen | Was passiert |
| --- | --- | --- |
| Selbst bauen: `git clone`, dann `./build.sh` | Technisch Interessierte | Keine Warnung von macOS, da die App lokal entsteht |
| Fertige App als ZIP unter „Releases“ | Alle anderen | macOS blockiert den ersten Start. Freigabe über *Systemeinstellungen → Datenschutz & Sicherheit → Trotzdem öffnen* |

Die Warnung beim ZIP-Weg entfällt nur mit Notarisierung durch Apple. Dafür bräuchtest du das Developer-Programm für 99 $ pro Jahr. Für ein kostenloses Hobbyprojekt ist das nicht nötig. Die README sollte den Freigabe-Schritt einfach erklären.

**Vertrauen:** Weil die App Eingaben mitlesen kann, ist offener Quellcode ein Vorteil. Jeder kann prüfen, dass sie nichts speichert und nichts ins Netz sendet. Das sollte die README ausdrücklich sagen.

## Bekannte Einschränkungen und Hinweise für den Agent

**Einschränkungen**

- **Passwortfelder:** Dort schaltet macOS „Secure Input“ ein, und kein Event-Tap bekommt Tastendrücke zu sehen. Caps Lock wirkt dort wie gewohnt nur auf Buchstaben. Das ist eine bewusste Schutzfunktion von macOS.
- **Berechtigung nach Neubau:** Mit Ad-hoc-Signatur erkennt macOS jede neu gebaute Version als andere App. Die Berechtigung muss dann entfernt und neu erteilt werden. Abhilfe: einmal ein eigenes Zertifikat anlegen (*Schlüsselbundverwaltung → Zertifikatsassistent → Zertifikat erstellen*, Name „ScrollShift Dev“, Typ „Codesignatur“) und mit `SIGN_IDENTITY="ScrollShift Dev" ./build.sh` bauen.
- **Mäuse mit Hersteller-Software:** Logitech Options+ und ähnliche Treiber erzeugen teils „weiches“ Scrollen, das wie ein Trackpad aussieht. Dann greift die Umkehr nicht. Lösung: „Smooth Scrolling“ in der Hersteller-Software ausschalten.
- **Andere Tastaturen:** Die Keycode-Liste gilt für die Mac-ISO-Tastatur. Auf ANSI-Tastaturen (US-Bauform) fehlt die Taste `<` (Keycode 50 sitzt dort links neben der 1), was unkritisch ist.
- **Kein App Store:** Apple lässt systemweites Verändern von Eingaben in Store-Apps nicht zu. GitHub ist der richtige Weg.

**Hinweise für den Agent**

- Architektur nicht erweitern: kein Einstellungsfenster, keine Fremdbibliotheken, kein Timer außer dem Berechtigungs-Timer, der sich selbst beendet.
- Der Event-Callback muss sofort zurückkehren. Keine Logs, keine Dateizugriffe, keine Dispatch-Aufrufe darin.
- Die Bedienungshilfen-Berechtigung kann der Agent nicht selbst erteilen. An dieser Stelle anhalten und den Nutzer bitten, sie einzuschalten.
- Bei Compilerfehlern in `translateWithShift` (Carbon-Typen): Typumwandlungen anpassen, die Logik aber beibehalten.
- Nach jeder Änderung `./build.sh` erneut ausführen und Tests 1 bis 11 wiederholen.
