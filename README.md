# ScrollShift

Kleine Menüleisten-App für macOS ab Version 13. Sie behebt ein paar Eigenheiten von Maus und Tastatur, die macOS selbst nicht einstellen lässt. Jede Funktion lässt sich im Menü per Häkchen an- und ausschalten:

- **Mausrad umkehren:** Das Mausrad scrollt klassisch, das Trackpad bleibt „natürlich“. macOS kennt sonst nur eine Richtung für beide.
- **Caps Lock für Zahlen & Zeichen:** Mit Caps Lock werden auch Zahlen und Sonderzeichen zu ihrem Shift-Zeichen (`1` → `!`), wie bei einer Schreibmaschine.
- **Caps Lock ohne Verzögerung:** Caps Lock reagiert sofort, auch auf einen kurzen Tastendruck.
- **Minimieren ohne Genie-Effekt:** Fenster werden schlicht verkleinert statt mit der Genie-Animation.
- **Bei Anmeldung starten:** Die App startet automatisch mit dem Mac.

Die App hat kein Fenster und kein Dock-Symbol. Im Leerlauf braucht sie keine CPU. Sie speichert nur ihre Schalter und sendet nichts ins Netz.

## Starten

Voraussetzung sind die Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/MateoSkmn/ScrollShift.git
cd ScrollShift
./build.sh
cp -R build/ScrollShift.app /Applications/
open /Applications/ScrollShift.app
```

Danach erscheint ein Maus-Symbol in der Menüleiste.

**Berechtigung erteilen:** Beim ersten Start fragt macOS nach der Berechtigung für *Bedienungshilfen*. Unter *Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen* ScrollShift einschalten. Ohne sie funktionieren Mausrad- und Caps-Lock-Funktion nicht. Fehlt sie, zeigt das Menü einen Punkt, der direkt dorthin führt.

> Die App ist nur ad-hoc signiert. Nach jedem Neubau den alten Eintrag unter *Bedienungshilfen* entfernen und die Berechtigung neu erteilen.

## Lizenz

[MIT](LICENSE). Änderungen pro Version stehen in [RELEASE.md](RELEASE.md).
