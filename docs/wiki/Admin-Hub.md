# Admin-Hub – Die Werkzeuge

Spezifikation: `docs/design/feature-spec-admin-hub.md` · Milestone:
`docs/design/milestone-v0.7.2.md` · Implementiert in PR #12–#19.

Die Sidebar hat seit v0.7.2 eine Sektion **WERKZEUGE** mit vier Einträgen:

| Tool | Art | Screen |
|---|---|---|
| 🌐 Browser | Launch-Aktion (extern) | – |
| 📝 Quick Notes | Screen-Tool | `lib/layouts/tools/quick_notes.dart` |
| 📁 Dateimanager | Screen-Tool | `lib/layouts/tools/file_manager.dart` |
| 📊 Systemmonitor | Screen-Tool | `lib/layouts/tools/system_monitor.dart` |

---

## Browser (E1)

Klick startet den Browser als **detached Prozess** – die Hub-Section ändert
sich nicht. Start-Kette in `lib/services/app_launcher.dart` (seit V0.8.2):

```
preferred_browser (Allowlist-geprüft) → XDG-Standardbrowser
(xdg-settings + .desktop-Prüfung; gtk-launch bzw. xdg-open für URLs)
→ bekannte Browser-Binaries (brave → … → falkon)
```

Feedback: still bei preferred/XDG-Start, Info-Snackbar beim Binary-Listen-
Fallback, Fehler-Snackbar wenn gar kein Browser gefunden wurde.

## Quick Notes (E2)

Markdown-/Plaintext-Notizen ohne die App zu verlassen.

- **Master-Detail:** Liste links (zuletzt geändert zuerst), Editor rechts
- **Autosave:** debounced 500 ms, kein Speichern-Button
- **Persistenz:** eine `.md` pro Notiz unter
  `~/.local/share/linux-assistant/notes/` (respektiert `XDG_DATA_HOME`),
  atomare Writes (tmp + rename – kein halber Stand bei Absturz)
- **Löschen:** destructive → Confirm-Dialog
- Titel wird aus der ersten nicht-leeren Zeile abgeleitet
- Service: `lib/services/notes_service.dart` (injizierbar:
  `NotesService.test(dir)`)

Bewusst NICHT: Markdown-Preview, Cloud-Sync (v2, Service ist Interface).

## Dateimanager (E4)

Eingebetteter Datei-Browser – kein externer Prozess für die Navigation.

- **Schnellzugriff:** Home, `/`, `/mnt`, Downloads, Desktop (nur existierende)
- **Breadcrumb** + Up-Button + Hidden-Files-Toggle + Refresh
- Zeilen: Icon (Ordner = Akzent), Name, Größe (nur Dateien),
  Änderungsdatum, Permissions (`FileStat.modeString`)
- **Öffnen:** `xdg-open` detached
- **Löschen:** Confirm-Dialog **mit vollem Pfad**; Verzeichnisse rekursiv;
  Symlinks werden als Links gelöscht (Ziel bleibt)
- **Sicherheit:**
  - Symlinks werden nie navigiert (Loop-Gefahr) – Klick öffnet extern
  - `/proc`, `/sys`, `/dev`: Warn-Banner, Einträge ausgegraut, Delete
    deaktiviert (Policy in `FileBrowserService.isProtected`)
  - Größen nur für Dateien beim Listing (Performance)

Service: `lib/services/file_browser_service.dart` (reines dart:io).

Bewusst NICHT: Copy/Move/Rename, Thumbnails, Drag&Drop (v2).

## Systemmonitor (E3)

Der große Bruder der Dashboard-Kacheln: 1-s-Live, pausierbar.

- **Kacheln (HubGrid):** CPU (Sparkline + Per-Core-Balken), RAM (Badge +
  Swap), GPU (nur wenn `nvidia-smi` vorhanden), Disks (Worst + Top-3-Balken),
  Netzwerk (↓/↑-Raten + Sparkline), Thermal (heißeste Zone + Top-3)
- **Prozess-Tabelle:** Suche, sortierbare Spalten (PID/CPU/RAM/Name),
  Beenden-Dialog (Abbrechen / SIGTERM / SIGKILL)
- **Control-Bar:** HaloDot (Live/Pausiert), Pause/Resume, Refresh
- **Sampling-Architektur:** `Ticker`-getrieben statt `Timer` – das
  `TickerMode` des Hubs stoppt das Polling automatisch, wenn der Screen
  off-screen ist. `/proc`-Reads ohne Fork; einzige Forks pro Tick: `ps` +
  `df`; `nvidia-smi` nur alle 5 s
- Parser alle rein & fixture-getestet: `parseProcStat`, `cpuUsageDelta`,
  `parseMemInfo`, `parseNetDev`, `parseThermal`, `parseNvidiaSmi`, `parsePs`

Service: `lib/services/system_monitor_service.dart`.

---

## Eigenes Werkzeug hinzufügen

Siehe [[Architecture]] → „Modul-Registry“ (Enum-Wert + `hubModules`-Eintrag in `hub_module.dart`).
Konventionen: Hermes-Tokens statt harter Farben, Service injizierbar,
Parser rein, destructive Aktionen mit Confirm.
