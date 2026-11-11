import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings()
    private lazy var eventTap = EventTap(settings: settings)
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?

    private lazy var reverseItem = makeItem("Mausrad umkehren", #selector(toggleReverseScroll))
    private lazy var capsItem = makeItem("Caps Lock für Zahlen & Zeichen", #selector(toggleCapsLock))
    private lazy var capsDelayItem = makeItem("Caps Lock ohne Verzögerung", #selector(toggleCapsLockDelay))
    private lazy var minimizeItem = makeItem("Minimieren ohne Genie-Effekt", #selector(toggleFastMinimize))
    private lazy var loginItem = makeItem("Bei Anmeldung starten", #selector(toggleLaunchAtLogin))
    private lazy var permissionItem = makeItem("Berechtigung fehlt – hier erteilen …", #selector(openAccessibilitySettings))

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "ScrollShift")

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(reverseItem)
        menu.addItem(capsItem)
        menu.addItem(capsDelayItem)
        menu.addItem(minimizeItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(permissionItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "ScrollShift beenden",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item

        // Wird von macOS beim Neustart vergessen: bei jedem Start setzen.
        if settings.capsLockNoDelay { SystemTweaks.setCapsLockDelayDisabled(true) }

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
        capsDelayItem.state = settings.capsLockNoDelay ? .on : .off
        minimizeItem.state = SystemTweaks.isFastMinimizeEnabled ? .on : .off
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

    @objc private func toggleCapsLockDelay() {
        settings.capsLockNoDelay.toggle()
        SystemTweaks.setCapsLockDelayDisabled(settings.capsLockNoDelay)
    }

    /// Startet das Dock neu (kurzes Flackern), damit der Effekt sofort gilt.
    @objc private func toggleFastMinimize() {
        SystemTweaks.setFastMinimize(!SystemTweaks.isFastMinimizeEnabled)
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
