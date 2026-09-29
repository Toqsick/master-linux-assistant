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
5. **Messbasis 0.0.3 offen:** der Flutter-vs-GTK-Vergleich (Roadmap
   0.0.3/0.4.x) hat noch keine `la_probe`-Messwerte; §7 bleibt bis Gate 1
   Platzhalter. Diese Baseline (§1, §2, §4) ist die Vergleichsgrundlage.

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
