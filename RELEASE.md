# ScrollShift – Releases

Alle Änderungen pro Version, neueste oben. Versionsnummern folgen [Semantic Versioning](https://semver.org/lang/de/): `MAJOR.MINOR.PATCH`.

## Ablauf für ein neues Release

1. Neuen Abschnitt unten nach der Vorlage anlegen (neueste Version oben).
2. Version in `Resources/Info.plist` anheben: `CFBundleShortVersionString` (z. B. `1.1.0`) und `CFBundleVersion` (fortlaufende Build-Nummer, +1).
3. App bauen und testen: `./build.sh`, danach die Bedienungshilfen-Berechtigung neu erteilen, falls ad-hoc signiert.
4. Committen, Tag setzen (`v1.1.0`) und pushen.
5. Optional: `build/ScrollShift.app` als ZIP packen und auf GitHub unter *Releases* zum Tag hochladen.

### Vorlage

```markdown
## [X.Y.Z] – JJJJ-MM-TT

**Build:** N · **macOS:** ab 13.0 · **Tag:** vX.Y.Z

### Neu
### Geändert
### Behoben
### Entfernt
### Bekannte Einschränkungen
### Hinweise zum Update
```

---

## [1.0.0] – 2026-11-11

**Build:** 1 · **macOS:** ab 13.0 · **Tag:** v1.0.0 · **Bundle-ID:** `io.github.mateoskmn.scrollshift-menubar`

Erste Version. Menüleisten-App ohne Fenster und ohne Dock-Symbol, alle Funktionen per Häkchen im Menü schaltbar.

### Neu

- **Mausrad umkehren:** Klassische Mausräder scrollen umgekehrt, Trackpad und Magic Mouse bleiben „natürlich“. Unterscheidung über `scrollWheelEventIsContinuous`.
- **Caps Lock für Zahlen & Zeichen:** Bei aktivem Caps Lock liefern auch Zahlen- und Sonderzeichentasten ihr Shift-Zeichen, passend zum aktiven Tastaturlayout. Tottasten funktionieren weiter, Kurzbefehle mit ⌘, Ctrl oder ⌥ bleiben unverändert.
- **Caps Lock ohne Verzögerung:** Setzt die Caps-Lock-Verzögerung auf 0 ms (Apple-Standard: 75 ms). Wird bei jedem App-Start neu gesetzt, da macOS den Wert beim Neustart vergisst.
- **Minimieren ohne Genie-Effekt:** Schaltet den Dock-Effekt auf „Verkleinern“ um. Das Dock startet dabei kurz neu.
- **Bei Anmeldung starten:** Autostart über `SMAppService`.
- **Berechtigungshinweis:** Fehlt die Bedienungshilfen-Berechtigung, erscheint ein Menüpunkt, der direkt die passende Systemeinstellung öffnet.
- Standardmäßig sind alle Funktionen eingeschaltet. Sind Mausrad- und Caps-Lock-Funktion aus, läuft kein Event-Tap.

### Bekannte Einschränkungen

- Ad-hoc-signiert: Nach jedem Neubau muss die Bedienungshilfen-Berechtigung entfernt und neu erteilt werden. Abhilfe mit eigenem Zertifikat: `SIGN_IDENTITY="ScrollShift Dev" ./build.sh`.
- Nicht notarisiert: Beim ersten Start einer heruntergeladenen App ist „Trotzdem öffnen“ in den Systemeinstellungen nötig.
- Noch ungeprüft, ob die 0-ms-Verzögerung auch für eine später angeschlossene externe Tastatur gilt.
