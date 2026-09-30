# MLA-Next: Verifikation und Handoff

Aktualisierung 2026-09-30: Die GTK-Scaffold-Laufzeit ist auf Zorin verifiziert (Wayland- und X11-Start — Gate 0, BASELINE §2; manuelle Checks offen), la_core-Spike und Registry sind getestet inkl. Performance-Messwerten (Gate 1, BASELINE §7). **#93 ist gemerged** (PR #89 → `6c5c625`, PR #107 → `e4c1346`; Merge-Freigabe 2026-09-30) und **#94 (Fixtures + Fehler-/Stale-Modelle) auf `feature/mla-94-fixtures` umgesetzt** (Handoff-Abschnitt unten, alle Gates grün, wartet auf Final-Review/Freigabe). Die #95-Baselinemessung Flutter-Release vs. GTK-Shell liegt vor (BASELINE §8, Handoff #95 unten). Weiterhin nicht ausgeführt: IPC-/Gate-2-Tests, manuelle Gate-0-Checks (BASELINE §3). Der Scaffold-Commit ist **kein** Release-Gate.

## Gate 0: Scaffold

- [x] `python3 -m py_compile prototype/gtk/mla_app.py` grün, Ausgabe und Python-Version erfassen. — 2026-09-29: automatisiert verifiziert, siehe docs/mla-next/BASELINE.md; manuelle Checks offen
- [x] Auf Zorin OS 18.1 als normaler Nutzer starten; GTK4/libadwaita-Version, Wayland/X11 festhalten. — 2026-09-29: automatisiert verifiziert, siehe docs/mla-next/BASELINE.md; manuelle Checks offen
- [ ] Dashboard, Monitor, Backup und Security anwählen; Titel, rechte Details und unbekannten Backup-Status prüfen.
- [ ] Fenster verkleinern/vergrößern; Tastatur/Fokus, Hell/Dunkel, 100/125/150%-Skalierung prüfen.
- [x] App ohne Root, ohne Systemschreibfunktion, ohne Secrets in Screenshots/Logs. — 2026-09-29: unprivilegierter Start als normaler Nutzer, Fixture-Only (Demo-Daten, keine Systemaktionen), Screenshots nur /tmp — siehe docs/mla-next/BASELINE.md

## Gate 1: Kern/Registry

- [x] Issue #59: `dart test` und `dart compile exe`; Probe ohne DISPLAY/WAYLAND_DISPLAY; Binärgröße/Startzeit messen. — 2026-09-30: `dart test` (damals 14/14, heute 30/30) in packages/la_core; `dart compile exe` + Headless-Lauf ohne DISPLAY/WAYLAND_DISPLAY; Binär 6 547 240 Bytes, Median-Startzeit 3 ms — siehe docs/mla-next/BASELINE.md §7
- [x] Issue #60: IDs eindeutig, fehlende/zyklische Abhängigkeiten abgewiesen, Start/Stop/Lazy-Loading getestet; Flutter-Navigation unverändert. — Kern-Registry-Teil 2026-09-30: `dart test` 30/30 in packages/la_core (doppelte IDs, fehlende/zyklische Abhängigkeiten, Topo-Start/Rückwärts-Stop, Single-Flight); `git diff --stat 92bef60..HEAD -- lib/ additional/ deb/ linux/` leer (Exit 0). **Der Flutter-`HubModule`-Adapter samt Vollständigkeitstest ist nachgeliefert** — Belege im Abschnitt „Abnahme #60" unten (Root-`flutter test` +200)
- [x] Bestehende Repo-Gates nach Scope tatsächlich ausführen: `tool/check-versions.sh`, `dart format`, `flutter analyze`, `flutter test`, Python-Tests. — 2026-09-30 frisch ausgeführt, alle Exit 0: `version 0.8.0 is consistent`; `Formatted 118 files (0 changed)`; `No issues found!`; `00:02 +184: All tests passed!`; `Ran 49 tests` / `OK` — vgl. docs/mla-next/BASELINE.md §4
- [x] Issue #93, Schnitt 1 (Parser-Umzug nach `packages/la_core`): App-Test byte-identisch, alle Gates grün. — 2026-09-30: Handoff-Abschnitt unten. DI, Event-Vertrag und `la_probe`-Ablage sind in **Schnitt 2** geliefert (Abschnitt „Handoff #93 Schnitt 2" unten, alle Gates grün); der Flutter-`HubModule`-Adapter ist mit #60 geliefert (Abschnitt unten).
- [x] Issue #94 (Gemeinsame Fixtures + Fehler-/Stale-Modelle): beide Tracks lesen `test/fixtures/`, Leak-Check leer, `ProbeStatus` getestet. — 2026-09-30: Handoff-Abschnitt „Handoff #94" unten; alle Gates grün (flutter 200/200, la_core 60/60, Python 53/53).

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
`ValueNotifier<SystemStats>`; Saat = `ProbeResult`/`ModuleDescriptor`), Flutter-`HubModule`-Adapter (**mit #60 geliefert**, siehe Abschnitt unten),
`la_probe`-Ablage in `build-deb.sh`, Logger-/`CommandHelper`-Umzug.

## Abnahme #60 (FU1) — Modul-Registry und Flutter-`HubModule`-Adapter

**Basis-SHA:** `70ddd05` (= `HEAD` auf `feature/mla-gtk-scaffold` beim Start), Arbeitsbaum sauber.
**Status:** umgesetzt und **nicht committet** — Push/PR/Bump/Tag warten auf Bastis OK.

**Scope.** Acht navigationsrelevante `switch`-Blöcke in `lib/layouts/hub/hub_shell.dart` werden durch
Lookups in eine neue Registry ersetzt. Neu: `lib/layouts/hub/hub_module.dart` (`HubModule`,
`hubModules`, `hubModuleOf`; die Enums `HubSection`/`HubTool` ziehen dorthin um, `hub_shell.dart`
re-exportiert sie). Die neun Einträge reichen je einen `ModuleDescriptor` aus `packages/la_core`
**durch**; `la_core` bleibt unangetastet und Flutter-frei. Vier neue ARB-Keys (`browser`,
`quickNotes`, `fileManager`, `systemMonitor`) in allen vier ARB-Dateien + `flutter gen-l10n`.
`SystemStatsService` bekommt einen read-only Test-Seam `sectionActive` (nur lesend, nur für den Test).
Die neun Screens bleiben unverändert.

**Geänderte/neue Dateien** (`git status --short`): 11 modifiziert (`lib/l10n/*` 9×,
`lib/layouts/hub/hub_shell.dart`, `lib/services/system_stats_service.dart`), 4 neu
(`lib/layouts/hub/hub_module.dart`, `test/hub_module_registry_test.dart`, `test/hub_navigation_test.dart`,
`test/hub_test_harness.dart`).

**Gates — tatsächlich ausgeführt (2026-09-30), alle Exit 0.**

| Gate | Ausgabe |
|---|---|
| `bash tool/check-versions.sh` | `version 0.8.0 is consistent` |
| `dart format --output=none --set-exit-if-changed lib test` | `Formatted 122 files (0 changed)` |
| `flutter analyze` | `No issues found!` |
| `flutter test` (voller Lauf) | `00:09 +200: All tests passed!` |
| `flutter test test/hub_navigation_test.dart` | `+9: All tests passed!` (H1–H9) |
| `flutter test test/hub_module_registry_test.dart` | `+7: All tests passed!` (T1–T7) |
| `flutter test test/l10n_test.dart` | `+7: All tests passed!` (Budgets halten) |
| `python3 -m unittest discover -s tests -t .` (additional/python) | `Ran 49 tests` / `OK` |
| la_core: `dart analyze` · `dart format` · `dart test` | `No issues found!` · `13 files (0 changed)` · `+30: All tests passed!` |

**Rest-Switch-Beweis.** `grep -n "switch (" lib/layouts/hub/hub_shell.dart` → nur `:151`
(`BrowserLaunchResult`) und `:456` (`ThemeMode`), die zwei erlaubten Ausnahmen. Kein
`_sectionUsesStats`/`_titleOf`/`_iconOf`/`_iconOfTool`/`_titleOfTool`/`_buildSection`/`_contentFor`
mehr im Baum. Jede verbleibende `HubSection`/`HubTool`-Nennung in `lib/` ist ein typisiertes Feld,
eine Iteration (`HubSection.values`) oder ein Navigationsaufruf — keine Icon-/Titel-/Screen-/
Stats-Unterscheidung.

**Abnahmekriterien → Beleg.** (a) *Verhalten unverändert:* H1–H8 blieben **byte-identisch** und waren
grün **gegen den Switch-Code** (Phase 1) wie danach; sie laufen unter en/de. (b) *Neues Modul =
Listeneintrag + Screen:* Map-Eintrag + `screenBuilder` + ein ARB-Key je Datei. (c) *Vollständigkeits-
test:* T1 (Bijection `hubModules.keys` == Enum-Namen, genau neun, `id == key`), T3 (Enum→Screen-Typ,
deckt die nicht pumpbaren Sektionen ab), T4 (`ModuleRegistry.validate()` über alle neun Deskriptoren).
(d) *Adapter:* `HubModule` ergänzt Icon, Tier, `screenBuilder`, `isAvailable(Environment)`; `la_core`
unberührt (`git status --short packages/` leer) und Flutter-frei.

**Unabhängige Verifikation.** Workflow `mla-60-phase3-registry` (Phase 3 + drei read-only Linsen +
Synthese, 444 k Subagenten-Tokens, 0 Fehler): **Synthese `PASS`, keine Blocker.** Linse 1
(Verhaltens-Diff gegen `HEAD`) bestätigt alle acht Switches als zweiggenau ersetzt; Linse 2 (Vertrag/
Single-Source) bestätigt `hubModules` als Single Source, `id == Enum.name` durch T1 gehalten und
`la_core` unberührt; Linse 3 (Belege) hat alle Gates selbst nachgefahren und dabei meinen
Test-Gesamtwert korrigiert (+200, nicht +193 — die +193 zählten die sieben Registry-Fälle nicht mit).

**Akzeptierte Befunde (alle minor/info, keiner blockierend).**

1. **it/fi-Titel-Delta.** Für it/fi zeigen die vier Werkzeugtitel jetzt echte Übersetzungen statt des
   englischen `_tr`-Fallbacks (`Dateimanager`→`Gestore file`, `Systemmonitor`→`Monitor di sistema`,
   fi `Tiedostoselain`, `Järjestelmän seuranta`). en/de sind **byte-identisch** zu vorher. Das ist die
   vom l10n-Gate erzwungene, beabsichtigte Folge des ARB-Umzugs (Planabweichung 3); nur Labels, keine
   Zeile/Screen/Selection. H1–H9 decken it/fi **nicht** ab — deshalb Bastis Sichtprüfung.
2. **Tools-`usesStats` hat eine zweite Quelle.** Sektionen lesen die Registry
   (`hubModuleOf(...).usesStats`), aber `_selectTool` setzt `setSectionActive(false)` hart. Heute
   deckungsgleich (alle vier Tools `false`, von T2 gepinnt), doch ein künftiges Tool mit
   `usesStats: true` würde ignoriert. Latent, nicht blockierend.
3. **Sidebar-Verfügbarkeitsfilter** neu (`isAvailable(Linux.currentenvironment)`): heute inert, da alle
   neun `alwaysAvailable`. Beobachtbar verhaltensneutral.
4. **Topbar-Such-Icon** dupliziert `Icons.search`/`hubSearch` aus der Registry (Chrome, keine Nav-Zeile).
5. **`hubModuleOf` matcht nur über `key.name`** — ein fremdes Enum mit kollidierendem Namen würde still
   falsch auflösen (heute kein solcher Name; latent).
6. **Rest-Enum-Vergleich** `if (_section != HubSection.search)` (`:429`) ist mit `HEAD` identisch und
   keiner der acht migrierten Switches (Transparenzhinweis).

**Nicht ausgeführt / keine Aussage.**

- **Kein CI-Grün.** `.github/workflows/build.yml` triggert `feature/mla-gtk-scaffold` nicht.
  Ersatzwahrheit ist der lokale Lauf oben.
- Keine Messung des 3-s-Polls über echte `ps`/`df`/`free`-Forks — die Stats-Kopplung ist über den
  Test-Seam `sectionActive` belegt (H9), nicht über Prozess-Spawns.
- Kein `ModuleActivator` in Produktion, kein `activate`/`deactivate`, keine DI, kein Lebenszyklus; nur
  der Test registriert und validiert. `probes`/`actions` sind Getter **ohne Aufrufer** (#62/#74).
- `tier` ist definiert und gepinnt, aber von **keiner** Mechanik gelesen (Andockpunkt #86).
- `install.sh`, `deb/`, `prototype/` unberührt.

**Nebenwirkung der Tests (melden, nicht beheben).** H5/H9 pumpen `QuickNotesPage`; deren `_ensureDir()`
legt beim Lauf ein echtes Verzeichnis unter dem XDG-Datenpfad an. Inhalt wird nie assertiert.

**Planabweichungen.**

1. Das Issue nennt „sechs switch-Blöcke"; tatsächlich sind es **acht** navigationsrelevante (das Issue
   bittet selbst um Nachzählung).
2. „Ein neues Modul ist ein Listeneintrag plus Screen" wird zu: Map-Eintrag + Screen-Fabrik + ein
   ARB-Key in **vier** Dateien (+ `gen-l10n`). Kein zentraler Titel-Table möglich (Flutters l10n kennt
   keinen dynamischen Zugriff).
3. „Verhalten unverändert" gilt **byte-genau für en/de**; für **it/fi** ändern sich vier Werkzeugtitel
   (Befund 1). fi-**Sektions**labels bleiben englischer Fallback wie zuvor.
4. `usesStats` und `tier` stehen nicht in der Issue-Feldliste, sind aber durch Entscheid 1 (Enums als
   ID-Raum) bzw. die Issue-Nennung „Tier" erzwungen.
5. Der Vollständigkeitstest ist eine **eigene neue Datei** (`test/hub_module_registry_test.dart`), keine
   Erweiterung von `hub_navigation_test.dart` — so bleibt H1–H9 byte-identisch als Charakterisierung.

**Rückfallplan.** `git revert` der (noch zu committenden) #60-Commits genügt: kein Migrationsschritt,
kein Datenpfad, keine Unit, kein Packaging; `la_core` ist unberührt, die generierten l10n-Dateien
laufen mit `gen-l10n` reproduzierbar neu. Der Branch ist seit 2026-09-30 geteilt (gepusht), deshalb
ist `git reset --hard 70ddd05` hier **kein** Weg — er bräuchte einen Force-Push.

**Leak-Grep (öffentliches Repo).** Über den #60-Diff und die neuen Dateien: keine Treffer. Über
`docs/` insgesamt bleiben Treffer, aber **kein neuer** und **kein echter**: die Muster `~/…`
(generische XDG-Pfade ohne Nutzernamen) und `:[0-9]{4,5}` (Dart-Zeilenreferenzen wie
`mint_y.dart:1054`, eine Prozess-ID) sind Fehlalarme der Plan-Regex, dazu ein bewusst fiktives
`/home/john`-Beispiel in `docs/handoff/analysis/bug-hunt-2026-09-10.md`. Der einzige echte Befund war
der **Nutzername** in drei Handoff-Dateien (Journal-/pkexec-Auszüge) — in einem eigenen Commit
redigiert (`<user>` statt des Namens; `--home=/home/<user>`). Empfehlung: das Gate auf
Nutzername/IP/`localhost` prüfen, nicht auf `~/` und Zeilen-/PID-Ziffern.

**Manuelle Abnahme (Bastis Teil, Wayland **und** X11).** Browser-Tap in der Sidebar (echter Start bzw.
die drei Snackbar-Varianten) · Sektions- und Tool-Wechsel im echten Fenster (3-s-Poll stoppt in
Security und in Tool-Screens, startet beim Zurückwechseln wieder) · Minimieren/Wiederherstellen ·
Sidebar-Kollaps an der 1000-px-Grenze beim echten Resize · **it/fi-Anzeige bestätigen** (Wortwahl ist
Vorschlag, ggf. zu korrigieren) · Optik: keine Verschiebung außer den Labels.

## Handoff #93 Schnitt 2 — DI, Event-Vertrag und `la_probe`-Ablage

**Basis-SHA:** `6c5c625` (= `HEAD` auf `feature/mla-93-rest`; Squash-Merge von PR #89 = `main` nach dem
#60-Adapter). Arbeitsbaum vor dem Schnitt sauber.
**Status:** umgesetzt und **nicht committet** — Push/PR folgen; **Merge und Schließen von #93 erst nach
gesonderter Freigabe**.

**Scope (vier beabsichtigte `lib/`-Dateien + Paket + Doku; `git diff --stat 6c5c625 -- lib/ deb/ additional/ linux/`
= genau `lib/helpers/command_helper.dart`, `lib/linux/linux_system.dart`, `lib/services/linux.dart`).**
- **la_core (neu, Flutter-frei):** `src/command_runner.dart` (`CommandRunner`-Interface mit der geforderten
  `run(...)`-Signatur, `CommandResult` byte-identisch aus `lib/helpers/command_helper.dart`, `CommandException`),
  `src/core_logger.dart` (`CoreLogger` + `const NullLogger`), `src/event_bus.dart` (typisierte `Topic<T>`,
  `CoreTopics.probeResult`/`moduleRegistered`, idempotentes `Subscription.cancel()`, `EventBus` mit
  `onListenerError`, Publish über `List.of`-Snapshot), `src/cpu_info.dart` (`CpuInfo({required CommandRunner
  runner})`, **Instanzfeld** `_cachedThreadCount`), `src/probe_registry.dart` (`ProbeRegistry({required EventBus
  bus, CoreLogger logger})` — `register`/`probe`/`run`, `run` publiziert genau ein `ProbeResult`).
  `module_registry.dart` um optionalen `EventBus? bus` erweitert (null → kein Publish). Barrel `la_core.dart` erweitert.
- **App-Grenze:** `lib/helpers/command_helper.dart` — `ProcessCommandRunner implements core.CommandRunner`
  (wörtlicher alter `runWithArguments`-Körper, `runningInFlatpak` als **Instanzfeld**), `CommandHelper` als
  Fassade mit `static final processRunner` + `static core.CommandRunner runner` (Injektions-Seam); `CommandResult`
  **sowohl** importiert (`as core`) **als auch** re-exportiert (Import-vs-Export-Falle aus Schnitt 1).
  `lib/services/linux.dart` — **genau eine Zeile** (`CommandHelper.processRunner.runningInFlatpak = true;`).
  `lib/linux/linux_system.dart` — `static int? _cachedThreadCount` entfernt, `getCpuThreadCount()` →
  `CpuInfo.threadCount()`; `parse*`/`uptime`/`getCpuAverageLoad` unangetastet.
- **Packaging:** `build-deb.sh` — nach dem Bundle-Copy `dart compile exe` von `packages/la_core/bin/la_probe.dart`
  nach `$STAGE/usr/lib/linux-assistant/la_probe` + display-loser `--version`-Smoke, `command -v dart`-Guard;
  **nicht** `/usr/bin`, **kein** `chmod +x`, **keine** polkit-Action, `deb/DEBIAN/control` unverändert.

**Bewusste Grenze.** `lib/services/linux.dart` (~2600 Zeilen Statik) bleibt Service-Locator; volle
Konstruktor-Injektion hätte das Minimal-Diff-Abnahmekriterium gesprengt. Kern = Konstruktor-Injektion,
App-Grenze = ein einziger Seam + Instanzfelder.

**Failing-Test/Fixture.** Keiner — reiner Zusatz im Flutter-freien Kern. Der Beweis liegt in den **22 neuen
la_core-Tests** (30 → 52) plus der byte-identischen App-Suite (`test/system_parsers_test.dart` sha-identisch,
kein App-Test angefasst).

**Nicht ausgeführte Gates / Grenzen.** Kein echter Prozess-Spawn-Beweis für `pkexec`/`flatpak-spawn` (nur
Codepfad wörtlich übernommen); CI für den Branch nicht getriggert; manuelle Gate-0-/Gate-1-Prüfungen auf Zorin
bleiben Bastis Teil; polkit-Dreifaltigkeit (`_privilegedEntryPoints`, Policy-`exec.path`, die zwei `chmod +x`)
bewusst **unberührt**.

**Reviewer.** Adversarialer Workflow `mla-93-rest-verify` (3 Sonnet-Linsen + Synthese, 2026-09-30), Stand
Arbeitsbaum auf `6c5c625`:
- **Reviewer 1 (Funktion/Umfang/Regeln)** — PASS: polkit-Dreifaltigkeit unberührt (`.policy`-Diff leer,
  `linux.dart` 1/1, kein neues `chmod +x`); `test/system_parsers_test.dart` sha-identisch (`d78d0141…`); kein
  App-Test geändert.
- **Reviewer 2 (Verträge/Korrektheit/Sicherheit)** — PASS: `CommandResult`-Signatur und Feldreihenfolge
  deckungsgleich, `ProcessCommandRunner`-Körper wörtlich, keine unprefixten la_core-Importe (keine
  Re-Export-Ambiguität), keine Secret-/`/home`-Pfade im Diff.
- **Beweisqualität/Lens 3 (Tore/Fälschungssicherheit)** — PASS: alle Gate-Aussagen selbst reproduziert.
  **Synthese: PASS ohne Blocker.**

**Gates — tatsächlich ausgeführt (2026-09-30), alle Exit 0.**

| Gate | Ausgabe |
|---|---|
| la_core `dart analyze` | `No issues found!` |
| la_core `dart format --output=none --set-exit-if-changed .` | `Formatted 22 files (0 changed)` |
| la_core `dart test` | `00:00 +52: All tests passed!` (30 alt + 22 neu) |
| `dart compile exe bin/la_probe.dart` | `Generated: /tmp/la_probe` |
| `env -u DISPLAY -u WAYLAND_DISPLAY /tmp/la_probe --version` | `la_probe 0.0.1-spike.1 (dart 3.13.4 … linux_x64)` |
| `bash tool/check-versions.sh` | `version 0.8.0 is consistent` |
| `dart format --output=none --set-exit-if-changed lib test` | `Formatted 122 files (0 changed)` |
| `flutter analyze` | `No issues found! (ran in 2.4s)` |
| `flutter test` (voller Lauf) | `00:04 +200: All tests passed!` |
| `flutter test test/system_parsers_test.dart` | `00:00 +22: All tests passed!` |
| `python3 -m unittest discover -s tests -t .` (additional/python) | `Ran 49 tests` / `OK` |
| `bash -n build-deb.sh` | Exit 0 |

**Neue Tests (22).** `command_runner_test` (Signatur/Fehlerpfad), `cpu_info_test` (**zwei `CpuInfo`-Instanzen
teilen keinen Cache** = Beweis, dass das Static weg ist), `event_bus_test` (No-Op ohne Abonnenten, werfender
Listener + `onListenerError`, Nutzung nach `dispose` → `EventBusError`), `probe_registry_test`
(Duplikat/unbekannt/Publish/Log).

**Rückfallplan.** `git revert` der Schnitt-2-Commits genügt: kein Migrationsschritt, kein Datenpfad, keine Unit
in `deb/DEBIAN/control`, `la_core` nirgends installiert.

## Handoff #94 — Gemeinsame Fixtures + Fehler-/Stale-Modelle

**Status:** umgesetzt auf `feature/mla-94-fixtures` (Basis `e4c1346`, 6 eigene Commits `aff40ac..3786464`), **nicht gepusht** — Push/PR folgen; **Merge und Schließen von #94 erst nach gesonderter Freigabe.**

**Basis-SHA/Pfade/Scope.** Basis `e4c1346` (main, nach PR-#107-Squash). Neu: `test/fixtures/` (fünf echte geschwärzte Zorin-Ausgaben `zorin_df/ps/uptime/free/loadavg.txt` + sieben synthetische Edge-Vektoren + `README.md` mit Capture-Kommandos, Schwärzungsregeln, GTK-/Python-Track-Abschnitt), `additional/python/tests/test_fixture_leak_check.py`, `packages/la_core/lib/src/probe_status.dart` (+ Barrel-Export), `packages/la_core/test/probe_status_test.dart`, SDD-Plan `docs/superpowers/plans/2026-09-30-mla-94-fixtures-state-models.md`. Geändert: `test/system_parsers_test.dart`, `packages/la_core/test/parsers_test.dart` (lesen nun die Fixtures statt Inline-Duplikate). Grenzen eingehalten: `test/system_monitor_service_test.dart` unberührt (QA3/#87), kein Code in `prototype/gtk/` (A2/#92), keine IPC-Contract-Fixtures (`IPC_CONTRACT.md:22`), polkit-Dreifaltigkeit unberührt.

**Failing-Test/Fixture.** Task 1: RED `FixturesClean` ohne `test/fixtures/` (zwei Failures, Output im Task-Report). Task 2: RED Compile-Fehler `Couldn't find constructor 'ProbeStatus'`. Task 3: Umbau bestehender Tests — Baseline-Vorher-Lauf dokumentiert (flutter 200/200 vor wie nach).

**Umsetzung.** Subagent-Driven Development: je Task frischer Implementer + Two-Reviewer-Gate (Reviewer A Funktion/Korrektheit, Reviewer B Vollständigkeit/Spec), Reports unter `.superpowers/sdd/task-{1..4}-{report,review*}.md`, Ledger `.superpowers/sdd/progress.md`.

**Zustandsmodell.** `ProbeState { unknown, running, ok, stale, failed }`; `stale` nur über `markStale()` aus `ok` (behält `data`/`observedAt`), kein Pfad zurück zu `ok` ohne frische Observation — 8 neue Tests, Vertragslage `IPC_CONTRACT.md:16`.

**Schwärzung/Leak-Check.** Capture exakt der Produktions-Aufrufe (df ohne LC_ALL, uptime/free mit `LC_ALL=C`, ps `-eo pcpu,args --sort=-pcpu`, `/proc/loadavg`), alles unprivilegiert. Schwärzung: `/home|/media/<name>` → `/user`-Platzhalter, Usernamen → `user`, URLs/Hosts → `example.invalid`; über die Regeln hinaus zusätzlich geschwärzt: QEMU-SMBIOS-Serial, MAC-Adresse, Xwayland-Authority-Suffix, eine Konto-URL (`.ai`-TLD, vom Leak-Check nicht abgedeckt — Lücke in `test/fixtures/README.md` dokumentiert, manuelle Durchsicht bleibt Pflicht). Leak-Check läuft bei jedem CI-Lauf mit (Trigger ausschließlich Push/PR) und ist auf allen zwölf `*.txt` leer. Final-Review-Fix (eigener Commit): die Brave-Crash-Reporter-Client-ID — persistent pro Installation, in der ersten Fassung fälschlich als Session-Zufallswert geführt — wurde 4× in `zorin_ps.txt` zu `<redacted>` geschwärzt; der Leak-Check prüft nun zusätzlich Ports in `port=`-/`port:`- und `host:port`-Form, wodurch `--port=41641`, `telnet:localhost:7100` und `tcp:<redacted>:7149` gleichfalls geschwärzt wurden; die verbleibenden bloßen Port-Zahlen (`websocket=5700`, `--port 7000`) sind in `test/fixtures/README.md` dokumentiert.

**Reviewer.** Je Task A (Korrektheit) + B (Vollständigkeit) parallel:
- Task 1: A APPROVED / B SPEC_OK — Werte und Scope unabhängig verifiziert; Minor: TLD-Allowlist-Lücke, `/opt/brave.com`-Fehlalarm (im Fixture neutralisiert), keine `subTest`s.
- Task 2: A APPROVED / B SPEC_OK — „kein stillschweigender stale→ok-Pfad" konstruktiv geprüft (`final class`, `_stale` privat, `ok` nur frischer Konstruktor); Gates von B reproduziert (60/60).
- Task 3: A APPROVED / B SPEC_OK — alle gepinnten Erwartungswerte gegen die Fixture-Dateien nachgerechnet; Asserts teils gestrafft (df `hasLength(2)`, beide `_removableDevices`-Einträge abgedeckt).
- Task 4: A NEEDS_FIXES (F1 dirname-Zählung, F2 „täglich in CI", F3 Präsens-Overclaim) → Fix `3786464` → Re-Review A APPROVED / B SPEC_OK.
- Secrets/Privilegien-Sicht (Reviewer-2-Pflicht aus dem Issue): unprivilegierte Captures, Schwärzung inkl. Zusatzfunde oben, Leak-Check-Vektoren (MUST_FLAG/MUST_NOT_FLAG) grün, kein `pkexec`/polkit-Bezug im Diff.

**Gates — tatsächlich ausgeführt (2026-09-30 auf `3786464`), alle Exit 0.**

| Gate | Ausgabe |
|---|---|
| la_core `dart format --output=none --set-exit-if-changed lib test` | `Formatted 23 files (0 changed)` |
| la_core `dart analyze` | `No issues found!` |
| la_core `dart test` | `00:00 +60: All tests passed!` (52 alt + 8 neu) |
| `dart compile exe bin/la_probe.dart` + display-less `--version`-Lauf | `Generated: /tmp/la_probe94`; `la_probe 0.0.1-spike.1 (dart 3.13.4 … linux_x64)` |
| Root `dart format --output=none --set-exit-if-changed lib test` | `Formatted 122 files (0 changed)` |
| `flutter analyze` | `No issues found! (ran in 3.1s)` |
| `flutter test` (voller Lauf) | `00:07 +200: All tests passed!` |
| `python3 -m unittest discover -s tests -t .` (additional/python) | `Ran 53 tests` / `OK` (49 alt + 4 neu) |
| `bash tool/check-versions.sh` | `version 0.8.0 is consistent` |

Nach der Final-Review-Fix-Runde `8bddeb6` erneut ausgeführt und grün: Python `Ran 53 tests` / `OK`, `flutter test` `+200: All tests passed!`,
la_core `dart test` `+60: All tests passed!` (Belege in `.superpowers/sdd/final-review-94-fix-report.md`; der Re-Review hat den Python-Lauf
unabhängig reproduziert).

**Rote/übersprungene Gates.** Rot nur die geplanten TDD-REDs (Task 1 `FixturesClean`, Task 2 Compile-Fehler). Übersprungen: `build-deb.sh` (kein Paketbezug — `la_probe`-Kompilat direkt geprüft; CI baut beim PR), CI für den Branch (läuft mit dem späteren PR), manuelle Gate-0-Checks (unverändert offen, von #94 nicht berührt).

**Manuelle Zorin-Prüfung.** Für #94 nicht erforderlich (keine UI-Änderung); die Captures stammen von diesem Zorin-Rechner (2026-09-30).

**Rückfallplan.** `git revert` der Task-Commits genügt: Task 2 isoliert (nur la_core-Neudatei + Barrel-Zeile), Task 1+3 gemeinsam (gemeinsame Fixture-Dateien), Task 4 reine Doku. Kein Migrationsschritt, kein Datenpfad.

## Handoff #95 — Baseline-Messung Flutter-Release vs. GTK-Shell

**Status:** Messung vollständig (4 Zellen {Flutter-Release, GTK-Shell} × {Wayland, X11}, je 5 Startup- + 5 Steady-Läufe) und als Messprotokoll in `docs/mla-next/BASELINE.md` §8 dokumentiert. Umgesetzt auf `feature/mla-95-baseline` (Basis-SHA `31277a2`; Plan-Commit `5757c0d`, Erratum-Commit `9de72b0`), Task 3 (Doku) ist der Commit dieses Abschnitts. Messaufgabe: kein Code, keine Tests, kein Packaging angefasst; Messhelfer und die 20er-Roh-Serien liegen ausschließlich unter `/tmp` und `.superpowers/sdd/` (gitignored, ephemeral) — §8 führt alle Startup-Einzelwerte und die je-Lauf-Steady-Mediane selbst.

**Messfenster/Rechner.** Task 1 (Flutter-Zellen) 2026-09-30 07:41–07:58 MESZ (Release-Build 07:36:01, Probe-Läufe 07:41:28–07:50:16, serielle Zellen 07:51:54–07:57:59); Task 2 (GTK-Zellen) 08:34–08:45 MESZ (08:34:41–08:44:54). Rechner-Box frisch erhoben (BASELINE §8: i7-13620H, 16 066 996 kB RAM, Kernel 7.0.0-34-generic, Wayland-Sitzung, XWayland `:1`; keine Hostnamen — Leak-Disziplin wie bei den #94-Fixtures). Anomalie dokumentiert: der Task-2-Report §1 führt MemTotal abweichend (9 071 472 640 Bytes); die frische Erhebung (`/proc/meminfo`, `free -b`) ergibt 16 066 996 kB — §8 folgt der frischen Erhebung, die Messwerte sind davon unberührt.

**Failing-Test/Fixture.** Keiner — Messaufgabe (Plan-Constraint 6); Belege sind die Rohwerte 1:1 (BASELINE §8) und die Gates unten.

**Reviewer.** Je Task A (Korrektheit) + B (Vollständigkeit/Spec):
- Task 1: A APPROVED (alle 20 RESULT-Zeilen gegen die Zellenlogs nachgerechnet, Kontrolllauf ~99,9 % eines Kerns bestätigt das Dauerrendern) / B SPEC_OK (Rohwerte gegen die `/tmp`-Serien belegt, die 3 Plan-Errata verifiziert).
- Task 2: A APPROVED (Helfer diff-identisch zur Task-1-Technik, alle 10 Steady-Mediane nachgerechnet, CPU = 0 Ticks durch eigenen Kontrolllauf reproduziert) / B NEEDS_FIXES (Lastasymmetrie-Begründung §7 textlich invertiert) → Fix-Subagent (Richtung korrigiert: Flutter-Startup-Vorteil = konservative Untergrenze, GTK-Aufstellung schonend, RSS/PSS praktisch lastunabhängig — §8 Befund (e)) → Re-Review SPEC_OK.

**Kernresultate (Mediane; Details/Rohwerte in §8).** Startup X11↔X11 (identisches Ereignis „Fenster im X-Baum“): Flutter 39 ms vs. GTK 285 ms; Wayland↔Wayland nur mit Proxy-Vorbehalt (29 vs. 63 ms, „erster Protokollverkehr“ ≠ First-Frame). CPU: Flutter ~101 % eines Kerns in allen 10 Steady-Läufen (Impeller-Dauerrendern; ~+1 %-Formelverzerrung betrifft nur Flutter), GTK 0 Ticks in 10/10 Läufen (kein Timer, grep-Beleg). RSS/PSS (Wayland-Mediane): Flutter 161 472/89 740 kB, GTK 187 972/101 166 kB. X11-Aufschlag backendintern: GTK +222 ms (63→285), Flutter +10 ms (29→39). Größen nur Angabe (Bundle 26 885 925 B, Binary 23 664 B, `mla_app.py` 3 924 B — kein Ranking). „Nicht verglichen“: 8 Punkte in §8 (6 Plan-Punkte wortgleich + X11-Poll-Ereignis „im X-Baum, nicht strikt gemappt sichtbar“ + Probe-Läufe außerhalb der Serien).

**Gates — tatsächlich ausgeführt (2026-09-30 nach Task 3), alle Exit 0.**

| Gate | Ausgabe |
|---|---|
| Root `dart format --output=none --set-exit-if-changed lib test` | `Formatted 122 files (0 changed) in 0.23 seconds.` |
| `flutter analyze` | `No issues found! (ran in 2.2s)` |
| `flutter test` (voller Lauf) | `00:04 +200: All tests passed!` |
| la_core `dart pub get` | `Got dependencies!` |
| la_core `dart format --output=none --set-exit-if-changed lib test` | `Formatted 23 files (0 changed) in 0.04 seconds.` |
| la_core `dart analyze` | `No issues found!` |
| la_core `dart test` | `00:00 +60: All tests passed!` |
| `python3 -m unittest discover -s tests -t .` (additional/python) | `Ran 53 tests in 0.046s` / `OK` |
| `bash tool/check-versions.sh` | `version 0.8.0 is consistent` |

**Rote/übersprungene Gates.** Keine roten (Messaufgabe). Übersprungen: `build-deb.sh` (kein Paketbezug; CI baut beim späteren PR), CI für den Branch (läuft mit dem späteren PR), manuelle Gate-0-Checks (BASELINE §3 — von #95 unberührt, bleiben separat offen).

**Manuelle Zorin-Prüfung.** Für #95 nicht erforderlich — die GUI-Messungen liefen automatisiert auf dem Zorin-Zielrechner (Sitzung siehe §8-Rahmen); manuelle Gate-0-Checks bleiben separat offen.

**Rückfallplan.** `git revert` der #95-Commits (`5757c0d`, `9de72b0`, Task-3-Doku-Commit) genügt: reine Doku (Plan-Datei, BASELINE §8, dieser Abschnitt, ISSUES-Spiegel), kein Code, kein Datenpfad, keine Unit, kein Packaging.

**Grenzen (bewusst offen).** Die #92-Abnahme bleibt formal offen (GTK-Datenadapter-Rest) und ist im §8-„Nicht verglichen“ benannt, nicht weggebügelt; die Flutter-vs-GTK-Entscheidung ist 0.4.x-Aufgabe (#105 nimmt diese Basis auf).

## Agenten-Handoff

Je Aufgabe: Basis-SHA, Pfade, Scope, Failing-Test/Fixture, Umsetzung, Ergebnis von Reviewer 1 (Funktion/UX) und Reviewer 2 (Sicherheit), **wirklich ausgeführte** Gates mit Ausgaben, rote/übersprungene Gates, manuelle Zorin-Prüfung, Rückfallplan. Kein Merge/Release/Policy-Update ohne gesonderte Freigabe.
