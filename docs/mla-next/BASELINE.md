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
  Anmerkung zur Messung: `$!` erfasste in diesem ersten Lauf die Wrapper-Shell
  statt direkt python3 (App-Prozess war python3, PID 154923); der App-Prozess lief
  nachweislich über die 3 s hinaus und wurde anschließend per gespeicherter PID
  beendet. Der X11-Lauf unten misst die python3-PID direkt.
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

## §3 Manuelle Checkliste (Basti) — offen

- [ ] Dashboard anklicken: Titel „Dashboard", rechte Details „Keine Live-Daten …"
- [ ] Systemmonitor anklicken: Titel „Systemmonitor", rechte Details („Datenadapter folgt")
- [ ] Backup-Cockpit anklicken: Titel „Backup-Cockpit", rechte Details, Backup-Status `unknown` („Ein Backup-Erfolg ist nicht belegt")
- [ ] Security-Hub anklicken: Titel „Security-Hub", rechte Details
- [ ] Fenster verkleinern/vergrößern (NavigationSplitView / Paned-Verhalten)
- [ ] Tastatur/Fokus (Sidebar-Navigation, Tab-Reihenfolge)
- [ ] Hell/Dunkel-Umschaltung
- [ ] Skalierung 100 % / 125 % / 150 %

## §4 Repo-Gates (folgt — Task 3/A0)

## §5 Evidence-Map (folgt — Task 3/A0)

## §6 Offene Punkte (folgt — Task 3/A0)

## §7 la_probe-Messung (folgt — Gate 1)
