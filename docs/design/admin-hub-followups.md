# Admin-Hub: Nacharbeiten

> Nacharbeiten zum Admin-Hub-Epic (#12–#19, komplett auf main).
> Reihenfolge = Priorität. Issues sind in diesem Repo deaktiviert, daher
> lebt diese Checkliste hier. Spec: `docs/design/feature-spec-admin-hub.md`.

---

## 1. Verifikation der gemergten PRs (kritisch, zuerst)

Die PRs #14, #15, #17, #18, #19 wurden ohne lokalen Build gemergt. Vor allen
weiteren Features:

```bash
git checkout main && git pull
flutter analyze
flutter test
```

Manuelle Checks:

- [ ] WERKZEUGE-Sektion erscheint in der Sidebar (nicht collapsed)
- [ ] Browser-Klick startet preferred/XDG-Standardbrowser (gtk-launch bzw. xdg-open), ändert die Section nicht
- [ ] Quick Notes: anlegen, tippen (Autosave 500 ms), Section wechseln,
      zurück → Inhalt + Selektion bleiben
- [ ] Dateimanager: navigieren, Datei öffnen, Löschen mit Confirm (voller
      Pfad), `/proc` → Banner + deaktivierte Delete-Buttons, Symlink öffnet
      extern
- [ ] Systemmonitor: Kacheln füllen sich nach 2 s, Pause/Resume, Prozess
      suchen/sortieren/beenden, Screen verlassen → 1-s-Polling stoppt
      (TickerMode)

Bei Fehlern: Analyzer-/Test-Output dokumentieren → Fix-PR.

**Stand 2026-08-22:** Erster Suite-Lauf brachte 3 Failures (2 Test-Erwartungen
+ Golden-Test ohne deklarierte Dependency) → behoben in #21. Erwartung danach:
128 passed, 0 failed.

---

## 2. l10n: `_tr()`-Pattern durch echte .arb-Keys ersetzen

Die Shell nutzt aktuell einen `_tr()`-Helper (TODO in
`lib/layouts/hub/hub_shell.dart`), weil die .arb-Dateien per API nicht
editierbar waren. **Lokal** eintragen:

### `lib/l10n/app_en.arb` (ans Ende, Komma beachten)

```json
"tools": "Tools",
"browser": "Browser",
"quickNotes": "Quick Notes",
"fileManager": "File manager",
"systemMonitor": "System monitor",
"newNote": "New note",
"noNotes": "No notes",
"deleteNoteTitle": "Delete note?",
"unnamed": "Untitled",
"startTyping": "Start typing …",
"parentFolder": "Parent folder",
"hiddenFiles": "Hidden files",
"reload2": "Reload",
"openFailed": "Could not open.",
"deleteFailed": "Delete failed",
"deleteFileTitle": "Delete file?",
"deleteFolderTitle": "Delete folder?",
"emptyFolder": "Empty folder",
"folderUnreadable": "Folder cannot be read",
"unknownError": "Unknown error",
"toParentFolder": "Go to parent folder",
"protectedPathBanner": "System path – read-only view, deleting is disabled here.",
"monitorPaused": "Paused",
"monitorLive": "Live · 1 s",
"resume": "Resume",
"pause": "Pause",
"refreshNow": "Refresh now",
"processesHeader": "Processes",
"searchProcess": "Search process …",
"noProcessesFound": "No processes found",
"terminateProcessTitle": "Terminate process?",
"terminateAction": "Terminate",
"forceKillAction": "Force",
"cores": "Cores",
"swapLabel2": "Swap",
"networkLabel": "Network",
"thermalLabel": "Thermal",
"cancel": "Cancel",
"deleteAction": "Delete"
```

### `lib/l10n/app_de.arb`

```json
"tools": "Werkzeuge",
"browser": "Browser",
"quickNotes": "Quick Notes",
"fileManager": "Dateimanager",
"systemMonitor": "Systemmonitor",
"newNote": "Neue Notiz",
"noNotes": "Keine Notizen",
"deleteNoteTitle": "Notiz löschen?",
"unnamed": "Unbenannt",
"startTyping": "Schreib los …",
"parentFolder": "Übergeordneter Ordner",
"hiddenFiles": "Versteckte Dateien",
"reload2": "Neu laden",
"openFailed": "Konnte nicht geöffnet werden.",
"deleteFailed": "Löschen fehlgeschlagen",
"deleteFileTitle": "Datei löschen?",
"deleteFolderTitle": "Ordner löschen?",
"emptyFolder": "Leerer Ordner",
"folderUnreadable": "Ordner kann nicht gelesen werden",
"unknownError": "Unbekannter Fehler",
"toParentFolder": "Zum übergeordneten Ordner",
"protectedPathBanner": "Systempfad – Ansicht nur lesen, Löschen ist hier deaktiviert.",
"monitorPaused": "Pausiert",
"monitorLive": "Live · 1 s",
"resume": "Fortsetzen",
"pause": "Pausieren",
"refreshNow": "Jetzt aktualisieren",
"processesHeader": "Prozesse",
"searchProcess": "Prozess suchen …",
"noProcessesFound": "Keine Prozesse gefunden",
"terminateProcessTitle": "Prozess beenden?",
"terminateAction": "Beenden",
"forceKillAction": "Erzwingen",
"cores": "Cores",
"swapLabel2": "Swap",
"networkLabel": "Netzwerk",
"thermalLabel": "Thermal",
"cancel": "Abbrechen",
"deleteAction": "Löschen"
```

(Keys `reload2`/`swapLabel2` nur falls `reload`/`swapLabel` bereits
existieren – sonst die vorhandenen Keys wiederverwenden.)

Danach:

```bash
flutter gen-l10n
```

- [ ] `.arb`-Keys eingetragen und generiert
- [ ] `hub_shell.dart`: `_tr()` entfernt,
      `l10n.tools`/`l10n.browser`/`l10n.quickNotes`/`l10n.fileManager`/`l10n.systemMonitor`
- [ ] `quick_notes.dart`, `file_manager.dart`, `system_monitor.dart`: harte
      deutsche Strings durch l10n-Keys ersetzt
- [ ] Confirm-Dialoge (Löschen/Prozess beenden) übersetzt

---

## 3. Golden-Baselines (Setup war unvollständig)

Der Golden-Test aus #11 (`test/goldens/layout_golden_test.dart`) importierte
`golden_toolkit`, das **nie in `pubspec.yaml` eingetragen** wurde – der Loader
schlug fehl und brach die gesamte Suite. Die Datei wurde in #21 entfernt.

Reaktivierung (lokal, in dieser Reihenfolge):

```bash
# 1. Dependency + Lockfile
flutter pub add --dev golden_toolkit
git add pubspec.yaml pubspec.lock

# 2. Test-Datei aus der Historie wiederherstellen
git show 4e716d7:test/goldens/layout_golden_test.dart > test/goldens/layout_golden_test.dart
```

3. In der wiederhergestellten Datei `const` vor `SuccessMessage`,
   `WarningMessage` und `SingleBarChart` entfernen – das sind keine
   const-Konstruktoren (zweiter Compile-Fehler im CI-Log vom 2026-08-22,
   wurde damals vom golden_toolkit-Fehler überdeckt).

```bash
# 4. Baseline erzeugen und prüfen
flutter test test/goldens/layout_golden_test.dart --update-goldens
flutter test
```

- [ ] `golden_toolkit` in `pubspec.yaml` + `pubspec.lock` committed
- [ ] `layout_golden_test.dart` wiederhergestellt, const-Fixes drin
- [ ] Baselines: `QuickNotesPage` (Empty-State), `FileManagerPage` (Listing +
      Protected-Banner), `SystemMonitorPage` (Kacheln + Tabelle)
- [ ] Goldens in CI grün (Plattform-Falle beachten: Fonts/OS-sensitiv,
      siehe `docs/design/screenshot-baseline.md` §4)

---

## 4. Optional: Branch-Cleanup

```bash
git fetch --prune && git push origin --delete \
  feature/quick-notes-wiring feature/e2-quick-notes feature/e2-quick-notes-wiring \
  feature/sidebar-tools feature/e4-file-manager feature/e3-system-monitor \
  feature/e1-browser-launcher feature/admin-hub-spec fix/test-suite
```

`copilot/migrate-dashboard-widgets-to-mintytheme` (PR #10) **behalten** –
offener Tracker. Alte `release/v0.7`-, `hotfix/*`- und `claude/*`-Branches:
Merge-Stand unklar, separat prüfen.

---

## Referenzen

- Spec: `docs/design/feature-spec-admin-hub.md`
- Screen-Tool-Architektur: #17
- Test-Suite-Fixes: #21
- Offener Parallel-Track: PR B (#10, Dashboard-Token-Migration)
