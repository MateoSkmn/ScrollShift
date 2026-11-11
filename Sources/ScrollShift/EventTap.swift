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
