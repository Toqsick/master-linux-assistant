# Roadmap: Linux Assistant (Toqsick-Fork) — V0.8.0 → V0.9

**Stand:** 2026-09-10 · **Konsolidiert aus:** PR #24 (Implementierungsplan Admin-Hub v0.8.5 — wird hiermit ersetzt), Issues #25–#30, `.claude/plans/den-linux-assistant-weiter-swift-adleman.md` (Härtungs-Plan 0.7.1→0.8.0), 5-Agenten-Recon 2026-09-10, Bastis Zielbild („Admin Linux Hub", All-in-One).
**DR:** Deep-Research-Auswertung 2026-09-11 (Perplexity, 11 Themen) — der Bericht bleibt bewusst außerhalb des Repos; „DR 4.x" verweist auf seine Themen-Abschnitte.

## Status quo (Kurzfassung)

- `main` (GitHub): v0.7.1-Basis + **E1–E4-Werkzeuge gemergt** (Browser-Launcher, Quick Notes, Dateimanager, Systemmonitor als HubTool-Screens), Werkzeuge-Sektion in der Sidebar, MintYColors-ThemeExtension, Design-Docs (12), Wiki (9), CI mit Gates + deb/rpm-Artefakten.
- `hardening/0.8.0` (lokal, rebase auf main): Phase 0+1+2 der Härtung — argv statt Shell im Root-Pfad, Polkit-Split (2 präzise Actions), deb822-Fix (`apt_sources.py`), Single-Instance-Socket statt wmctrl, Keybinding-Idempotenz, Install-Robustheit, Versions-Gate (eine Quelle: `version`).
- Installiert auf Bastis Laptop (Stand Aufnahme): noch v0.7.1 — deren Security-Check crasht nach Passwort-Eingabe (deb822-`IndexError`, UI zeigt falsch „Root-Rechte nötig"). **Evidence:** `screenshots/v0.7.1/04b…04c` + journal 2026-09-10 21:53.

---

## V0.8.0 — „Alles nutzbar" (✅ Tag v0.8.0, 2026-09-11)

Ziel: Jede angezeigte Funktion funktioniert auf Zorin/Ubuntu 24.04 ohne Fehlertext-Lügen. Release als Tag + GitHub-Release + deb.

| # | Thema | Status | Wo |
|---|---|---|---|
| 1 | Security-Check deb822-Fix | ✅ implementiert (`apt_sources.py` + Tests) | `additional/python/` |
| 2 | **Error-UX:** Script-Fehler ≠ „keine Root-Rechte" — rc-Unterscheidung + stderr sichtbar machen | 🔶 dieser Session (Phase E) | `lib/layouts/security_check/overview.dart` |
| 3 | Nutzbarkeitsreste Phase 3: tote Settings, Hub-Default-Nav, fi-Locale registrieren | 🔶 dieser Session | `main.dart:281-285`, settings |
| 4 | Version-Gate/CI | ✅ | `tool/check-versions.sh`, `build.yml` |
| 5 | Baseline-Handoff (Screenshots/Design/Roadmap) | 🔶 dieser Session | `docs/handoff/` |

**Definition of Done V0.8.0:** Gates grün (analyze/test/format/python-unittest), `build-deb.sh`, Install per `install.sh --purge` (Passwort: Basti), Security-Check läuft mit echtem Passwort fehlerfrei durch (journal-Evidence), Tag `v0.8.0` + GitHub-Release mit deb-Asset, PR #24 geschlossen (Verweis auf dieses Dokument).

## V0.8.X — „Zorin optimal" (nach 0.8.0, kurze Zyklen)

1. **Zorin-Erkennung & Akzent:** `get_environment.py` prüfen (Zorin als Distro + Desktop GNOME/Xfwm-Varianten), Zorin-Palette in `main.dart`-Distro-Set sicherstellen, `features.csv` Z.18 (Timeshift auf Zorin „?") auflösen.
2. **deb822-Vollabdeckung:** `apt_sources.py` überall verwenden, wo `.list`/`.sources` gelesen werden (Updater, Uninstaller-Quellen, Autoupdates) — Prüfen + vereinheitlichen.
3. ✅ **Updater-Stand repariert:** Fork-eigene Release-Erkennung über `releaseRepository` (`lib/services/updater.dart:21` → `Toqsick/master-linux-assistant`) statt Upstream-Verwirrung.
4. **Tool-/Plugin-Registry (Issue #27) als Architekturbasis (ohne Panel-/Dock-Teil):** HubTool-Muster aus E1–E4 formalisieren (Interface: id, Titel, Icon, Screen-Builder, Capabilities) — V0.9-Module registrieren sich nur noch. Grundlage für alles Folgende.
5. **`la-helper` privilegierter Helper (Issue #28):** ein abgesicherter, polkit-gated Helper statt N einzelner pkexec-Scripte; Actions bleiben feingranular (bestehende Policy-Struktur beibehalten).
6. **D-Bus SystemdService (Issue #29):** Systemd-Unit-Status/-Start/-Stop ohne Shell-Umwege; Basis für Docker-Watcher & Backup-Status in V0.9.
7. **l10n-`_tr()`-Pattern (Issue #25) + MintYColors-Dashboard-Migration (Issue #10/#26):** Schulden aus E1–E4 (hardcoded deutsche Strings in tools/*) in ARBs überführen; Dashboard-Widgets auf ThemeExtension umstellen.
8. **Golden-Tests (Issue #30):** visuelle Regression für Kern-Screens (dark+light) — schützt das Design-System.
9. ✅ **Browser-Launcher XDG (V0.8.2):** startet den konfigurierten oder XDG-Standardbrowser (`xdg-settings` + `.desktop`-Prüfung, dann `gtk-launch`/`xdg-open`); die Binär-Liste ist nur noch letzter Fallback.
10. **Release-Gates (V0.8.5):** manuelle Gate-Tabelle für Wayland- und X11-Session im Release-Process-Dokument.

## Nach V0.8.X — aus der Deep-Research-Auswertung (DR)

1. **Hotkey über gsettings in beiden Sessions:** `hotkey_manager` + `libkeybinder-3.0-0` raus; Keybinding via gsettings statt In-App-Grab — funktioniert auf X11 wie Wayland.
2. **Browser-Status (Core, read-only):** Kachel zeigt den XDG-Standardbrowser (`xdg-settings`); Wechsel bleibt außerhalb der App — keine Browser-Verwaltung.
3. **Agenten-Tile → V0.9 P2:** ersetzt Tokentelemetrie (siehe V0.9-Tabelle).
4. **Gate-Automatisierung (Spike):** headless gnome-shell nur für die Wayland-Gates; Monitorwechsel und alle X11-Gates bleiben manuell; kein Self-hosted-Runner.

## V0.9 — „Wiring an Use-Cases" (Hub-Modul-Slots über die Registry)

Bastis Ziel: interaktives Admin-Dashboard, in dem seine realen Workflows leben. Reihenfolge nach Nutzen/Abhängigkeit:

| Prio | Modul | Beschreibung / Anbindung | Hängt ab von |
|---|---|---|---|
| P1 | **System Monitor (ausbauen)** | E3 existiert (Prozesstabelle, CPU/RAM/Thermal-Tiles) → zu persistentem Dashboard ausbauen: Warnschwellen, History (Ringpuffer → Datei), Autostart-Option | nur E3-Verfeinerung |
| P1 | **Backup-System (Restic-Status)** | Restic-Snapshots/Timers/letzte Fehler lesend anzeigen (Bastis reale Restic-Lücke: 0 erfolgreiche Snapshots!) — Status-Kachel + Detail-Screen; Aktionen (snapshot now) via la-helper | #28, #29 |
| P2 | **Docker Watcher** | Container-Liste (docker ps --format json), Status/Badges, Logs-Tail, Start/Stop über la-helper | #28 |
| P2 | **Agenten-Tile (n2h, DR)** | Status-Kachel für Bastis Agenten-Stack (Hermes, ZCode, Claude Code) inkl. Token-Verbrauch aus dem token-calc-Export — ersetzt die frühere Tokentelemetrie-Zeile (DR 4.2/4.3) | Datenvertrag mit token-calc |

**Gestrichen (DR):** „Hermes Gateway Manager" und „Kanban Watcher" —
Basti-spezifische n2h-Integrationen ohne laufende Nutzung; Wiedervorlage nur
mit Beleg (siehe „Geparkt").

**Architektur-Regel für V0.9:** jedes Modul = Registry-Eintrag + eigener Service (Dart, isoliert testbar wie `SystemMonitorService`) + optional la-helper-Action. Kein Modul schreibt direkt Shell-Befehle in Widgets.

## Feature-Tiers & QoL/n2h-Kandidaten

Das Grundkonzept (`MANIFEST.md`, Stand 2026-09-11) gruppiert Features in drei
Tiers: **Core** (Mission: täglicher Helfer, Admin-Aufgaben und die
mitgelieferten Hub-Werkzeuge; am Referenzsystem Zorin OS 18.1 ist Bruch =
Release-Blocker), **QoL** (Alltagskomfort, keine neuen Abhängigkeiten, darf
auf Distros fehlen) und **n2h** (optionale Extras, kleiner
Abhängigkeits-Fußabdruck, Security-Invariante unangetastet). Die
Klassifikation aller 45 Features steht in `features.csv` (Spalte `Category`:
24 Core / 17 QoL / 4 N2H).

**Einordnung der V0.9-Module:** der System Monitor ist ein Core-Hub-Werkzeug;
Backup-Status und Docker Watcher sind QoL; das Agenten-Tile ist n2h
(Basti-spezifische Integration).

**Grenzfälle der Klassifikation:** Feedback → N2H (optional, kein
Alltags-Workflow) · Multimedia-Codecs → QoL (Installationskomfort, kein Kern)
· Passwort-Dialog → QoL (Admin-Komfort-Wrapper) · makeAdmin → Core (echte
Admin-Aufgabe).

### QoL-Kandidaten (neu)

| Kandidat | Anknüpfung |
|---|---|
| Update-Benachrichtigung/Tray-Hinweis | Updater-Service existiert |
| Aufräumen: Journal-Vakuum, APT-/Flatpak-Cache | über la-helper (#28) |
| Boot-Zeit-Analyse | `systemd-analyze`, read-only |
| Disk-Health/SMART-Tile | erweitert „Recognition of drive space utilization“ |
| Systemd-Service-Manager-Screen | baut auf D-Bus SystemdService (#29) auf |
| Timeshift-Status/Backup-Erinnerung | Security-/Health-Check-Umfeld |

### n2h-Kandidaten (neu)

| Kandidat | Anmerkung |
|---|---|
| Tray-Icon mit Quick-Actions | Tray-Support je Desktop uneinheitlich |
| Clipboard-Historie | Wayland-restriktiv — bewusst n2h |
| WLAN-/Netzwerk-Info-Screen | read-only |
| Audio-Geräte-Umschalter | PipeWire/WirePlumber-Abhängigkeit prüfen |
| Rechnen/Einheiten in der Suche | offline, keine neuen Abhängigkeiten |

Kandidaten werden erst nach dem V0.8.X-Härtungsblock angetastet — das Prinzip
„Verifizieren → Härten → Erweitern“ bleibt.

## Geparkt — Wiedervorlage nur mit Beleg (DR)

| DR | Thema | Kern |
|---|---|---|
| 4.1 | Hermes-Web-UI einbetten | Webview in Flutter/GTK (Compositing/DPI/IM-Risiken) vs. nativer Dart-Client vs. externer Browser |
| 4.4 | Wetter-Widget | Freie Wetter-API (Open-Meteo, MET Norway) — Datenschutz zuerst; Hub-Tile vor GNOME-Shell-Extension |
| 4.6 | Notizen: Transkription + QoL | whisper.cpp/faster-whisper lokal, Audio-Aufnahme auf PipeWire, Markdown-Editor-Komponenten |
| 4.8 | Resizable Dash-Leiste + rechtes Dock | Stufenlose Sidebar + andockbare Panels (Datei-Vorschau, Terminal) |
| 4.9 | „Terminal+" | Eingebettetes Terminal (xterm.dart + PTY vs. VTE vs. externes Ptyxis mit Deep-Linking) |
| 4.10 | Proton Hub | Mail/VPN/Pass/Drive/Authenticator — nur Launch + Status + Quick-Actions ohne ToS-Verstoß |
| 4.11 | Gmail + Odysseus-Frontend | Mail-Frontend über den eigenen Gateway (OAuth/Tokens im Gateway, nicht in der App) |

Wiedervorlage nur mit Beleg: Ein Thema kommt zurück auf die Roadmap, wenn
sein DR-Abschnitt (oder eine neue Recherche) den Weg mit Quellen belegt.

## Was aus PR #24 / offenen Issues aufgeht

- **PR #24 (Implementierungsplan v0.8.5):** ersetzt durch dieses Dokument — schließen mit Verweis. Inhaltlich aufgegangen in V0.8.0/V0.8.X.
- **Issue #25 (l10n `_tr`)** → V0.8.X.7 · **#26/#10 (MintYColors-Migration)** → V0.8.X.7 · **#27 (Tool-Registry)** → V0.8.X.4 · **#28 (la-helper)** → V0.8.X.5 · **#29 (D-Bus Systemd)** → V0.8.X.6 · **#30 (Goldens)** → V0.8.X.8.

## Nicht-Ziele / bewusst draußen — verbindliche Nie-Liste

- Kein Upstream-PR (44 Commits Distanz, Upstream dormat bei 0.6.2) — fork-only, deb ist der einzige gepflegte Paketweg (rpm/flatpak/arch → `packaging/unmaintained/`).
- Keine Neuentwicklung eines Widget-Frameworks: HermesTokens + MintYColors zusammenführen/institutionalisieren stattdessen (Entscheidung in V0.8.X.7 treffen).
- Keine fremden Backends als Core (siehe `MANIFEST.md`): TokenTelemetry, Hermes, Odysseus, Wetter-APIs bleiben QoL/n2h.
- Keine Cloud- oder Telemetrie-Pflicht: alles läuft lokal; Netzwerk nur für Funktionen, die der Nutzer explizit anstößt.
- Kein Self-hosted-CI-Runner und keine Automatisierung der X11-Gates (Monitorwechsel bleibt manuell — siehe „Nach V0.8.X").

**Upstream-Punkte (Basti-Tasks, nicht Teil der Releases):** Kommentar in
Upstream-#253 (Hypothese mit Link `eb1dfb5`) · privater Maintainer-Hinweis an
Jean28518 zu den jtools-unix-python-Fixes aus V0.8.3 (WP-P1/P2).
