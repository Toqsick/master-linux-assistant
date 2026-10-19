# HubShell — Architektur des Hub-Frames

Stand: 2026-09-10, Zweig `hardening/0.8.0` (inkl. Werkzeuge-Erweiterung von origin/main). Quelle: `lib/layouts/hub/hub_shell.dart` (576 Zeilen). Zeilenbezüge ohne Präfix = hub_shell.dart.

## ASCII-Layout

```
┌──────────────┬──────────────────────────────────────────────┐
│ Sidebar      │ Top-Bar (52px)                               │
│ 260px        │  Titel…            🔍   ↻   ☀/🌙            │
│ (<1000px:    ├──────────────────────────────────────────────┤
│  56px-Rail)  │                                              │
│              │  Content: IndexedStack                       │
│ ◼ Dashboard  │   ┌ aktive Sektion oder Screen-Tool ┐        │
│ ◻ Suche      │   │                                 │        │
│ ◻ Speicher   │   │                                 │        │
│ ◻ Gesundheit │   └─────────────────────────────────┘        │
│ ◻ Sicherheit │                                              │
│ ── WERKZEUGE─│                                              │
│ ◻ Browser    │  (Browser: detached, nie im Frame)           │
│ ◻ QuickNotes │                                              │
│ ◻ Dateimgr.  │                                              │
│ ◻ SysMonitor │                                              │
│ ─────────────│                                              │
│ ⚙ Einstell.  │  → öffnet Dialog (kein Sectionswechsel)      │
└──────────────┴──────────────────────────────────────────────┘
```

## Struktur

| Baustein | Details | Beleg |
|---|---|---|
| Sektions-Enum | `HubSection { dashboard, search, storage, health, security }` | :21 |
| Tool-Enum | `HubTool { browser, quickNotes, fileManager, systemMonitor }` — `browser` feuert nur einen detached Launch, die drei anderen rendern im Frame | :23-30 |
| Stats-Polling-Steuerung | `_sectionUsesStats()`: dashboard/storage/health/search = true, security = false; steuert `SystemStatsService` | :36-48 |
| Shell-Widget | `HubShell({initialSection})`, statisches `HubShell.onSearchRequested` als Hook für den globalen Hotkey | :56-67 |
| Sidebar | 260px (`_sidebarWidth` :71), kollabiert zu 56px-Rail unter `_collapseBreakpoint` = 1000 (:72-75); `AnimatedContainer` 180 ms | :350-415 (350-361) |
| Top-Bar | 52px hoch (:519); Titel der aktiven Sektion bzw. des Tools (:529-538); Suche-Button (nur wenn nicht schon Suche, :540-546); Refresh → `SystemStatsService().refresh()` (:547-552); Theme-Toggle → `ThemeController().cycleThemeMode()` (:553-560, Icon-Mapping :566-575) | :514-564 |
| Sektionswechsel | **kein Navigator-Push** (bewusst, Kommentar :52-55), sondern `IndexedStack` über die `_built`-Map: Sektionen werden beim ersten Besuch gebaut und bleiben alive; `TickerMode` stoppt Animationen off-screen | :302-320 (:307 IndexedStack, :314 TickerMode) |
| Screen-Tools | `_screenTool` überlagert die Sektion, die darunter selektiert bleibt; Zurückkehren verliert keinen Zustand; während eines Tools ist der 3s-Stats-Poll aus (Systemmonitor hat eigenen 1s-Sampler) | :82, :156-164 |
| Settings | als `showDialog(SettingsStart())` — kein Sectionswechsel | :399-411 (:406-409) |
| Lifecycle | Minimize/Restore + App-Lifecycle schalten den Stats-Poll; Hub räumt `MainSearch.onDismiss`/`onSearchRequested` in dispose auf | :90-134, :105-119 |

Sektions-Inhalte: `_buildSection()` :263-282 — Dashboard bekommt die Callbacks `onOpenStorage`/`onOpenSecurity` (:266-269), Suche = `MainSearch(embedded: true)` (:271), Health = `LinuxHealthContent` in `space4`-Padding (:274-278), Security = `SecurityCheckContent` (:279-280).

## Werkzeuge-Sektion (NEU von origin/main)

Registrierung erfolgt **statisch über zwei Enums**, nicht über eine Laufzeit-Registry:

1. Sektionen: `HubSection.values` werden in der Sidebar gerendert mit `HermesNavItem` (:374-381; Icon-Mapping `_iconOf` :211-224, Titel `_titleOf` :195-209).
2. Werkzeuge: darunter ein `_sectionLabel` „WERKZEUGE" (11px, w600, letterSpacing 1.2, nur wenn nicht kollabiert, :386 + :436-454), dann `HubTool.values` als weitere `HermesNavItem` (:387-394; Icons `_iconOfTool` :226-237, Titel `_titleOfTool` :239-250).
3. Routing: `_onToolTap()` (:417-432) verzweigt — `browser` → `_launchBrowser()` (:171-187), sonst → `_selectTool()` (:156-164).
4. Content: `_contentFor()` mappt `HubTool` auf Seite — `QuickNotesPage` (:287-288), `FileManagerPage` (:289-290), `SystemMonitorPage` (:291-292); `browser` wird nie Content (`SizedBox.shrink()`, :293-296).

**E1 Browser-Launcher:** kein eigenes Panel. `AppLauncher.launchBrowser()` (`services/app_launcher.dart:44, :173`; XDG-Stufe `xdg-settings` + `.desktop`-Prüfung + `gtk-launch`/`xdg-open`, letzter Fallback `kKnownBrowsers` :21-28) startet detached; Feedback über `BrowserLaunchResult` → Snackbars nur bei Listen-Fallback („Standard-Browser nicht ermittelbar – ersatzweise bekannten Browser gestartet.") und Fehler (:174-186).

**E2 Quick Notes:** `layouts/tools/quick_notes.dart` (`QuickNotesPage`, :13) — nutzt `MintYText.mono` für das Textfeld (:298, 301).

**E3 Dateimanager:** `layouts/tools/file_manager.dart` (`FileManagerPage`, :14) — nutzt `HermesTokens.fontMono` (:120, 435).

**E4 Systemmonitor:** `layouts/tools/system_monitor.dart` (`SystemMonitorPage`, :24) — Ticker-getriebener 1s-Sampler; der `TickerMode` im IndexedStack (:312-314) stoppt ihn automatisch beim Verlassen; nutzt `HermesSectionHeader`, `HermesBadge`, `HermesMetaRow`, `HermesSparkline`, `HermesHaloDot`, `HermesStatTile` (siehe component-catalog.md).

**Neue Sektion/Tool anlegen (Rezept):** Enum-Wert ergänzen (hub_shell.dart:21 bzw. :30) → Icon in `_iconOf`/`_iconOfTool` (:211/:226) → Titel in `_titleOf`/`_titleOfTool` (:195/:239) → Content in `_buildSection` (:263) bzw. `_contentFor` (:284) → fertig; Sidebar/Stats-Polling folgen den Enums. Eine datengetriebene Registry (Roadmap #28 „Tool-/Plugin-Registry") existiert **noch nicht** — die Enums sind der Vorläufer.

**l10n-Lücke:** Werkzeuge-Strings laufen über die Hilfsfunktion `_tr(de:, en:)` statt über die .arb-Dateien — bewusst, TODO im Code (:252-261). Betrifft auch `supportedLocales` (en/de/it, main.dart:281-285).

## Hotkey-Flow (Alt+Q bzw. Meta+Q)

Zwei Mechanismen, je Session-Typ genau einer ist wirksam (Kommentar `main.dart:106-110`):

- **X11:** App greift die Taste selbst via hotkey_manager/libkeybinder — `MyApp.initHotkeyToShowUp()` (`main.dart:111-138`): `PhysicalKeyboardKey.keyQ` (:117), Modifier aus `Linux.getHotkeyModifier()` (:122-125), `HotKeyScope.system` (:126), Handler → `raiseWindow()` (:130-136).
- **Wayland:** kein globaler Grab möglich → Desktop-eigener Shortcut via gsettings: `_ensureDesktopShortcut()` (`main.dart:147-159`) ruft einmalig `Linux.activateSystemHotkeyForLinuxAssistant()` (:157), welche `setup_keybinding.py` mit `--alt`-Flag startet (`services/linux.dart:2470-2471`), und persistiert Erfolg in Config-Key `keybinding_registered` (:151-158).
- **Modifier-Erkennung:** `Linux.getHotkeyModifier()` (`linux.dart:2481-2493`) — KDE, Zorin, Ubuntu, Pop!_OS → `<Alt>`; sonst `<Super/Windows>`. (Der greeter-Kommentar dokumentiert den historischen Bug: hardcoded Meta warb Alt+Q, griff aber Super+Q.)
- **Raise + Fokus:** `raiseWindow()` (`main.dart:82-87`) — restore/show/focus, dann `HubShell.onSearchRequested?.call()`; der Shell hookt das auf `_focusSearch()` (:95, :136), was direkt die Suche-Sektion selektiert. Zweiter Prozessdruck läuft über Single-Instance-Socket in denselben Pfad (`main.dart:31-34`, Kommentar :78-81). Rückweg aus der Suche: `MainSearch.onDismiss = _returnToDashboard` (:94, :138).
- Theme-Zyklus des Top-Bar-Toggles: system → light → dark → system (`services/theme_controller.dart:87-95`); Theme wird pro Build in `_MyAppState` aufgelöst, nicht als `ThemeMode.system` an Flutter delegiert (`main.dart:263-294`, Kommentar :288-291).

## Screenshots

| Zustand | Datei |
|---|---|
| Dashboard (dark/light) | `screenshots/v0.7.1/00-start_dark_01.png`, `00b-dashboard_light.png` |
| Suche-Sektion (embedded MainSearch) | `01-suche_dark.png`, `01-suche_light.png` |
| Speicher / Gesundheit | `02-speicher_*`, `03-gesundheit_*` |
| Sicherheit (Auto-Scan + Bug-Zustand) | `04-sicherheit_dark.png`, `04b-sicherheit_nach-scan_dark.png`, `04c-sicherheit-fehlerseite2_dark.png` |
| Settings-Dialog | `05-einstellungen_light.png`, Appearance `05b-erscheinungsbild_light.png` (⚠️ unverifiziert) |
| Alt+Q-Fokusverhalten | `06-suche-fokus_light.png` |
| **Werkzeuge (alle 4)** | **keine v0.7.1-Shots** — Tools sind neu auf origin/main und in der installierten v0.7.1 nicht vorhanden; für `screenshots/v0.8.0/` nachholen (geplant, 00-PLAN Phase A/E) |
| Rail-Modus (<1000px) | kein Shot; rein code-belegt (:71-75, :328) |
