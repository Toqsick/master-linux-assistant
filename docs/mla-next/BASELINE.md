# MLA-Next: Baseline

Erstellt am 2026-09-29 durch den automatisierten Gate-0-Lauf (Task 2, Scaffold-Verifikation)
auf dem Zielrechner. Evidence für PR #89. Screenshots liegen ausschließlich in `/tmp`
und sind nicht Teil des Repos.

## §1 Zorin-Matrix (Umgebung, 2026-09-29)

Rohausgaben 1:1 (Eingabe → Ausgabe):

```text
$ printf '%s' "$XDG_SESSION_TYPE"
wayland
$ printf '%s' "$XDG_CURRENT_DESKTOP"
zorin:GNOME
$ . /etc/os-release && echo "$PRETTY_NAME"
Zorin OS 18.1
$ python3 --version
Python 3.12.3
$ python3 -c "import gi; gi.require_version('Gtk','4.0'); gi.require_version('Adw','1'); from gi.repository import Gtk, Adw; print('GTK', Gtk.get_major_version(), Gtk.get_minor_version(), Gtk.get_micro_version(), '/ Adw', Adw.get_major_version(), Adw.get_minor_version(), Adw.get_micro_version())"
GTK 4 14 5 / Adw 1 5 0
$ pkg-config --modversion gtk4 libadwaita-1
Package gtk4 was not found in the pkg-config search path.
Perhaps you should add the directory containing `gtk4.pc'
to the PKG_CONFIG_PATH environment variable
Package 'gtk4', required by 'virtual:world', not found
Package 'libadwaita-1', required by 'virtual:world', not found
$ dart --version
Dart SDK version: 3.13.4 (stable) (Tue Sep 15 01:01:15 2026 -0700) on "linux_x64"
$ flutter --version | head -2
Flutter 3.47.5 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 6a19cca564 (vor 12 Tagen) • 2026-09-17 14:13:22 -0400
```

Ergänzend: `WAYLAND_DISPLAY=wayland-0`, `DISPLAY=:1` (XWayland verfügbar).

Bewertung: Die GI-Introspection (Runtime) liefert GTK 4.14.5 und libadwaita 1.5.0.
Die `-dev`-Pakete (`.pc`-Dateien für pkg-config) sind auf dem Desktop nicht
installiert — für den PyGObject-Lauf irrelevant, für künftige C-Builds relevant.

## §2 Gate 0 — automatisierte Ergebnisse (2026-09-29)

### py_compile

```text
$ cd prototype/gtk && python3 -m py_compile mla_app.py; echo $?
0
```

Exit 0, keine Ausgabe. Python-Version: 3.12.3.

### Wayland-Start

Kommando: `python3 mla_app.py >/tmp/mla-gate0-wayland.stdout 2>/tmp/mla-gate0-wayland.stderr &`,
danach `sleep 3` und `kill -0`.

- Kriterium „3 s am Leben": **erfüllt** — Meldung `lebt (Wayland, PID 154921)`.
  Anmerkung zu Messung und Beleglage: `$!` erfasste in diesem ersten Lauf die
  Wrapper-Shell statt direkt python3; `kill -0` belegte zum Prüfpunkt also das
  Leben der Wrapper-Shell (PID 154921), für das Child nur den indirekten Schluss.
  Die python3-PID (154923) ist im Implementer-Report
  (`.superpowers/sdd/task-2-report.md`) geführt, jedoch ohne `ps`-Zitat — ein
  direkter Prozessbeleg für den Wayland-Lauf liegt nicht vor. Nachträgliche
  Kontrollprüfung per `pgrep -af mla_app.py` (2026-09-29): kein
  `mla_app.py`-Prozess mehr aktiv — einziger Treffer war der Self-Match der
  prüfenden Shell; kein Restprozess. Die Aussage „der App-Prozess lief die
  vollen 3 s als python3" beruht damit auf dem X11-Direktbeleg unten (gleiche
  App; python3-PID 157124 per `ps` bestätigt) plus leerem stderr, nicht auf
  direktem `ps` während des Wayland-Laufs. Der X11-Lauf misst die python3-PID
  direkt.
- stderr: **0 Byte (leer) — kein Traceback.** stdout: 0 Byte.
- Screenshot: **nicht möglich.** `gnome-screenshot` ist nicht installiert; der
  D-Bus-Fallback `org.gnome.Shell.Screenshot.Screenshot` wird von GNOME (≥ 41)
  abgelehnt:
  `GDBus.Error:org.freedesktop.DBus.Error.AccessDenied: Screenshot is not allowed`.
  Nachholen der Aufnahme bleibt der manuellen Prüfung vorbehalten.

### X11-Start (`GDK_BACKEND=x11`)

Kommando: `GDK_BACKEND=x11 python3 mla_app.py >/tmp/mla-gate0-x11.stdout 2>/tmp/mla-gate0-x11.stderr &`,
danach `sleep 3` und `kill -0`.

- Kriterium „3 s am Leben": **erfüllt** — Meldung `lebt (X11, PID 157124)`;
  `ps` bestätigt `157124 python3 mla_app.py`.
- stderr: **0 Byte (leer) — kein Traceback.** stdout: 0 Byte.
- Screenshot: `/tmp/mla-gate0-x11.png` (PNG, 1368×1473, 26 275 Bytes). Aufnahme
  gezielt des App-Fensters (`xdotool search --name Prototyp` → Fenster-ID, dann
  `import -window <id>`); ein Root-Grab per `scrot` lieferte nur ein schwarzes
  XWayland-Root-Fenster und wurde verworfen. Inhalt: NavigationSplitView mit
  Dashboard / Systemmonitor / Backup-Cockpit / Security-Hub, goldfarbener
  „Dashboard"-Titel, KONTEXT-Panel rechts, dunkles Theme.

### Zusammenfassung

| Prüfung | Ergebnis |
| --- | --- |
| py_compile | PASS (Exit 0, keine Ausgabe) |
| Wayland-Start | PASS (≥ 3 s am Leben, stderr leer); Screenshot-Lücke dokumentiert |
| X11-Start | PASS (≥ 3 s am Leben, stderr leer, Screenshot vorhanden) |

Beleg zu VERIFY-Box 5 („unprivilegierter Start als normaler Nutzer,
Fixture-Only, Screenshots nur /tmp"): `prototype/gtk/mla_app.py` ist reine
Demo-Ware — ausschließlich Demo-Daten und GTK-/Adw-Widget-Aufbau, keine
Systemaufrufe im Code (Docstring dort: „Demo-Daten, keine Systemaktionen").
Beide Läufe starteten ohne sudo als normaler Nutzer; die Laufprotokolle
(Kommandos, PIDs, leere stdout/stderr) stehen oben bzw. in
`.superpowers/sdd/task-2-report.md`. Screenshots liegen ausschließlich in
`/tmp` (siehe Kopf dieser Datei).

## §3 Manuelle Checkliste (Basti) — offen

- [ ] Dashboard anklicken: Titel „Dashboard", rechte Details „Keine Live-Daten …"
- [ ] Systemmonitor anklicken: Titel „Systemmonitor", rechte Details („Datenadapter folgt")
- [ ] Backup-Cockpit anklicken: Titel „Backup-Cockpit", rechte Details, Backup-Status `unknown` („Ein Backup-Erfolg ist nicht belegt")
- [ ] Security-Hub anklicken: Titel „Security-Hub", rechte Details
- [ ] Fenster verkleinern/vergrößern (NavigationSplitView / Paned-Verhalten)
- [ ] Tastatur/Fokus (Sidebar-Navigation, Tab-Reihenfolge)
- [ ] Hell/Dunkel-Umschaltung
- [ ] Skalierung 100 % / 125 % / 150 %

## §4 Repo-Gates (Task 3/A0, 2026-09-29)

Lokal im Repo-Root auf `feature/mla-gtk-scaffold` (Working Tree sauber vor dem
Lauf), Reihenfolge wie CI. Umgebung siehe §1 (Dart 3.13.4, Flutter 3.47.5,
Python 3.12.3). Alle fünf Gates grün.

| Gate | Kommando | Exit | Kernausgabe |
| --- | --- | --- | --- |
| Version-Konsistenz | `bash tool/check-versions.sh` | 0 | `version 0.8.0 is consistent` |
| Dart-Format | `dart format --output=none --set-exit-if-changed lib test` | 0 | `Formatted 118 files (0 changed) in 0.30 seconds.` |
| Analyzer | `flutter analyze` | 0 | `No issues found! (ran in 9.5s)` |
| Dart-Tests | `flutter test` | 0 | `00:02 +184: All tests passed!` |
| Python-Tests | `cd additional/python && python3 -m unittest discover -s tests -t .` | 0 | `Ran 49 tests in 0.052s` / `OK` |

Frischlauf 2026-09-30: alle 5 Gates erneut Exit 0 (`flutter test` +184,
49 Python-Tests, Format/Analyze/check-versions ohne Befunde) — Details im
Task-7a-Report (Scratch, `.superpowers/sdd/task-7a-report.md`, nicht Teil
des Repos).

Rohausgaben 1:1 (Exit-Zeile jeweils ergänzt):

```text
$ bash tool/check-versions.sh
version 0.8.0 is consistent
(EXIT=0)

$ dart format --output=none --set-exit-if-changed lib test
Formatted 118 files (0 changed) in 0.30 seconds.
(EXIT=0)

$ flutter analyze
Upgrading analysis_options.yaml to exclude build and platform directories.
Analyzing linux-assistant...
No issues found! (ran in 9.5s)
(EXIT=0)

$ flutter test
…
00:02 +183: …/test/quick_notes_widget_test.dart: a failing load shows an error state, not an endless spinner
00:02 +184: All tests passed!
(EXIT=0)

$ cd additional/python && python3 -m unittest discover -s tests -t .
Ran 49 tests in 0.052s

OK
(EXIT=0)
```

Anmerkungen:

- Gemessene Dart-Testanzahl: **184** (Zähler `+184: All tests passed!`) —
  deckt sich mit der Handoff-Referenz von 184.
- `flutter analyze` modifizierte bei dem Lauf eigenmächtig
  `analysis_options.yaml` (fügte `analyzer.exclude: build/**, linux/**`
  ein; Meldung „Upgrading analysis_options.yaml …"). Die Änderung wurde
  unmittelbar nach dem Lauf per `git checkout -- analysis_options.yaml`
  zurückgenommen; der Commit dieses Tasks enthält nur diese Datei. Ob das
  Exclude fest übernommen werden sollte, ist ein offener Punkt (§6).

## §5 Evidence-Map (Task 3/A0, 2026-09-29)

Jede Zeile: Aussage → konkreter Beleg (Kommando + Kernausgabe bzw. Abschnitt
dieser Datei).

| Aussage | Beleg |
| --- | --- |
| PR #89 ist OPEN, Draft und MERGEABLE | `gh pr view 89 -R Toqsick/master-linux-assistant --json state,isDraft,mergeable` → `{"isDraft":true,"mergeable":"MERGEABLE","state":"OPEN"}` (2026-09-29) |
| Issues #59, #60, #63 sind offen und auf Milestone „V0.9 – Fundament & Lagebild" | `gh issue view 59/60/63 -R Toqsick/master-linux-assistant --json number,title,state,milestone` → jeweils `"state":"OPEN"`, Milestone Nr. 7 „V0.9 – Fundament & Lagebild"; Titel: #59 „FU2 Reiner Dart-Kern packages/la_core", #60 „FU1 Modul-Registry (#27)", #63 „LB2 Backup-Cockpit" |
| CI ist auf `feature/mla-gtk-scaffold` grün (PR-Run) | `gh run list -R Toqsick/master-linux-assistant --limit 3` → Run 36631724173, `completed success`, `pull_request`, Branch `feature/mla-gtk-scaffold`, 2026-09-29T21:12:38Z; die beiden älteren Runs (2026-09-24, `main`/`hardening/0.8.x-browser-xdg`) ebenfalls `success` |
| `version` ↔ `pubspec.yaml` ↔ `deb/DEBIAN/control` konsistent (0.8.0) | §4, Zeile Version-Konsistenz: `bash tool/check-versions.sh` → Exit 0, `version 0.8.0 is consistent` |
| Formatierungs-Gate erfüllt (118 Dateien, 0 geändert) | §4, Zeile Dart-Format: `dart format --output=none --set-exit-if-changed lib test` → Exit 0, `Formatted 118 files (0 changed)` |
| Analyzer ohne Befunde | §4, Zeile Analyzer: `flutter analyze` → Exit 0, `No issues found! (ran in 9.5s)` |
| Dart-Testsuite grün mit 184 Tests | §4, Zeile Dart-Tests: `flutter test` → Exit 0, `00:02 +184: All tests passed!` |
| Python-Testsuite des Root-Runners grün mit 49 Tests | §4, Zeile Python-Tests: `python3 -m unittest discover -s tests -t .` → Exit 0, `Ran 49 tests`, `OK` |
| Umgebung: Zorin OS 18.1, Wayland, GTK 4.14.5, Adw 1.5.0, Dart 3.13.4, Flutter 3.47.5 | §1 (Rohausgaben 1:1, 2026-09-29) |
| GTK-Scaffold kompiliert und startet unter Wayland und X11 (je ≥ 3 s am Leben, stderr leer) | §2 „Gate 0" inkl. Zusammenfassungstabelle; X11 mit direktem `ps`-Beleg (PID 157124), Wayland-Life-Beleg indirekt (siehe §2-Anmerkung) |
| Scaffold ist Fixture-Only (keine Systemaktionen) | §2 Belegabsatz zu VERIFY-Box 5 + `prototype/gtk/mla_app.py` (Docstring: „Demo-Daten, keine Systemaktionen") |

## §6 Offene Punkte (Stand 2026-09-29)

1. **GTK-Laufzeit nur Smoke-getestet:** verifiziert ist ausschließlich der
   3 s-Lebenstest (§2) — Wayland ohne direkten `ps`-Beleg während des Laufs,
   X11 mit. Keine Interaktion (Klicks, Fokus, Themewechsel, Skalierung) —
   die manuelle Checkliste §3 bleibt Basti vorbehalten und ist offen.
2. **Wayland-Screenshot-Lücke:** kein Bild des Wayland-Laufs
   (`gnome-screenshot` fehlt, D-Bus-API verweigert, §2); belegt ist nur der
   X11-Screenshot. Nachholen nur manuell.
3. **`-dev`-Pakete fehlen:** `gtk4.pc`/`libadwaita-1.pc` nicht installiert
   (§1) — für den PyGObject-Lauf irrelevant, für künftige C-Builds
   (GSettings-Schemas, Compile) relevant.
4. **`analysis_options.yaml`-Auto-Änderung:** `flutter analyze` fügt bei
   jedem Lauf `analyzer.exclude: build/**, linux/**` ein (§4); im A0-Lauf
   zurückgenommen. Entscheidung offen: Exclude dauerhaft übernehmen oder
   Analyzer-Verhalten ignorieren — vor dem nächsten Gate-Lauf klären, sonst
   bleibt der Working Tree nicht sauber.
5. **Messbasis 0.0.3 (aufgelöst 2026-09-30, teils):** die `la_probe`-Messwerte
   liegen vor (§7, Task-4/#59-Spike — §7 ist kein Platzhalter mehr); offen
   bleibt der Flutter-vs-GTK-Vergleich selbst (Roadmap 0.0.3/0.4.x). Diese
   Baseline (§1, §2, §4) ist die Vergleichsgrundlage.

## §7 la_probe-Messung (Task 4/#59-Spike, 2026-09-30)

Erste Messbasis für `la_probe` (Spike `packages/la_core`, Issue #59). Aufgenommen
am **2026-09-30 00:11 CEST** auf dem Zielrechner (§1-Umgebung). Toolchain:
`dart compile exe` mit dem Dart aus dem Flutter-SDK —
`dart --version` → `Dart SDK version: 3.13.4 (stable) (Tue Sep 15 01:01:15 2026 -0700) on "linux_x64"`,
`flutter --version | head -1` → `Flutter 3.47.5 • channel stable` (beide via
snap; Dart 3.13.4 ist die dem Flutter-3.47.5-Stand beiliegende SDK-Version).

### Paket-Gates (`cd packages/la_core`)

| Gate | Kommando | Exit | Kernausgabe |
| --- | --- | --- | --- |
| Abhängigkeiten | `dart pub get` | 0 | `Got dependencies!` |
| Tests (RED-Mutation) | `mv lib/src/probe.dart lib/src/probe.dart.bak && dart test` | 1 | `Error when reading 'lib/src/probe.dart': No such file or directory` … `Some tests failed.` |
| Tests (GREEN) | `dart test` (nach Restore) | 0 | `00:00 +3: All tests passed!` |
| Analyzer | `dart analyze` | 0 | `No issues found!` |
| Format | `dart format --output=none --set-exit-if-changed .` | 0 | `Formatted 4 files (0 changed) in 0.02 seconds.` |

RED-Nachweis (Mutation statt klassischem RED, da die Implementation aus dem
unterbrochenen Vorlauf bereits existierte) — Auszug 1:1:

```text
$ mv lib/src/probe.dart lib/src/probe.dart.bak && dart test
00:00 +0: loading test/probe_test.dart
00:00 +0 -1: loading test/probe_test.dart [E]
  Failed to load "test/probe_test.dart":
  lib/la_core.dart:1:1: Error: Error when reading 'lib/src/probe.dart': No such file or directory
  export 'src/probe.dart';
  ^
  test/probe_test.dart:6:34: Error: Undefined name 'ProbeLevel'.
  …
00:00 +0 -1: Some tests failed.
(EXIT=1)
```

GREEN 1:1:

```text
$ dart test
00:00 +0: loading test/probe_test.dart
00:00 +0: test/probe_test.dart: ProbeResult.describe enthaelt Level und Key
00:00 +1: test/probe_test.dart: ProbeLevel deckt ok/warn/crit/unknown ab
00:00 +2: test/probe_test.dart: SelfProbe liefert ok mit key probe.self
00:00 +3: All tests passed!
(EXIT=0)
```

### Kompilieren + Headless-Lauf

```text
$ cd packages/la_core && dart compile exe bin/la_probe.dart -o /tmp/la_probe
Generated: /tmp/la_probe
(EXIT=0)

$ env -u DISPLAY -u WAYLAND_DISPLAY /tmp/la_probe --version
la_probe 0.0.1-spike.1 (dart 3.13.4 (stable) (Tue Sep 15 01:01:15 2026 -0700) on "linux_x64")
(EXIT=0)

$ env -u DISPLAY -u WAYLAND_DISPLAY /tmp/la_probe
ok:probe.self @ 2026-09-30T00:11:41.458200
(EXIT=0)
```

Kein Display nötig (DISPLAY und WAYLAND_DISPLAY entfernt) — der AOT-Binary
läuft headless; reiner Dart-Kern, keine GTK-/Flutter-Typen.

### Messwerte

| Messgröße | Wert |
| --- | --- |
| Binärgröße (`stat -c '%s' /tmp/la_probe`) | **6 547 240 Bytes** (≈ 6,24 MiB) |
| Startzeit (`--version`, 5 Läufe, je frischer Prozess) | 3 / 3 / 3 / 3 / 3 ms |
| **Median-Startzeit** | **3 ms** |
| Datum/Uhrzeit der Messung | 2026-09-30 00:11:50 CEST |
| Dart-Version (compile + Lauf) | 3.13.4 (stable), linux_x64 |

Rohausgaben 1:1:

```text
$ stat -c '%s' /tmp/la_probe
6547240

$ s=$(date +%s%N); env -u DISPLAY -u WAYLAND_DISPLAY /tmp/la_probe --version >/dev/null; e=$(date +%s%N); echo $(( (e-s)/1000000 )) ms
3 ms   # run1
3 ms   # run2
3 ms   # run3
3 ms   # run4
3 ms   # run5
```

Einordnung: Die 6,2-MiB-Binärgröße ist der AOT-Runtime-Overhead eines
minimalen Dart-Executables (Fixturm-Basis für die 0.0.3/0.4.x-Vergleiche);
die 3-ms-Startzeit bestätigt die Headless-Tauglichkeit des reinen Dart-Kerns.
Die Messwerte sind die Vergleichsbasis für Gate 1 (Registry #60) und die
Flutter-vs-GTK-Messbasis (löst den offenen Punkt 5 aus §6 teilweise ein — die
`la_probe`-Messwerte existieren nun; der Flutter/GTK-Vergleich selbst bleibt
offen).

## §8 Flutter-Release vs. GTK-Shell (Issue #95, 2026-09-30)

Messprotokoll der #95-Baselinemessung nach Issue-#95-Abnahme: Flutter-Release-Build
gegen die GTK-Shell (statisches Demo-Dashboard) auf demselben Zielrechner, je
Backend Wayland und X11. Ergänzt §1 und die `la_probe`-Referenz aus §7; die
Flutter-vs-GTK-Entscheidung selbst ist 0.4.x-Aufgabe — dieser Abschnitt liefert
nur die Vergleichsbasis (Rohwerte, Mediane, Grenzen), keine Empfehlung.

### Rahmen

| Messfenster | Wert |
| --- | --- |
| Task 1 — Flutter-Zellen | 2026-09-30, 07:41–07:58 MESZ (Release-Build 07:36:01+02:00; Probe-Läufe 07:41:28–07:50:16; serielle Zellen 07:51:54–07:57:59+02:00) |
| Task 2 — GTK-Zellen | 2026-09-30, 08:34–08:45 MESZ (08:34:41–08:44:54+02:00; Probe-Läufe 08:34:41–08:36:08, serielle Zellen 08:37:50–08:44:54) |

Rechner (frisch erhoben 2026-09-30T09:13:15+02:00, ausschließlich unprivilegiert;
Identifikation über CPU/RAM/Kernel wie bei den #94-Fixtures — kein Hostname,
keine Nutzernamen):

| Messung | Wert |
| --- | --- |
| CPU (`grep -m1 'model name' /proc/cpuinfo`) | 13th Gen Intel(R) Core(TM) i7-13620H |
| RAM (`grep MemTotal /proc/meminfo`) | 16 066 996 kB |
| Kernel (`uname -r`) | 7.0.0-34-generic |
| `getconf CLK_TCK` | 100 |
| Sitzung | `XDG_SESSION_TYPE=wayland`, `WAYLAND_DISPLAY=wayland-0`, `DISPLAY=:1` (XWayland) |
| Referenz | Zorin-Matrix §1 (2026-09-29): Zorin OS 18.1, `zorin:GNOME` |

Versionen (aus den Task-Reports übernommen, nicht neu gemessen): Flutter
3.47.5 (stable) und Dart SDK 3.13.4 (Task 1, vor dem Build 07:36:01); GTK 4 14 5 /
Adw 1 5 0 via GI-Introspection (Kommando wörtlich aus §1) und Python 3.12.3
(Task 2; Python frisch bestätigt). Hinweis: der Task-2-Report §1 führt MemTotal
abweichend mit 9 071 472 640 Bytes; die obige Rechner-Box folgt der frischen
Erhebung (16 066 996 kB) — die Messwerte sind davon unberührt.

### Messdesign

Vier Zellen {Flutter-Release, GTK-Shell} × {Wayland, X11}; je Zelle 5 Startup-
und 5 Steady-Läufe, strikt sequenziell.

| Zelle | Artefakt | Startkommando | Startzustand |
| --- | --- | --- | --- |
| `flutter-wayland` | `build/linux/x64/release/bundle/linux-assistant` | Binär direkt (nativer Wayland-Client) | Dashboard mit aktivem 3-s-Stat-Poll — echte Systemdaten (df/ps/uptime/free/loadavg) |
| `flutter-x11` | dito | `GDK_BACKEND=x11 <Binär>` | dito (über XWayland `:1`) |
| `gtk-wayland` | `prototype/gtk/mla_app.py` (3 924 Bytes) | `python3 prototype/gtk/mla_app.py` (cwd Repo-Root) | statisches Demo-Dashboard, kein Refresh-Timer — `grep -nE 'timeout_add\|GLib\.timeout\|Thread\|subprocess' prototype/gtk/mla_app.py` → keine Treffer |
| `gtk-x11` | dito | `GDK_BACKEND=x11 python3 prototype/gtk/mla_app.py` | dito |

Gemessen wird stets der App-Prozess selbst — direkter Launch ohne Shell-Wrapper,
`$!` ist die App-PID. Zwischen den Läufen: SIGTERM ans eigene Kind (max. 10 s
warten, sonst SIGKILL nur ans eigene Kind), auf Exit warten, 2 s Cooldown.

Wesentliche Messkommandos (1:1 aus den Helferskripten; Abbruchwachen für
60-s-Timeout und vorzeitigen Process-Exit ausgelassen):

Startup Wayland — erster Wayland-Protokollverkehr (Proxy-Ereignis, vor First-Frame):

```text
: > "$WL_LOG"
s=$(date +%s%N)
WAYLAND_DEBUG=1 "$BIN" 2>>"$WL_LOG" &   # GTK: WAYLAND_DEBUG=1 python3 "$APP" 2>>"$WL_LOG" &
APP_PID=$!
while [ ! -s "$WL_LOG" ]; do sleep 0.005; done
e=$(date +%s%N); echo $(( (e-s)/1000000 )) ms
```

`WAYLAND_DEBUG=1` lässt libwayland-client jeden Protokollverkehr auf stderr
drucken; erste Zeile ≈ Verbindungs-/Registry-Phase. Die Perturbation (fprintf
je Nachricht) ist dokumentiert; die Variable ist nur in den 5 Startup-Läufen
je App gesetzt, nie in den Steady-Läufen. Erstes Log-Ereignis war jeweils
`wl_display@1.get_registry(new id wl_registry@2)` (echter Protokollverkehr,
keine Python-Warning; bei GTK je Lauf belegt). Umfang des Logs beim ersten
Poll-Treffer: Flutter 3 536–3 817 Bytes, GTK konstant 8 255 Bytes (Probe 5 092 —
Auflösungs-/Timing-Varianz des ersten Poll-Treffers, kein Protokollunterschied).

Startup X11 — Fenster mit passendem Namen im X-Baum:

```text
s=$(date +%s%N)
GDK_BACKEND=x11 "$BIN" >/dev/null 2>&1 &   # GTK: GDK_BACKEND=x11 python3 "$APP" >/dev/null 2>&1 &
APP_PID=$!
while ! xdotool search --name "linux.assistant" >/dev/null 2>&1; do sleep 0.01; done   # GTK: --name "Prototyp"
e=$(date +%s%N); echo $(( (e-s)/1000000 )) ms
```

Harte Vorbedingung je Lauf (Selbst-Match der prüfenden Shell über
Klammerausdrücke ausgeschlossen; Fremdinstanzen werden nie beendet — bei
Verstoß 3× 30 s warten, dann Abbruch mit Exit 2):

```text
pgrep -af '[l]inux-assistan[t]|[l]inux_assistan[t]|[m]la_app[.]py'   # muss leer sein
xdotool search --name '[Ll]inux.[Aa]ssistant'                        # nur X11, muss leer sein — GTK-Zellen: 'Prototyp'
```

Steady — 10 s Settle, 20 Samples @ 1 Hz, CPU-Fenster 20 s (ohne `WAYLAND_DEBUG`):

```text
"$BIN" >/dev/null 2>&1 & APP_PID=$!                 # GTK analog
sleep 10                                            # Settle
cpu0="$(awk '{print $14+$15}' "/proc/$APP_PID/stat")"
for i in $(seq 1 20); do
  grep -E 'VmRSS|VmHWM' "/proc/$APP_PID/status"     >> "$sample_file"
  grep '^Pss:'          "/proc/$APP_PID/smaps_rollup" >> "$sample_file"
  sleep 1
done
cpu1="$(awk '{print $14+$15}' "/proc/$APP_PID/stat")"
kill "$APP_PID"; wait "$APP_PID" 2>/dev/null || true; sleep 2   # SIGTERM, Exit, Cooldown
```

- **CPU:** `cpu_percent_eines_Kerns = (cpu1 − cpu0) / (CLK_TCK × 20) × 100` mit
  `CLK_TCK=100` (utime+stime in Ticks; comm beider Apps ohne Leerzeichen —
  Feldposition sicher).
- **RAM:** je Lauf Median der 20 Samples (`VmRSS`, `Pss`); `VmHWM` = letzter Sample.
- **Median-Regel:** `sort -n`; bei gerader Anzahl Mittel der beiden mittleren
  Werte (betroffen: PSS flutter-x11 Lauf 1: 90 883,5 kB).
- **Umgebung je Zelle protokolliert:** `date -Is`, Sitzungsvariablen,
  `cat /proc/loadavg` vor/nach der Zelle (Werte in den Zell-Unterschriften unten).

Vollständige Helferskripte (`/tmp/mla95-measure.sh`, `/tmp/mla95-measure-gtk.sh`)
und die 20er-Roh-Sample-Serien (`/tmp/mla95-steady-*.txt`, `/tmp/mla95-gtk-steady-*.txt`)
liegen nur in den Session-Scratch-Reports (`.superpowers/sdd/task-1-report.md`,
`task-2-report.md`; gitignored, ephemeral). Dieser Abschnitt führt alle
Startup-Einzelwerte und die je-Lauf-Steady-Mediane selbst.

### Errata und Prädikate (drei Plan-Pins korrigiert, von Reviewern A/B verifiziert)

| # | Plan-Pin | Realität / gemessene Umsetzung |
| --- | --- | --- |
| 1 | Artefakt `…/bundle/linux_assistant` | Real **`linux-assistant`** (Bindestrich); comm ebenfalls; pgrep-/ERE-Muster entsprechend |
| 2 | X11-Poll `xdotool search --name "Linux Assistant"` | `WindowManager.instance.setTitle("Linux Assistant")` (`lib/main.dart:27`) greift unter X11 nicht — `WM_NAME`/`_NET_WM_NAME` des Dev-Builds sind `linux-assistant`/`linux_assistant`; gemessen wird das ERE `linux.assistant`, die Vorbedingung prüft breiter `[Ll]inux.[Aa]ssistant`; der erste Probe-Lauf lief in den 60-s-Timeout (BLOCKED, außerhalb der Serie) |
| 3 | `grep VmPss /proc/<pid>/smaps_rollup` | Key ist **`Pss:`** (ohne `Vm`-Präfix) — gemessen `grep '^Pss:'` (Anker vermeidet `Pss_Dirty`/`Pss_Anon`/…) |

Prädikate je Zelle: Flutter-X11-Startup-Poll = ERE `linux.assistant`; GTK-X11-Startup-Poll
= `Prototyp` (Fenstertitel „Master Linux Assistant · Prototyp" — traf in allen 6
X11-Läufen sofort; Erratum 2 betrifft GTK nicht); PSS-Schlüssel durchgängig `^Pss:`.

### Zelle flutter-wayland

Umgebung `XDG_SESSION_TYPE=wayland`, `DISPLAY=:1`, `WAYLAND_DISPLAY=wayland-0`.
Zelle 07:51:54+02:00 (loadavg 4.89 4.35 3.43) bis 07:54:48+02:00 (4.99 4.63 3.70).

Startup (5-ms-Poll auf `/tmp/mla95-wl.log`):

| Lauf | startup_ms | app_pid | wl_log_bytes |
| --- | --- | --- | --- |
| 1 | 30 | 256729 | 3536 |
| 2 | 34 | 256839 | 3769 |
| 3 | 29 | 257037 | 3817 |
| 4 | 23 | 257231 | 3817 |
| 5 | 25 | 257281 | 3769 |

Zellen-Median Startup: **29 ms** (sortiert: 23, 25, 29, 30, 34).

Steady:

| Lauf | RSS-Median (kB) | PSS-Median (kB) | VmHWM (kB) | cpu0 | cpu1 | cpu_percent |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 161524 | 89740 | 164956 | 996 | 3020 | 101.20 |
| 2 | 161216 | 89720 | 164688 | 998 | 3019 | 101.05 |
| 3 | 161472 | 89775 | 164980 | 996 | 3018 | 101.10 |
| 4 | 161216 | 89676 | 164440 | 997 | 3021 | 101.20 |
| 5 | 161580 | 89749 | 164904 | 998 | 3022 | 101.20 |

Zellen-Mediane: RSS **161 472 kB** · PSS **89 740 kB** · HWM **164 904 kB** ·
CPU **101.20 %** eines Kerns.

### Zelle flutter-x11

Identische Sitzung; App via `GDK_BACKEND=x11` über XWayland `:1`.
Zelle 07:55:05+02:00 (loadavg 4.65 4.57 3.70) bis 07:57:59+02:00 (5.43 5.37 4.18).

Startup (10-ms-Poll, Prädikat ERE `linux.assistant` — Erratum 2):

| Lauf | startup_ms | app_pid |
| --- | --- | --- |
| 1 | 37 | 265298 |
| 2 | 39 | 265403 |
| 3 | 72 | 265515 |
| 4 | 37 | 265745 |
| 5 | 41 | 265792 |

Zellen-Median Startup: **39 ms** (sortiert: 37, 37, 39, 41, 72). Ausreißer Lauf 3
(72 ms) fiel mit ansteigender Systemlast zusammen (1-min-loadavg erreichte 8.04
am Ende des steady-Laufs 2); der Rohwert bleibt in der Serie, der Median ist
nicht betroffen.

Steady:

| Lauf | RSS-Median (kB) | PSS-Median (kB) | VmHWM (kB) | cpu0 | cpu1 | cpu_percent |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 162968 | 90883.5 | 166592 | 996 | 3014 | 100.90 |
| 2 | 163232 | 91302 | 166140 | 991 | 3012 | 101.05 |
| 3 | 163100 | 91393 | 166420 | 997 | 3021 | 101.20 |
| 4 | 163148 | 91340 | 166720 | 996 | 3016 | 101.00 |
| 5 | 163240 | 91415 | 166420 | 997 | 3014 | 100.85 |

Zellen-Mediane: RSS **163 148 kB** · PSS **91 340 kB** · HWM **166 420 kB** ·
CPU **101.00 %** eines Kerns.

### Zelle gtk-wayland

Identische Sitzung. Zelle 08:37:50+02:00 (loadavg 1.87 2.13 2.66) bis
08:41:12+02:00 (2.70 2.38 2.64).

Startup (5-ms-Poll auf `/tmp/mla95-gtk-wl.log`):

| Lauf | startup_ms | app_pid | wl_log_bytes |
| --- | --- | --- | --- |
| 1 | 76 | 310184 | 8255 |
| 2 | 70 | 310246 | 8255 |
| 3 | 57 | 310326 | 8255 |
| 4 | 63 | 310357 | 8255 |
| 5 | 63 | 310407 | 8255 |

Zellen-Median Startup: **63 ms** (sortiert: 57, 63, 63, 70, 76).

Steady:

| Lauf | RSS-Median (kB) | PSS-Median (kB) | VmHWM (kB) | cpu0 | cpu1 | cpu_percent |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 187520 | 101347 | 187520 | 36 | 36 | 0.00 |
| 2 | 187972 | 101093 | 187972 | 38 | 38 | 0.00 |
| 3 | 187836 | 101166 | 187836 | 37 | 37 | 0.00 |
| 4 | 188096 | 101161 | 188096 | 36 | 36 | 0.00 |
| 5 | 188076 | 101327 | 188076 | 38 | 38 | 0.00 |

Zellen-Mediane: RSS **187 972 kB** · PSS **101 166 kB** · HWM **187 972 kB** ·
CPU **0.00 %** eines Kerns.

### Zelle gtk-x11

Identische Sitzung. Zelle 08:41:26+02:00 (loadavg 2.63 2.38 2.64) bis
08:44:54+02:00 (2.01 2.13 2.48).

Startup (10-ms-Poll, Prädikat `Prototyp`):

| Lauf | startup_ms | app_pid |
| --- | --- | --- |
| 1 | 316 | 314505 |
| 2 | 277 | 314589 |
| 3 | 285 | 314702 |
| 4 | 284 | 314790 |
| 5 | 298 | 314902 |

Zellen-Median Startup: **285 ms** (sortiert: 277, 284, 285, 298, 316).

Steady:

| Lauf | RSS-Median (kB) | PSS-Median (kB) | VmHWM (kB) | cpu0 | cpu1 | cpu_percent |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 187884 | 101749 | 187884 | 37 | 37 | 0.00 |
| 2 | 187772 | 101428 | 187772 | 37 | 37 | 0.00 |
| 3 | 188060 | 101562 | 188060 | 35 | 35 | 0.00 |
| 4 | 188216 | 101800 | 188216 | 37 | 37 | 0.00 |
| 5 | 187996 | 101683 | 187996 | 37 | 37 | 0.00 |

Zellen-Mediane: RSS **187 996 kB** · PSS **101 683 kB** · HWM **187 996 kB** ·
CPU **0.00 %** eines Kerns.

### Zellen-Mediane über alle vier Zellen

| Zelle | Startup-Median | RSS (kB) | PSS (kB) | HWM (kB) | CPU (% eines Kerns) |
| --- | --- | --- | --- | --- | --- |
| flutter-wayland | 29 ms¹ | 161 472 | 89 740 | 164 904 | 101.20 |
| flutter-x11 | 39 ms² | 163 148 | 91 340 | 166 420 | 101.00 |
| gtk-wayland | 63 ms¹ | 187 972 | 101 166 | 187 972 | 0.00 |
| gtk-x11 | 285 ms² | 187 996 | 101 683 | 187 996 | 0.00 |

¹ erster Wayland-Protokollverkehr (Proxy-Ereignis, vor First-Frame).
² Fenster mit passendem Namen im X-Baum (xdotool ohne `--onlyvisible`, nicht
  strikt „gemappt sichtbar").

### Befunde

Nüchterne Befunde, keine Empfehlung — die Flutter-vs-GTK-Entscheidung ist
0.4.x-Aufgabe; #95 liefert die Vergleichsbasis für #105.

**(a) CPU-Dauerrendern Flutter:** Alle 10 Flutter-Steady-Läufe zeigen ~101 %
eines Kerns (100.85–101.20 %): der Release-Build rendert im Ruhezustand
kontinuierlich (Impeller; App-Log „Using the Impeller rendering backend
(OpenGLESSDF)"). Die CPU-Formel trägt eine konstante ~+1 %-Verzerrung
(Sample-Zeit + `sleep 1` verlängern das reale Fenster auf ~20,2 s, der Nenner
bleibt fix 20 s) — sie betrifft nur Flutter. Die GTK-Shell verbraucht im
Fixture-Startzustand 0 CPU-Ticks: cpu0 == cpu1 in allen 10 Steady-Läufen
(statisches Demo-Dashboard ohne Timer, grep-Beleg oben).

**(b) Startup backendintern vergleichen:** direkt vergleichbar ist X11↔X11 —
identisches Ereignis „Fenster mit passendem Namen im X-Baum": Flutter 39 ms
vs. GTK 285 ms. Wayland↔Wayland nur mit Proxy-Vorbehalt (29 vs. 63 ms —
„erster Protokollverkehr" ≠ First-Frame). Backendübergreifend wird nicht
gerankt.

**(c) X11-Aufschlag** (backendintern): GTK +222 ms (63 → 285), Flutter
+10 ms (29 → 39).

**(d) RSS/PSS** (Wayland-Mediane): Flutter 161 472 kB RSS / 89 740 kB PSS;
GTK 187 972 kB / 101 166 kB. PSS ist umgebungsvariabel und sharer-abhängig;
die GTK-RSS enthält die geteilten Python+GI+GTK-Runtime-Seiten (GTK-PSS liegt
~87 MB unter GTK-RSS). In den GTK-Zellen ist RSS/PSS zudem fast
backendunabhängig (Δ < 0,2 %).

**(e) Lastasymmetrie** (korrigierte Richtung, Task-2-Report §7): Task 1 lief
unter 1-min-loadavg 4.6–8.0 (Zellgrenzen 4.65–5.43; 15-min 3.4–4.2), Task 2
unter 1.62–2.92 (15-min 2.5–2.7) — gleich gelagert (keine künstliche Last,
stets nur eine App-Instanz aktiv), aber nicht lastgleich. Hohe Last verlängert
Startup-Zeiten, nie umgekehrt: der gemessene Flutter-Startup-Vorteil ist damit
eine **konservative Untergrenze**; die GTK-Aufstellung war schonend (GTK unter
den milderen Bedingungen gemessen). Geltungsbereich: Last wirkt vor allem auf
Startup-Zeiten und CPU-Konkurrenz, praktisch nicht auf RSS/PSS; die
Prozess-CPU ist per `/proc/<pid>/stat` gemessen (Verzerrungsrichtung ebenfalls
eher Untergrenze). Ob die GTK-Zellen bei Last ~5–8 (Task-1-Bedingung) gleich
ruhig reagieren wie bei ~2, ist aus diesen Daten allein nicht belegbar.

**(f) Größen** (nur Angabe, kein Ranking): Flutter-Bundle
`build/linux/x64/release/bundle` 26 885 925 Bytes; Flutter-Binary
`linux-assistant` 23 664 Bytes; `mla_app.py` 3 924 Bytes. Unterschiedliche
Natur (das Python-Skript braucht Python+GI-Runtime); `la_probe` (§7:
6 547 240 Bytes, 3 ms Median-Startzeit) bleibt separater Referenzpunkt.

### «Nicht verglichen»

1. **GTK-Fixture-Last:** kein Datenadapter/Refresh-Timer in `mla_app.py`
   (grep-Beleg) — hängt am #92-Rest; die GTK-Zellen messen den
   Fixture-**Startzustand**.
2. **Flutter-Last-Zustände** (z. B. Systemmonitor-1-s-Sampler): nur per
   UI-Interaktion erreichbar, unter Wayland nicht fernsteuerbar; bewusst keine
   xdotool-Koordinatenklicks in die Baseline (Validitätsrisiko).
   User-Entscheidung 2026-09-30 «Reduziert messen».
3. **Wayland-Startzeit = erster Protokollverkehr ≠ First-Frame** (X11 misst
   Fenster-Erscheinen) → Startzeiten backend-übergreifend nicht direkt
   vergleichbar.
4. **Datenquellen nicht identisch:** Flutter pollt echte Systemdaten
   (df/ps/uptime/free/loadavg, 3 s), GTK zeigt statische Demo-Fixtures.
5. **Kein Binärgrößen-Ranking:** Flutter-Bundle vs. Python-Skript haben
   unterschiedliche Natur (Skript braucht Python+GI-Runtime) — nur Angabe;
   `la_probe` (§7: 6 547 240 Bytes, 3 ms) bleibt separater Referenzpunkt.
6. **Kein Debug-Build, keine Langlauf-/Memory-Growth-Aussage** (Langlauf ist
   0.1.x-Aufgabe).
7. Das X11-Poll-Ereignis ist „Fenster mit passendem Namen existiert im
   X-Baum" (xdotool ohne `--onlyvisible`), nicht strikt „gemappt sichtbar"
   (Erratum 2).
8. Die Probe-Läufe (je Task 4–5, Zeiten in den Task-Reports) waren
   Skript-Validierung außerhalb der 5+5-Serien und fließen in keine Mediane
   ein.
