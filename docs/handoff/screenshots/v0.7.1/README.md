# V0.7.1-Baseline-Screenshots (2026-09-10)

Aufgenommen von der **installierten v0.7.1** (deb-Build vom 30.07.2026, commit c86c855)
auf Zorin OS 18.1. App dafür temporär unter `GDK_BACKEND=x11` neu gestartet
(Fenster-Capture via ImageMagick `import -window`, Navigation via `xdotool`).
Laufende Instanz danach im Normalzustand (Wayland) wiederhergestellt.

## Inventar

| Datei | Inhalt | Theme | Qualität/Anmerkung |
|---|---|---|---|
| `00-start_dark_01.png` | Dashboard (Systemstatus-Tiles + Schnellaktionen) | dark | ✅ vision-verifiziert |
| `00b-dashboard_light.png` | Dashboard | light | ✅ Helligkeit verifiziert (Ø-RGB 206,203,195) |
| `01-suche_dark.png` | Suche-Sektion (Embedded-Suche im Hub) | dark | ✅ |
| `01-suche_light.png` | Suche-Sektion | light | ✅ |
| `02-speicher_dark.png` | Speicher-Sektion (Datenträger, Bereinigungs-Einstiege) | dark | ✅ |
| `02-speicher_light.png` | Speicher-Sektion | light | ✅ |
| `03-gesundheit_dark.png` | Gesundheit-Sektion (Prozesstabelle, CPU/RAM, Partitionsliste) | dark | ✅ |
| `03-gesundheit_light.png` | Gesundheit-Sektion | light | ✅ |
| `04-sicherheit_dark.png` | Sicherheit-Sektion, Scan läuft (Spinner) | dark | ✅ Auto-Scan beim Betreten |
| `04b-sicherheit_nach-scan_dark.png` | **Bug-Zustand:** Fehlerseite nach Root-Auth | dark | ✅✅ Kern-Evidence (s. u.) |
| `04c-sicherheit-fehlerseite2_dark.png` | Fehlerseite, zweiter Zustand | dark | ✅ |
| `04-sicherheit_light.png` | — | — | ❌ entfernt (war Dark-Duplikat) |
| `05-einstellungen_light.png` | Settings-Dialog (3 Kacheln: Verteilung/Suche/Erscheinungsbild), Dialog-Fläche hell | mixed* | ✅ vision-verifiziert (Dialog) |
| `05b-erscheinungsbild_light.png` | vermutlich Appearance-Screen (Kachel-Klick worked, Pixel-Diff zu 05 signifikant) | light | ⚠️ unverifiziert (Vision-MCP instabil) |
| `05-einstellungen_dark.png` | — | — | ❌ entfernt (Fake: Input war blockiert, Duplikat der Fehlerseite) |
| `06-launcher_dark.png` | — | — | ❌ entfernt (Fake-Duplikat) |
| `06-suche-fokus_light.png` | Suche-Sektion mit Fokus (nach Alt+Q) | light | ✅ Alt+Q-Fokus-Verhalten dokumentiert |

\* Dialog-Oberfläche ist in beiden Themes hell-creme; Hintergrund hinter Dialog war dark.

## Der dokumentierte Bug (Kern-Evidence)

`04b` zeigt den Zustand **nach erfolgreicher Passwort-Eingabe**: polkit-Auth
erfolgreich (journal 21:53:19: „successfully authenticated as unix-user:<user>"),
`check_security.py` lief als Root, crashte ~1 s später mit `IndexError` an der
deb822-Datei `/etc/apt/sources.list.d/graphics-drivers-ubuntu-ppa-noble.sources`,
und die UI zeigt danach falsch:

> „Das hat leider nicht funktioniert. Du benötigst Root-Rechte, um die
> Sicherheits-Überprüfung durchzuführen." + „Erneut versuchen"

Fix: `additional/python/apt_sources.py` (deb822-Parser) — im 0.8.0-Zweig vorhanden.

## Bekannte Lücken (bewusst in Kauf genommen)

- **Security-Sektion in Light:** nicht aufgenommen — jeder Sektionsbesuch triggert
  den Auto-Scan → weiteren Polkit-Passwortdialog. Nicht zumutbar während der
  Aufnahme; Dark-Set + Fehlerzustand sind vollständig dokumentiert.
- **Standalone-Launcher** (Vollbild-Suche ohne Hub-Sidebar): kein verifizierter
  Shot (Input-Blockade durch modalen Settings-Dialog + GNOME-Shell-Grabs).
  Struktur in `lib/layouts/main_screen/main_search.dart` dokumentiert (Phase B).
- **Appearance-Screen** (`05b`): vermutlich korrekt, aber ohne Vision-Verifikation.
- Werkzeug-Screens (Disk-Cleaner, Updater, Leistungsmodus): bewusst weggelassen —
  Live-Klicken in Admin-Tools während der Besitzer am Rechner sitzt ist zu riskanter
  Nebenwirkungen (destruktive Dialoge).

## Technische Notizen für Wiederholung

- Flutter-Fenster ist Wayland-nativ → `scrot`/`xdotool` greifen nicht; `GDK_BACKEND=x11`
  beim Start erzwingen X11-Client-Verhalten (Fenster-ID via `xdotool search --name "Linux Assistant"`).
- Modal-Dialog + GNOME-Shell blockieren positionsbasierte Klicks zeitweise
  (mutter-X11-Modality-Grab) — Escape schließt Dialog, Keybinder-Grab (Alt+Q)
  funktioniert unabhängig vom Fokus.
- `pkill -f` mit vollem App-Pfad in derselben Shell-Zeile tötet die eigene Wrapper-Shell
  (Pattern matcht den Kommandozeilen-Text) — pkill und Launch trennen.
- Theme verlässlich umschalten: `theme_mode` in `~/.config/linux-assistant/config.json`
  (`system|light|dark`) + App-Neustart — der UI-Toggle durchläuft einen 3er-Zyklus.
