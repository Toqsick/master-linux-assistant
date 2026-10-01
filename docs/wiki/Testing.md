# Testing

## Suite-Überblick (`test/`)

| Datei | Gegenstand | Pattern |
|---|---|---|
| `app_launcher_test.dart` | E1 Browser-Fallback-Kette | Service-Test |
| `notes_service_test.dart` | E2 NotesService | Temp-Dir-Fixtures |
| `file_browser_service_test.dart` | E4 FileBrowserService | Temp-Dir + Symlinks |
| `system_monitor_service_test.dart` | E3 Parser & Helfer | String-Fixtures |
| `system_parsers_test.dart` | SystemStatsService, Parser | Fixtures + Service-Gating |
| `environment_test.dart` | Distro-Fallback, Enum-Roundtrips, Versionsvergleich | Pure Functions |
| `hermes_tokens_test.dart` | Token-Konsistenz | Unit |
| `hermes_widgets_test.dart` | Hermes-Widgets | Widget-Tests |
| `widget_test.dart` | App-Smoke | Widget-Test |
| `action_handler_test.dart` | openfile: Bestätigung vor Ausführung (recent/favorites) | Widget-Tests |
| `command_queue_test.dart` | CommandQueue-Serialisierung (JSON-Zeilen, Sonderzeichen) | Unit |
| `config_handler_test.dart` | ConfigHandler: Defaults, Laden, Zurücklesen | Unit |
| `l10n_test.dart` | l10n-Vollständigkeit der `.arb`-Dateien | Unit |
| `quick_notes_widget_test.dart` | E2 QuickNotes-Widget (Save-Race, Fehler-State) | Widget-Tests |
| `security_check_outcome_test.dart` | `classifySecurityCheck` (Exit-Code-Deutung) | Unit |
| `hub_module_registry_test.dart` | `hubModules`-Registry (#60): Bijektion, Widget-Bau, ARB-Titel | Pure Dart |
| `hub_navigation_test.dart` | Hub-Shell-Navigation H1–H9 (#60, Characterization) | Widget-Tests |
| `process_command_runner_test.dart` | `ProcessCommandRunner`: echte Prozesse, pkexec/flatpak-Präfixe | Spawn-Tests |

Ausführen: `flutter test` (aktuell: 18 Dateien, 208 Tests; Python-Suite:
`additional/python` → 53 Tests, `packages/la_core` → 61 Dart-Tests mit
eigenen `dart analyze`/`dart format`-Gates).

## Etablierte Patterns

1. **Services sind injizierbar.** Beispiele: `NotesService.test(directory)`,
   `SystemMonitorService(readFile: …)` (FileReader-Typedef),
   `FileBrowserService` ohne Konstruktor-Zwang. → Tests ohne echtes
   System.
2. **Parser sind reine statische Funktionen.** Sie nehmen Strings (Inhalt
   von `/proc/stat`, `ps`-Output, …) und liefern Modelle. Fixtures leben
   als `const`-Strings im Test. Delta-Berechnungen werden mit
   nachgerechneten Erwartungswerten geprüft (`closeTo`).
3. **Fehler in-band.** `DirListing.error` statt Exception – der Screen
   rendert Berechtigungsprobleme inline.
4. **Destructive Logik hat Guard-Tests:** Protected-Pfade werden abgelehnt
   *bevor* das Dateisystem angefasst wird; Symlink-Delete berührt nie das
   Ziel; Verzeichnis-Delete braucht `recursive`.
5. **Service-Gating ist getestet:** `system_parsers_test.dart` deckt die
   drei Polling-Bedingungen des `SystemStatsService` ab (Subscriber,
   Section, Fenster) inkl. `resetForTesting`.

## Erwartungswerte verifizieren

Lehre aus #21: handgerechnete Erwartungswerte sind ein Fehlervektor. Für
Delta-Mathe gilt: Erwartung **per Rechnung** gegen die Fixture prüfen,
bevor sie in den Test wandert. Beispiel aus `system_monitor_service_test.dart`:

```
aggregate: dBusy 330 / dTotal 1050 = 31.43 %
core:      dBusy  55 / dTotal  515 = 10.68 %
```

## Golden-Tests (Status: zurückgestellt)

Der erste Golden-Test (#11) importierte `golden_toolkit`, ohne dass die
Dependency in `pubspec.yaml` stand – der Loader brach die gesamte Suite.
In #21 entfernt; Reaktivierung lokal:

```bash
flutter pub add --dev golden_toolkit
git add pubspec.yaml pubspec.lock
git show 4e716d7:test/goldens/layout_golden_test.dart > test/goldens/layout_golden_test.dart
# const vor SuccessMessage/WarningMessage/SingleBarChart entfernen
flutter test test/goldens/layout_golden_test.dart --update-goldens
```

Details & Plattform-Falle (Fonts/OS-Sensitivität): `docs/design/screenshot-baseline.md` §4,
Schritte: `docs/design/admin-hub-followups.md` §3. Neue Screens (Quick Notes,
Dateimanager, Systemmonitor) sollen danach Baselines bekommen.

## CI

`.github/workflows/build.yml` (ubuntu-24.04 gepinnt): `dart format`- und
`flutter analyze`-Gates laufen vor `flutter test` – ein roter Test failt
früh. `flutter analyze` ist seit dem 0.8.0-Hardening scharf geschaltet
(0 Findings, `unawaited_futures` aktiv; Commits `8ec042f`, `210e456`).
