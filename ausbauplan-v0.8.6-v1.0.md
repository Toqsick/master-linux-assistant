# Ausbauplan „Master Linux Assistant (MLA)" — V0.8.6 bis V1.0 (Master-Plan)

> Repo: `Toqsick/linux-assistant` · Quelle: Master-Plan-Session 2026-09-23 (Brainstorming + read-only geprüfter Evidenz-Schnappschuss)
> Zerlegung in Meilensteine und Issues: `meilensteine-v0.8.6-v1.0.md` · `issues-v0.8.6-v1.0.md`
> Globale Randbedingungen wie die V0.8.1–V0.8.5-Serie: Referenzsystem Zorin OS 18.1, Security-Invarianten unangetastet, kein Push/PR/Versions-Bump/Tag ohne Bastis ausdrückliches OK.

> **Für ausführende Agenten:** Dies ist ein Master-Plan. Umgesetzt wird nie direkt aus ihm, sondern
> aus dem Teilplan, der beim Start eines Eintrags entsteht (siehe „Überführung", Schritt 4). Jede ID
> (FU1, LB2, …) = ein eigener Teilplan; Ausnahme: Welle 1 (Q1–Q7) ist ein gemeinsamer Plan.

## Kontext

**Warum:** Basti will nach der laufenden V0.8.x-Härtungsserie wissen, welche Follow-ups und
Weiterentwicklungen sich für seinen Fork `Toqsick/linux-assistant` lohnen. Die Ideen sollen „cool,
sinnvoll, hilfreich" sein und als ein großer Plan vorliegen, der in einzelne Pläne zerfällt.

**Stand 2026-09-23 (verifiziert):**
- `v0.8.0` getaggt und installiert (`dpkg -l linux-assistant` → 0.8.0). Branch
  `hardening/0.8.x-browser-xdg`, lokal, nicht gepusht, HEAD `b36afac`.
- Serie V0.8.1–V0.8.5 ist geplant (`release-plaene-v0.8.1-v0.8.5.md`, `security-fixplan-42-50.md`,
  GitHub-Milestones 1–5).
  - Erledigt: V0.8.1 (Branch + Memory) und WP-S1 (#49, `0024fcd`).
  - Offen: V0.8.2 (XDG-Browser + WP-B1/B2 nach RV-1), V0.8.2.5 (WP-S2/S3), V0.8.3 (Depends + WP-P1/P2),
    V0.8.4 (Scope-Doku), V0.8.5 (Gates, Prompt, E2E).
- Arbeitsbaum: 9 uncommittete Doku-Dateien (`AGENTS.md`, `README.md`, 7× `docs/wiki/`, „Last verified
  2026-09-18").
- Der Grill vom 2026-09-11 gilt weiter (Q1–Q35):
  - persönliches Cockpit für Zorin OS 18.1
  - Tiers und Nie-Liste
  - sieben geparkte Themen
  - Agenten-Tile statt Gateway-Manager und Kanban-Watcher

**Bastis Vorgaben (2026-09-23):**
- Alle vier Richtungen kommen zuerst: Lagebild & Backups · Stabilität & Speicher · Sicherheit &
  Transparenz · Tempo im Alltag.
- Hintergrund-Meldungen laufen über einen **Wächter-Timer**: kein Dauerprozess, kein Handy-Push.
- Die **Parkliste bleibt geparkt, wird aber neu bewertet**: Urteil je Thema, eine Nie-Listen-konforme
  Mini-Variante und ein Beleg-Trigger. Nichts davon wird ohne sein Go aktiv.
- Tracking: **Plan + Repo + GitHub**, wie bei V0.8.1–0.8.5.

**Ergebnis:**
- Sechs Releases nach V0.8.5 (V0.8.6 → V1.0).
- Zehn Epics mit 29 Teilplänen, dazu ein Sammelplan „Sofort-Nutzen".
- Housekeeping, eine Neubewertung der Parkliste und die Überführung in Repo und GitHub.

## Leitplanken (gelten für jeden Teilplan)

1. **Reihenfolge:** Zuerst V0.8.2 → V0.8.5, unverändert nach den bestehenden Plänen („Verifizieren → Härten →
   Erweitern"). Dieser Plan beginnt danach.
2. **Cockpit-Regel:** Eigene lokale Daten bekommen eine Arbeitsfläche. Fremde Backends (Hermes,
   TokenTelemetry, Odysseus, Web-Dienste) bekommen nur Read-only-Status und Starten und sind nie Core.
   apt, systemd, Restic und Docker dürfen Core sein.
3. **Nie-Liste (verbindlich):**
   - kein Inline-WebView als einziger Hermes-Zugang
   - kein eigener WebKitGTK-FFI-Stack
   - keine universellen Wayland-Hotkeys versprechen
   - kein Tray als Voraussetzung
   - kein eingebetteter Terminalemulator als Core
   - kein Shell-Syntaxhighlighting
   - kein Proton-Vollclient, kein Reverse Engineering, kein Pass-/OTP-Zugriff
   - kein Zwei-Wege-Kanban-Sync
   - kein Gmail-Vollclient in Stufe 1
   - kein Klartext-Fallback für Secrets
4. **Security-Invarianten:**
   - Privilegiertes läuft nur über die JSON-Lines-Command-Queue und die zwei polkit-Actions
     (`org.linux-assistant.operations.policy:23,37`) mit festen Exec-Pfaden. Keine dritte Action, kein
     neuer Root-Pfad.
   - Keine Shell, nur argv-Listen.
   - Keine Secrets lesen: Backup-Status kommt aus Units und Journal, nie aus Repos oder Tokens.
5. **Abhängigkeits-Budget:**
   - Standard: keine neuen pub-Pakete. Jede Ausnahme wird im Teilplan begründet. Bekannte Ausnahme:
     `test` als dev_dependency von `packages/la_core` (FU2). CLI-Argumente werden ohne `args` geparst.
   - Neue Laufzeit-Tools kommen nur als `Recommends:` ins Paket. Features degradieren sauber, wenn Docker,
     `nvidia-smi`, restic oder snap fehlen.
6. **Tiers:** Jede neue Funktion bekommt eine Zeile in `features.csv` (21 Felder; `yes` nur bei Zorin OS
   und GNOME, sonst `?`). Geprüft wird mit dem CSV-Check aus V0.8.4.
7. **l10n-Ratchet:** Jeder neue Key steht in allen vier ARB-Dateien (`test/l10n_test.dart`, Budgets
   de 0 / it 20 / fi 77, doppelseitig). Sonst ist `flutter test` rot.
8. **Design:** Neue Screens nutzen nur ThemeExtension-Tokens (`HermesTokens`, `MintYColors`) und
   Hermes-Widgets (`lib/widgets/hermes/`), nie `MintY.currentColor` oder `MintY.dark`.
9. **Tests:**
   - Reine Parser bekommen Fixtures aus echten Zorin-Ausgaben (geschwärzt, `test/fixtures/`).
   - Prozesszugriffe sind injizierbar nach dem `debugOverride`-Muster (`AppLauncher`, `ActionHandler`).
   - Neue Screens bekommen Widget-Tests.
   - `unawaited_futures` gilt; geloggt wird über `lib/services/logger.dart`.
10. **Gates:** Die fünf CI-Gates müssen grün sein (check-versions, dart format, `flutter analyze` mit 0,
    flutter test, Python-unittest). Dazu kommt die Abnahme des Teilplans auf dem Referenzsystem, in Wayland und
    X11, wo UI oder Hotkey betroffen sind.
11. **Prozess:**
    - Ohne Bastis OK: kein Push, PR, Versions-Bump, Tag oder Release.
    - `install.sh` führt Basti selbst aus (sudo).
    - Das Hermes-Verzeichnis wird nie beschrieben.
    - Commits tragen die Co-Authored-By-Zeile des ausführenden Modells.
    - Das Repo ist öffentlich: keine Hosts, IPs, Ports privater Dienste und keine `/home`-Pfade in Code,
      Doku oder Issues. Geprüft wird mit dem Leak-Grep aus V0.8.5 Task 7.

## Evidenz-Schnappschuss (2026-09-23, read-only live geprüft)

| Befund | Quelle | führt zu |
|---|---|---|
| Zwei User-Units (Backup + Heartbeat) **failed**, Exit 1, je einer am Morgen und Mittag. Das Backup läuft nicht, und niemand wurde gewarnt | `systemctl --user --failed` | Q3, LB1–LB3 |
| `/var/run/reboot-required` vorhanden | Dateisystem | Q2, SI3 |
| zram: 7,2 GB Daten → 2,1 GB komprimiert (von 7,7 GB); PSI memory `some avg60 0.94` | `zramctl`, `/proc/pressure/memory` | Q6, WZ1 |
| 6 Listener auf allen Interfaces (u. a. Host-Netz-Container), dazu LXC-Bridge-DNS und Tailnet-Adressen | `ss -tlnH` | SI1, DI2 |
| Boot dauert 59,5 s, davon **19,9 s Bootloader** | `systemd-analyze` | ST1 → vorhandener GRUB-Screen |
| NVIDIA-Treiber jetzt 595.91.07, obwohl die Doku „595.91 zurückgestellt" sagt | `nvidia-smi` | ST1, ST2 |
| Nutzer ist in `adm` und `docker` → Journal und Docker ohne root lesbar | `id -nG` | DI1, DI2, ST1 |
| systemd 255: `-o json` für `list-units`, `list-timers` und `journalctl --list-boots` | CLI | robuste Parser |
| `notify-send -A/--wait` verfügbar | libnotify | LB3 |
| UDisks2 liefert kein `SmartPercentUsed` | `busctl` | SMART nur als Spike (ST1) |
| Security-Check startet pkexec schon beim Betreten der Sektion (`late Future … = _runChecker()`) | `lib/layouts/security_check/overview.dart:54` | Q1 |
| Feedback geht an den Upstream-Server `feedback.server-jean.de` | `lib/services/feedback_service.dart:33` | Q7 |
| `linux.dart` (3351 Zeilen) importiert Flutter-UI, `lib/linux/*` hängt daran; nur `lib/helpers/command_helper.dart` ist reines Dart | Imports | FU2 (Voraussetzung für den Wächter) |
| Upstream-Crash-Issues #268–#272 (von Toqsick): #269, #271, #272 sind im Fork behoben; #268 (`int.parse` in `lib/linux/linux_filesystem.dart:67`) und processCount (`lib/linux/linux_process.dart:38-42`) sind ungeprüft | Code | H3 |
| UI-Befunde (`docs/handoff/analysis/findings.md`): I1 ist behoben (Modus-Icon). Offen sind I6; N3 (Einstellungen als Dialog, `hub_shell.dart:406`); I2/I4 (MintY-Statik in 32 Dateien); I3 (`_tr(` 8×, harte deutsche Strings in `lib/layouts/tools/*`); M1, M3, M5, M6, N1, N4 | Code | Q1, DS1–DS4, WZ1, TE3 |

**Außerhalb dieses Plans:** Basti prüft, warum die Backup-Unit scheitert. Die App soll so etwas künftig
anzeigen, aber nicht reparieren.

## Bewertung bestehender Vorhaben

| Vorhaben | Urteil | Begründung |
|---|---|---|
| V0.8.2–V0.8.5 inkl. Security-Pass | **behalten, zuerst** | Die Pläne sind ausgearbeitet; Härtung vor Ausbau |
| #27 Tool-Registry | **behalten → FU1**, erweitert um Probes, Suchanbieter und Aktionen, ohne Panel/Dock | Naht für alles Neue (Grill: ohne Dock) |
| #28 `la-helper` | **schließen nach WP-S2** | 0.8.0 hat die Queue und zwei präzise polkit-Actions; WP-S2 bringt argv[0]-Guard und Env-Filter. Ein weiterer Helper wäre eine dritte Root-Naht |
| #26 D-Bus-SystemdService | **zurückstufen auf optional** | `systemctl … -o json` (systemd 255) reicht für Status und User-Unit-Start, ohne neue Abhängigkeit. D-Bus erst bei echtem Bedarf an Live-Signalen |
| #25 l10n · #29/#10 Tokens · #30 Goldens | **behalten → Begleitstrom DS** | Schulden, die jede neue Oberfläche verteuern |
| V0.9 P1 „System Monitor ausbauen" | **umschneiden → WZ1** | Die Autostart-Option entfällt, weil der Wächter den Hintergrund übernimmt und RAM spart. Langzeit-History wird nicht nachgebaut; dafür ein n2h-Link auf das vorhandene health-Grafana |
| V0.9 P1 „Backup (Restic-Status)" | **vorziehen → LB2** | Heute rot, ohne dass es jemand merkt |
| V0.9 P2 Docker Watcher | **behalten → DI2**, plus Expositions-Flags | Docker-Freigaben umgehen UFW |
| V0.9 P2 Agenten-Tile | **behalten wie beschlossen → DI3** | Grill Q13–Q15, Q22, Q35 |
| Nach-V0.8.X #1 Hotkey über gsettings, #2 Browser-Status | **→ V0.8.6 (Q4, Q5)** | Beschlossen, klein, täglicher Nutzen |
| Nach-V0.8.X #4 Gate-Automatisierung | **→ QA1, früh** | Der Spike entscheidet go/no-go und entlastet jede Welle |
| QoL-Kandidaten der Roadmap | Update-Hinweis → SI3 · Aufräumen → SP2 · Boot-Zeit → ST1 · SMART → Spike in ST1 · Service-Manager → DI1 · Timeshift-Status → LB2 (Could) | alle aufgenommen |
| n2h-Kandidaten der Roadmap | Rechnen/Einheiten → TE3 · Netzwerk-Info → Mini-Probe in DI1 · Tray, Clipboard-Historie und Audio-Umschalter **nicht aufgenommen** | Nie-Liste bzw. kein Beleg |
| Upstream-Wunschliste | nur übernommen, was hier einen Job bedient: #151 → SI2 · #231/#239 → TE1 · #244 (tldr) → TE3 (Could) · #208 → Q2 | persönliches Cockpit |
| Feedback-Funktion (N2H) | **Q7: im Fork entfernen (Empfehlung)** | Sie schickt Fork-Feedback an den Upstream-Maintainer; MANIFEST erlaubt die Entfernung von n2h |
| Repo-Umbenennung (angekündigt in `meilensteine-v0.8.1-v0.8.5.md`) | **H5: Entscheidung Basti** | Falls ja: `lib/services/updater.dart:21`, `lib/services/weekly_tasks.dart:33` und Doku in einem Commit |

## Ideenpool — verdichtet (Brainstorming 2026-09-23)

Sechs wiederkehrende Aufgaben (Jobs) auf dem Referenzsystem; aus ihnen entstehen die Epics:

| Job | Ideen | Epic |
|---|---|---|
| „Ist alles in Ordnung?" | Status-Ampeln, Backup-Status aus Units, Neustart-Badge, fehlgeschlagene Dienste, Wächter mit Benachrichtigung | LB, Q2, Q3 |
| „Was ist passiert, was hat sich geändert?" | Boot-/Freeze-Bericht, Änderungs-Zeitleiste, App-Doctor, Support-Bericht | ST |
| „Meine Dienste im Griff" | Dienste & Timer, Docker nach Compose-Projekt, Agenten-Tile | DI |
| „Bin ich offen, was lief als root?" | Scan auf Knopfdruck, Abgleich offener Ports gegen eine Soll-Liste, Aktions-Journal, Update-Radar | SI, Q1 |
| „Platz schaffen, bevor es knallt" | Trend und „voll in ~N Tagen", Kategorien, Aufräumen mit Vorschau | SP |
| „Schnell erledigen" | Such-Cache, Befehlspalette, eigene Skripte als Aktionen, Suchanbieter, Rechner, Quick-Capture | TE, WZ2 |

- **Weglassen statt bauen:** #28 schließen, #26 zurückstufen, Autostart-Option und Langzeit-History
  streichen, Upstream-Feedback entfernen.
- **Integrieren statt nachbauen:**
  - GRUB-Screen für die Boot-Zeit
  - Obsidian für Rich-Notes
  - externes Terminal statt Emulator
  - health-Grafana für Langzeitkurven
  - `systemctl --user` statt eigenem Daemon
- **Bewusst verworfen:**
  - residenter Dauerprozess (RAM, zram ist schon fast voll)
  - Tray
  - Handy-Push (nicht gewählt → geparkt)
  - Clipboard-Historie
  - eigener Kanban
  - SMART über einen neuen Root-Pfad

## Release-Wellen

| Release | Titel | Teilpläne | Richtungen |
|---|---|---|---|
| V0.8.2–V0.8.5 | laufende Serie + Housekeeping | bestehende Pläne, H1–H5 | — |
| **V0.8.6** | Sofort-Nutzen | Q1–Q7 (ein Plan) | alle vier |
| **V0.9** | Fundament & Lagebild | FU2, FU1, FU3, LB1, LB2 · parallel QA1, DS1 | Lagebild |
| **V0.10** | Wächter & Dienste | LB3, DI1, DI2, DI3, TE1 · parallel QA2, DS2 | Lagebild, Tempo |
| **V0.11** | Tempo & Diagnose | TE2, TE3, WZ2, ST1, ST2, ST3 · parallel DS3 | Tempo, Stabilität |
| **V0.12** | Sicherheit & Speicher | SI1, SI2, SI3, SP1, SP2, WZ1 · parallel DS4 | Sicherheit, Speicher |
| **V1.0** | Cockpit komplett | QA3, Parkliste-Entscheide, E2E, Doku (MANIFEST, features.csv, Architecture-Wiki) | alle |

V0.11 und V0.12 lassen sich gegeneinander tauschen. Die einzige Querbeziehung: ST2 bekommt das
Aktions-Journal aus SI2 als zusätzliche Quelle.

## Abhängigkeiten

```text
V0.8.5 ─► Q1–Q7            (keine neue Architektur; Q5 braucht V0.8.2)
V0.8.5 ─► FU2-Spike + Probe-Vertrag ─► FU1 Registry ─┬─► LB1 Lagebild ─► LB3 Wächter ─► SP1 Prognose
          FU2 Parser-Umzug (parallel zu FU1)          ├─► LB2 Backup ─────┘
                                                      ├─► DI1 Dienste ─┬─► TE3 Suchanbieter
                                                      ├─► DI2 Docker ──┴─► SI1 Exposition
                                                      ├─► DI3 Agenten-Tile
                                                      ├─► TE2 Palette + eigene Aktionen
                                                      └─► ST1–ST3, SP2, WZ1 (Screens)
FU2 (la_probe-CLI) ─► LB3 Wächter · ST3 --doctor ohne GUI
WP-S2 ─► SI2 Aktions-Journal ─► ST2 Zeitleiste (Zusatzquelle)
FU1 ─► DS1 Tokens (hub_shell.dart zuerst durch FU1) ─► DS3 Goldens
QA1 Gate-Spike: unabhängig, so früh wie möglich
```

## Epics & Teilpläne

Größen: S = höchstens eine Session · M = 2–3 Sessions · L = 4+ Sessions. Tier je Funktion wie in
`features.csv`.

### Welle 0 — Housekeeping (neben V0.8.2–V0.8.5, Kurzdesign im Chat)

- **H1 Doku-Diff vom 18.09.:** Basti sichtet die 9 Dateien → eigener Docs-Commit oder verwerfen, bevor
  V0.8.2 committet wird. Die Gates brauchen einen sauberen Baum.
- **H2 GitHub-Pflege:**
  - #31/#32 schließen (V0.8.1 ist belegt: Branch + Memory).
  - #28 nach WP-S2 schließen, #26 als optional labeln, jeweils mit der Begründung aus „Bewertung".
  - #27 → FU1; #25/#29/#30/#10 → DS-Issues verlinken.
- **H3 Crash-Nachlese:**
  - Fixture-Tests für #268: `df` mit overlay-, btrfs-, fuse- und Netz-Mounts gegen
    `linux_filesystem.dart:67`.
  - Fixture-Tests für processCount: Kopf- und Leerzeile in `linux_process.dart:38-42`.
  - Fix, falls rot; I5 (fi-Locale registriert) mitprüfen.
  - Upstream-Kommentare mit den Fork-Commits übernimmt Basti.
- **H4 Roadmap-Verweis:** V0.8.4 Task 5 ergänzt in `docs/handoff/roadmap.md` eine Zeile „Ausbau ab
  V0.8.6: `ausbauplan-v0.8.6-v1.0.md`". Keine doppelte Detailplanung.
- **H5 Entscheidung Repo-Name:** `linux-assistant` behalten oder in `linux-master-assistant` umbenennen.
  Bei Umbenennung ändern sich in einem Commit: `updater.dart:21`, `weekly_tasks.dart:33`, README/Wiki
  und der Kopf von `meilensteine-*`.

### Welle 1 — V0.8.6 „Sofort-Nutzen" (ein gemeinsamer Plan, 7 Tasks, je S)

- **Q1 Security-Scan auf Knopfdruck** (Core, Sicherheit)
  - `_checkerOutput` (`security_check/overview.dart:54`) startet nicht mehr beim ersten Build, sondern
    erst über einen Button „Prüfen".
  - Das letzte Ergebnis (nur Befund-Tokens) wird mit Zeitstempel in
    `$XDG_CACHE_HOME/linux-assistant/security-last.json` gespeichert.
  - Abnahme: Sektion öffnen → kein pkexec-Dialog; „Prüfen" → Dialog; nach App-Neustart steht das Ergebnis
    noch da, mit „vor X".
- **Q2 Neustart-Badge** (Core, Lagebild)
  - `/var/run/reboot-required(.pkgs)` → Badge im Dashboard und eine Zeile in der Health-Sektion mit den
    auslösenden Paketen.
  - Abnahme: heute sichtbar, nach dem Neustart weg.
- **Q3 Kachel „Fehlgeschlagene Dienste"** (Core, Lagebild)
  - `systemctl [--user] list-units --failed -o json` in beiden Scopes → Kachel mit Zahl und Liste (Unit,
    Beschreibung, Scope).
  - Abnahme: zeigt auf dem Referenzsystem aktuell die beiden fehlschlagenden Backup-Units.
- **Q4 Hotkey über gsettings in beiden Sessions** (Core, Tempo; beschlossen; Größe eher M)
  - `hotkey_manager` und `libkeybinder-3.0-0` fliegen raus: aus `pubspec.yaml`, `deb/DEBIAN/control`,
    README und der CI-apt-Zeile (`.github/workflows/build.yml:46`).
  - Das Keybinding läuft auch unter X11 über `additional/python/setup_keybinding.py` und
    `keybinding_files.py`.
  - Neue Diagnosezeile in den Einstellungen: aktuelles Binding und verwaiste `custom*`-Einträge.
  - Abnahme: X11- und Wayland-Gate „Hotkey holt das Fenster, Fokus im Suchfeld".
- **Q5 Browser-Status** (Core, Tempo; beschlossen)
  - Read-only „Standard ist X" aus `AppLauncher.defaultBrowserDesktopId()` (entsteht in V0.8.2).
  - Warnung, wenn `gio mime x-scheme-handler/https` abweicht; neue Zeile in `features.csv`.
  - Abnahme: zeigt `brave-origin.desktop`.
- **Q6 Speicher-Kachel ehrlich** (QoL, Stabilität)
  - Der Warnton richtet sich nach PSI (`/proc/pressure/memory`, avg60) statt nur nach der RAM-Quote.
  - Die Swap-Zeile trennt zram (Daten → komprimiert, `/sys/block/zram*/mm_stat`) von Disk-Swap.
  - Andockpunkte: `SystemStatsService` (`system_stats_service.dart:26-32`), `_memoryTile`
    (`dashboard_section.dart:226`).
  - Abnahme: bei heutiger Last kein Alarm; zram-Zeile zeigt „7,2 → 2,1 GB".
- **Q7 Feedback an Upstream abklemmen** (n2h, Transparenz; Basti entscheidet vorab)
  - Empfehlung: entfernen, also Menüeintrag, `feedback_service.dart`, `lib/layouts/feedback/*` und die
    l10n-Keys.
  - Alternative: ein Link auf die Issues des Forks.

### Epic FU — Fundament (V0.9)

- **FU2 Reiner Dart-Kern `packages/la_core`** — Core · L · Spec + Plan · **zuerst**
  - Ziel: Logik, die ohne GUI laufen muss (Probes, Parser, Doctor), liegt in einem Paket **ohne
    Flutter-Abhängigkeit**. Die Reinheit erzwingt der Build, nicht eine Konvention.
  - Spike (eine Session):
    - `dart compile exe packages/la_core/bin/la_probe.dart` mit dem Dart aus dem Flutter-SDK, lokal und in CI.
    - Messen: Binärgröße, Startzeit, Lauf ohne `DISPLAY`/`WAYLAND_DISPLAY`.
  - Danach:
    - `CommandHelper` umziehen (heute `lib/helpers/command_helper.dart`, nur `dart:io`).
    - Logger-Shim ohne `flutter/foundation` (heute hängt `lib/services/logger.dart:1` daran).
    - Probe-Vertrag: `Probe`, `ProbeResult{level: ok|warn|crit|unknown, key, params, at}`.
    - Parser für free, df, uptime und ps aus `system_stats_service.dart:32`, `linux_filesystem.dart`,
      `linux_system.dart:36ff` und `linux_process.dart:19ff`.
    - Die App bindet das Paket als path-Dependency ein.
  - Nicht: `linux.dart` komplett zerlegen. Umziehen wird nur, was Probes brauchen; M5 geht schrittweise
    weiter.
  - Abnahme:
    - `flutter test` und `dart test` in `packages/la_core` grün.
    - `la_probe --version` läuft auf Zorin ohne Session-Variablen.
    - `build-deb.sh` legt das Binary nach `/usr/lib/linux-assistant/`.
  - Risiko: Die Verflechtung ist größer als gedacht. Fallback: Probes laufen vorerst nur im App-Prozess,
    der Wächter kommt später.
- **FU1 Modul-Registry (#27)** — Core · M · Spec + Plan
  - `HubModule`-Deskriptor mit: id, Titel-Key, Icon, Tier, Art (section|tool|launch), `screenBuilder`,
    `probes`, `searchProviders`, `actions`, `isAvailable(Environment)`.
  - Die 5 `HubSection`s und 4 `HubTool`s (`hub_shell.dart:21,30`, sechs switch-Blöcke) wandern in eine
    Liste. Ohne Panel/Dock (Grill).
  - Abnahme:
    - Verhalten unverändert (Widget-Tests der Navigation).
    - Ein neues Modul ist ein Listeneintrag plus Screen.
    - Test auf Vollständigkeit der Registry.
- **FU3 Fehlerrahmen** — Core · S · Kurzdesign
  - `FlutterError.onError` und `PlatformDispatcher.instance.onError` → Logger und ein nicht blockierendes
    Banner.
  - Fehler vor `runApp` (`main.dart:31-72`) zeigen einen Fehlerbildschirm mit Ursache und Doctor-Hinweis
    statt eines leeren Fensters. Beispiel: fehlendes `additional/` → `RangeError` in
    `Linux.getCurrentEnvironment` (Gotcha aus dem Handoff).
  - Abnahme: Ein Bundle ohne `additional/` startet in den Fehlerbildschirm.

### Epic LB — Lagebild & Wächter (V0.9 / V0.10)

- **LB1 Lagebild-Leiste** — Core · M
  - Fünf Ampeln oben im Dashboard (`dashboard_section.dart`): Backups · Updates & Neustart · Speicher ·
    Dienste · Sicherheit.
  - Jede Ampel ist eine Registry-Probe; Klick führt ins Detail.
  - Der Startzustand kommt sofort aus `status.json` (falls LB3 aktiv ist), danach live.
  - Widgets: `HermesHaloDot`, `HermesBadge`, `HermesStatTile`.
  - Abnahme: Heute stehen Backups auf ROT und Updates auf GELB (Neustart), Speicher je nach Schwelle. Jede
    Ampel erklärt sich in einem Satz.
- **LB2 Backup-Cockpit** (V0.9 P1, vorgezogen) — QoL · M
  - Units per Muster, in beiden Scopes (Default `*restic*`, `*backup*`, `*borg*`; konfigurierbar):
    - letzter Lauf und Ergebnis (`systemctl show`)
    - nächster Termin (`list-timers -o json`)
    - letzter Erfolg aus dem Journal („Deactivated successfully" vs. „Failed with result")
    - Heartbeat-Units werden als Totmannschalter gedeutet
  - „Jetzt sichern" = `systemctl --user start <unit>`, ohne polkit.
  - Nicht: restic-Repo, Passwörter, `restic snapshots`.
  - Could: Timeshift-Plan aus `/etc/timeshift/timeshift.json`; die Snapshot-Liste nur über den
    privilegierten Report.
  - Abnahme: heute ROT mit Unit-Beschreibung und letzter Journal-Zeile; nach erfolgreichem Lauf GRÜN.
- **LB3 Wächter** — QoL · M · Spec + Plan
  - Bestandteile: `la_probe` (aus FU2) und `linux-assistant-watch.service/.timer` als User-Units im .deb
    (`/usr/lib/systemd/user/`). `build-deb.sh` und den Pfad in `install.sh` prüfen.
  - Aktivierung über einen Schalter in den Einstellungen (`systemctl --user enable --now …`, kein root).
  - Takt: alle 30 min und 5 min nach dem Login.
  - Schreibt `$XDG_STATE_HOME/linux-assistant/status.json` atomar und versioniert (`schema`).
  - Meldet per `notify-send -A open=Öffnen` nur beim Übergang nach Rot; Erinnerung alle N Stunden ist
    optional.
  - „Öffnen" bringt die App auf die Ziel-Sektion:
    - Das Single-Instance-Protokoll (`single_instance.dart:87`, heute nur `raise`) wird um
      `raise:<section>` erweitert.
    - Die wartende Benachrichtigung darf den Timer-Lauf nicht blockieren (z. B. `systemd-run --user`);
      das klärt der Spec.
  - Nicht: Dauerprozess, Tray, Handy-Push (geparkt). `Recommends: libnotify-bin`.
  - Abnahme:
    - Eine Ampel wird rot → genau eine Benachrichtigung.
    - Zweiter Lauf ohne Änderung → keine.
    - Die App zeigt denselben Stand wie `status.json`.

### Epic DI — Dienste & Container (V0.10)

- **DI1 Dienste & Timer** — QoL · M
  - Zeigt eine Watchlist (config), alle fehlgeschlagenen Units und alle Timer (`-o json`), in beiden
    Scopes.
  - Start, Stop und Restart nur für `--user`-Units. System-Units bleiben read-only; Restart über die Queue
    ist Could.
  - Journal-Tail je Unit.
  - n2h: Mini-Probe für Netzwerk/VPN (aktive Interfaces wie `tailscale0`/`proton0` über `ip -j link`).
  - Kein D-Bus (#26) nötig.
- **DI2 Docker & Compose** (V0.9 P2) — QoL · M
  - Daten aus `docker ps -a --format '{{json .}}'` und `docker inspect` (NetworkMode, PortBindings,
    Health); gruppiert nach `com.docker.compose.project`.
  - Start, Stop, Restart und Logs-Tail über die Docker-CLI. Der Nutzer ist schon in `docker`, es entsteht
    also keine neue Rechte-Naht. Hinweis im UI: die `docker`-Gruppe ist ≈ root.
  - Expositions-Flags: veröffentlicht auf allen Interfaces oder im LAN („umgeht UFW"), Host-Netz.
  - Ohne Docker: ein Hinweis statt eines Fehlers.
- **DI3 Agenten-Tile** (beschlossen) — n2h · M
  - Exakt wie in der Roadmap festgelegt:
    - kritischstes TokenTelemetry-Budget (`/budgets`)
    - Blocker-Zahl aus `hermes kanban boards list --json`
    - Gateway-Status und Start-Knöpfe
    - offline → Hinweis und „Dienst starten" (`systemctl --user`)
  - Das Hermes-Verzeichnis wird nur über CLI und systemctl gelesen.

### Epic TE — Tempo im Alltag (V0.10 / V0.11)

- **TE1 Such-Index-Cache** — Core · M
  - Das Ergebnis von `prepare()` (`main_search_loader.dart:63`) wird nach
    `$XDG_CACHE_HOME/linux-assistant/search-index.json` geschrieben.
  - Beim Start lädt die App den Cache sofort, frischt ihn im Hintergrund auf und zeigt dezent an, dass
    geladen wird.
  - Behebt den Hänger bei „Bereite Suche vor…" (Upstream #231, #239).
  - Abnahme: Der zweite Start zeigt Treffer, bevor der Refresh fertig ist; nach dem Zusammenführen keine
    doppelten Einträge.
- **TE2 Befehlspalette + eigene Aktionen** — Core/QoL · M
  - Befehlspalette: `>` im Suchfeld bzw. Strg+K im Hub listet alle Registry-Aktionen (Sektionen,
    Werkzeuge, Probe-Aktionen, Einstellungen).
  - Eigene Aktionen kommen aus `config.json` (`custom_actions`: name, argv, cwd,
    mode `output|terminal|detached`, confirm, keywords):
    - argv ohne Shell, nie pkexec.
    - Modus `terminal` nutzt das Muster von `runExecutableInTerminal`; sudo fragt dort selbst. Das ist die
      Nie-Listen-konforme „Terminal+"-Mini-Variante.
    - Bestätigung nach dem WP-S1-Muster (`action_handler.dart`, `_confirmExecution`).
  - Beispiele: Scan- und Diagnose-Skripte des Referenzsystems als Start-Aktionen.
- **TE3 Suchanbieter & Kleinigkeiten** — QoL/n2h · M
  - Neue Suchanbieter:
    - Dienste und Container (führen in die DI-Screens)
    - GNOME-Einstellungsseiten (`gnome-control-center --list`)
    - Notizen nach Titel und Inhalt (Substring-Suche, kein FTS5)
    - tldr, falls installiert (Could)
  - Rechner und Einheiten (n2h; eigener kleiner Parser, offline).
  - Privatsphäre-Modus (M6): Recent-Dateien und Favoriten im Leerzustand ausblenden.
  - Executable-Badge an `openfile:`-Treffern (#49, Empfehlung 3).

### Epic ST — Stabilität & Diagnose (V0.11)

- **ST1 Boot- & Stabilitätsbericht** — QoL · M
  - Je Boot aus `journalctl --list-boots -o json`:
    - Dauer und sauber/unsauber (Shutdown-Marker vorhanden?)
    - Fehlerzahl (prio err)
    - Treffer für GPU, nvkms, Xid und OOM (`journalctl -k -b <id> --grep`)
  - Boot-Zeit aus `systemd-analyze`. Heute 19,9 s Loader → Hinweis und Sprung in den vorhandenen
    GRUB-Screen (`lib/layouts/grub_config/grub_config.dart`).
  - Außerdem: SysRq-Status, persistentes Journal, konfigurierbarer Link „Notfall-Runbook".
  - GPU-Kachel aus `nvidia-smi --query-gpu`; degradiert ohne NVIDIA.
  - SMART nur als Spike (UDisks2 liefert kein `SmartPercentUsed`), sonst weglassen.
  - Abnahme: Die unsauberen Boots vom 13.–16.09. werden als solche erkannt (Fixture aus dem echten
    Journal).
- **ST2 Änderungs-Zeitleiste** — QoL · M
  - Eine gefilterte Zeitleiste aus `/var/log/apt/history.log(.N.gz)`, `flatpak history`, `snap changes`
    (falls vorhanden) und später dem Aktions-Journal (SI2).
  - Kernel und NVIDIA sind hervorgehoben; aus ST1 führt ein Sprung „Was änderte sich vor Boot X?".
  - Abnahme: Der Treiberwechsel 595.84 → 595.91 und die Kernel-Updates erscheinen mit Datum.
- **ST3 App-Doctor + Support-Bericht** — Core/QoL · M
  - `la_probe --doctor` läuft ohne GUI; dazu ein Screen. Geprüft wird:
    - Version (`version` vs. `dpkg`)
    - Pflicht-Tools und die `additional/`-Skripte
    - polkit-Policy und ihre Exec-Pfade
    - Hotkey-Binding und Single-Instance-Socket
    - ob `config.json` lesbar ist
    - ob der Wächter-Timer läuft
  - Support-Bericht als Markdown mit Schwärzung (IPs, Hostnamen, `/home`-Pfade) → Zwischenablage oder
    Datei.
  - Abnahme: Bei einem kaputten Bundle (ohne `additional/`) nennt der Doctor genau das.

### Epic SI — Sicherheit & Transparenz (V0.12)

- **SI1 Expositions-Check + UFW** — Core · M · Spec + Plan (berührt den Root-Report)
  - Der privilegierte Report (`read_security_report.py` → `check_security.py`; heute UFW-Heuristik
    `:34-44`, SSH `:50`) liefert zusätzlich:
    - `ss -tulpnH` mit Prozessnamen
    - `ufw status verbose`
    - Docker-Port-Bindings
  - Dart gleicht gegen eine Soll-Liste ab (config `exposure_baseline`):
    - Loopback wird ignoriert.
    - Tailnet-Adressbereiche (CGNAT- und ULA-Präfix) = Info.
    - LAN oder Bindung auf allen Interfaces = Warnung.
    - Docker-Freigabe oder Host-Netz = kritisch („umgeht UFW").
  - Jeder Eintrag lässt sich als bekannt markieren.
  - polkit-Actions und Exec-Pfade bleiben unverändert; Umsetzung mit Python-TDD.
  - Abnahme: Die heutigen sechs Listener erscheinen, bis Basti sie markiert. Ein frisch gestarteter
    Test-Listener auf allen Interfaces wird gemeldet.
- **SI2 Aktions-Journal** (Upstream #151) — Core · M · nach WP-S2
  - Die Dart-Seite protokolliert jede Queue-Ausführung als JSONL in
    `$XDG_STATE_HOME/linux-assistant/actions.jsonl` (mit Rotation):
    - Beschreibung und argv
    - Env-Schlüssel ohne Werte
    - Exit-Code je Befehl und Dauer
  - Neuer Screen „Verlauf".
  - Die Exit-Codes kommen aus der Runner-Ausgabe (`run_multiple_commands.py:64-81`: `-- EXIT CODE`,
    `FINISHED WITH n FAILED`). Optional gibt der Runner zusätzlich eine maschinenlesbare
    `-- RESULT {json}`-Zeile aus (Python-TDD).
- **SI3 Update-Radar** — Core · M
  - Ausstehende Updates aus dem apt-Cache (python3-apt als Nutzer, ohne `apt update`), gruppiert nach
    Sicherheit, Kernel, NVIDIA und Rest.
  - Außerdem: `apt-mark showhold`, Alter des letzten `apt update`, `reboot-required.pkgs`.
  - Risiko-Hinweis bei Kernel- und NVIDIA-Updates („Neustart, danach ST1 beobachten").
  - Die Aktion ist der vorhandene Updater.

### Epic SP — Speicher (V0.12)

- **SP1 Trend & Prognose** — QoL · M · braucht LB3
  - Stichproben je echtem Mount (bei jedem Wächter-Lauf und App-Start) → `disk-history.jsonl`,
    180 Tage.
  - Lineare Prognose über 14 Tage → „<Mount> voll in ~N Tagen", nur bei relevantem Wachstum.
  - Ampelschwellen 85/90/95 %.
  - Abnahme: Mit einer Fixture des echten Verlaufs (69 → 100 %) hätte die Prognose mindestens 7 Tage
    vorher gewarnt.
- **SP2 Kategorien & Aufräumen** — QoL · M
  - Größen je Kategorie mit Vorschau: Docker `system df`, `journalctl --disk-usage`, apt-Cache, alte
    Kernel (`dpkg` vs. `uname -r`), Papierkorb, Nutzer-Cache.
  - Nutzer-Aktionen laufen direkt (docker builder prune, Papierkorb leeren).
  - Root-Aktionen laufen über die Queue (`apt clean`, `journalctl --vacuum-time`,
    `apt autoremove --purge`); jeder Befehl ist vor pkexec sichtbar.
  - Baut auf `lib/layouts/disk_cleaner/*` auf.

### Epic WZ — Hub-Werkzeuge (V0.11 / V0.12)

- **WZ1 Systemmonitor ausbauen** (V0.9 P1, umgeschnitten) — Core · M
  - Schwellen-Badges für Temperatur, PSI und Platte.
  - History von 3 min auf 1 h, downsampled (heute `historyLength = 60` bei 3 s,
    `system_stats_service.dart:139-140`).
  - Prozess-Filter und -Sortierung; gefilterte Partitionsnamen (M3).
  - n2h: Link auf ein konfigurierbares Grafana-Dashboard.
  - Keine Autostart-Option.
- **WZ2 Quick Notes** — Core · S–M
  - Notizordner wählbar, z. B. die Inbox des Obsidian-Vaults (Inbox-first bleibt gewahrt).
  - Quick-Capture aus der Suche: `note: Text` legt eine neue Notiz an.
  - „In Obsidian öffnen" (`obsidian://`-URI über `xdg-open`) statt den Rich-Editor nachzubauen.

### Epic DS — Design & Sprache (Begleitstrom V0.9–V0.12)

- **DS1 Token-Einheit** (#29/#10, I2/I4/M2/M4)
  - MintY-Statik in 32 Dateien → ThemeExtension.
  - Harte Farben ersetzen; Geometrie- und Typo-Skala einführen.
  - Erst nach FU1, weil beide `hub_shell.dart` anfassen.
- **DS2 l10n** (#25, I3, M1)
  - `_tr(` (8×) → ARB; harte deutsche Strings in `lib/layouts/tools/*` übersetzen.
  - „Nachbor" korrigieren; Du/Sie einheitlich, auch in den polkit-Texten.
  - Budgets für it und fi senken.
- **DS3 Goldens + Tastatur** (#30, N4)
  - Nach DS1.
  - Tastenkürzel Strg+1…9, Strg+K, Esc; Fokusreihenfolge prüfen.
- **DS4 Navigation** (N3, N1, Mini-Variante zu 4.8)
  - Einstellungen als Sektion statt Dialog (`hub_shell.dart:406`).
  - Breadcrumb klickbar machen oder entfernen.
  - Sidebar einklappbar, falls das Parkliste-Urteil angenommen wird.

### Epic QA — Qualität & Release

- **QA1 Gate-Automatisierung, Spike** (beschlossen, V0.9)
  - Headless `gnome-shell --wayland --virtual-monitor` auf `ubuntu-24.04`.
  - Nur Wayland-Hotkey (Test-Hook) und Clipboard.
  - Ergebnis: go/no-go. Kein Self-hosted-Runner.
- **QA2 Release-Workflow** (V0.10)
  - Tag `v*` → CI baut das deb → GitHub-Release mit Asset und Notes aus Conventional Commits.
  - Der Updater prüft den Asset-Digest (`updater.dart:124-147`).
  - Den Tag setzt nur Basti, nach der Gate-Tabelle.
- **QA3 Fixture-Bibliothek** (V1.0)
  - Echte Zorin-Ausgaben (geschwärzt) für alle Parser zusammenführen; Doku in `docs/wiki/Testing.md`.
  - Die Regel gilt schon ab FU2.

## Parkliste — Neubewertung 2026-09-23

Der Status bleibt **geparkt**. Eine Mini-Variante wird nur mit Bastis Go zu einem Teilplan.

| Thema (Bericht) | Nie-Liste | Urteil | Nie-Listen-konforme Mini-Variante | Beleg-Trigger für Wiedervorlage |
|---|---|---|---|---|
| 4.1 Hermes Web-UI/Client | kollidiert (Inline-WebView, FFI-Stack) | bleibt geparkt | Start-Knöpfe für `hermes dashboard`/`hermes desktop` im Agenten-Tile; steckt schon in DI3 | Hermes verliert seine eigene Oberfläche |
| 4.4 Wetter | frei | billigster Kandidat, aber ohne Missionsbezug | n2h-Kachel über Open-Meteo mit dem vorhandenen `http`, Ort manuell (keine Geolokalisierung), S | Basti will es im Dashboard; Open-Meteo-Nutzungsbedingungen im Spike belegen |
| 4.6 Notizen-Ausbau | Audio/Transkription sprengt das RAM-Budget (zram voll) und bringt Abhängigkeiten | Suche, Ordner und Capture stecken schon in TE3/WZ2 (ohne FTS5); der Rest bleibt geparkt | Markdown-Vorschau erst nach einem Spike zur Paketlage 2026 (Stand von `flutter_markdown` unverifiziert) | Quick Notes wird trotz Obsidian-Übergabe zum Haupteditor |
| 4.8 Dock / stufenlose Sidebar | frei | Sidebar einklappbar = S (DS4); das rechte Dock bleibt geparkt | Sidebar-Breite in `config.json` merken | zwei Screens brauchen belegbar Master-Detail nebeneinander |
| 4.9 Terminal+ | kollidiert (Emulator als Core, Syntaxhighlighting) | bleibt geparkt | Terminal-Übergabe: TE2-Modus `terminal`, im Dateimanager „Hier im Terminal öffnen", im Security-Check „Befehl im Terminal ausführen" | keiner absehbar |
| 4.10 Proton-Hub | kollidiert (Vollclient, Reverse Engineering, Pass/OTP) | bleibt geparkt | generischer VPN-Status (Interface aktiv?); steckt in DI1 | Proton veröffentlicht eine offizielle lokale Status-Schnittstelle |
| 4.11 Gmail/Odysseus | kollidiert (Vollclient in Stufe 1, Secrets) | bleibt geparkt | frühestens „Ungelesen: N" über die Odysseus-Scoped-API nach dem DI3-Muster; Token nur im Secret Service (`secret-tool`), nie im Klartext | Agenten-Tile hat sich bewährt und der Bedarf ist belegt |
| Handy-Push (neu, nicht gewählt) | frei | geparkt | optionales ntfy-Ziel im Wächter, standardmäßig aus | Wächter läuft und Basti vermisst Meldungen unterwegs |

## Überführung in Repo & GitHub (nach Freigabe)

1. **Repo-Fassung:**
   - `ausbauplan-v0.8.6-v1.0.md` im Repo-Root, nach dem Muster von `release-plaene-v0.8.1-v0.8.5.md`.
   - Die Evidenz wird generalisiert: keine Ports privater Dienste, keine IPs, keine `/home`-Pfade. Der
     Leak-Grep aus V0.8.5 Task 7 muss leer bleiben.
   - Dazu `meilensteine-v0.8.6-v1.0.md` und `issues-v0.8.6-v1.0.md`, wie bei der Vorserie, inklusive
     Zuordnungstabelle (siehe Verifikation).
2. **Commit:**
   - Lokal auf `hardening/0.8.x-browser-xdg`, getrennt von H1: „docs(planning): Ausbauplan V0.8.6–V1.0 …".
   - Kein Push ohne OK.
   - Die Memory `linux-master-assistant-projekt.md` bekommt einen Zeiger auf den Ausbauplan.
3. **GitHub (Toqsick/linux-assistant):**
   - Milestones: V0.8.6, V0.9, V0.10, V0.11, V0.12, V1.0.
   - Labels: `epic:{fu,lb,di,te,st,si,sp,wz,ds,qa}`, `tier:{core,qol,n2h}`, `size:{S,M,L}`, dazu die
     vorhandenen `gate:*`.
   - Ein Issue je Teilplan, z. B. `[V0.9] FU1 Modul-Registry`. Der Body enthält Ziel, Umfang, Abnahme,
     Abhängigkeiten und Tier.
   - Welle 1 wird ein einziges Issue mit Checkliste Q1–Q7.
   - Bestehende Issues verknüpfen: #27 → FU1, #25/#29/#30/#10 → DS, #26/#28 laut Bewertung.
   - Ein Sammel-Issue „Parkliste — Wiedervorlage nur mit Beleg".
   - Vor dem Anlegen zeige ich Basti die komplette Liste. Erst nach seinem OK läuft das `gh`-Skript (aus
     dem Scratchpad). Issue-Texte unterliegen demselben Leak-Grep.
4. **Beim Start jedes Teilplans:**
   - Einordnung nach brainstorming: bounded → Kurzdesign im Chat; architectural → Spec, dann
     `superpowers:writing-plans`.
   - Plan-Datei im Session-Planverzeichnis (außerhalb des Repos).
   - Umsetzung inline mit TDD (`superpowers:executing-plans`); subagent-driven nur auf Wunsch.
   - Ausnahmen: Welle 1 wird ein gemeinsamer Plan; FU3 und H1–H5 laufen mit Kurzdesign.

## Risiken

1. **FU2 wird größer als gedacht**, weil `linux.dart` mit der UI verflochten ist. Gegenmittel: Spike
   zuerst, nur probe-relevante Teile umziehen. Fallback: Probes vorerst im App-Prozess, Wächter später.
2. **Paketierung des CLI** (`dart compile exe` im deb-Build, CI-Zeit, Binärgröße): wird im FU2-Spike
   gemessen.
3. **Benachrichtigungs-Müdigkeit:** nur Übergänge nach Rot melden, Entprellung, Erinnerung optional.
4. **SI1 ändert den Root-Report** und berührt damit den privilegierten Pfad. Gegenmittel: Python-TDD,
   Invarianten-Review vor dem Merge, gleiche Exec-Pfade.
5. **l10n-Ratchet:** Jeder Teilplan liefert alle vier Sprachen, sonst ist der Test rot.
6. **Scope-Drift** weg vom persönlichen Cockpit: Jeder Teilplan nennt seinen Job und seinen Beleg. Ohne
   Beleg geht das Thema auf die Parkliste.
7. **Öffentliches Repo:** keine Basti-spezifischen Unit-Namen, Ports oder Pfade fest im Code; alles läuft
   über Defaults und `config.json`.

## Verifikation

- **Vollständigkeit des Master-Plans:** Jedes offene Fork-Issue hat genau ein Ziel (Teilplan, Welle 0,
  „bestehender Plan" oder „geschlossen"):
  - #31–#41 → V0.8.1–V0.8.5-Pläne
  - #42–#57 → Security-Fixplan
  - #25, #29, #30, #10 → DS
  - #27 → FU1
  - #26, #28 → Bewertung
- **UI-Befunde:**
  - I1 ✓ behoben; I5 (0.8.0) wird in H3 bestätigt.
  - I2, I4, M2, M4 → DS1 · I3, M1 → DS2 · I6 → Q1
  - M3 → WZ1 · M5 → FU2 · M6 → TE3
  - N1, N3 → DS4 · N2 → LB1/WZ1 · N4 → DS3
- **Roadmap und Parkliste:** Jeder V0.9-Punkt, jeder Nach-V0.8.X-Punkt und jedes Parkthema steht in
  „Bewertung" bzw. „Parkliste". Die Tabelle wird in `issues-v0.8.6-v1.0.md` festgeschrieben.
- **Nie-Liste:** Kein Teilplan kollidiert damit; die Grenzfälle belegt die Parkliste-Tabelle.
- **Je Teilplan:**
  - die fünf CI-Gates grün
  - die Abnahme auf Zorin 18.1 mit Beleg (Screenshot oder Journal)
  - `features.csv`-Check (21 Felder) bei neuen Zeilen
  - Leak-Grep bei Doku und Issues
- **Je Release:**
  - Gate-Tabelle aus `docs/wiki/Release-Process.md` (V0.8.5) in Wayland und X11.
  - `bash install.sh` führt Basti aus; Push und Tag erst nach seinem OK.
