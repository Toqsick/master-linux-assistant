# Release-Prozess

Aktuell: `v0.8.0` ist getaggt und veröffentlicht. Die Planung für
`v0.8.1`–`v0.8.5` liegt in `meilensteine-v0.8.1-v0.8.5.md`,
`issues-v0.8.1-v0.8.5.md` und `release-plaene-v0.8.1-v0.8.5.md` (Repo-Root).

## Versionierung

Die Datei **`version`** im Repo-Root ist die einzige Source of Truth.
`build-deb.sh` liest sie und ersetzt die Werte zur Build-Zeit – der
eingecheckte Wert in `deb/DEBIAN/control` bleibt unangetastet (Commit
`1e90957`). RPM und Arch sind im Fork unmaintained, ihre Vorlagen liegen
unter `packaging/unmaintained/` (inkl. `rpmbuild/SPECS/…` und `PKGBUILD`).

## Release-Schritte

```bash
# 1. Gate prüfen (siehe Milestone §5): CI grün, Verifikation abgehakt, l10n done

# 2. Version bumpen
echo "0.7.2" > version
git add version && git commit -m "release: v0.7.2"

# 3. Taggen & pushen
git tag -a v0.7.2 -m "Admin-Hub: Werkzeuge-Sektion (Browser, Quick Notes, Dateimanager, Systemmonitor)"
git push origin main --tags

# 4. Pakete bauen
bash ./build-deb.sh   # linux-assistant_0.7.2_amd64.deb (+ Alias linux-assistant.deb für den CI-Artefakt-Upload)
# rpm/arch: unmaintained, siehe packaging/unmaintained/
```

## Packaging-Details

- **deb:** `build-deb.sh` staged in `build/deb-root/` (schreibt nichts mehr
  in getrackte Dateien), deklariert GTK + Python-Module + keybinder. Es
  kompiliert außerdem den headless-Probe `la_probe` aus
  `packages/la_core/bin/la_probe.dart` nach
  `/usr/lib/linux-assistant/la_probe` und smoked ihn display-los
  (`--version`); fehlt `dart` im PATH, wird der Schritt übersprungen (kein
  Paketfehler). Install: `sudo apt install ./linux-assistant_*_amd64.deb`.
- **rpm:** unmaintained (`packaging/unmaintained/build-rpm.sh`, Version-Ersetzung per Feldname).
- **arch:** unmaintained (`build-arch-pkg.sh` bricht ab, solange kein `PKGBUILD`
  neben dem Skript liegt; siehe `packaging/unmaintained/`).
- **Flatpak:** eigenständiger Track, separates Repo
  (`Jean28518/flathub`, Package-ID `io.github.jean28518.Linux-Assistant`).
- **Desktop-Entry:** `Icon=linux-assistant` (Icon-Theme-Namen statt
  absoluter Pfade) + `StartupWMClass=linux-assistant`.

## CI

`.github/workflows/build.yml`, gepinnt auf **ubuntu-24.04**: gebaute
Binaries tragen die glibc des Build-Images – ein stiller Wechsel von
`ubuntu-latest` würde Artefakte erzeugen, die auf 24.04-basierten Systemen
(Zorin OS 18, Mint 22, Ubuntu 24.04) nicht starten.

Reihenfolge: `flutter pub get` → `tool/check-versions.sh` → `dart format`-Gate
→ `flutter analyze`-Gate → `flutter test` → Python-Unit-Tests → la_core-Gates
(`dart pub get` → `dart analyze` → `dart format` → `dart test` →
`la_probe`-Headless-Compile in `packages/la_core`) → `build-deb.sh`
→ Artefakt-Upload.

## In-App-Updater

`LinuxAssistantUpdater.isVersionGreaterThanCurrent` toleriert Tags wie
`0.8`, `v0.8.0-rc1` oder Müll (parst nur numerische Präfixe, wirft nie).
Der Updater wählt das Release-Artefakt nach `content_type`
(`application/vnd.debian.binary-package` bzw. `application/x-rpm`), nicht
nach dem Dateinamen.

## Smoke-Test nach Installation (DoD-Ausschnitt)

- App startet in den Hub (Dashboard)
- Hotkey (Super+Q, auf KDE/Pop!_OS/Ubuntu/Zorin OS Alt+Q) öffnet die Suche
- Alle vier Werkzeuge erreichbar und funktional (Checks:
  `docs/design/admin-hub-followups.md` §1)
- Idle: kein Polling-Lärm im Journal (`kDebugMode`-gated Logs)
