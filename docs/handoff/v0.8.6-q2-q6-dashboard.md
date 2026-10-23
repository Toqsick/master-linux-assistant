# deliverable.md — V0.8.6 Welle 1: Q2, Q3, Q5, Q6 (#58)

> **Stand:** 2026-10-23 · **Basis:** `main` @ `08dad94` · **Branch:** `feature/58-q2-q6-dashboard`
> **Umfang:** die vier Dashboard-Punkte Q2, Q3, Q5 und Q6 aus Issue #58.

## Was geändert wurde

| Datei | Änderung |
|---|---|
| `lib/linux/linux_memory.dart` (neu) | `MemoryPressure` (PSI aus `/proc/pressure/memory`) und `ZramInfo` (zram aus `/sys/block/zram*/mm_stat` + `disksize`) mit reinen Parse-Funktionen |
| `lib/services/reboot_service.dart` (neu) | Liest `/var/run/reboot-required(.pkgs)`, parst die Paketliste |
| `lib/services/failed_units_service.dart` (neu) | Liest `systemctl list-units --failed -o json` in **beiden** Scopes (System und `--user`) |
| `lib/services/browser_status_service.dart` (neu) | Read-only-Status des Standardbrowsers aus `AppLauncher.defaultBrowserDesktopId()`, Abgleich mit `gio mime x-scheme-handler/https` |
| `lib/layouts/hub/dashboard_section.dart` | Neustart-Badge, Kachel „Fehlgeschlagene Dienste", Browser-Fakt, ehrliche Speicher-Kachel (PSI + getrennte zram-/Disk-Swap-Zeile) |
| `lib/layouts/hub/hub_shell.dart` | Die neuen Poller laufen nur, wenn ihre Kachel wirklich sichtbar ist; Fenster-Sichtbarkeit an alle drei Services |
| `lib/layouts/linux_health/overview.dart` | Zeile in der Health-Sektion mit den auslösenden Paketen |
| `lib/services/system_stats_service.dart` | hängt die neuen Werte an (zram, PSI) an |
| `lib/l10n/*.arb` + generierte Dateien | 15 neue Strings in **allen vier** Sprachen (en/de/it/fi), generiert mit `flutter gen-l10n` |
| `features.csv` | eine neue Zeile „Browser status" (Core) |
| `test/q_dashboard_kacheln_test.dart` (neu) | 24 Tests für die vier Parser |
| `test/hub_navigation_test.dart` | Hermetizität: die zwei neuen Poller schlafen genauso wie der Stats-Poller |

## Die vier Abnahmekriterien

### Q2 — Neustart-Badge

`RebootService` liest `/var/run/reboot-required` (Marker) und `/var/run/reboot-required.pkgs`
(Paketliste). Das Dashboard zeigt ein Badge („Neustart nötig") und die Health-Sektion listet
die auslösenden Pakete. Fehlt die Paketliste, ist der Neustart trotzdem fällig — die Ursache
lässt sich dann nur nicht benennen. Das Badge verschwindet, sobald die Marker-Datei nach dem
Neustart weg ist.

### Q3 — Kachel „Fehlgeschlagene Dienste"

`FailedUnitsService` fragt **beide** Scopes ab: `systemctl list-units --failed -o json` und
`systemctl --user list-units --failed -o json`. Die Kachel zeigt die Zahl und die Liste mit
Unit, Beschreibung und Scope. Kaputtes JSON, ein leerer Wert oder ein Unit-Eintrag ohne Namen
werden übersprungen, statt die Kachel zu sprengen. Eigener Poller mit 30-Sekunden-Takt — der
Zustand ändert sich viel langsamer als die CPU-Zahlen.

### Q5 — Browser-Status

Read-only. Der Standardbrowser kommt aus `AppLauncher.defaultBrowserDesktopId()` (aus V0.8.2),
der Vergleich gegen `gio mime x-scheme-handler/https` liefert den Handler, den HTTPS-Links
tatsächlich öffnen. Weichen die beiden ab, steht eine Warnung daneben. Die App stellt nichts
um.

**Das Ausgabeformat von `gio` wurde gemessen, nicht geraten** (gio 2.74):

```
Default application for ?x-scheme-handler/https?: brave-browser.desktop
No registered applications
No recommended applications
```

Der Parser liest die erste Zeile; die beiden anderen Abschnitte listen nur Kandidaten und
werden ignoriert.

### Q6 — Speicher-Kachel ehrlich

Die Warnstufe kommt jetzt aus **PSI** (`/proc/pressure/memory`, `avg60`) statt aus der
RAM-Quote. Die Swap-Zeile ist aufgeteilt: zram (`/sys/block/zram*/mm_stat`, komprimierter
RAM-Speicher) und Disk-Swap stehen in zwei eigenen Zeilen, weil sie verschiedene Dinge sind.
zram zeigt den Weg „7,2 → 2,1 GB".

## TDD-Beleg

`test/q_dashboard_kacheln_test.dart` — 24 Tests in vier Gruppen:

| Gruppe | Testfälle |
|---|---|
| Q2 — der Reboot-Marker | Paketliste · leere Zeilen und Kommentare werden übersprungen · leere Datei · ohne Marker kein Reboot · Marker ohne Paketliste · Marker mit Paketliste |
| Q3 — die fehlgeschlagenen Units | Unit, Beschreibung und Scope · der Scope kommt vom gefragten Manager · Unit ohne Beschreibung · Eintrag ohne Namen · kaputtes JSON · leere Antwort |
| Q5 — der Standardbrowser | Handler wird gelesen · Kandidaten-Sektionen werden ignoriert · Ausgabe ohne Default-Zeile · leerer Wert |
| Q6 — die Speicher-Kachel | `avg60` aus der PSI-Datei · normal / elevated / high · unbrauchbare PSI-Datei · zram vor/nach der Kompression · kaputte zram-Statistik · zram-Kapazität |

Die Tests laufen ohne Dateisystem und ohne Prozess: die Parser sind reine Funktionen, der
Dateisystem-Teil ist in `RebootService.readStatus` getrennt (dort mit Temp-Verzeichnis getestet).

## Gate-Protokoll

`bash /workspace/tools/run-mla-gates.sh` — echte Exitcodes, Ausgabe zeigt den geprüften Baum.

| Gate | Ergebnis |
|---|---|
| `flutter pub get` | OK |
| `bash tool/check-versions.sh` | OK |
| `dart format --output=none --set-exit-if-changed lib test` | OK — 129 Dateien, 0 geändert |
| `flutter analyze` | OK — *No issues found!* |
| `flutter test` | OK — **254 Tests** (230 Baseline + 24 neue) |
| Python-Unit-Tests | OK — 62 Tests |
| GTK-Token-Gate | OK — 96 Tests (2 skipped) |
| `packages/la_core` | OK — 0 Findings, 25 Dateien, 68 Tests |

**Summenzeile: `ALLE GATES GRUEN`.**

**CSV-Check:** `{21} [25, 17, 4]` — 21 Felder, 46 Zeilen. Core steigt von 24 auf 25 durch die
neue Zeile „Browser status" (Core, gleiche Spaltenbelegung wie der Browser-Launcher).

## Konventionen geprüft

- Conventional Commit, deutschsprachiger Body, `Refs #58` ✓
- `dart format` vor dem Commit ✓
- Logging über `lib/services/logger.dart`, kein `print` ✓
- **l10n-Ratchet:** alle vier ARB-Dateien (en/de/it/fi) mit denselben 15 neuen Keys; die
  generierten Dateien mit `flutter gen-l10n` neu erzeugt ✓
- features.csv: 21 Felder, Header unverändert ✓
- Keine Secrets, kein Versions-Bump, kein Release ✓
- **Kein Prozessstart beim Betreten des Dashboards ohne Nutzerwunsch:** die neuen Poller
  starten `systemctl` bzw. `gio` erst, wenn ihre Kachel sichtbar ist — im Test nachgewiesen
  (der Hub-Navigation-Test startet keinen Prozess)

## Zwei Korrekturen an der Vorarbeit

1. **Das `gio`-Format.** Die ursprüngliche Parser-Version erwartete die Zeile
   `x-scheme-handler/https: <id>`. Diese Zeile gibt `gio` **nie** aus — der Parser hätte in
   Produktion immer `null` geliefert und die Kachel hätte nie den Browser gezeigt. Das
   tatsächliche Format steht oben; Parser und Test sind darauf umgestellt.

2. **Die Hermetizität des Hub-Tests.** Die beiden neuen Poller starten beim Mount des
   Dashboards einen echten Prozess. Im Widget-Test hinterlässt das einen hängenden Timer und
   der Test schlägt fehl. Die Poller werden jetzt im `setUp` genauso schlafen gelegt wie der
   Stats-Poller — die Reihenfolge (erst `resetForTesting`, dann `setWindowVisible(false)`)
   ist dokumentiert.

## Offene Punkte

- **Q7 bleibt offen** — die Empfehlung „Feedback an Upstream abklemmen" braucht Bastis
  Entscheidung; das Issue ist nicht Teil dieses Pakets.
- **Q4 bleibt offen** — der Wechsel des Hotkeys auf gsettings ist ein M-Thema, greift in den
  C++/GTK-Runner ein und braucht ein Desktop-System zum Abnehmen.
- **Die Kacheln zeigen Systemzustand, keine Aktion.** Weder Reboot noch Dienste noch Browser
  werden von der App aus verändert — der Safety-Default des Projekts bleibt.
- **Die visuellen Details** (Farbe des Badges, Zeilenumbrüche in der Health-Sektion) sind
  nicht per Screenshot geprüft; die Logik ist es.
