# MLA-Next: Verifikation und Handoff

Aktualisierung 2026-09-30: Die GTK-Scaffold-Laufzeit ist auf Zorin verifiziert (Wayland- und X11-Start — Gate 0, BASELINE §2; manuelle Checks offen), la_core-Spike und Registry sind getestet inkl. Performance-Messwerten (Gate 1, BASELINE §7). Weiterhin nicht ausgeführt: IPC-/Gate-2-Tests, Flutter-vs-GTK-Vergleichsmessung (Roadmap 0.0.3), manuelle Gate-0-Checks (BASELINE §3). Der Scaffold-Commit ist **kein** Release-Gate.

## Gate 0: Scaffold

- [x] `python3 -m py_compile prototype/gtk/mla_app.py` grün, Ausgabe und Python-Version erfassen. — 2026-09-29: automatisiert verifiziert, siehe docs/mla-next/BASELINE.md; manuelle Checks offen
- [x] Auf Zorin OS 18.1 als normaler Nutzer starten; GTK4/libadwaita-Version, Wayland/X11 festhalten. — 2026-09-29: automatisiert verifiziert, siehe docs/mla-next/BASELINE.md; manuelle Checks offen
- [ ] Dashboard, Monitor, Backup und Security anwählen; Titel, rechte Details und unbekannten Backup-Status prüfen.
- [ ] Fenster verkleinern/vergrößern; Tastatur/Fokus, Hell/Dunkel, 100/125/150%-Skalierung prüfen.
- [x] App ohne Root, ohne Systemschreibfunktion, ohne Secrets in Screenshots/Logs. — 2026-09-29: unprivilegierter Start als normaler Nutzer, Fixture-Only (Demo-Daten, keine Systemaktionen), Screenshots nur /tmp — siehe docs/mla-next/BASELINE.md

## Gate 1: Kern/Registry

- [x] Issue #59: `dart test` und `dart compile exe`; Probe ohne DISPLAY/WAYLAND_DISPLAY; Binärgröße/Startzeit messen. — 2026-09-30: `dart test` 14/14 in packages/la_core (frisch); `dart compile exe` + Headless-Lauf ohne DISPLAY/WAYLAND_DISPLAY; Binär 6 547 240 Bytes, Median-Startzeit 3 ms — siehe docs/mla-next/BASELINE.md §7
- [x] Issue #60: IDs eindeutig, fehlende/zyklische Abhängigkeiten abgewiesen, Start/Stop/Lazy-Loading getestet; Flutter-Navigation unverändert. — 2026-09-30: `dart test` 14/14 in packages/la_core (doppelte IDs, fehlende/zyklische Abhängigkeiten, Topo-Start/Rückwärts-Stop, Single-Flight); `git diff --stat 92bef60..HEAD -- lib/ additional/ deb/ linux/` leer (Exit 0); Root-`flutter test` +184 bestanden
- [x] Bestehende Repo-Gates nach Scope tatsächlich ausführen: `tool/check-versions.sh`, `dart format`, `flutter analyze`, `flutter test`, Python-Tests. — 2026-09-30 frisch ausgeführt, alle Exit 0: `version 0.8.0 is consistent`; `Formatted 118 files (0 changed)`; `No issues found!`; `00:02 +184: All tests passed!`; `Ran 49 tests` / `OK` — vgl. docs/mla-next/BASELINE.md §4
- [x] Issue #93, Schnitt 1 (Parser-Umzug nach `packages/la_core`): App-Test byte-identisch, alle Gates grün. — 2026-09-30: Handoff-Abschnitt unten. DI/Event-Vertrag und Flutter-`HubModule`-Adapter bleiben offen (spätere Schnitte von #93).

## Gate 2: IPC und Backup

- [ ] Frame-/UTF-8-/JSON-/Schema-/Timeout-/Reconnect-/Backpressure-Tests; falsche Peer-UID und Event-Lücke.
- [ ] Issue #63: User-/System-Units, Timer, Journal-Fehler und Unknown/Stale mit Fixtures; keine Repo-/Passwortzugriffe.
- [ ] `systemctl --user start` nur nach Bestätigung und serverseitiger Allowlist; Abbruch, Race und Doppel-Request prüfen.
- [ ] Kein grünes Backup allein wegen eines erfolgreichen Unit-Starts; Restore separat beurteilen.

## Handoff #93 Schnitt 1 — Parser-Umzug nach `packages/la_core`

**Basis-SHA:** `513def150dbb37ff3883b2061396f7f326e4527b` (= `origin/feature/mla-gtk-scaffold` beim Start).
**Commits:** `94b5ef8` (la_core), `755665c` (App), `080becf` (dieser Nachweis) — **gepusht** nach
`origin/feature/mla-gtk-scaffold` als Fast-Forward `513def1..080becf` (2026-09-30).

**Scope.** Vier reine Parser und ihre Modelle wandern in den Flutter-/GTK-freien Kern; die App-Dateien
werden zu delegierenden Fassaden. Die **Runner bleiben app-seitig** (`disks`, `processCount`,
`zombieCount`, `topProcessesBy*`, `hasSwap`, `uptime`, `getCpuThreadCount`, `getCpuAverageLoad`) — sie
hängen an `Linux.runCommandWithCustomArguments` bzw. `CommandHelper`, ein Umzug würde
`runInShell`/`expandCommand`/`kDebugMode` verschieben und damit echtes Verhalten.

**Pfade.**

| Wandert nach `packages/la_core/lib/src/parsers/` | Quelle |
|---|---|
| `df.dart` — `DeviceInfo` + `parseDfOutput` | `lib/linux/linux_filesystem.dart` |
| `process.dart` — `ProcessStat` + `parsePsOutput` | `lib/linux/linux_process.dart` |
| `system.dart` — `Uptime` + `parseUptime` + `parseLoadAvg` | `lib/linux/linux_system.dart` |
| `memory.dart` — `MemoryInfo` + `MemoryInfo.parseFreeOutput` | `lib/services/system_stats_service.dart` |

Barrel: `packages/la_core/lib/la_core.dart` (+4 Exporte). Neu: `packages/la_core/test/parsers_test.dart`.
App-seitig geändert: die drei `lib/linux/*`-Fassaden, `lib/services/system_stats_service.dart`
(Import **und** Export von `MemoryInfo`), `pubspec.yaml`, `pubspec.lock`.

**Umsetzung.** Die Rümpfe sind 1:1 übernommen, nur `static` → Top-Level; `@immutable` entfällt, damit
der Kern dependency-frei bleibt (die Felder sind weiterhin `final`, der Konstruktor `const`).
`SystemStats` und `SystemStatsService` bleiben unverändert app-seitig.

Zwei Fallen, die den Umbau bestimmen und beide **nicht** von einem Analyzer-Gate gefangen werden:

- **Class-Scope-Schatten.** `static parseDfOutput(s) => parseDfOutput(s)` bindet auf den eigenen
  static → Endlosrekursion, die sauber kompiliert. Deshalb `import ... as core;` + `core.parseX(...)`
  in jedem Delegator.
- **`export` importiert nicht.** `system_stats_service.dart` braucht beides: `import ... show MemoryInfo`
  für den eigenen Scope (Feld `SystemStats.memory`, Aufruf in `refresh`) und `export ... show MemoryInfo`,
  damit `test/system_parsers_test.dart` über `package:linux_assistant/...` weiter an den Typ kommt.

**Gates — tatsächlich ausgeführt (2026-09-30), alle Exit 0.**

| Gate | Ausgabe |
|---|---|
| `dart pub get` (la_core) | `Got dependencies!`; `packages/la_core/pubspec.lock` unverändert (kein Lock-Churn) |
| `dart analyze` (la_core) | `No issues found!` |
| `dart format --output=none --set-exit-if-changed .` (la_core) | `Formatted 13 files (0 changed)` |
| `dart test` (la_core) | `00:00 +30: All tests passed!` (vorher 14) |
| `dart compile exe bin/la_probe.dart` | `Generated: /tmp/la_probe` |
| `env -u DISPLAY -u WAYLAND_DISPLAY /tmp/la_probe --version` | `la_probe 0.0.1-spike.1 (dart 3.13.4 (stable) … on "linux_x64")`, Exit 0 |
| `flutter pub get` (App) | `Got dependencies!` |
| `bash tool/check-versions.sh` | `version 0.8.0 is consistent` |
| `dart format --output=none --set-exit-if-changed lib test` | `Formatted 118 files (0 changed)` |
| `flutter analyze` | `No issues found! (ran in 1.4s)` |
| `flutter test` | `00:02 +184: All tests passed!` (unverändert) |
| `flutter test test/system_parsers_test.dart` | `00:00 +22: All tests passed!` |
| `python3 -m unittest discover -s tests -t .` | `Ran 49 tests` / `OK` |

**Abnahme-Diff** (`git diff --stat 513def1..HEAD -- lib/ packages/ pubspec.yaml pubspec.lock tool/ additional/ deb/ linux/`):
13 Dateien, +452/−186 — 4 App-Dateien unter `lib/`, 7 unter `packages/la_core/`, `pubspec.yaml`/`pubspec.lock`.
`test/system_parsers_test.dart` ist **byte-identisch** (leerer Diff). Leak-Grep über die neuen
la_core-Dateien: keine Treffer.

**Nicht ausgeführt / keine Aussage.**

- **Kein CI-Grün.** `.github/workflows/build.yml` triggert `feature/mla-gtk-scaffold` nicht.
- Kein Verhaltensnachweis für die Runner — die Tests prüfen `isRunning`/`subscriberCount`, `refresh()`
  schluckt Exceptions. In Schnitt 1 unkritisch, weil die Runner unverändert sind; bei einem späteren
  Runner-Umbau ist eine echte Verhaltensprobe Pflicht.
- Keine manuelle Zorin-Prüfung nötig (kein UI-Anteil); `install.sh`, `deb/`, `prototype/` unberührt.

**Planabweichung (festgehalten, weil sie vorher anders geplant war).** Der Plan wollte das SDK-Bound von
`packages/la_core` auf `^3.4.0` senken. Das wurde **verworfen**: `bf4942b3` hat es bewusst auf `^3.11.0`
gehoben, `packages/la_core/pubspec.lock` (getrackt) verlangt `dart: ">=3.11.0 <4.0.0"`, und die
Spracheversion steuert die Formatierer-Regeln — das Absenken hätte `test/module_registry_validate_test.dart`
umformatiert (fremde Datei) statt ein No-op zu sein. `^3.11.0` bleibt; ergänzt ist nur ein Kommentar,
der die Falle festhält.

**Unabhängige Verifikation.** Workflow `mla-93-parser-move-verify` (read-only, vier Linsen + Synthese,
412 942 Subagenten-Tokens): **Synthese-Verdikt `PASS`, keine Blocker.** Die drei Block-Muster wurden
gezielt geprüft und ausgeschlossen: (1) Endlosrekursion — alle vier Delegatoren rufen prefixed
`core.parseX(...)`, die unqualifizierten Aufrufe in `disks()`/`_getTopProcesses()`/`LinuxSystem` binden
auf den statischen Delegator, nicht auf sich selbst; (2) gespaltener Typ — je **genau eine** Definition
von `DeviceInfo`/`ProcessStat`/`Uptime`/`MemoryInfo`, alle in la_core; (3) Logikdrift — die Rümpfe sind
gegen `513def1` byte-identisch, nur `static` → Top-Level. Alle Gates hat die Synthese **selbst**
ausgeführt und bestätigt (u. a. `+184`, `+22`, `30/30`, `No issues found!`, `0 changed`,
`Generated: /tmp/la_probe_test` + Probelauf `ok:probe.self`).

Linsen: 1 (Rekursion) `clean` · 2 (Typ-Identität/import-vs-export) `clean` · 4 (Gate-Belege) `clean` ·
3 (Flutter-Freiheit/Body-Treue) `befund` **ohne Blocker** — beide Hinweise betreffen nur
`packages/la_core/pubspec.yaml`, keine Parser-Abweichung.

Belegehrlichkeit, drei Einschränkungen dieser Runde (aus der Synthese übernommen):

- Die Veredikte der Linsen 1, 2 und 4 tragen **leere Findings-Arrays**, also keine eigene Belegkette.
  Ihre Substanz ist durch die Nachprüfung der Synthese gedeckt — nicht durch Linsen-Belege.
- Der Arbeitsbaum hat sich **während** der Verifikation bewegt (Rücknahme der SDK-Absenkung, Rücknahme
  des Umformatierens von `module_registry_validate_test.dart`). Dieses `PASS` gilt für den Stand
  `513def1` + `94b5ef8` + `755665c`.
- **Formatierer-Methodik:** `dart format` zieht die Spracheversion aus `.dart_tool/package_config.json`,
  nicht nur aus der `pubspec.yaml`. Während der Sitzung war la_core dort noch auf `3.4` gepinnt, während
  die `pubspec.yaml` `^3.11.0` deklarierte — das Format-Gate hätte die falschen Regeln gemessen. Jetzt
  konsistent (package_config 3.11 == pubspec `^3.11.0` == `pubspec.lock` `>=3.11.0`). **Regel für
  künftige Floor-Änderungen: erst `dart pub get`, dann `dart format` als Gate.**

**Rückfallplan.** `git revert 080becf 755665c 94b5ef8` genügt: kein Migrationsschritt, kein Datenpfad,
keine Unit, kein Packaging berührt; `la_core` ist nirgends installiert. Der Branch ist seit 2026-09-30
geteilt (gepusht), deshalb ist `git reset --hard 513def1` hier **kein** gangbarer Weg mehr — er bräuchte
einen Force-Push. Die fünf neu aufgelösten Transitiven in `pubspec.lock` (`intl` 0.20.3, `test_api` 0.7.12,
`matcher` 0.12.20, `meta` 1.19.0, `vector_math` 2.4.3) kommen durch die installierte Flutter 3.47.5 ohnehin
wieder — die Lockdatei war ihr gegenüber veraltet.

**Offene Punkte (Schnitt-1-Grenze von #93).** DI (injizierbarer Runner statt static-Global,
`runningInFlatpak`/`_cachedThreadCount` als Instanzzustand), Event-Vertrag (heute nur
`ValueNotifier<SystemStats>`; Saat = `ProbeResult`/`ModuleDescriptor`), Flutter-`HubModule`-Adapter,
`la_probe`-Ablage in `build-deb.sh`, Logger-/`CommandHelper`-Umzug.

## Agenten-Handoff

Je Aufgabe: Basis-SHA, Pfade, Scope, Failing-Test/Fixture, Umsetzung, Ergebnis von Reviewer 1 (Funktion/UX) und Reviewer 2 (Sicherheit), **wirklich ausgeführte** Gates mit Ausgaben, rote/übersprungene Gates, manuelle Zorin-Prüfung, Rückfallplan. Kein Merge/Release/Policy-Update ohne gesonderte Freigabe.
