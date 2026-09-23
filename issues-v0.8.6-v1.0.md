# Issues V0.8.6 – V1.0 — Linux Master Assistant

> 31 Issues, je mit Titel, Meilenstein, Labels und fertigem Body (1:1 kopierbar).
> Labels müssen vorher existieren: vorhanden sind `gate:*`, `roadmap`, `documentation` u. a.; neu: `epic:fu` … `epic:qa` (10), `tier:core`, `tier:qol`, `tier:n2h`, `size:S`, `size:M`, `size:L`.
> Issue-Bodies unterliegen dem Leak-Grep aus V0.8.5 Task 7 (keine Hosts, IPs, Ports, `/home`-Pfade).
> Die Nummern 1–31 sind Anlege-Reihenfolge; die echten GitHub-Nummern werden nach dem Anlegen in der Zuordnungstabelle nachgetragen.

---

## Issue 1 — [V0.8.6] Welle 1 „Sofort-Nutzen": Q1–Q7

**Meilenstein:** V0.8.6 · **Labels:** `tier:core`, `size:M`

### Body

```markdown
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

_Abhängigkeit: V0.8.5 abgeschlossen; Q5 braucht V0.8.2._
_Quelle: Ausbauplan V0.8.6–V1.0, Welle 1 (Q1–Q7)._
```

---

## Issue 2 — [V0.9] FU2 Reiner Dart-Kern `packages/la_core`

**Meilenstein:** V0.9 · **Labels:** `epic:fu`, `tier:core`, `size:L`

### Body

```markdown
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
- [ ] `la_probe --version` läuft auf Zorin ohne Session-Variablen
- [ ] `build-deb.sh` legt das Binary nach `/usr/lib/linux-assistant/`
- [ ] Risiko geprüft (Verflechtung größer als gedacht): Fallback = Probes vorerst im App-Prozess, Wächter später

_Tier: Core · Größe: L · Spec + Plan · zuerst im Epic._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic FU (Teilplan FU2)._
```

---

## Issue 3 — [V0.9] FU1 Modul-Registry (#27)

**Meilenstein:** V0.9 · **Labels:** `epic:fu`, `tier:core`, `size:M`

### Body

```markdown
## Scope
Weiterführung von #27, erweitert um Probes, Suchanbieter und Aktionen — ohne Panel/Dock (Grill-Entscheidung).

- `HubModule`-Deskriptor: id, Titel-Key, Icon, Tier, Art (section|tool|launch), `screenBuilder`, `probes`, `searchProviders`, `actions`, `isAvailable(Environment)`
- Die 5 `HubSection`s und 4 `HubTool`s (`hub_shell.dart:21,30`, sechs switch-Blöcke) wandern in eine Liste

## Abnahme
- [ ] Verhalten unverändert (Widget-Tests der Navigation)
- [ ] Ein neues Modul ist ein Listeneintrag plus Screen
- [ ] Test auf Vollständigkeit der Registry

_Abhängigkeit: nach FU2-Spike + Probe-Vertrag._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic FU (Teilplan FU1)._
```

---

## Issue 4 — [V0.9] FU3 Fehlerrahmen

**Meilenstein:** V0.9 · **Labels:** `epic:fu`, `tier:core`, `size:S`

### Body

```markdown
## Scope
- `FlutterError.onError` und `PlatformDispatcher.instance.onError` → Logger + nicht blockierendes Banner
- Fehler vor `runApp` (`main.dart:31-72`) zeigen einen Fehlerbildschirm mit Ursache und Doctor-Hinweis statt eines leeren Fensters (Beispiel-Gotcha: fehlendes `additional/` → `RangeError` in `Linux.getCurrentEnvironment`)

## Abnahme
- [ ] Ein Bundle ohne `additional/` startet in den Fehlerbildschirm

_Tier: Core · Größe: S · Kurzdesign._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic FU (Teilplan FU3)._
```

---

## Issue 5 — [V0.9] LB1 Lagebild-Leiste

**Meilenstein:** V0.9 · **Labels:** `epic:lb`, `tier:core`, `size:M`

### Body

```markdown
## Scope
Fünf Ampeln oben im Dashboard (`dashboard_section.dart`): Backups · Updates & Neustart · Speicher · Dienste · Sicherheit.

- Jede Ampel ist eine Registry-Probe; Klick führt ins Detail
- Startzustand sofort aus `status.json` (falls LB3 aktiv), danach live
- Widgets: `HermesHaloDot`, `HermesBadge`, `HermesStatTile` (kein `MintY.currentColor`/`MintY.dark`)

## Abnahme
- [ ] Heute stehen Backups auf ROT und Updates auf GELB (Neustart), Speicher je nach Schwelle
- [ ] Jede Ampel erklärt sich in einem Satz

_Abhängigkeit: FU1 (Registry-Probes)._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic LB (Teilplan LB1)._
```

---

## Issue 6 — [V0.9] LB2 Backup-Cockpit

**Meilenstein:** V0.9 · **Labels:** `epic:lb`, `tier:qol`, `size:M`

### Body

```markdown
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

_Nicht: restic-Repo, Passwörter, `restic snapshots`._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic LB (Teilplan LB2)._
```

---

## Issue 7 — [V0.9] QA1 Gate-Automatisierung, Spike

**Meilenstein:** V0.9 · **Labels:** `epic:qa`, `size:S`

### Body

```markdown
## Scope
Spike (beschlossen): Headless `gnome-shell --wayland --virtual-monitor` auf dem `ubuntu-24.04`-Runner.

- Nur Wayland-Hotkey (Test-Hook) und Clipboard
- Ergebnis: go/no-go; kein Self-hosted-Runner

## Abnahme
- [ ] Ergebnis dokumentiert (go/no-go mit Begründung und Messwerten)

_Unabhängig — so früh wie möglich in V0.9._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic QA (Teilplan QA1)._
```

---

## Issue 8 — [V0.9] DS1 Token-Einheit (#29/#10)

**Meilenstein:** V0.9 · **Labels:** `epic:ds`, `tier:qol`, `size:L`

### Body

```markdown
## Scope
- MintY-Statik in 32 Dateien → ThemeExtension (`HermesTokens`, `MintYColors`)
- Harte Farben ersetzen; Geometrie- und Typo-Skala einführen
- Deckt die UI-Befunde I2, I4, M2, M4

## Abnahme
- [ ] Keine direkten MintY-Farbzugriffe mehr außerhalb der Token-Definition
- [ ] `flutter analyze` 0 Findings; Widget-Tests grün; Goldens aktualisiert (Vorbereitung für DS3)

_Abhängigkeit: erst nach FU1 — beide fassen `hub_shell.dart` an._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic DS (Teilplan DS1)._
```

---

## Issue 9 — [V0.10] LB3 Wächter

**Meilenstein:** V0.10 · **Labels:** `epic:lb`, `tier:qol`, `size:M`

### Body

```markdown
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

_Abhängigkeit: FU2 (la_probe-CLI)._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic LB (Teilplan LB3)._
```

---

## Issue 10 — [V0.10] DI1 Dienste & Timer

**Meilenstein:** V0.10 · **Labels:** `epic:di`, `tier:qol`, `size:M`

### Body

```markdown
## Scope
- Watchlist (config), alle fehlgeschlagenen Units und alle Timer (`-o json`), in beiden Scopes
- Start, Stop, Restart nur für `--user`-Units; System-Units read-only (Restart über die Queue = Could)
- Journal-Tail je Unit
- n2h: Mini-Probe für Netzwerk/VPN (aktive Interfaces wie `tailscale0`/`proton0` über `ip -j link`)
- Kein D-Bus nötig (#26 zurückgestuft)

## Abnahme
- [ ] Watchlist + fehlgeschlagene Units + Timer beider Scopes in einem Screen
- [ ] Start/Stop/Restart nur für User-Units möglich

_Abhängigkeit: FU1 (Registry)._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic DI (Teilplan DI1)._
```

---

## Issue 11 — [V0.10] DI2 Docker & Compose

**Meilenstein:** V0.10 · **Labels:** `epic:di`, `tier:qol`, `size:M`

### Body

```markdown
## Scope
- Daten aus `docker ps -a --format '{{json .}}'` und `docker inspect` (NetworkMode, PortBindings, Health); gruppiert nach `com.docker.compose.project`
- Start, Stop, Restart, Logs-Tail über die Docker-CLI (keine neue Rechte-Naht, Nutzer ist in `docker`); Hinweis im UI: `docker`-Gruppe ≈ root
- Expositions-Flags: veröffentlicht auf allen Interfaces oder im LAN („umgeht UFW"), Host-Netz
- Ohne Docker: Hinweis statt Fehler

## Abnahme
- [ ] Compose-Projekte gruppiert mit Health- und Expositions-Flags
- [ ] Degradierung ohne Docker getestet

_Quelle: Ausbauplan V0.8.6–V1.0, Epic DI (Teilplan DI2)._
```

---

## Issue 12 — [V0.10] DI3 Agenten-Tile

**Meilenstein:** V0.10 · **Labels:** `epic:di`, `tier:n2h`, `size:M`

### Body

```markdown
## Scope
Wie in der Roadmap beschlossen (Grill Q13–Q15, Q22, Q35):

- kritischstes TokenTelemetry-Budget (`/budgets`)
- Blocker-Zahl aus `hermes kanban boards list --json`
- Gateway-Status und Start-Knöpfe
- offline → Hinweis und „Dienst starten" (`systemctl --user`)

Fremdes Backend: read-only-Status + Starten, nie Core. Das Hermes-Verzeichnis wird nur über CLI und systemctl gelesen.

## Abnahme
- [ ] Tile zeigt Budget, Blocker, Gateway-Status; Start-Knöpfe funktionieren im User-Scope

_Quelle: Ausbauplan V0.8.6–V1.0, Epic DI (Teilplan DI3)._
```

---

## Issue 13 — [V0.10] TE1 Such-Index-Cache

**Meilenstein:** V0.10 · **Labels:** `epic:te`, `tier:core`, `size:M`

### Body

```markdown
## Scope
- Ergebnis von `prepare()` (`main_search_loader.dart:63`) nach `$XDG_CACHE_HOME/linux-assistant/search-index.json` schreiben
- Beim Start: Cache sofort laden, im Hintergrund auffrischen, dezent anzeigen
- Behebt den Hänger bei „Bereite Suche vor…" (Upstream #231, #239)

## Abnahme
- [ ] Zweiter Start zeigt Treffer, bevor der Refresh fertig ist
- [ ] Nach dem Zusammenführen keine doppelten Einträge

_Quelle: Ausbauplan V0.8.6–V1.0, Epic TE (Teilplan TE1)._
```

---

## Issue 14 — [V0.10] QA2 Release-Workflow

**Meilenstein:** V0.10 · **Labels:** `epic:qa`, `size:M`

### Body

```markdown
## Scope
- Tag `v*` → CI baut das deb → GitHub-Release mit Asset und Notes aus Conventional Commits
- Der Updater prüft den Asset-Digest (`updater.dart:124-147`)
- Den Tag setzt nur Basti, nach der Gate-Tabelle

## Abnahme
- [ ] Release-Lauf end-to-end geprüft (CI-Build, Asset, Notes, Digest-Prüfung durch den Updater)

_Quelle: Ausbauplan V0.8.6–V1.0, Epic QA (Teilplan QA2)._
```

---

## Issue 15 — [V0.10] DS2 l10n (#25)

**Meilenstein:** V0.10 · **Labels:** `epic:ds`, `tier:qol`, `size:M`

### Body

```markdown
## Scope
- `_tr(` (8×) → ARB; harte deutsche Strings in `lib/layouts/tools/*` übersetzen
- „Nachbor" korrigieren; Du/Sie einheitlich, auch in den polkit-Texten
- Budgets für it und fi senken (Ratchet in `test/l10n_test.dart`: de 0 / it 20 / fi 77, doppelseitig)
- Deckt die UI-Befunde I3, M1

## Abnahme
- [ ] Kein `_tr(` mehr in `lib/`
- [ ] l10n-Test mit gesenkten Budgets grün

_Quelle: Ausbauplan V0.8.6–V1.0, Epic DS (Teilplan DS2)._
```

---

## Issue 16 — [V0.11] TE2 Befehlspalette + eigene Aktionen

**Meilenstein:** V0.11 · **Labels:** `epic:te`, `tier:core`, `size:M`

### Body

```markdown
## Scope
**Befehlspalette:** `>` im Suchfeld bzw. Strg+K im Hub listet alle Registry-Aktionen (Sektionen, Werkzeuge, Probe-Aktionen, Einstellungen).

**Eigene Aktionen** aus `config.json` (`custom_actions`: name, argv, cwd, mode `output|terminal|detached`, confirm, keywords):
- argv ohne Shell, nie pkexec
- Modus `terminal` nutzt das Muster von `runExecutableInTerminal`; sudo fragt dort selbst — die Nie-Listen-konforme „Terminal+"-Mini-Variante
- Bestätigung nach dem WP-S1-Muster (`action_handler.dart`, `_confirmExecution`)

## Abnahme
- [ ] Palette listet alle Registry-Aktionen; Strg+K und `>` funktionieren
- [ ] Custom-Action im Modus `terminal` startet im externen Terminal mit Bestätigungsdialog

_Abhängigkeit: FU1 (Registry-Aktionen)._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic TE (Teilplan TE2)._
```

---

## Issue 17 — [V0.11] TE3 Suchanbieter & Kleinigkeiten

**Meilenstein:** V0.11 · **Labels:** `epic:te`, `tier:qol`, `size:M`

### Body

```markdown
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

_Abhängigkeit: DI1/DI2-Screens für den Dienste/Container-Anbieter._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic TE (Teilplan TE3)._
```

---

## Issue 18 — [V0.11] WZ2 Quick Notes

**Meilenstein:** V0.11 · **Labels:** `epic:wz`, `tier:core`, `size:S`

### Body

```markdown
## Scope
- Notizordner wählbar (z. B. die Inbox des Obsidian-Vaults; Inbox-first bleibt gewahrt)
- Quick-Capture aus der Suche: `note: Text` legt eine neue Notiz an
- „In Obsidian öffnen" (`obsidian://`-URI über `xdg-open`) statt den Rich-Editor nachzubauen

## Abnahme
- [ ] Capture legt Notiz im gewählten Ordner an; Öffnen-Übergabe an Obsidian funktioniert

_Quelle: Ausbauplan V0.8.6–V1.0, Epic WZ (Teilplan WZ2)._
```

---

## Issue 19 — [V0.11] ST1 Boot- & Stabilitätsbericht

**Meilenstein:** V0.11 · **Labels:** `epic:st`, `tier:qol`, `size:M`

### Body

```markdown
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

_Quelle: Ausbauplan V0.8.6–V1.0, Epic ST (Teilplan ST1)._
```

---

## Issue 20 — [V0.11] ST2 Änderungs-Zeitleiste

**Meilenstein:** V0.11 · **Labels:** `epic:st`, `tier:qol`, `size:M`

### Body

```markdown
## Scope
- Gefilterte Zeitleiste aus `/var/log/apt/history.log(.N.gz)`, `flatpak history`, `snap changes` (falls vorhanden), später dem Aktions-Journal (SI2)
- Kernel und NVIDIA hervorgehoben; aus ST1 ein Sprung „Was änderte sich vor Boot X?"

## Abnahme
- [ ] Der Treiberwechsel 595.84 → 595.91 und die Kernel-Updates erscheinen mit Datum

_Quelle: Ausbauplan V0.8.6–V1.0, Epic ST (Teilplan ST2)._
```

---

## Issue 21 — [V0.11] ST3 App-Doctor + Support-Bericht

**Meilenstein:** V0.11 · **Labels:** `epic:st`, `tier:core`, `size:M`

### Body

```markdown
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

_Abhängigkeit: FU2 (la_probe-CLI)._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic ST (Teilplan ST3)._
```

---

## Issue 22 — [V0.11] DS3 Goldens + Tastatur (#30)

**Meilenstein:** V0.11 · **Labels:** `epic:ds`, `tier:qol`, `size:M`

### Body

```markdown
## Scope
- Golden-Tests für die wichtigsten Screens (nach DS1, damit die Token-Fläche steht)
- Tastenkürzel Strg+1…9, Strg+K, Esc; Fokusreihenfolge prüfen (UI-Befund N4)

## Abnahme
- [ ] Goldens laufen in CI und sind gegen Token-Regressionen empfindlich
- [ ] Tastenkürzel dokumentiert und getestet

_Abhängigkeit: DS1._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic DS (Teilplan DS3)._
```

---

## Issue 23 — [V0.12] SI1 Expositions-Check + UFW

**Meilenstein:** V0.12 · **Labels:** `epic:si`, `tier:core`, `size:M`

### Body

```markdown
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

_Risiko: berührt den Root-Report — Invarianten-Review vor dem Merge._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic SI (Teilplan SI1)._
```

---

## Issue 24 — [V0.12] SI2 Aktions-Journal (#151)

**Meilenstein:** V0.12 · **Labels:** `epic:si`, `tier:core`, `size:M`

### Body

```markdown
## Scope
Die Dart-Seite protokolliert jede Queue-Ausführung als JSONL in `$XDG_STATE_HOME/linux-assistant/actions.jsonl` (mit Rotation):
- Beschreibung und argv
- Env-Schlüssel ohne Werte
- Exit-Code je Befehl und Dauer

Neuer Screen „Verlauf". Die Exit-Codes kommen aus der Runner-Ausgabe (`run_multiple_commands.py:64-81`: `-- EXIT CODE`, `FINISHED WITH n FAILED`); optional gibt der Runner eine maschinenlesbare `-- RESULT {json}`-Zeile aus (Python-TDD).

## Abnahme
- [ ] Jede Queue-Ausführung landet mit argv und Exit-Codes im Journal
- [ ] Rotation greift

_Abhängigkeit: nach WP-S2 (argv[0]-Guard und Env-Filter). Liefert ST2 eine Zusatzquelle._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic SI (Teilplan SI2)._
```

---

## Issue 25 — [V0.12] SI3 Update-Radar

**Meilenstein:** V0.12 · **Labels:** `epic:si`, `tier:core`, `size:M`

### Body

```markdown
## Scope
- Ausstehende Updates aus dem apt-Cache (python3-apt als Nutzer, ohne `apt update`), gruppiert nach Sicherheit, Kernel, NVIDIA und Rest
- Außerdem: `apt-mark showhold`, Alter des letzten `apt update`, `reboot-required.pkgs`
- Risiko-Hinweis bei Kernel- und NVIDIA-Updates („Neustart, danach ST1 beobachten")
- Die Aktion ist der vorhandene Updater

## Abnahme
- [ ] Radar zeigt ausstehende Updates gruppiert; reboot-required-Pakete benannt

_Quelle: Ausbauplan V0.8.6–V1.0, Epic SI (Teilplan SI3)._
```

---

## Issue 26 — [V0.12] SP1 Trend & Prognose

**Meilenstein:** V0.12 · **Labels:** `epic:sp`, `tier:qol`, `size:M`

### Body

```markdown
## Scope
- Stichproben je echtem Mount (bei jedem Wächter-Lauf und App-Start) → `disk-history.jsonl`, 180 Tage
- Lineare Prognose über 14 Tage → „<Mount> voll in ~N Tagen", nur bei relevantem Wachstum
- Ampelschwellen 85/90/95 %

## Abnahme
- [ ] Mit einer Fixture des echten Verlaufs (69 → 100 %) hätte die Prognose mindestens 7 Tage vorher gewarnt

_Abhängigkeit: LB3 (Wächter-Lauf als Stichproben-Punkt)._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic SP (Teilplan SP1)._
```

---

## Issue 27 — [V0.12] SP2 Kategorien & Aufräumen

**Meilenstein:** V0.12 · **Labels:** `epic:sp`, `tier:qol`, `size:M`

### Body

```markdown
## Scope
Größen je Kategorie mit Vorschau: Docker `system df`, `journalctl --disk-usage`, apt-Cache, alte Kernel (`dpkg` vs. `uname -r`), Papierkorb, Nutzer-Cache.

- Nutzer-Aktionen laufen direkt (docker builder prune, Papierkorb leeren)
- Root-Aktionen laufen über die Queue (`apt clean`, `journalctl --vacuum-time`, `apt autoremove --purge`); jeder Befehl ist vor pkexec sichtbar
- Baut auf `lib/layouts/disk_cleaner/*` auf

## Abnahme
- [ ] Kategorien-Übersicht mit korrekten Größen; Cleanup-Aktionen mit Vorschau und sichtbarem Befehl vor pkexec

_Quelle: Ausbauplan V0.8.6–V1.0, Epic SP (Teilplan SP2)._
```

---

## Issue 28 — [V0.12] WZ1 Systemmonitor ausbauen

**Meilenstein:** V0.12 · **Labels:** `epic:wz`, `tier:core`, `size:M`

### Body

```markdown
## Scope
Umschnittene Version von V0.9 P1 (Autostart-Option entfällt — der Wächter übernimmt den Hintergrund):

- Schwellen-Badges für Temperatur, PSI und Platte
- History von 3 min auf 1 h, downsampled (heute `historyLength = 60` bei 3 s, `system_stats_service.dart:139-140`)
- Prozess-Filter und -Sortierung; gefilterte Partitionsnamen (M3)
- n2h: Link auf ein konfigurierbares Grafana-Dashboard (Langzeit-History wird nicht nachgebaut)

## Abnahme
- [ ] 1-h-History downgesampelt dargestellt; Schwellen-Badges korrekt; Prozess-Filter/-Sortierung funktioniert

_Keine Autostart-Option._
_Quelle: Ausbauplan V0.8.6–V1.0, Epic WZ (Teilplan WZ1)._
```

---

## Issue 29 — [V0.12] DS4 Navigation

**Meilenstein:** V0.12 · **Labels:** `epic:ds`, `tier:qol`, `size:S`

### Body

```markdown
## Scope
- Einstellungen als Sektion statt Dialog (UI-Befund N3, `hub_shell.dart:406`)
- Breadcrumb klickbar machen oder entfernen (N1)
- Sidebar einklappbar, falls das Parkliste-Urteil zu 4.8 angenommen wird (Mini-Variante: Sidebar-Breite in `config.json` merken)

## Abnahme
- [ ] Einstellungen als Sektion erreichbar; Breadcrumb-Entscheidung umgesetzt; Sidebar-Zustand wird gemerkt

_Quelle: Ausbauplan V0.8.6–V1.0, Epic DS (Teilplan DS4)._
```

---

## Issue 30 — [V1.0] QA3 Fixture-Bibliothek

**Meilenstein:** V1.0 · **Labels:** `epic:qa`, `size:M`

### Body

```markdown
## Scope
- Echte Zorin-Ausgaben (geschwärzt) für alle Parser in `test/fixtures/` zusammenführen
- Doku in `docs/wiki/Testing.md`
- Die Regel gilt schon ab FU2 — dieser Teilplan konsolidiert den Bestand

## Abnahme
- [ ] Alle Parser laufen gegen die Fixture-Bibliothek
- [ ] Testing-Wiki dokumentiert Anlage und Schwärzung neuer Fixtures

_Quelle: Ausbauplan V0.8.6–V1.0, Epic QA (Teilplan QA3)._
```

---

## Issue 31 — [V1.0] Parkliste — Wiedervorlage nur mit Beleg

**Meilenstein:** V1.0 · **Labels:** `roadmap`

### Body

```markdown
## Scope
Sammel-Issue zur Neubewertung 2026-09-23. Der Status bleibt **geparkt**; eine Mini-Variante wird nur mit Bastis Go zu einem Teilplan. Wiedervorlage nur, wenn der Beleg-Trigger eintritt:

| Thema | Urteil | Nie-Listen-konforme Mini-Variante | Beleg-Trigger |
|---|---|---|---|
| 4.1 Hermes Web-UI/Client | bleibt geparkt | Start-Knöpfe im Agenten-Tile (steckt in DI3) | Hermes verliert seine eigene Oberfläche |
| 4.4 Wetter | billigster Kandidat, ohne Missionsbezug | n2h-Kachel über Open-Meteo, Ort manuell, S | Basti will es im Dashboard; Open-Meteo-Nutzungsbedingungen im Spike belegen |
| 4.6 Notizen-Ausbau | Rest bleibt geparkt | Suche/Ordner/Capture stecken in TE3/WZ2 | Quick Notes wird trotz Obsidian-Übergabe zum Haupteditor |
| 4.8 Dock / stufenlose Sidebar | rechte Dock bleibt geparkt | Sidebar einklappbar (DS4) | zwei Screens brauchen belegbar Master-Detail nebeneinander |
| 4.9 Terminal+ | bleibt geparkt | Terminal-Übergabe: TE2-Modus `terminal` | keiner absehbar |
| 4.10 Proton-Hub | bleibt geparkt | generischer VPN-Status (steckt in DI1) | Proton veröffentlicht eine offizielle lokale Status-Schnittstelle |
| 4.11 Gmail/Odysseus | bleibt geparkt | frühestens „Ungelesen: N" über die Scoped-API nach DI3-Muster; Token nur im Secret Service | Agenten-Tile hat sich bewährt und der Bedarf ist belegt |
| Handy-Push | geparkt | optionales ntfy-Ziel im Wächter, standardmäßig aus | Wächter läuft und Basti vermisst Meldungen unterwegs |

## Abnahme
- [ ] V1.0: Je Thema ein Entscheidungseintrag (bleibt geparkt / Mini-Variante wird Teilplan mit Go)

_Quelle: Ausbauplan V0.8.6–V1.0, „Parkliste — Neubewertung 2026-09-23"._
```

---

## Bestands-Issues & PR — Aktionen beim Überführen

| Nr | Typ | Aktion |
|---|---|---|
| #27 | Issue | Kommentar: läuft als FU1 weiter (Modul-Registry, erweitert um Probes/Suchanbieter/Aktionen, ohne Panel/Dock) → verlinken |
| #25 | Issue | Kommentar: läuft in DS2 (l10n) weiter → verlinken |
| #29 | Issue | Kommentar: läuft in DS1 (Token-Einheit) weiter → verlinken |
| #30 | Issue | Kommentar: läuft in DS3 (Goldens + Tastatur) weiter → verlinken |
| #10 | PR | Kommentar: Tokens-Thema läuft im Fork über DS1/#29 weiter (PR #10 bleibt davon unberührt) |
| #26 | Issue | Label `roadmap` + Kommentar: zurückgestuft auf **optional** — `systemctl … -o json` (systemd 255) reicht für Status und User-Unit-Start; D-Bus erst bei echtem Bedarf an Live-Signalen |
| #28 | Issue | Kommentar: Schließkriterium „nach WP-S2" (0.8.0 hat Queue + zwei präzise polkit-Actions; WP-S2 bringt argv[0]-Guard und Env-Filter — ein weiterer Helper wäre eine dritte Root-Naht). **Jetzt nicht schließen.** |
| #31, #32 | Issues | Schließen als erledigt: V0.8.1 ist belegt (Branch `hardening/0.8.x-browser-xdg` existiert, Memory aktualisiert 2026-09-15) |

## Zusammenfassung

| # | Titel | Meilenstein | Labels |
|---|---|---|---|
| 1 | [V0.8.6] Welle 1 „Sofort-Nutzen": Q1–Q7 | V0.8.6 | tier:core, size:M |
| 2 | [V0.9] FU2 Reiner Dart-Kern `packages/la_core` | V0.9 | epic:fu, tier:core, size:L |
| 3 | [V0.9] FU1 Modul-Registry (#27) | V0.9 | epic:fu, tier:core, size:M |
| 4 | [V0.9] FU3 Fehlerrahmen | V0.9 | epic:fu, tier:core, size:S |
| 5 | [V0.9] LB1 Lagebild-Leiste | V0.9 | epic:lb, tier:core, size:M |
| 6 | [V0.9] LB2 Backup-Cockpit | V0.9 | epic:lb, tier:qol, size:M |
| 7 | [V0.9] QA1 Gate-Automatisierung, Spike | V0.9 | epic:qa, size:S |
| 8 | [V0.9] DS1 Token-Einheit (#29/#10) | V0.9 | epic:ds, tier:qol, size:L |
| 9 | [V0.10] LB3 Wächter | V0.10 | epic:lb, tier:qol, size:M |
| 10 | [V0.10] DI1 Dienste & Timer | V0.10 | epic:di, tier:qol, size:M |
| 11 | [V0.10] DI2 Docker & Compose | V0.10 | epic:di, tier:qol, size:M |
| 12 | [V0.10] DI3 Agenten-Tile | V0.10 | epic:di, tier:n2h, size:M |
| 13 | [V0.10] TE1 Such-Index-Cache | V0.10 | epic:te, tier:core, size:M |
| 14 | [V0.10] QA2 Release-Workflow | V0.10 | epic:qa, size:M |
| 15 | [V0.10] DS2 l10n (#25) | V0.10 | epic:ds, tier:qol, size:M |
| 16 | [V0.11] TE2 Befehlspalette + eigene Aktionen | V0.11 | epic:te, tier:core, size:M |
| 17 | [V0.11] TE3 Suchanbieter & Kleinigkeiten | V0.11 | epic:te, tier:qol, size:M |
| 18 | [V0.11] WZ2 Quick Notes | V0.11 | epic:wz, tier:core, size:S |
| 19 | [V0.11] ST1 Boot- & Stabilitätsbericht | V0.11 | epic:st, tier:qol, size:M |
| 20 | [V0.11] ST2 Änderungs-Zeitleiste | V0.11 | epic:st, tier:qol, size:M |
| 21 | [V0.11] ST3 App-Doctor + Support-Bericht | V0.11 | epic:st, tier:core, size:M |
| 22 | [V0.11] DS3 Goldens + Tastatur (#30) | V0.11 | epic:ds, tier:qol, size:M |
| 23 | [V0.12] SI1 Expositions-Check + UFW | V0.12 | epic:si, tier:core, size:M |
| 24 | [V0.12] SI2 Aktions-Journal (#151) | V0.12 | epic:si, tier:core, size:M |
| 25 | [V0.12] SI3 Update-Radar | V0.12 | epic:si, tier:core, size:M |
| 26 | [V0.12] SP1 Trend & Prognose | V0.12 | epic:sp, tier:qol, size:M |
| 27 | [V0.12] SP2 Kategorien & Aufräumen | V0.12 | epic:sp, tier:qol, size:M |
| 28 | [V0.12] WZ1 Systemmonitor ausbauen | V0.12 | epic:wz, tier:core, size:M |
| 29 | [V0.12] DS4 Navigation | V0.12 | epic:ds, tier:qol, size:S |
| 30 | [V1.0] QA3 Fixture-Bibliothek | V1.0 | epic:qa, size:M |
| 31 | [V1.0] Parkliste — Wiedervorlage nur mit Beleg | V1.0 | roadmap |
