# SDD-Plan: Follow-ups aus den Reviews #89–#95 («Kompakt + Spawn-Tests»)

- **Datum:** 2026-09-30 · **Quellen:** Final-Review-Minors der SDD-Läufe #89/#93/#94/#95 (Ledger `.superpowers/sdd/progress.md`) + Ad-hoc-Befund RAM-Anzeige
- **Branch:** `chore/mla-followups` · **Basis-SHA:** `1f6c2ef` (main, nach Merge PR #109)
- **Freigabe:** Plan am 2026-09-30 via ExitPlanMode genehmigt (vorher User-Freigabe für Merge PR #109 + Close #95 erteilt und ausgeführt: squash `1f6c2ef`, CI 36689052933 grün). Umfang-Entscheidung User: **«Kompakt + Spawn-Tests»**.
- **Kein eigenes GitHub-Issue** — Commits referenzieren die Quell-Reviews im Body; PR-Titel `chore(mla): Follow-ups aus #89–#95-Reviews`.

## Global Constraints (für jeden Task verbindlich)

1. **Gates je Task frisch ausführen und im Report belegen:** Working-Dir `/home/bratan/10-Projekte/10-active/linux-assistant`.
   - la_core: `cd packages/la_core && dart pub get && dart format --output=none --set-exit-if-changed lib test && dart analyze && dart test` (Reihenfolge: `pub get` vor `dart format`)
   - Flutter-Root: `dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test`
   - Python: `cd additional/python && python3 -m unittest discover -s tests -t .` → `OK`
   - `bash tool/check-versions.sh`
2. **Ausschließlich unprivilegierte Kommandos.** Die polkit-Trinität (`_privilegedEntryPoints`, Policy `exec.path`, `chmod +x` in build-deb.sh) bleibt unberührt — Task 2 ändert `/usr/bin/free` (unprivilegierter Lese-Befehl, steht in keiner der drei Stellen).
3. **TDD für Code-Fixes:** RED beobachten, dann implementieren, dann GREEN. Reine Doku-/CI-Änderungen (Task 5) ohne RED; Beleg sind die Gates.
4. Repo-Konventionen: `unawaited_futures` enforced, kein `print`, Conventional Commits (deutschsprachige Bodies, Quell-Referenz im Body statt `(#NN)`-Suffix, da kein eigenes Issue).
5. **Kein Push/Merge/Release ohne Freigabe.** gh immer `-R Toqsick/master-linux-assistant`.
6. `git status` vor jedem Commit; `.superpowers/`, `build/`, `/tmp` nie committen.

## Design-Entscheidungen (vom Controller gesetzt)

- **RAM-Bug-Fix-Richtung:** Parser/Felder/Formatter (`MemoryInfo.*Mb`, Doc „free -m, in mebibytes", `_formatGb` = `/1024`) sind konsistent MiB — falsch ist der **Capture**: `lib/linux/linux_system.dart:11` ruft `/usr/bin/free` ohne `-m` (KiB-Ausgabe; Fixture `zorin_free.txt` belegt es: `Mem: 16066996` = 15,3 GiB in KiB). Fix = Capture auf `/usr/bin/free -m` + Fixture-Recapture + Test-Erwartungen. **Kein** Feld-Rename, **keine** Formatter-Änderung.
- **ProbeLevel-Rename:** `ProbeLevel` → `ProbeSeverity` (beide `unknown`/`ok` kollidieren semantisch mit `ProbeState`). Nur 3 Dateien in la_core (`probe.dart`, `probe_test.dart`, `probe_registry_test.dart`); `describe()`-Format (`'ok:key @ …'`) bleibt unverändert — nur der Typname.
- **Spawn-Test-Konstruktion:** `ProcessCommandRunner` ruft `Process.run(argv.first, …)` mit **nacktem** `pkexec`/`flatpak-spawn` (PATH-Auflösung). Fakes = ausführbare Shell-Skripte in einem Temp-Verzeichnis, die ihr argv in eine Datei dumpen; PATH-Präfix über das `environment`-Argument. Dabei die Dart-Semantik pinnen: ein übergebenes `environment` **ersetzt** das Eltern-Env — ohne PATH-Übernahme wird `pkexec` nicht gefunden (Dokumentations-Test, kein Produktionsfix in diesem Paket).
- **`free_no_swap.txt` bleibt** (synthetisch, bereits MiB-skaliert). Leak-Check-`.ai`-Fix: generischer Vektor (z. B. `foo.bar.ai`), keine echten Account-URLs.

## Tasks

- **Task 0 — Controller-Prep:** Branch, diese Plan-Datei, Ledger-Sektion. Commit `docs(mla): SDD-Plan Follow-up-Paket (#89–#95-Reviews)`.
- **Task 1 — la_core-Code-Follow-ups (TDD):** RED: neuer Test in `packages/la_core/test/parsers_test.dart` — Kernel-Thread-Bare-Line unter den ersten N Zeilen ⇒ trotzdem N gültige Einträge (aktuell kommen weniger). Fix `parsers/process.dart:16`: ungültige Zeilen filtern, **dann** `.take(count)`. Rename `ProbeLevel` → `ProbeSeverity` in den 3 Dateien. `ProbeStatus`-Doc-Hinweis: „Diskriminator ist `state`, nie `data != null`". Gates la_core. Commit.
- **Task 2 — RAM-Anzeige-Bug (App + Fixture):** `linux_system.dart:11` `/usr/bin/free` → `/usr/bin/free -m`; `test/fixtures/zorin_free.txt` neu capturen (`LC_ALL=C /usr/bin/free -m`, unprivilegiert); Erwartungen in `test/system_parsers_test.dart` + `packages/la_core/test/parsers_test.dart` an MiB-Werte; `test/fixtures/README.md` (Capture-Kommando + Bug-Notiz mit Referenz). Gates Root + la_core. Commit.
- **Task 3 — Leak-Check-Politur (TDD, Python):** RED: MUST_FLAG-Vektor `foo.bar.ai` schlägt fehl; dann `.ai` in `ALLOWED_TLDS` → GREEN. `FixturesClean` mit `subTest` je Datei. Testvektor-Politur (Username-Minor aus #94-Task-2-Review). Gates Python. Commit.
- **Task 4 — Spawn-Echtheits-Nachweis:** Neue `test/process_command_runner_test.dart` (Root-Suite, kein Fake-Async um echte `Process.run`-Aufrufe — Repo-Lektion). Fälle: (1) asRoot ⇒ argv `pkexec <cmd> <args>`; (2) `runningInFlatpak` + `hostOnFlatpak` ⇒ `flatpak-spawn --host …`, ohne ⇒ ohne `--host`; (3) Kombination ⇒ `flatpak-spawn --host pkexec …`; (4) exit-code/stdout/stderr-Mapping; (5) fehlendes Binary ⇒ `success=false`, `exitCode=-1`, keine Exception; (6) `environment` ohne PATH ⇒ nacktes `pkexec` wird nicht gefunden (Dokumentations-Test). Gates Root. Commit.
- **Task 5 — CI + Doku:** `build.yml` `checkout@v3` → `@v4`; BASELINE §6.4-Abgleich (Exclude wurde in `1367d3c` übernommen — Punkt als erledigt textieren, offenes #90-Teilitem); BASELINE §8-Impeller-Halbsatz („~101 % enthalten auch den 3-s-Poll-Anteil"); #95-Plan-Erratum (je Zelle 5+5 getrennte Läufe statt kombiniert 5); AGENTS.md-Testzahlen frisch erheben (flutter test Zähler + Dateianzahl, Python-Tests) und korrigieren. Commit.
- **Task 6 — Abschluss:** Final-Whole-Branch-Review (A Korrektheit/Tests + B Security/Beweisqualität, parallel), alle Gates frisch, finishing-a-development-branch → PR-Frage an den User (inkl. Option Tracking-Issue).

## Boundary / bewusst draußen

- Registry-Race-Härtung (eigenes Issue wert), Release-Process.md-Rewrite, manuelle Gate-0-Checks (Basti), Spawn-Umgebungs-**Produkt**-Fix (falls Test 6 eine echte Lücke zeigt → dokumentieren, separates Issue, kein Mitnehm-Fix).
- Wayland-Screenshot und `-dev`-Pakete (#90) bleiben manuell.
