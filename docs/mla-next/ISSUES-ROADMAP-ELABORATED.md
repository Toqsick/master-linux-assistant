# Roadmap V0.8.6–V1.0 — ausgearbeitete Issue-Bodies (#58–#87)

> Spiegel der GitHub-Bodies nach der Ausarbeitung vom 2026-09-30. Der Originaltext jedes Issues bleibt enthalten; ergänzt sind Ziel, Andockpunkte, Teststrategie, Risiko, Abhängigkeiten und Gates. Der Ursprung `issues-v0.8.6-v1.0.md` im Repo-Wurzelverzeichnis bleibt unverändert (die dortigen Bodies sind kürzer als der Stand auf GitHub).

---

## #58 — [V0.8.6] Welle 1 „Sofort-Nutzen": Q1–Q7

```markdown
## Ziel
Sieben kleine, einzeln abnehmbare Verbesserungen ohne neue Architektur — der schnellste sichtbare Nutzen vor dem Fundament (V0.9).

## Scope
Welle 1 als ein gemeinsamer Plan (7 Tasks, je S). Keine neue Architektur — alles dockt an Bestandescode an. Q7 entscheidet Basti vorab (Empfehlung: entfernen).

## Abnahme
- [ ] **Q1 Security-Scan auf Knopfdruck:** `_checkerOutput` (`security_check/overview.dart:54`) startet nicht mehr beim ersten Build, sondern über „Prüfen"; kein pkexec-Dialog beim Betreten der Sektion; letztes Ergebnis (Befund-Tokens + Zeitstempel) in `$XDG_CACHE_HOME/linux-assistant/security-last.json`, nach App-Neustart mit „vor X"
- [ ] **Q2 Neustart-Badge:** `/var/run/reboot-required(.pkgs)` → Badge im Dashboard + Zeile in der Health-Sektion mit auslösenden Paketen; nach dem Neustart weg
- [ ] **Q3 Kachel „Fehlgeschlagene Dienste":** `systemctl [--user] list-units --failed -o json`, beide Scopes → Kachel mit Zahl und Liste (Unit, Beschreibung, Scope); zeigt auf dem Referenzsystem aktuell zwei fehlschlagende Backup-Units
- [ ] **Q4 Hotkey über gsettings in beiden Sessions:** `hotkey_manager` + `libkeybinder-3.0-0` raus (pubspec, `deb/DEBIAN/control`, README, CI-apt-Zeile); X11-Keybinding über `additional/python/setup_keybinding.py` + `keybinding_files.py`; Diagnosezeile: aktuelles Binding + verwaiste `custom*`-Einträge; Gate „Hotkey holt das Fenster, Fokus im Suchfeld" in Wayland UND X11
- [ ] **Q5 Browser-Status:** read-only „Standard ist X" aus `AppLauncher.defaultBrowserDesktopId()` (aus V0.8.2); Warnung, wenn `gio mime x-scheme-handler/https` abweicht; neue Zeile in `features.csv`
- [ ] **Q6 Speicher-Kachel ehrlich:** Warnton nach PSI (`/proc/pressure/memory`, avg60) statt nur RAM-Quote; Swap-Zeile trennt zram (`/sys/block/zram*/mm_stat`) von Disk-Swap; bei heutiger Last kein Alarm, zram zeigt „7,2 → 2,1 GB"
- [ ] **Q7 Feedback an Upstream abklemmen:** Empfehlung entfernen (Menüeintrag, `feedback_service.dart`, `lib/layouts/feedback/*`, l10n-Keys) — Alternative: Link auf die Fork-Issues
- [ ] Fünf CI-Gates grün; l10n-Ratchet (alle vier ARB); features.csv-Check (21 Felder) bei neuen Zeilen

## Andockpunkte (geprüft 2026-09-30)
- Q4: `hotkey_manager` in `pubspec.yaml:53`, `libkeybinder-3.0-0` in `deb/DEBIAN/control:2` und `README.md`, CI-Zeile `.github/workflows/build.yml:66` (der Ausbauplan nannte `:46`, die Zeile ist verschoben); Python-Seite `additional/python/setup_keybinding.py`, `additional/python/keybinding_files.py`
- Q5: `AppLauncher.defaultBrowserDesktopId()` existiert im Code noch **nicht** (Stand 2026-09-30, entsteht in V0.8.2 #34); `kKnownBrowsers` steht in `lib/services/app_launcher.dart:20`
- Q1: `lib/layouts/security_check/overview.dart:54` (`_checkerOutput = _runChecker()`, startet beim ersten Build); Q7: `lib/services/feedback_service.dart`, `lib/layouts/feedback/*`
- Q6: `lib/services/system_stats_service.dart` (`parseFreeOutput`, ab :32), `_memoryTile` in `lib/layouts/hub/dashboard_section.dart:226`

## Risiko & Fallback
Q4 ist eher M als S (zwei Sitzungstypen, Diagnosezeile, Paket-Abhängigkeit entfällt). Q7 entscheidet Basti vorab (Empfehlung: entfernen); ohne Entscheidung bleibt Q7 offen und blockiert die übrigen Punkte nicht.

## Abhängigkeiten
Blockiert durch: #41 (V0.8.5 abgeschlossen (Release-Gates, E2E)), #34 (nur Q5: XDG-Stufe und `defaultBrowserDesktopId()` aus V0.8.2)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Abhängigkeit: V0.8.5 abgeschlossen; Q5 braucht V0.8.2._
_Quelle: Ausbauplan V0.8.6–V1.0, Welle 1 (Q1–Q7)._
```

---

## #59 — [V0.9] FU2 Reiner Dart-Kern packages/la_core

```markdown
## Ziel
Probes, Parser und Doctor laufen ohne GUI; die Reinheit erzwingt der Build. Voraussetzung für den Wächter (#66) und den Doctor (#78).

## Scope
Logik, die ohne GUI laufen muss (Probes, Parser, Doctor), liegt in einem Paket **ohne Flutter-Abhängigkeit** — die Reinheit erzwingt der Build, nicht eine Konvention. Voraussetzung für LB3 (Wächter) und ST3 (Doctor).

**Spike (eine Session, zuerst):**
- `dart compile exe packages/la_core/bin/la_probe.dart` mit dem Dart aus dem Flutter-SDK, lokal und in CI
- Messen: Binärgröße, Startzeit, Lauf ohne `DISPLAY`/`WAYLAND_DISPLAY`

**Danach (Spec + Plan):**
- `CommandHelper` umziehen (heute `lib/helpers/command_helper.dart`, nur `dart:io`)
- Logger-Shim ohne `flutter/foundation` (heute hängt `lib/services/logger.dart:1` daran)
- Probe-Vertrag: `Probe`, `ProbeResult{level: ok|warn|crit|unknown, key, params, at}`
- Parser für free, df, uptime und ps aus `system_stats_service.dart:32`, `linux_filesystem.dart`, `linux_system.dart:36ff`, `linux_process.dart:19ff`
- App bindet das Paket als path-Dependency ein; `test` als dev_dependency (begründete Ausnahme vom pub-Budget)

Nicht: `linux.dart` komplett zerlegen — umgezogen wird nur, was Probes brauchen (M5 geht schrittweise weiter).

## Abnahme
- [ ] `flutter test` und `dart test` in `packages/la_core` grün
- [x] `la_probe --version` läuft auf Zorin ohne Session-Variablen
- [ ] `build-deb.sh` legt das Binary nach `/usr/lib/linux-assistant/`
- [ ] Risiko geprüft (Verflechtung größer als gedacht): Fallback = Probes vorerst im App-Prozess, Wächter später

## Stand 2026-09-30 (Branch `feature/mla-gtk-scaffold`, Draft-PR #89)
Spike und Probe-Vertrag sind im Branch umgesetzt und belegt (`docs/mla-next/BASELINE.md` §7, `docs/mla-next/VERIFY.md` Gate 1):
- `dart test` in `packages/la_core`: 14/14 grün (Probe + Registry)
- `dart compile exe bin/la_probe.dart`; Lauf mit `env -u DISPLAY -u WAYLAND_DISPLAY`: `la_probe --version` Exit 0
- Messwerte (Zorin OS 18.1, Dart 3.13.4): Binärgröße 6 547 240 Bytes, Median-Startzeit 3 ms (5 Läufe)
- Root-Gates unverändert grün: `flutter test` +184, `flutter analyze` 0 Findings, Python-Tests 49 OK
- CI-Schritte für `la_core` sind im Branch eingerichtet

**Offen:** `build-deb.sh` legt das Binary ab · Parser-Umzug · Logger-Shim/`CommandHelper`-Umzug · App-Einbindung als path-Dependency · Risiko-Fallback prüfen.
Erste Abnahmezeile: `dart test` ist erfüllt; `flutter test` im reinen Dart-Paket ist nicht sinnvoll (bewusst ohne Flutter-Abhängigkeit) → Formulierung im Spec klären, das Kästchen bleibt daher offen.

## Andockpunkte (geprüft 2026-09-30)
- `lib/helpers/command_helper.dart` (nur `dart:io`) und `lib/services/logger.dart:1` (importiert `flutter/foundation`, braucht einen Shim)
- Parser: `parseFreeOutput` in `lib/services/system_stats_service.dart:32`, `lib/linux/linux_filesystem.dart`, `parseUptime` in `lib/linux/linux_system.dart`, ps-Parser in `lib/linux/linux_process.dart`
- Im Branch `feature/mla-gtk-scaffold` bereits vorhanden: `packages/la_core/bin/la_probe.dart`, `lib/src/probe.dart`, `lib/src/module_descriptor.dart`, `lib/src/module_registry.dart`

## Teststrategie
- `dart test` in `packages/la_core` (Stand 2026-09-30: 14/14); Root-`flutter test` bleibt grün (+184)
- Fixtures aus echten, geschwärzten Zorin-Ausgaben; die bestehenden Parser-Tests (`test/system_parsers_test.dart`) laufen unverändert gegen die umgezogenen Parser
- `dart compile exe` und Lauf ohne `DISPLAY`/`WAYLAND_DISPLAY` in CI

## Risiko & Fallback
Die Verflechtung von `linux.dart` mit der UI ist größer als gedacht → Spike zuerst, nur Probe-relevantes umziehen; Fallback: Probes vorerst im App-Prozess, Wächter später. Paketierung des CLI (`dart compile exe` im deb-Build: CI-Zeit, Binärgröße) — Spike-Messung: 6 547 240 Bytes, Median-Start 3 ms (`docs/mla-next/BASELINE.md` §7).

## Abhängigkeiten
Blockiert durch: #41 (V0.8.5 abgeschlossen)
Blockiert: #60, #66, #78

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Tier: Core · Größe: L · Spec + Plan · zuerst im Epic._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic FU (Teilplan FU2)._
_MLA-Next-Bezug: MLA-Next A3 #93 (Rest des Dart-Kerns)._
```

---

## #60 — [V0.9] FU1 Modul-Registry (#27)

```markdown
## Ziel
Ein neues Modul ist ein Listeneintrag plus Screen: Sektionen, Werkzeuge, Probes, Suchanbieter und Aktionen hängen an einer Registry statt an switch-Blöcken.

## Scope
Weiterführung von #27, erweitert um Probes, Suchanbieter und Aktionen — ohne Panel/Dock (Grill-Entscheidung).

- `HubModule`-Deskriptor: id, Titel-Key, Icon, Tier, Art (section|tool|launch), `screenBuilder`, `probes`, `searchProviders`, `actions`, `isAvailable(Environment)`
- Die 5 `HubSection`s und 4 `HubTool`s (`hub_shell.dart:21,30`, sechs switch-Blöcke) wandern in eine Liste

## Abnahme
- [ ] Verhalten unverändert (Widget-Tests der Navigation)
- [ ] Ein neues Modul ist ein Listeneintrag plus Screen
- [ ] Test auf Vollständigkeit der Registry
- [ ] Flutter-Adapter: `HubModule` (Icon, Tier, `screenBuilder`, `isAvailable(Environment)`) ergänzt den reinen `la_core`-Deskriptor um UI-Typen; `la_core` bleibt frei von Flutter

## Stand 2026-09-30 (Branch `feature/mla-gtk-scaffold`, Draft-PR #89)
Der Registry-**Kern** liegt im Paket `packages/la_core` (belegt in `docs/mla-next/VERIFY.md` Gate 1): Deskriptor (id, titleKey, viewId, kind, capabilities, requires, probeIds, actionIds, subscribedTopics), ID-Eindeutigkeit, Abweisung fehlender/zyklischer Abhängigkeiten, topologischer Start, Rückwärts-Stopp, Single-Flight-Aktivierung — `dart test` 14/14. Die Flutter-Navigation ist unverändert (`git diff --stat 92bef60..HEAD -- lib/ additional/ deb/ linux/` leer).

**Abgrenzung:** Der Deskriptor in `la_core` ist bewusst **rein** (keine Flutter-/GTK-Typen; View-Factories gehören in die UI-Adapter). Der unten beschriebene `HubModule` mit Icon, Tier, `screenBuilder` und `isAvailable(Environment)` ist der **Flutter-Adapter** darüber und noch nicht umgesetzt — die Kästchen unten bleiben deshalb offen.

## Andockpunkte (geprüft 2026-09-30)
- `lib/layouts/hub/hub_shell.dart:21` (`enum HubSection`) und `:30` (`enum HubTool`) sowie die zugehörigen switch-Blöcke ebenda (Plan: sechs; per `grep -n "switch" lib/layouts/hub/hub_shell.dart` neu zählen)
- Im Branch: `packages/la_core/lib/src/module_descriptor.dart`, `module_registry.dart`; Tests `module_registry_validate_test.dart`, `module_registry_lifecycle_test.dart`

## Teststrategie
- Registry im Paket: eindeutige IDs, fehlende/zyklische Abhängigkeiten, Start/Stop, Single-Flight (bereits 14 Tests)
- Widget-Tests der Navigation belegen, dass das Verhalten unverändert bleibt
- Vollständigkeitstest: jede `HubSection`/`HubTool` hat genau einen Registry-Eintrag

## Risiko & Fallback
`hub_shell.dart` wird auch von DS1 (#65) angefasst → FU1 zuerst, sonst Merge-Konflikte.

## Abhängigkeiten
Blockiert durch: #59 (Spike + Probe-Vertrag)
Blockiert: #62, #63, #65, #67, #68, #69, #73, #76, #77, #78, #80, #84, #85

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Abhängigkeit: nach FU2-Spike + Probe-Vertrag._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic FU (Teilplan FU1)._
_MLA-Next-Bezug: MLA-Next A3 #93._
```

---

## #61 — [V0.9] FU3 Fehlerrahmen

```markdown
## Ziel
Fehler zeigen sich als lesbarer Fehlerbildschirm oder als Banner, nicht mehr als leeres Fenster.

## Scope
- `FlutterError.onError` und `PlatformDispatcher.instance.onError` → Logger + nicht blockierendes Banner
- Fehler vor `runApp` (`main.dart:31-72`) zeigen einen Fehlerbildschirm mit Ursache und Doctor-Hinweis statt eines leeren Fensters (Beispiel-Gotcha: fehlendes `additional/` → `RangeError` in `Linux.getCurrentEnvironment`)

## Abnahme
- [ ] Ein Bundle ohne `additional/` startet in den Fehlerbildschirm
- [ ] `FlutterError.onError` und `PlatformDispatcher.instance.onError` landen im Logger und zeigen ein nicht blockierendes Banner
- [ ] Der Fehlerbildschirm nennt Ursache und Doctor-Hinweis (ST3 #78)

## Andockpunkte (geprüft 2026-09-30)
- `lib/main.dart:31-72` (Start bis `runApp`; `SingleInstance.claim` steht bei :31)
- `Linux.getCurrentEnvironment` (`lib/services/linux.dart`) — wirft `RangeError`, wenn `additional/` fehlt (Gotcha aus dem Handoff)
- `lib/services/logger.dart` (geloggt wird nie über `print`)

## Teststrategie
- Widget-Test des Fehlerbildschirms
- Fehlerinjektion: `getCurrentEnvironment` wirft → Fehlerbildschirm mit Ursache statt leerem Fenster

## Abhängigkeiten
Blockiert durch: —
Reihenfolge (weich): #78 (Doctor-Hinweis im Fehlerbildschirm verlinkt lose)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Tier: Core · Größe: S · Kurzdesign._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic FU (Teilplan FU3)._
```

---

## #62 — [V0.9] LB1 Lagebild-Leiste

```markdown
## Ziel
Ein Blick zeigt, ob etwas Aufmerksamkeit braucht: fünf Ampeln, jede mit einer Ein-Satz-Erklärung.

## Scope
Fünf Ampeln oben im Dashboard (`dashboard_section.dart`): Backups · Updates & Neustart · Speicher · Dienste · Sicherheit.

- Jede Ampel ist eine Registry-Probe; Klick führt ins Detail
- Startzustand sofort aus `status.json` (falls LB3 aktiv), danach live
- Widgets: `HermesHaloDot`, `HermesBadge`, `HermesStatTile` (kein `MintY.currentColor`/`MintY.dark`)

## Abnahme
- [ ] Heute stehen Backups auf ROT und Updates auf GELB (Neustart), Speicher je nach Schwelle
- [ ] Jede Ampel erklärt sich in einem Satz
- [ ] Klick auf eine Ampel führt in den passenden Detail-Screen
- [ ] Unbekannt oder veraltet wird als `unknown` angezeigt, nie als grün

## Andockpunkte (geprüft 2026-09-30)
- `lib/layouts/hub/dashboard_section.dart` (`_memoryTile` :226 als Vorbild für Kacheln)
- Widgets: `lib/widgets/hermes/hermes_halo_dot.dart`, `hermes_badge.dart`, `hermes_stat_tile.dart`; Tokens `lib/layouts/hermes_tokens.dart`

## Teststrategie
- Probe-Fakes (`ProbeResult` ok|warn|crit|unknown) → Widget-Test je Ampel
- Fixture für Backups ROT und Updates GELB (Neustart)

## Abhängigkeiten
Blockiert durch: #60 (Registry-Probes)
Blockiert: #66

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Abhängigkeit: FU1 (Registry-Probes)._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic LB (Teilplan LB1)._
_MLA-Next-Bezug: MLA-Next Lagebild #102._
```

---

## #63 — [V0.9] LB2 Backup-Cockpit

```markdown
## Ziel
Ein stiller Backup-Ausfall wird sichtbar (heute: rot, ohne dass es jemand merkt).

## Scope
Backup-Status aus Units und Journal (nie aus Repos oder Tokens), in beiden Scopes, Units per Muster (Default `*restic*`, `*backup*`, `*borg*`; konfigurierbar):

- letzter Lauf und Ergebnis (`systemctl show`)
- nächster Termin (`list-timers -o json`)
- letzter Erfolg aus dem Journal („Deactivated successfully" vs. „Failed with result")
- Heartbeat-Units werden als Totmannschalter gedeutet
- „Jetzt sichern" = `systemctl --user start <unit>`, ohne polkit

Could: Timeshift-Plan aus `/etc/timeshift/timeshift.json`; Snapshot-Liste nur über den privilegierten Report.

## Abnahme
- [ ] Heute ROT mit Unit-Beschreibung und letzter Journal-Zeile
- [ ] Nach erfolgreichem Lauf GRÜN
- [ ] Unit-Muster konfigurierbar (Default `*restic*`, `*backup*`, `*borg*`), beide Scopes; keine Unit-Namen oder Pfade fest im Code (öffentliches Repo)
- [ ] Kein Zugriff auf Repos, Passwörter oder Tokens; `restic snapshots` wird nie aufgerufen

## MLA-Next / Gate 2
Der GTK/Dart-Host-Track setzt dieselben Vorgaben um (`docs/mla-next/VERIFY.md`, Gate 2); Fixtures werden geteilt. Zusätzlich gilt dort:
- [ ] `systemctl --user start` nur nach Bestätigung und serverseitiger Allowlist; Abbruch, Race und Doppel-Request getestet
- [ ] Ein erfolgreicher Unit-Start macht das Backup nicht grün; ein erfolgreicher Unit-Exit ist kein Restore-Nachweis
- [ ] Der rsync-Ordnerkopier-Prototyp ist nicht Teil dieses Issues

## Andockpunkte (geprüft 2026-09-30)
- CLI-Quellen: `systemctl [--user] show`, `systemctl [--user] list-timers -o json`, Journal (`journalctl`); Could: `/etc/timeshift/timeshift.json`
- Injizierbare Runner nach dem `debugOverride`-Muster (`lib/services/app_launcher.dart`, `lib/services/action_handler.dart`)

## Teststrategie
- Fixtures: `systemctl show`-Ausgaben (ok und failed), `list-timers -o json`, Journal-Zeilen „Deactivated successfully“ vs. „Failed with result“ — geschwärzt
- Heartbeat-Unit (Totmannschalter) mit Fixture: ausbleibender Lauf → rot

## Abhängigkeiten
Blockiert durch: #60 (Registry)
Blockiert: #66

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Nicht: restic-Repo, Passwörter, `restic snapshots`._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic LB (Teilplan LB2)._
_MLA-Next-Bezug: MLA-Next A6 #101 (Dart-Host-Seite, gemeinsame Fixtures)._
```

---

## #64 — [V0.9] QA1 Gate-Automatisierung, Spike

```markdown
## Ziel
Klären, ob Wayland-Hotkey und Clipboard in CI automatisierbar sind (go/no-go), statt sie weiter nur manuell zu prüfen.

## Scope
Spike (beschlossen): Headless `gnome-shell --wayland --virtual-monitor` auf dem `ubuntu-24.04`-Runner.

- Nur Wayland-Hotkey (Test-Hook) und Clipboard
- Ergebnis: go/no-go; kein Self-hosted-Runner

## Abnahme
- [ ] Ergebnis dokumentiert (go/no-go mit Begründung und Messwerten)
- [ ] Ergebnis nennt Messwerte (Laufzeit, Flakiness) und einen klaren Schnitt: go oder no-go
- [ ] Bei no-go bleiben die manuellen Gates; die Begründung steht in `docs/wiki/Release-Process.md`

## Andockpunkte (geprüft 2026-09-30)
- `.github/workflows/build.yml` (Runner `ubuntu-24.04`)
- `docs/wiki/Release-Process.md` (Gate-Tabelle Wayland/X11)

## Teststrategie
- Spike-Messwerte: Laufzeit im Runner, Wiederholbarkeit über mehrere Läufe, Fehlerbild

## Risiko & Fallback
Headless-`gnome-shell` auf dem Runner kann instabil oder zu langsam sein — dann no-go; ein Self-hosted-Runner kommt nicht in Frage.

## Abhängigkeiten
Blockiert durch: —
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Unabhängig — so früh wie möglich in V0.9._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic QA (Teilplan QA1)._
```

---

## #65 — [V0.9] DS1 Token-Einheit (#29/#10)

```markdown
## Ziel
Ein Token-System statt harter Farben: kein direkter MintY-Farbzugriff außerhalb der Token-Definition.

## Scope
- MintY-Statik in 32 Dateien → ThemeExtension (`HermesTokens`, `MintYColors`)
- Harte Farben ersetzen; Geometrie- und Typo-Skala einführen
- Deckt die UI-Befunde I2, I4, M2, M4

## Abnahme
- [ ] Keine direkten MintY-Farbzugriffe mehr außerhalb der Token-Definition
- [ ] `flutter analyze` 0 Findings; Widget-Tests grün; Goldens aktualisiert (Vorbereitung für DS3)
- [ ] Geometrie- und Typografie-Skala eingeführt; harte Farbwerte ersetzt
- [ ] UI-Befunde I2, I4, M2, M4 adressiert

## Andockpunkte (geprüft 2026-09-30)
- Die Extensions existieren bereits: `lib/layouts/hermes_tokens.dart` (`HermesTokens`), `lib/layouts/mint_y_tokens.dart` (`MintYColors`); Test `test/hermes_tokens_test.dart`
- Migrationsfläche: aktuell 37 Dateien mit `MintY.`-Zugriff (`grep -rl 'MintY\.' lib`, Stand 2026-09-30); der Plan nannte 32 — Zahl im Spec neu messen

## Teststrategie
- `flutter analyze` 0 Findings; Widget-Tests grün; Goldens aktualisiert (Vorbereitung für DS3)
- Prüfskript oder Test, der direkte MintY-Zugriffe außerhalb der Token-Datei findet

## Risiko & Fallback
`hub_shell.dart` wird auch von FU1 (#60) angefasst → FU1 zuerst.

## Abhängigkeiten
Blockiert durch: #60 (beide fassen `hub_shell.dart` an)
Blockiert: #79

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Abhängigkeit: erst nach FU1 — beide fassen `hub_shell.dart` an._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic DS (Teilplan DS1)._
_MLA-Next-Bezug: GTK-Track: Tokens in A1 #91 (Namensangleichung offen)._
```

---

## #66 — [V0.10] LB3 Wächter

```markdown
## Ziel
Meldungen ohne Dauerprozess: ein Timer prüft, schreibt `status.json` und meldet nur den Übergang nach Rot.

## Scope
Hintergrund-Meldungen ohne Dauerprozess, Tray oder Handy-Push:

- `la_probe` (aus FU2) + `linux-assistant-watch.service/.timer` als User-Units im .deb (`/usr/lib/systemd/user/`); `build-deb.sh` und Pfad in `install.sh` prüfen; `Recommends: libnotify-bin`
- Aktivierung per Schalter in den Einstellungen (`systemctl --user enable --now`, kein root)
- Takt: alle 30 min und 5 min nach Login
- Schreibt `$XDG_STATE_HOME/linux-assistant/status.json` atomar und versioniert (`schema`)
- Meldet per `notify-send -A open=Öffnen` nur beim Übergang nach Rot (Erinnerung optional)
- „Öffnen" → Ziel-Sektion: Single-Instance-Protokoll (`single_instance.dart:87`) um `raise:<section>` erweitern; wartende Benachrichtigung darf den Timer-Lauf nicht blockieren (z. B. `systemd-run --user`) — klärt der Spec

## Abnahme
- [ ] Eine Ampel wird rot → genau eine Benachrichtigung
- [ ] Zweiter Lauf ohne Änderung → keine
- [ ] Die App zeigt denselben Stand wie `status.json`
- [ ] Aktivierung nur über den Schalter in den Einstellungen (`systemctl --user enable --now`), kein root; Takt 30 min plus 5 min nach Login
- [ ] „Öffnen“ bringt die App in die Ziel-Sektion und blockiert den Timer-Lauf nicht

## Andockpunkte (geprüft 2026-09-30)
- `lib/services/single_instance.dart:87` (`socket.write("raise")`) → Protokoll um `raise:<section>` erweitern
- `build-deb.sh` und `install.sh` (Pfad `/usr/lib/systemd/user/` prüfen), `deb/DEBIAN/control` (`Recommends: libnotify-bin`)
- Probe-CLI: `packages/la_core/bin/la_probe.dart` (Spike im Branch)

## Teststrategie
- Zustandsübergänge ok→warn→crit→ok mit Fixtures: genau eine Benachrichtigung je Übergang nach Rot, keine bei unverändertem Zustand (Entprellung)
- `status.json`: atomar geschrieben (temporäre Datei + Rename), `schema`-Feld versioniert
- Unit-Dateien mit `systemd-analyze --user verify` geprüft

## Risiko & Fallback
Benachrichtigungs-Müdigkeit → nur Übergänge nach Rot, Entprellung, Erinnerung optional. Die wartende Benachrichtigung darf den Lauf nicht blockieren (z. B. `systemd-run --user`) — klärt der Spec. Paketierung des CLI: siehe FU2 (#59).

## Abhängigkeiten
Blockiert durch: #59 (`la_probe`-CLI), #62 (Ampel-Probes), #63 (Backup-Probe)
Blockiert: #83

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Abhängigkeit: FU2 (la_probe-CLI)._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic LB (Teilplan LB3)._
```

---

## #67 — [V0.10] DI1 Dienste & Timer

```markdown
## Ziel
Ein Screen für Dienste und Timer beider Scopes: Fehlgeschlagenes fällt auf, `--user`-Units lassen sich steuern.

## Scope
- Watchlist (config), alle fehlgeschlagenen Units und alle Timer (`-o json`), in beiden Scopes
- Start, Stop, Restart nur für `--user`-Units; System-Units read-only (Restart über die Queue = Could)
- Journal-Tail je Unit
- n2h: Mini-Probe für Netzwerk/VPN (aktive Interfaces wie `tailscale0`/`proton0` über `ip -j link`)
- Kein D-Bus nötig (#26 zurückgestuft)

## Abnahme
- [ ] Watchlist + fehlgeschlagene Units + Timer beider Scopes in einem Screen
- [ ] Start/Stop/Restart nur für User-Units möglich
- [ ] Journal-Tail je Unit
- [ ] Watchlist konfigurierbar; keine Unit-Namen fest im Code (öffentliches Repo)

## Andockpunkte (geprüft 2026-09-30)
- CLI statt D-Bus (#26 zurückgestuft): `systemctl [--user] list-units --failed -o json`, `list-timers -o json`, `journalctl -u … -n`; VPN-Mini-Probe über `ip -j link`
- Watchlist in `config.json` über `lib/services/config_handler.dart`
- Überschneidung mit Q3 (#58, Kachel „Fehlgeschlagene Dienste“): gleiche Datenquelle, nicht doppelt implementieren

## Teststrategie
- Fixtures der JSON-Ausgaben (beide Scopes); Runner injizierbar
- Scope-Prüfung im Code (nicht nur im UI): Start/Stop/Restart für System-Units wird abgewiesen

## Abhängigkeiten
Blockiert durch: #60 (Registry)
Blockiert: #74

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Abhängigkeit: FU1 (Registry)._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic DI (Teilplan DI1)._
_MLA-Next-Bezug: GTK-Track: Lagebild + Dienste #102._
```

---

## #68 — [V0.10] DI2 Docker & Compose

```markdown
## Ziel
Docker-Projekte im Überblick, mit ehrlichen Expositions-Flags („umgeht UFW“).

## Scope
- Daten aus `docker ps -a --format '{{json .}}'` und `docker inspect` (NetworkMode, PortBindings, Health); gruppiert nach `com.docker.compose.project`
- Start, Stop, Restart, Logs-Tail über die Docker-CLI (keine neue Rechte-Naht, Nutzer ist in `docker`); Hinweis im UI: `docker`-Gruppe ≈ root
- Expositions-Flags: veröffentlicht auf allen Interfaces oder im LAN („umgeht UFW"), Host-Netz
- Ohne Docker: Hinweis statt Fehler

## Abnahme
- [ ] Compose-Projekte gruppiert mit Health- und Expositions-Flags
- [ ] Degradierung ohne Docker getestet
- [ ] Start, Stop, Restart und Logs-Tail über die Docker-CLI; UI-Hinweis „`docker`-Gruppe ≈ root“

## Andockpunkte (geprüft 2026-09-30)
- CLI: `docker ps -a --format '{{json .}}'`, `docker inspect` (NetworkMode, PortBindings, Health); Gruppierung nach Label `com.docker.compose.project`

## Teststrategie
- Fixtures: Compose-Projekt, Host-Netz, Bindung auf allen Interfaces, Health-Zustände
- Test ohne Docker (Binary fehlt) → Hinweis statt Fehler

## Abhängigkeiten
Blockiert durch: #60 (Registry)
Blockiert: #74, #80

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Quelle: Ausbauplan V0.8.6–V1.0, Epic DI (Teilplan DI2)._
```

---

## #69 — [V0.10] DI3 Agenten-Tile

```markdown
## Ziel
Ein Tile zeigt, ob der Agenten-Betrieb Aufmerksamkeit braucht — ohne ein Fremd-Backend zum Core zu machen.

## Scope
Wie in der Roadmap beschlossen (Grill Q13–Q15, Q22, Q35):

- kritischstes TokenTelemetry-Budget (`/budgets`)
- Blocker-Zahl aus `hermes kanban boards list --json`
- Gateway-Status und Start-Knöpfe
- offline → Hinweis und „Dienst starten" (`systemctl --user`)

Fremdes Backend: read-only-Status + Starten, nie Core. Das Hermes-Verzeichnis wird nur über CLI und systemctl gelesen.

## Abnahme
- [ ] Tile zeigt Budget, Blocker, Gateway-Status; Start-Knöpfe funktionieren im User-Scope
- [ ] Das Hermes-Verzeichnis wird nur über CLI und `systemctl` gelesen, nie beschrieben; keine Secrets im Log
- [ ] Endpunkte und Dienstnamen kommen aus `config.json` oder Defaults, nicht fest im Code (öffentliches Repo)

## Andockpunkte (geprüft 2026-09-30)
- TokenTelemetry `/budgets` (read-only), `hermes kanban boards list --json`, Gateway-Status über `systemctl --user`
- Cockpit-Regel: fremde Backends bekommen nur Read-only-Status und Starten

## Teststrategie
- Fixtures: JSON von `boards list` und Budget-Antwort (geschwärzt); Offline-Fall

## Abhängigkeiten
Blockiert durch: #60 (Registry)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Quelle: Ausbauplan V0.8.6–V1.0, Epic DI (Teilplan DI3)._
```

---

## #70 — [V0.10] TE1 Such-Index-Cache

```markdown
## Ziel
Die Suche ist beim zweiten Start sofort da; der Hänger bei „Bereite Suche vor…“ verschwindet.

## Scope
- Ergebnis von `prepare()` (`main_search_loader.dart:63`) nach `$XDG_CACHE_HOME/linux-assistant/search-index.json` schreiben
- Beim Start: Cache sofort laden, im Hintergrund auffrischen, dezent anzeigen
- Behebt den Hänger bei „Bereite Suche vor…" (Upstream #231, #239)

## Abnahme
- [ ] Zweiter Start zeigt Treffer, bevor der Refresh fertig ist
- [ ] Nach dem Zusammenführen keine doppelten Einträge
- [ ] Eine defekte Cache-Datei führt nie zu einem Fehler beim Start
- [ ] Die Anzeige „lädt“ ist dezent und blockiert die Suche nicht

## Andockpunkte (geprüft 2026-09-30)
- `lib/services/main_search_loader.dart:63` (`prepare()`)
- Cache-Datei `$XDG_CACHE_HOME/linux-assistant/search-index.json`

## Teststrategie
- Cache-Roundtrip; Zusammenführen ohne Duplikate
- Korrupte oder veraltete Cache-Datei → Neuaufbau (Schema-Version im Cache)

## Abhängigkeiten
Blockiert durch: —
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Quelle: Ausbauplan V0.8.6–V1.0, Epic TE (Teilplan TE1)._
```

---

## #71 — [V0.10] QA2 Release-Workflow

```markdown
## Ziel
Ein Release entsteht reproduzierbar aus einem Tag: CI baut das deb, GitHub-Release mit Asset und Notes.

## Scope
- Tag `v*` → CI baut das deb → GitHub-Release mit Asset und Notes aus Conventional Commits
- Der Updater prüft den Asset-Digest (`updater.dart:124-147`)
- Den Tag setzt nur Basti, nach der Gate-Tabelle

## Abnahme
- [ ] Release-Lauf end-to-end geprüft (CI-Build, Asset, Notes, Digest-Prüfung durch den Updater)

## Andockpunkte (geprüft 2026-09-30)
- `lib/services/updater.dart:124-147` (Digest-Prüfung `sha256:`; :129 lehnt Assets ohne Digest ab)
- `.github/workflows/build.yml`, `build-deb.sh` (Alias-Artefakt `linux-assistant.deb`), `tool/check-versions.sh`, `docs/wiki/Release-Process.md`

## Teststrategie
- Trockenlauf des Workflows ohne echten Release-Tag (z. B. per `workflow_dispatch` oder Pre-Release-Tag), nur nach Bastis Go
- Updater-Test: Asset ohne `sha256:`-Digest wird abgelehnt (Bestandstest bleibt grün)

## Risiko & Fallback
Den Tag setzt nur Basti, nach der Gate-Tabelle; kein Push, Tag oder Release durch einen Agenten.

## Abhängigkeiten
Blockiert durch: —
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Quelle: Ausbauplan V0.8.6–V1.0, Epic QA (Teilplan QA2)._
```

---

## #72 — [V0.10] DS2 l10n (#25)

```markdown
## Ziel
Alle sichtbaren Texte kommen aus ARB-Dateien; die Übersetzungs-Budgets sinken.

## Scope
- `_tr(` (8×) → ARB; harte deutsche Strings in `lib/layouts/tools/*` übersetzen
- „Nachbor" korrigieren; Du/Sie einheitlich, auch in den polkit-Texten
- Budgets für it und fi senken (Ratchet in `test/l10n_test.dart`: de 0 / it 20 / fi 77, doppelseitig)
- Deckt die UI-Befunde I3, M1

## Abnahme
- [ ] Kein `_tr(` mehr in `lib/`
- [ ] l10n-Test mit gesenkten Budgets grün
- [ ] Du/Sie einheitlich in App und polkit-Texten
- [ ] „Nachbor“ korrigiert

## Andockpunkte (geprüft 2026-09-30)
- `_tr(` — aktuell 8 Treffer in `lib/` (`grep -rn "_tr(" lib`); harte deutsche Strings in `lib/layouts/tools/*`
- Ratchet: `test/l10n_test.dart` (Budgets: `lib/l10n/app_it.arb` 20, `lib/l10n/linuxassistant_fi.arb` 77, doppelseitig)
- polkit-Texte in `org.linux-assistant.operations.policy` (Du/Sie einheitlich)

## Teststrategie
- `flutter test test/l10n_test.dart` mit den gesenkten Budgets (doppelseitig: Unterschreiten ohne Nachziehen des Budgets ist ebenfalls rot)

## Abhängigkeiten
Blockiert durch: —
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Quelle: Ausbauplan V0.8.6–V1.0, Epic DS (Teilplan DS2)._
```

---

## #73 — [V0.11] TE2 Befehlspalette + eigene Aktionen

```markdown
## Ziel
Jede Aktion ist per Tastatur erreichbar; eigene Aktionen laufen ohne Shell.

## Scope
**Befehlspalette:** `>` im Suchfeld bzw. Strg+K im Hub listet alle Registry-Aktionen (Sektionen, Werkzeuge, Probe-Aktionen, Einstellungen).

**Eigene Aktionen** aus `config.json` (`custom_actions`: name, argv, cwd, mode `output|terminal|detached`, confirm, keywords):
- argv ohne Shell, nie pkexec
- Modus `terminal` nutzt das Muster von `runExecutableInTerminal`; sudo fragt dort selbst — die Nie-Listen-konforme „Terminal+"-Mini-Variante
- Bestätigung nach dem WP-S1-Muster (`action_handler.dart`, `_confirmExecution`)

## Abnahme
- [ ] Palette listet alle Registry-Aktionen; Strg+K und `>` funktionieren
- [ ] Custom-Action im Modus `terminal` startet im externen Terminal mit Bestätigungsdialog
- [ ] Ungültige `custom_actions`-Einträge werden übersprungen und geloggt, nie ausgeführt
- [ ] Nie pkexec, nie ein Shell-String

## Andockpunkte (geprüft 2026-09-30)
- `lib/services/action_handler.dart:70` (`_confirmExecution`), `:222` (Bestätigung vor Ausführung), `:32`/`:57` (injizierbarer `_terminalRunner`)
- `Linux.runExecutableInTerminal` in `lib/services/linux.dart`; `config.json` (`custom_actions`)

## Teststrategie
- Parser für `custom_actions` (gültig, ungültig, fehlendes argv, `cwd`)
- argv ohne Shell: Sonderzeichen bleiben Argumente; Bestätigungsdialog als Widget-Test
- Palette: Suche über alle Registry-Aktionen

## Abhängigkeiten
Blockiert durch: #60 (Registry-Aktionen)
Reihenfolge (weich): #54 (WP-S1: Bestätigungsmuster für `openfile:`-Exec)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Abhängigkeit: FU1 (Registry-Aktionen)._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic TE (Teilplan TE2)._
```

---

## #74 — [V0.11] TE3 Suchanbieter & Kleinigkeiten

```markdown
## Ziel
Die Suche findet, was im Cockpit gebraucht wird: Dienste, Container, Einstellungsseiten, Notizen.

## Scope
Neue Suchanbieter:
- Dienste und Container (führen in die DI-Screens)
- GNOME-Einstellungsseiten (`gnome-control-center --list`)
- Notizen nach Titel und Inhalt (Substring-Suche, kein FTS5)
- tldr, falls installiert (Could)

Dazu:
- Rechner und Einheiten (n2h; eigener kleiner Parser, offline)
- Privatsphäre-Modus (M6): Recent-Dateien und Favoriten im Leerzustand ausblenden
- Executable-Badge an `openfile:`-Treffern (#49, Empfehlung 3)

## Abnahme
- [ ] Jeder neue Anbieter liefert Treffer mit Sprungziel
- [ ] Privatsphäre-Modus blendet Recent/Favoriten im Leerzustand aus
- [ ] Rechner und Einheiten ohne neue pub-Abhängigkeit

## Andockpunkte (geprüft 2026-09-30)
- `lib/services/main_search_loader.dart` (Anbieter-Anmeldung), `gnome-control-center --list`, `lib/services/notes_service.dart`
- Executable-Badge an `openfile:`-Treffern (#49, Empfehlung 3)

## Teststrategie
- Je Anbieter Fixture + Sprungziel
- Privatsphäre-Modus als Widget-Test
- Rechner/Einheiten: Unit-Tests des kleinen Parsers (offline)

## Abhängigkeiten
Blockiert durch: #67 (Dienste-Screen), #68 (Docker-Screen)
Reihenfolge (weich): #75 (Notizen-Anbieter nutzt die Quick-Notes-Struktur)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Abhängigkeit: DI1/DI2-Screens für den Dienste/Container-Anbieter._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic TE (Teilplan TE3)._
```

---

## #75 — [V0.11] WZ2 Quick Notes

```markdown
## Ziel
Schnell notieren, im richtigen Werkzeug weiterarbeiten: Capture aus der Suche, Öffnen in Obsidian.

## Scope
- Notizordner wählbar (z. B. die Inbox des Obsidian-Vaults; Inbox-first bleibt gewahrt)
- Quick-Capture aus der Suche: `note: Text` legt eine neue Notiz an
- „In Obsidian öffnen" (`obsidian://`-URI über `xdg-open`) statt den Rich-Editor nachzubauen

## Abnahme
- [ ] Capture legt Notiz im gewählten Ordner an; Öffnen-Übergabe an Obsidian funktioniert
- [ ] Schreiben nur in den gewählten Notizordner (Pfadgrenzen wie beim Dateimanager)
- [ ] Die `obsidian://`-URI ist korrekt kodiert und wird per argv übergeben

## Andockpunkte (geprüft 2026-09-30)
- `lib/layouts/tools/quick_notes.dart`, `lib/services/notes_service.dart`
- Übergabe: `xdg-open obsidian://…` über argv, kein Shell-String

## Teststrategie
- `test/notes_service_test.dart` und `test/quick_notes_widget_test.dart` erweitern: Ordnerwahl, `note:`-Capture, Kodierung der `obsidian://`-URI

## Risiko & Fallback
Nicht: einen Rich-Editor nachbauen. Die Inbox-first-Regel des Vaults bleibt gewahrt.

## Abhängigkeiten
Blockiert durch: —
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Quelle: Ausbauplan V0.8.6–V1.0, Epic WZ (Teilplan WZ2)._
_MLA-Next-Bezug: GTK-Track: Notes in A7 #98._
```

---

## #76 — [V0.11] ST1 Boot- & Stabilitätsbericht

```markdown
## Ziel
Nach einem Freeze zeigt die App, welche Boots unsauber endeten und was der Kernel dazu sagt.

## Scope
Je Boot aus `journalctl --list-boots -o json`:
- Dauer und sauber/unsauber (Shutdown-Marker vorhanden?)
- Fehlerzahl (prio err)
- Treffer für GPU, nvkms, Xid und OOM (`journalctl -k -b <id> --grep`)

Dazu:
- Boot-Zeit aus `systemd-analyze` (heute 19,9 s Loader) → Hinweis + Sprung in den vorhandenen GRUB-Screen (`lib/layouts/grub_config/grub_config.dart`)
- SysRq-Status, persistentes Journal, konfigurierbarer Link „Notfall-Runbook"
- GPU-Kachel aus `nvidia-smi --query-gpu`; degradiert ohne NVIDIA
- SMART nur als Spike (UDisks2 liefert kein `SmartPercentUsed`), sonst weglassen

## Abnahme
- [ ] Die unsauberen Boots vom 13.–16.09. werden als solche erkannt (Fixture aus dem echten Journal, geschwärzt)
- [ ] Geschwärzte Fixture liegt im Repo; Leak-Check leer
- [ ] GPU-Kachel degradiert ohne `nvidia-smi`

## Andockpunkte (geprüft 2026-09-30)
- CLI: `journalctl --list-boots -o json`, `journalctl -k -b <id> --grep`, `systemd-analyze`, `nvidia-smi --query-gpu` (degradiert ohne NVIDIA)
- `lib/layouts/grub_config/grub_config.dart` (Sprungziel für den Loader-Hinweis)

## Teststrategie
- Fixture aus echtem Journal, geschwärzt (keine Hostnamen, IPs, Pfade): die unsauberen Boots vom 13.–16.09.
- Test ohne NVIDIA und ohne persistentes Journal

## Risiko & Fallback
SMART nur als Spike (UDisks2 liefert kein `SmartPercentUsed`), sonst weglassen.

## Abhängigkeiten
Blockiert durch: #60 (Screen in der Registry)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Quelle: Ausbauplan V0.8.6–V1.0, Epic ST (Teilplan ST1)._
```

---

## #77 — [V0.11] ST2 Änderungs-Zeitleiste

```markdown
## Ziel
„Was änderte sich vor dem Problem?“ — Updates, Kernel und Treiber mit Datum in einer Zeitleiste.

## Scope
- Gefilterte Zeitleiste aus `/var/log/apt/history.log(.N.gz)`, `flatpak history`, `snap changes` (falls vorhanden), später dem Aktions-Journal (SI2)
- Kernel und NVIDIA hervorgehoben; aus ST1 ein Sprung „Was änderte sich vor Boot X?"

## Abnahme
- [ ] Der Treiberwechsel 595.84 → 595.91 und die Kernel-Updates erscheinen mit Datum
- [ ] Rotierte `.gz`-Logs werden gelesen
- [ ] Fehlt `snap` oder `flatpak`, degradiert die Zeitleiste ohne Fehler

## Andockpunkte (geprüft 2026-09-30)
- `/var/log/apt/history.log` (rotiert als `.N.gz`), `flatpak history`, `snap changes`; später das Aktions-Journal (#81)

## Teststrategie
- Fixtures: apt-History (auch `.gz`), Treiberwechsel 595.84 → 595.91 und Kernel-Updates

## Abhängigkeiten
Blockiert durch: #60 (Screen in der Registry)
Reihenfolge (weich): #81 (Aktions-Journal als Zusatzquelle), #76 (Sprung „Was änderte sich vor Boot X?“)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Quelle: Ausbauplan V0.8.6–V1.0, Epic ST (Teilplan ST2)._
```

---

## #78 — [V0.11] ST3 App-Doctor + Support-Bericht

```markdown
## Ziel
Ein kaputtes Bundle oder eine kaputte Installation wird mit einem Befehl erklärt, auch ohne GUI.

## Scope
`la_probe --doctor` läuft ohne GUI; dazu ein Screen. Geprüft wird:
- Version (`version` vs. `dpkg`)
- Pflicht-Tools und die `additional/`-Skripte
- polkit-Policy und ihre Exec-Pfade
- Hotkey-Binding und Single-Instance-Socket
- ob `config.json` lesbar ist
- ob der Wächter-Timer läuft

Support-Bericht als Markdown mit Schwärzung (IPs, Hostnamen, `/home`-Pfade) → Zwischenablage oder Datei.

## Abnahme
- [ ] Bei einem kaputten Bundle (ohne `additional/`) nennt der Doctor genau das
- [ ] `la_probe --doctor` läuft ohne `DISPLAY`/`WAYLAND_DISPLAY`
- [ ] Der Support-Bericht enthält keine IPs, Hostnamen oder `/home`-Pfade

## Andockpunkte (geprüft 2026-09-30)
- `version` vs. `dpkg`; `additional/`-Skripte; `org.linux-assistant.operations.policy` ↔ `_privilegedEntryPoints` (`lib/services/linux.dart`) ↔ chmod in `build-deb.sh` (Invariante aus `AGENTS.md`)
- `lib/services/single_instance.dart` (Socket), `additional/python/setup_keybinding.py` (Hotkey), `config.json`

## Teststrategie
- Doctor-Checks je Fixture-Umgebung, u. a. Verzeichnis ohne `additional/`
- Schwärzung: Unit-Tests mit Beispielen für IPs, Hostnamen und `/home`-Pfade

## Abhängigkeiten
Blockiert durch: #59 (`la_probe --doctor` ohne GUI), #60 (Screen in der Registry)
Reihenfolge (weich): #66 (Prüfung des Wächter-Timers)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Abhängigkeit: FU2 (la_probe-CLI)._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic ST (Teilplan ST3)._
```

---

## #79 — [V0.11] DS3 Goldens + Tastatur (#30)

```markdown
## Ziel
Token-Regressionen fallen in CI auf; die Bedienung per Tastatur ist definiert und getestet.

## Scope
- Golden-Tests für die wichtigsten Screens (nach DS1, damit die Token-Fläche steht)
- Tastenkürzel Strg+1…9, Strg+K, Esc; Fokusreihenfolge prüfen (UI-Befund N4)

## Abnahme
- [ ] Goldens laufen in CI und sind gegen Token-Regressionen empfindlich
- [ ] Tastenkürzel dokumentiert und getestet
- [ ] Tastenkürzel Strg+1…9, Strg+K und Esc dokumentiert und getestet; Fokusreihenfolge (UI-Befund N4) geprüft

## Andockpunkte (geprüft 2026-09-30)
- `test/hermes_widgets_test.dart`, `test/hermes_tokens_test.dart`; Tastenkürzel im Hub (`lib/layouts/hub/hub_shell.dart`)

## Teststrategie
- Golden-Update-Prozess dokumentiert (`flutter test --update-goldens`); CI vergleicht gegen die eingecheckten Bilder

## Risiko & Fallback
#30 nennt `golden_toolkit` — das wäre eine neue Dev-Abhängigkeit; laut Leitplanke 5 nur mit begründeter Ausnahme, sonst ohne Paket lösen. Schrift- und Rendering-Unterschiede zwischen CI-Runner und Referenzsystem im Spec klären.

## Abhängigkeiten
Blockiert durch: #65 (Token-Fläche zuerst)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Abhängigkeit: DS1._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic DS (Teilplan DS3)._
```

---

## #80 — [V0.12] SI1 Expositions-Check + UFW

```markdown
## Ziel
Der Expositions-Check zeigt, welche Dienste von außen erreichbar sind, und warnt bei Neuem.

## Scope
Der privilegierte Report (`read_security_report.py` → `check_security.py`; heute UFW-Heuristik `:34-44`, SSH `:50`) liefert zusätzlich:
- `ss -tulpnH` mit Prozessnamen
- `ufw status verbose`
- Docker-Port-Bindings

Dart gleicht gegen eine Soll-Liste ab (config `exposure_baseline`):
- Loopback wird ignoriert
- Tailnet-Adressbereiche (CGNAT- und ULA-Präfix) = Info
- LAN oder Bindung auf allen Interfaces = Warnung
- Docker-Freigabe oder Host-Netz = kritisch („umgeht UFW")

Jeder Eintrag lässt sich als bekannt markieren. polkit-Actions und Exec-Pfade bleiben unverändert; Umsetzung mit Python-TDD.

## Abnahme
- [ ] Die heutigen sechs Listener erscheinen, bis Basti sie markiert
- [ ] Ein frisch gestarteter Test-Listener auf allen Interfaces wird gemeldet
- [ ] polkit-Actions und Exec-Pfade bleiben unverändert (`git diff` auf `org.linux-assistant.operations.policy` leer)
- [ ] Invarianten-Review vor dem Merge (Root-Report)

## Andockpunkte (geprüft 2026-09-30)
- `additional/python/read_security_report.py` → `additional/python/check_security.py` (UFW-Heuristik `:34-44`, SSH `:50`); Python-Tests in `additional/python/tests/`
- `org.linux-assistant.operations.policy` (zwei Actions, feste Exec-Pfade) und `_privilegedEntryPoints` in `lib/services/linux.dart`

## Teststrategie
- Python-TDD: Fixtures für `ss -tulpnH`, `ufw status verbose` und Docker-Bindings bestimmen das Ausgabeformat des Reports
- Dart-Klassifikation: Loopback ignoriert, Tailnet = Info, LAN/alle Interfaces = Warnung, Docker-Freigabe/Host-Netz = kritisch
- `exposure_baseline`: „als bekannt markieren“ wird persistiert und wirkt beim nächsten Lauf

## Risiko & Fallback
Berührt den privilegierten Pfad → Python-TDD, Invarianten-Review, gleiche Exec-Pfade. Baseline-Listen gehören in die `config.json` des Nutzers, nicht in den Code (öffentliches Repo).

## Abhängigkeiten
Blockiert durch: #60 (Registry), #68 (Docker-Bindings und Expositions-Flags (laut Abhängigkeitsgraph des Ausbauplans))
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Risiko: berührt den Root-Report — Invarianten-Review vor dem Merge._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic SI (Teilplan SI1)._
_MLA-Next-Bezug: GTK-Track: Lagebild #102._
```

---

## #81 — [V0.12] SI2 Aktions-Journal (#151)

```markdown
## Ziel
Jede privilegierte Ausführung ist nachvollziehbar: was, womit, mit welchem Ergebnis.

## Scope
Die Dart-Seite protokolliert jede Queue-Ausführung als JSONL in `$XDG_STATE_HOME/linux-assistant/actions.jsonl` (mit Rotation):
- Beschreibung und argv
- Env-Schlüssel ohne Werte
- Exit-Code je Befehl und Dauer

Neuer Screen „Verlauf". Die Exit-Codes kommen aus der Runner-Ausgabe (`run_multiple_commands.py:64-81`: `-- EXIT CODE`, `FINISHED WITH n FAILED`); optional gibt der Runner eine maschinenlesbare `-- RESULT {json}`-Zeile aus (Python-TDD).

## Abnahme
- [ ] Jede Queue-Ausführung landet mit argv und Exit-Codes im Journal
- [ ] Rotation greift
- [ ] Keine Env-Werte und keine Secrets im Journal

## Andockpunkte (geprüft 2026-09-30)
- `additional/python/run_multiple_commands.py:64-81` (`-- COMMAND`, `-- EXIT CODE`, `FINISHED WITH n FAILED`); Queue-Aufruf in `lib/services/linux.dart`
- Datei `$XDG_STATE_HOME/linux-assistant/actions.jsonl` mit Rotation

## Teststrategie
- Parser der Runner-Ausgabe mit Fixture; Rotation (Größe/Anzahl legt der Spec fest)
- Env: nur Schlüssel, nie Werte (Test mit präparierter Umgebung)

## Abhängigkeiten
Blockiert durch: #55 (WP-S2: argv[0]-Guard und Env-Filter)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Abhängigkeit: nach WP-S2 (argv[0]-Guard und Env-Filter). Liefert ST2 eine Zusatzquelle._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic SI (Teilplan SI2)._
_MLA-Next-Bezug: GTK-Track: Audit im Agenten-Gateway #103._
```

---

## #82 — [V0.12] SI3 Update-Radar

```markdown
## Ziel
Ausstehende Updates sind nach Risiko gruppiert sichtbar, bevor man sie einspielt.

## Scope
- Ausstehende Updates aus dem apt-Cache (python3-apt als Nutzer, ohne `apt update`), gruppiert nach Sicherheit, Kernel, NVIDIA und Rest
- Außerdem: `apt-mark showhold`, Alter des letzten `apt update`, `reboot-required.pkgs`
- Risiko-Hinweis bei Kernel- und NVIDIA-Updates („Neustart, danach ST1 beobachten")
- Die Aktion ist der vorhandene Updater

## Abnahme
- [ ] Radar zeigt ausstehende Updates gruppiert; reboot-required-Pakete benannt
- [ ] Kein `apt update` im Nutzerkontext; das Alter des letzten Updates wird angezeigt

## Andockpunkte (geprüft 2026-09-30)
- `python3-apt` (bereits in `deb/DEBIAN/control` unter Depends), `apt-mark showhold`, `/var/run/reboot-required.pkgs`; Aktion = der vorhandene Updater (`lib/layouts/updater/`, `lib/services/updater.dart`)
- Überschneidung mit Q2 (#58, Neustart-Badge): gleiche Datenquelle nutzen

## Teststrategie
- Fixtures für apt-Cache-Ausgaben (Sicherheit, Kernel, NVIDIA, Rest)

## Abhängigkeiten
Blockiert durch: —
Reihenfolge (weich): #60 (Screen in der Registry — im Plan nicht ausdrücklich genannt, im Spec bestätigen)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Quelle: Ausbauplan V0.8.6–V1.0, Epic SI (Teilplan SI3)._
```

---

## #83 — [V0.12] SP1 Trend & Prognose

```markdown
## Ziel
Ein voller Datenträger wird Tage vorher gemeldet, nicht erst beim Schreibfehler.

## Scope
- Stichproben je echtem Mount (bei jedem Wächter-Lauf und App-Start) → `disk-history.jsonl`, 180 Tage
- Lineare Prognose über 14 Tage → „<Mount> voll in ~N Tagen", nur bei relevantem Wachstum
- Ampelschwellen 85/90/95 %

## Abnahme
- [ ] Mit einer Fixture des echten Verlaufs (69 → 100 %) hätte die Prognose mindestens 7 Tage vorher gewarnt
- [ ] Schwellen 85/90/95 % färben die Ampel
- [ ] Aufbewahrung 180 Tage (Beschneidung getestet)

## Andockpunkte (geprüft 2026-09-30)
- Stichprobe bei jedem Wächter-Lauf (#66) und App-Start; Datei `$XDG_STATE_HOME/linux-assistant/disk-history.jsonl`
- `lib/linux/linux_filesystem.dart` (df-Parser); Fixture-Fälle aus der Crash-Nachlese H3: overlay-, btrfs-, fuse- und Netz-Mounts

## Teststrategie
- Fixture des echten Verlaufs (69 → 100 %)
- Prognose-Unit-Tests: flach, linear, Sprung; nur echte Mounts

## Abhängigkeiten
Blockiert durch: #66 (Wächter-Lauf als Stichprobenpunkt)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Abhängigkeit: LB3 (Wächter-Lauf als Stichproben-Punkt)._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic SP (Teilplan SP1)._
```

---

## #84 — [V0.12] SP2 Kategorien & Aufräumen

```markdown
## Ziel
Aufräumen mit Vorschau: erst sehen, was es bringt und welcher Befehl läuft, dann bestätigen.

## Scope
Größen je Kategorie mit Vorschau: Docker `system df`, `journalctl --disk-usage`, apt-Cache, alte Kernel (`dpkg` vs. `uname -r`), Papierkorb, Nutzer-Cache.

- Nutzer-Aktionen laufen direkt (docker builder prune, Papierkorb leeren)
- Root-Aktionen laufen über die Queue (`apt clean`, `journalctl --vacuum-time`, `apt autoremove --purge`); jeder Befehl ist vor pkexec sichtbar
- Baut auf `lib/layouts/disk_cleaner/*` auf

## Abnahme
- [ ] Kategorien-Übersicht mit korrekten Größen; Cleanup-Aktionen mit Vorschau und sichtbarem Befehl vor pkexec
- [ ] Root-Aktionen nur über die Queue; keine dritte polkit-Action, kein neuer Root-Pfad
- [ ] Der laufende Kernel (`uname -r`) wird nie zur Entfernung angeboten (Sicherheitsvorschlag, im Spec bestätigen)

## Andockpunkte (geprüft 2026-09-30)
- `lib/layouts/disk_cleaner/{clean_disk,cleaner_select_disk,clean_timeshift,remove_software}.dart`
- Größenquellen: `docker system df`, `journalctl --disk-usage`, apt-Cache, `dpkg` vs. `uname -r`; Root-Aktionen nur über die Queue (`additional/python/run_multiple_commands.py`)

## Teststrategie
- Fixtures der Größenausgaben
- Vorschau enthält exakt das argv, das später ausgeführt wird

## Abhängigkeiten
Blockiert durch: #60 (Screen in der Registry)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Quelle: Ausbauplan V0.8.6–V1.0, Epic SP (Teilplan SP2)._
```

---

## #85 — [V0.12] WZ1 Systemmonitor ausbauen

```markdown
## Ziel
Der Systemmonitor zeigt Verläufe über eine Stunde und warnt bei Schwellen, ohne Hintergrunddienst.

## Scope
Umschnittene Version von V0.9 P1 (Autostart-Option entfällt — der Wächter übernimmt den Hintergrund):

- Schwellen-Badges für Temperatur, PSI und Platte
- History von 3 min auf 1 h, downsampled (heute `historyLength = 60` bei 3 s, `system_stats_service.dart:139-140`)
- Prozess-Filter und -Sortierung; gefilterte Partitionsnamen (M3)
- n2h: Link auf ein konfigurierbares Grafana-Dashboard (Langzeit-History wird nicht nachgebaut)

## Abnahme
- [ ] 1-h-History downgesampelt dargestellt; Schwellen-Badges korrekt; Prozess-Filter/-Sortierung funktioniert
- [ ] Der Speicherbedarf der History bleibt durch eine feste Puffergröße begrenzt

## Andockpunkte (geprüft 2026-09-30)
- `lib/services/system_stats_service.dart:139-140` (`historyLength = 60`, `defaultInterval` 3 s), `lib/layouts/tools/system_monitor.dart`, `test/system_monitor_service_test.dart`
- `lib/linux/linux_process.dart` (Prozessliste)

## Teststrategie
- Downsampling-Unit-Tests (60 Punkte bei 3 s → 1 h)
- Schwellen-Badges und Filter/Sortierung

## Risiko & Fallback
Keine Autostart-Option — den Hintergrund übernimmt der Wächter (#66).

## Abhängigkeiten
Blockiert durch: #60 (Screen in der Registry)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue Funktion → Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS + GNOME, sonst `?`)
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Keine Autostart-Option._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic WZ (Teilplan WZ1)._
_MLA-Next-Bezug: GTK-Track: lesender Monitor #96._
```

---

## #86 — [V0.12] DS4 Navigation

```markdown
## Ziel
Einstellungen und Navigation verhalten sich wie der Rest der App.

## Scope
- Einstellungen als Sektion statt Dialog (UI-Befund N3, `hub_shell.dart:406`)
- Breadcrumb klickbar machen oder entfernen (N1)
- Sidebar einklappbar, falls das Parkliste-Urteil zu 4.8 angenommen wird (Mini-Variante: Sidebar-Breite in `config.json` merken)

## Abnahme
- [ ] Einstellungen als Sektion erreichbar; Breadcrumb-Entscheidung umgesetzt; Sidebar-Zustand wird gemerkt
- [ ] Fokus und Tastatur in der neuen Sektion in Wayland **und** X11

## Andockpunkte (geprüft 2026-09-30)
- `lib/layouts/hub/hub_shell.dart:406` (`showDialog(... SettingsStart())` — Einstellungen als Dialog), Breadcrumb im selben Widget
- Sidebar-Breite in `config.json` merken (Mini-Variante zu Parkliste 4.8)

## Teststrategie
- Widget-Tests: Einstellungen als Sektion erreichbar, Breadcrumb-Klick oder -Entfernung, Sidebar-Zustand bleibt

## Risiko & Fallback
Berührt `hub_shell.dart` wie FU1 und DS1 — Reihenfolge im Spec festlegen.

## Abhängigkeiten
Blockiert durch: —
Reihenfolge (weich): #60 (berührt `hub_shell.dart`; im Plan keine harte Abhängigkeit), #65 (berührt `hub_shell.dart`; im Plan keine harte Abhängigkeit)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Neue l10n-Keys in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets de 0 / it 20 / fi 77)
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Quelle: Ausbauplan V0.8.6–V1.0, Epic DS (Teilplan DS4)._
```

---

## #87 — [V1.0] QA3 Fixture-Bibliothek

```markdown
## Ziel
Jeder Parser läuft gegen echte, geschwärzte Ausgaben; neue Fixtures folgen einem dokumentierten Weg.

## Scope
- Echte Zorin-Ausgaben (geschwärzt) für alle Parser in `test/fixtures/` zusammenführen
- Doku in `docs/wiki/Testing.md`
- Die Regel gilt schon ab FU2 — dieser Teilplan konsolidiert den Bestand

## Abnahme
- [ ] Alle Parser laufen gegen die Fixture-Bibliothek
- [ ] Testing-Wiki dokumentiert Anlage und Schwärzung neuer Fixtures
- [ ] Jede Fixture ist geschwärzt; Leak-Check leer

## Andockpunkte (geprüft 2026-09-30)
- `test/fixtures/` existiert noch nicht (Stand 2026-09-30); `docs/wiki/Testing.md`; `test/system_parsers_test.dart`; `packages/la_core/test/`

## Teststrategie
- Ein Test je Parser gegen die Fixture-Bibliothek

## Abhängigkeiten
Blockiert durch: —
Reihenfolge (weich): #59 (die Fixture-Regel gilt schon ab FU2; QA3 konsolidiert den Bestand)
Blockiert: —

## Gates
- [ ] Die fünf CI-Gates grün (`tool/check-versions.sh`, `dart format`, `flutter analyze` mit 0 Findings, `flutter test`, Python-unittest)
- [ ] Abnahme auf dem Referenzsystem (Zorin OS 18.1) mit Beleg; bei UI oder Hotkey in Wayland **und** X11
- [ ] Leak-Check auf Doku und Issue-Text (Muster aus `release-plaene-v0.8.1-v0.8.5.md`, Task 7): keine Hosts, IPs, Ports, `/home`-Pfade

_Quelle: Ausbauplan V0.8.6–V1.0, Epic QA (Teilplan QA3)._
_MLA-Next-Bezug: GTK-Track: gemeinsame Fixtures #94._
```

