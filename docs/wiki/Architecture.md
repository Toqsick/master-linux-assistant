# Architektur

## Schichten-Überblick

```
lib/
├── main.dart                  Einstieg, Theme, Distro-Farben
├── layouts/                   Screens
│   ├── hub/                   HubShell, DashboardSection, StorageSection, HubGrid
│   ├── tools/                 QuickNotesPage, FileManagerPage, SystemMonitorPage
│   ├── main_screen/           MainSearch (Launcher-Suche)
│   ├── linux_health/, security_check/, settings/, … (bestehende Screens)
│   ├── hermes_tokens.dart     Hermes Design-Tokens (Fork)
│   └── mint_y.dart / mint_y_tokens.dart   Mint-Y-Komponenten + Tokens
├── services/                  Logik ohne UI
│   ├── app_launcher.dart          E1: Browser-Fallback-Kette
│   ├── notes_service.dart         E2: Notizen (atomar, XDG)
│   ├── file_browser_service.dart  E4: Verzeichnisse (Protected-Policy)
│   ├── system_monitor_service.dart E3: Parser + Sampling
│   ├── system_stats_service.dart  Geteilter 3-s-Poller
│   ├── linux.dart, config_handler.dart, action_entry_list_service.dart, …
│   ├── main_search_loader.dart     Lädt Aktionskatalog → öffnet Hub
├── linux/                     System-Zugriff: linux_system, linux_process,
│                              linux_filesystem (df-Parser)
├── widgets/hermes/            Hermes-Widgets (Card, StatTile, Sparkline,
│                              Badge, HaloDot, NavItem, CopyCommand)
├── models/, enums/, content/, helpers/, l10n/
├── packages/                   la_core: Flutter-freier Dart-Kern (#59/#60/#93)
│                              Parser, Probe-Vertrag, ModuleRegistry, EventBus,
│                              CommandRunner, la_probe (headless CLI)
additional/python/             Helferskripte (Umgebung, Apps, Bookmarks, …)
```

## Die Hub-Shell (zentrales Stück)

`lib/layouts/hub/hub_shell.dart` – persistenter Rahmen: Sidebar, Top-Bar,
Content-Fläche.

**Kernprinzipien:**

1. **Swappen statt Pushen.** Sektionen ersetzen den Content im Frame; der
   Navigator wächst nicht. Begründung: Die App-Konvention „zurück = Ziel
   erneut pushen“ würde die History unbegrenzt wachsen lassen.
2. **Lazy + Keep-Alive.** Jeder Bereich wird beim ersten Besuch gebaut und
   bleibt via `IndexedStack` im Baum (`Map<Object, Widget> _built`).
   Scroll-Positionen, Selektionen und Editor-Inhalte überleben Wechsel.
3. **TickerMode pro Bereich.** Animationen/Ticker inaktiver Bereiche
   stoppen automatisch – der Systemmonitor nutzt das für sein 1-s-Sampling.
4. **Zwei Navigations-Typen:** `HubSection` (Hauptbereiche) und `HubTool`
   (Werkzeuge). Tools sind entweder Launch-Aktionen (`browser` → externer
   Prozess, kein Sectionswechsel) oder Screen-Tools (`quickNotes`,
   `fileManager`, `systemMonitor` → rendern im Frame, getrackt in
   `_screenTool`).

### Modul-Registry (Werkzeug hinzufügen, Issue #60)

Ein Eintrag in der `hubModules`-Map in `hub_module.dart` ersetzt die
ehemaligen `switch`-Blöcke: Wert in `enum HubSection`/`HubTool` aufnehmen und
ein zugehöriges `HubModule` registrieren (Icon, Titel, `screenBuilder`,
Starts-Prozess-Flag). `hubModuleOf(tool)` ist der einzige Reader und wirft
laut, wenn ein Enum-Wert ohne Registry-Eintrag bleibt; `hub_shell.dart`
iteriert die Enums und rendert die Sidebar aus der Registry.

## Stats-Polling (Performance)

`SystemStatsService` ist ein geteilter 3-s-Poller (CPU, RAM, Disks, Prozesse,
Uptime). Polling läuft nur wenn **alle drei** Bedingungen gelten:

- mindestens ein Subscriber (`acquire()`),
- die sichtbare Section nutzt Stats (`setSectionActive` – Dashboard,
  Speicher, Gesundheit, Suche ja; Sicherheit und Tool-Screens nein),
- das Fenster ist sichtbar (`setWindowVisible` via WindowListener +
  WidgetsBindingObserver – zwei Signale, weil keines allein auf jedem
  Linux-Desktop zuverlässig feuert).

Messung aus Commit `d221d0e`: 4.4 forks/s beim Pollen, 0.10/s idle.

Der Systemmonitor nutzt bewusst **nicht** diesen Service: Er sampled 1-s
über einen `Ticker` (Screen-getrieben) und liest `/proc` direkt.

## Python-Helferskripte

`additional/python/` wird ins Bundle kopiert. Wichtig:
`get_environment.py` gibt zeilenindizierte Werte aus – die Dart-Seite liest
per Zeilenindex, also **neue Felder nur hinten anhängen** (ID/ID_LIKE kamen
so dazu). Unbekannte Distros fallen über `ID_LIKE` auf ihre Familie zurück
(`Linux.distroFromIdLike`).

## Konfiguration & Persistenz

- `ConfigHandler` – JSON-Config unter `~/.config/linux-assistant/`
- Quick Notes – `~/.local/share/linux-assistant/notes/*.md` (XDG, atomare
  Writes: tmp + rename)
- Enum-Werte aus der Config fallen bei unbekannten Einträgen auf Defaults
  zurück statt zu werfen (`getEnumFromString`, `getDektopEnumOfString`)

## L10n

`flutter gen-l10n` aus `lib/l10n/*.arb` (de/en/it/fi; Finnisch heißt die
Datei `linuxassistant_fi.arb`). Übergangsweise nutzt die
Werkzeuge-Sektion einen `_tr()`-Helper – Ablösung ist in
`docs/design/admin-hub-followups.md` §2 geplant.

Weiter: [[Admin-Hub]] für die Werkzeuge im Detail, [[Design-System]] für
die visuelle Sprache.
