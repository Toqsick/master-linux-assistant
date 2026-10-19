# Feature-Spec: Admin-Hub (Dashboard-Erweiterung)
## Sidebar-Links, Brave-Verknüpfung, Quick Notes, Dateimanager, Systemmonitor

> Status: Spezifikation · Ziel-Release: v0.8 · Baut auf: Sidebar-UI v0.7.1
> (visuelle Baseline), `MintYColors` ThemeExtension, Fork-Services (`lib/services/`)
> Design-Regeln: `docs/design/linux-assistant-design-system.md`

---

## 1. Konzept

Das Dashboard wird vom „Status-Viewer" zum **Admin-Hub**: häufige
Administrations-Werkzeuge direkt in der Sidebar, ohne Kontextwechsel zu
Terminal oder externen Apps.

```
Sidebar (v0.7.1)                    Sidebar (v0.8 Admin-Hub)
┌──────────────────┐                ┌──────────────────┐
│ LA  v0.7.1       │                │ LA  v0.8         │
│ ──────────────── │                │ ──────────────── │
│ ⊞  Dashboard     │                │ ⊞  Dashboard     │
│ 🔍 Suche         │                │ 🔍 Suche         │
│ ☰  Speicher      │                │ ☰  Speicher      │
│ ♥  Linux-Gesundh.│                │ ♥  Linux-Gesundh.│
│ 🛡  Sicherheit   │                │ 🛡  Sicherheit   │
│                  │                │ ── WERKZEUGE ──  │
│                  │                │ 🌐 Browser       │
│                  │               │ 📝 Quick Notes   │
│                  │                │ 📁 Dateimanager  │
│                  │                │ 📊 Systemmonitor │
│                  │                │                  │
│ ⚙  Einstellungen │                │ ⚙  Einstellungen │
└──────────────────┘                └──────────────────┘
```

Neue Sektion **„Werkzeuge"** zwischen Haupt-Navigation und Einstellungen –
visuell abgesetzt (Sektions-Label in `textDim`, 12px, uppercase, wie
„EINGEBUNDENE DATENTRÄGER" im Speicher-Screen).

---

## 2. Feature 1: Browser-Verknüpfung (Brave)

> **Überholt (DR) seit V0.8.2:** Der Launch geht jetzt über `preferred_browser`
> (Allowlist-geprüft, WP-B1/#47) → XDG-Standardbrowser (`xdg-settings` +
> `.desktop`-Prüfung, `gtk-launch`/`xdg-open`) → `kKnownBrowsers`-Liste als
> letzter Fallback. Aktueller Stand: `docs/wiki/Admin-Hub.md` (E1). Der
> folgende Abschnitt beschreibt den historischen Erststand.

### Verhalten
- Klick auf „Browser" → öffnet Brave als externen Prozess
- Fallback-Kette: `brave` → `brave-browser` → `xdg-open https://`
- Nicht installiert → Nav-Item deaktiviert + Tooltip „Brave nicht gefunden"

### Implementierung

```dart
// lib/services/app_launcher.dart
class AppLauncher {
  static Future<bool> launchBrowser() async {
    for (final bin in ['brave', 'brave-browser']) {
      final result = await Process.run('which', [bin]);
      if (result.exitCode == 0) {
        await Process.start(bin, [], mode: ProcessStartMode.detached);
        return true;
      }
    }
    // Fallback: Standard-Browser
    await Process.start('xdg-open', ['https://'],
        mode: ProcessStartMode.detached);
    return false; // signalisiert: Fallback genutzt
  }
}
```

### Design
- Icon: `Icons.public` (oder Brave-Logo via `SystemIcon`, wenn im Icon-Theme)
- Kein eigener Screen – reine Launch-Aktion, kein `route`
- **Konfigurierbar machen:** In Einstellungen „Standard-Browser" wählbar
  (Brave/Firefox/Chromium/Custom) → ConfigHandler-Key `preferred_browser`

---

## 3. Feature 2: Quick Notes

### Verhalten
- Einfacher Markdown-Notizblock, persistent, ohne App zu verlassen
- Autosave (debounced, 500 ms), keine Speichern-Buttons
- Mehrere Notizen als Liste links, Editor rechts (Master-Detail)

### Dateien & Storage

```
lib/layouts/tools/quick_notes.dart        → Screen
lib/services/notes_service.dart           → CRUD + Persistenz
~/.local/share/linux-assistant/notes/     → eine .md pro Notiz
```

```dart
// lib/services/notes_service.dart (Skelett)
class NotesService {
  static final _dir = Directory(
      '${Platform.environment['HOME']}/.local/share/linux-assistant/notes');

  Future<List<Note>> list() async { /* *.md lesen, mtime sortiert */ }
  Future<Note> save(Note n) async { /* atomic write: tmp + rename */ }
  Future<void> delete(Note n) async { /* mit Confirm-Dialog! */ }
}
```

### Design-Tokens
- Editor: `MintYText.mono` (Monospace-Fallback-Stack ✅ bereits im Token-Set)
- Editor-Fläche: `colors.canvas`, Liste: `colors.surface`
- Aktive Notiz: HermesNavItem-Pattern (Akzent-Balken links)
- Löschen = **destructive** → Confirm-Dialog („Notiz ‚X' wird gelöscht")
  gemäß Roadmap-Vorschlag B.4

### Scope-Grenzen (bewusst NICHT)
- ❌ Kein Markdown-Preview (v1) – nur Plaintext-Editor
- ❌ Kein Sync, keine Cloud – lokale Dateien reichen
- ✅ Später erweiterbar: `notes_service` ist Interface, Sync = neuer Provider

---

## 4. Feature 3: Integrierter Dateimanager

### Verhalten
- Eingebetteter Datei-Browser (kein externer Prozess)
- Breadcrumb-Navigation, Liste mit Icon/Name/Größe/Änderungsdatum
- Aktionen: Öffnen (`xdg-open`), Ordnerwechsel, Löschen (mit Confirm),
  Im Terminal öffnen (optional)
- Start: `$HOME`, Schnellzugriff-Leiste: Home, /, /mnt, Downloads, Desktop

### Implementierung

```
lib/layouts/tools/file_manager.dart       → Screen
lib/services/file_browser_service.dart    → dart:io Directory-Listing
```

```dart
// Kern: dart:io, kein Shell-Out nötig
Stream<FileSystemEntity> listDir(String path) =>
    Directory(path).list(followLinks: false);
```

| Aktion | Umsetzung |
|---|---|
| Öffnen | `Process.start('xdg-open', [path])` |
| Löschen | `File/Directory.delete(recursive:)` + **Confirm-Dialog mit Pfad** |
| Berechtigungen lesen | `FileStat.stat(path)` → modeString |
| Größen | rekursiv nur auf Klick (Performance!) |

### Design-Tokens
- Zeilen: `colors.surface`, Hover: `colors.surfaceRaised`, Radius `MintYRadius.md`
- Ordner-Icon in `colors.accent`, Dateien in `colors.textDim`
- Versteckte Dateien (`.`-Prefix): Toggle in Top-Bar des Screens
- **Sicherheit:** Symlinks nicht folgen (Loop-Gefahr), Systempfade
  (`/proc`, `/sys`, `/dev`) ausgrauen + Warnung

### Scope-Grenzen
- ❌ Kein Copy/Move/Rename in v1 (nur Lesen + Öffnen + Löschen)
- ❌ Keine Thumbnails (Icon nach Extension reicht)
- ✅ v2-Kandidat: Drag & Drop, Tabs

---

## 5. Feature 4: Systemmonitor (detailliert)

### Verhalten
Der große Bruder der Dashboard-Karten: Echtzeit-Detailansicht aller
Systemmetriken mit 1-Sekunden-Refresh (pausierbar).

### Datenquellen (CLI-first, keine neuen Dependencies)

| Metrik | Quelle | Parser existiert? |
|---|---|---|
| CPU gesamt + per Core | `/proc/stat` | teilweise (`system_parsers_test.dart` existiert) |
| RAM/Swap Details | `/proc/meminfo` | ✅ (memory_status nutzt es) |
| Prozesse (sortierbar) | `ps aux --sort=-%cpu` | ✅ (linux_health) |
| Disks + I/O | `df -h` + `/proc/diskstats` | ✅ / neu |
| Netzwerk | `/proc/net/dev` (RX/TX pro Interface) | neu |
| GPU (NVIDIA) | `nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader` | neu, optional |
| Temperaturen | `/sys/class/thermal/thermal_zone*/temp` | neu |
| Uptime/Boot | `/proc/uptime` | ✅ (Laufzeit-Badge) |

### Layout

```
┌─ Systemmonitor ──────────────────── [⏸ Pausieren] ─┐
│ ┌─CPU──────────┐ ┌─RAM──────────┐ ┌─GPU──────────┐ │
│ │ 19 %  ▁▃▅▂  │ │ 10.4/15.3 GB │ │ 34 %  61 °C  │ │
│ │ 16 Cores ▓▓░ │ │ Swap 10.1 GB │ │ VRAM 2.1/8 GB│ │
│ └──────────────┘ └──────────────┘ └──────────────┘ │
│ ┌─Disks────────┐ ┌─Netzwerk─────┐ ┌─Thermal──────┐ │
│ │ / 88 %       │ │ ↓ 12 Mbit/s  │ │ CPU 52 °C    │ │
│ └──────────────┘ └──────────────┘ └──────────────┘ │
│ Prozesse (sortierbare Tabelle, Suche)               │
│ CPU % │ RAM % │ PID │ Name │ [Beenden]             │
└─────────────────────────────────────────────────────┘
```

### Design-Tokens
- Stat-Kacheln: HermesStatTile-Pattern (existiert in `lib/widgets/hermes/`
  auf main – Nutzung OK, nur Weiterentwicklung ist Backlog)
- Sparklines: HermesSparkline für CPU/RAM-Verlauf (Ringpuffer, 60 Werte)
- Prozess-Tabelle: `MintYTable` erweitern um Sortierung, oder DataTable
- „Beenden"-Aktion: `colors.statusDanger` + Confirm (SIGTERM, dann SIGKILL)
- Refresh-Indikator: HaloDot pulsiert (dezent, 1s-Takt)

### Performance-Budget
- Refresh 1 s, Parser < 50 ms pro Zyklus (alles `/proc`-Reads, kein Fork-Exec
  außer optional `nvidia-smi` – das nur alle 5 s)
- Pausieren, wenn Screen nicht sichtbar (Route-Awareness)

---

## 6. Integration: Sidebar & Routing

```dart
// In der Fork-Sidebar (v0.7.1, HermesNavItem-basiert) neue Sektion:
NavSection(label: 'Werkzeuge'),
HermesNavItem(icon: Icons.public,      label: l10n.browser,
              onTap: AppLauncher.launchBrowser),   // kein Route-Wechsel
HermesNavItem(icon: Icons.edit_note,   label: l10n.quickNotes,
              route: QuickNotesPage()),
HermesNavItem(icon: Icons.folder_open, label: l10n.fileManager,
              route: FileManagerPage()),
HermesNavItem(icon: Icons.monitor_heart, label: l10n.systemMonitor,
              route: SystemMonitorPage()),
```

### i18n (l10n existiert, `l10n.yaml`)
Neue Keys: `tools`, `browser`, `quickNotes`, `fileManager`, `systemMonitor`
+ alle Screen-Texte (de/en).

---

## 7. Aufwand & Reihenfolge

| # | Feature | Aufwand | Abhängigkeiten | PR-Vorschlag |
|---|---|---|---|---|
| 1 | Browser-Verknüpfung | ½ Tag | – | PR E1 (klein, sofort) |
| 2 | Quick Notes | 1–2 Tage | Confirm-Dialog-Pattern | PR E2 |
| 3 | Systemmonitor | 3–4 Tage | Parser-Erweiterungen, Ringpuffer | PR E3 |
| 4 | Dateimanager | 2–3 Tage | Destructive-Confirm, Symlink-Policy | PR E4 |

**Empfohlene Reihenfolge:** E1 → E2 → E4 → E3 (Systemmonitor zuletzt,
weil er am meisten Parser-/Performance-Arbeit braucht und von den
Dashboard-Erfahrungen aus PR B profitiert).

## 8. Abhängigkeit zum laufenden Track

- PR B (#10, Dashboard-Token-Migration) bleibt **Voraussetzung** – alle
  neuen Screens nutzen von Tag 1 `context.mintY.*`, keine Hardcodes
- Neue Screens bekommen sofort Golden-Tests (Baseline-Setup aus #11)
- Sidebar-Sektion „Werkzeuge" wird im Komponenten-Katalog nachgetragen
