# deliverable.md — WP-S3 Hygiene-Bundle (#56, #46, #50)

> **Stand:** 2026-10-23 · **Basis:** `main` @ `08dad94` · **Branch:** `feature/56-wp-s3-hygiene`
> **Umfang:** Work-Package WP-S3 aus `security-fixplan-42-50.md` plus die beiden
> zugehörigen Findings #46 (folder_recursion_depth) und #50 (Disk-Analyzer).

## Was geändert wurde

| Datei | Änderung |
|---|---|
| `lib/services/linux.dart:98` | `runCommandWithCustomArguments`: Default `runInShell` von `true` auf **`false`** |
| `lib/services/linux.dart:133` | `runProcess`: Default `runInShell` von `true` auf **`false`** |
| `lib/services/linux.dart:95-105` | Doc-Kommentar: Voraussetzung (absoluter Pfad via `expandCommand`) und Kosten des Shells präzisiert |
| `lib/services/linux.dart:1524-1536` | **Falschen Kommentar korrigiert** (siehe unten) |
| `lib/services/linux.dart:933-944` | Neue Methode `folderRecursionDepth()` — Config-Wert lesen und klemmen |
| `lib/services/linux.dart:959` | Aufrufstelle nutzt jetzt `folderRecursionDepth()` statt des rohen `final int`-Casts |
| `lib/services/linux.dart:2784-2821` | `openDiskSpaceAnalyzer`: Installationsprüfung zuerst (awaited), Start genau einmal, `runInShell: false`, `context.mounted`-Check nach dem Await |
| `lib/layouts/disk_cleaner/clean_disk.dart:61` | Aufrufer in `unawaited(...)` gewrappt (Lint `unawaited_futures`) |
| `lib/services/folder_recursion_depth.dart` (neu) | Klemmung auf 1..10, Fallback 3, über `BigInt` geklemmt (kein Überlauf) |
| `test/wp_s3_hygiene_test.dart` (neu) | 15 Tests in vier Gruppen |

## Bestandsaufnahme vor dem Default-Flip

Der Flip betrifft **jeden** Prozessstart der App. Geprüft und protokolliert:

| Prüfung | Ergebnis |
|---|---|
| `grep -rnE 'runCommandWithCustomArguments\(\s*"[^"]* [^"]*"' lib/` | **0 Treffer** — kein Aufruf übergibt ein Mehrwort-Kommando als exec-String |
| `grep -rnE 'runProcess\(\s*"[^"]* [^"]*"' lib/` | **0 Treffer** |
| `grep -rn 'runInShell: true' lib/` | **0 Produktionsaufrufe** (1 Kommentar, 2 Documentation-Tests im Testfile) |
| `runCommand(String)` (`linux.dart:83-92`) | splittet bereits Dart-seitig (`command.split(' ')`) und reicht eine **Liste** weiter → vom Flip nicht betroffen |
| `expandCommand` (`linux.dart:169`) | macht aus Bare-Namen absolute Pfade (`/usr/bin/<name>`) — die dokumentierte Voraussetzung für den Shell-Abdrehen |

**Aufrufstellen mit variablem exec** — alle Einzelwörter, alle geprüft:

| Stelle | Wert | Bewertung |
|---|---|---|
| `lib/services/action_handler.dart:63` | `exec` („xdg-open" u. a.) | Einzelwort ✓ |
| `lib/services/linux.dart:87` | `exec` aus `runCommand` | bereits Dart-seitig gesplittet ✓ |
| `lib/services/linux.dart:2674, 2677` | `term` (gnome-terminal, xterm …) | Einzelwort ✓ |
| `lib/services/linux.dart:3030` | `executable` (kgx, xterm, xfce4-terminal …) | Einzelwort ✓ |

**Ergebnis:** keine Stelle musste auf `runInShell: true` festgenagelt werden.

## Der korrigierte Kommentar

Der alte Kommentar behauptete, mit `runInShell` werde „argv space-joined unquoted", ein HOME wie
`/home/john doe` werde mitten im Pfad abgeschnitten, und ein Shell-Metazeichen würde laufen.

**Das ist falsch.** Dart quotet jedes argv-Element einzeln, wenn es den `sh -c`-String baut
(`_getShellArguments()` in `sdk/lib/_internal/vm/bin/process_patch.dart`, POSIX-Zweig: jedes
Argument wird als `' <arg>'` geschrieben, eingebettete Quotes als `'"'"'`). Empirisch gemessen am
2026-10-23 mit einer Sonde, die die **Argumentanzahl** zählt und nicht nur die Ausgabe vergleicht
(`/workspace/tools/rv1_probe_strict.py`, Exitcode 0 = Prämisse bestätigt):

| Payload | argv-Elemente | Ergebnis |
|---|---|---|
| `a b c` | 1 | bleibt ein Argument |
| `x'; echo INJECTED > /tmp/pwned42; #'` | 1 | inert, kein Artefakt erzeugt |
| `$(id)` / `` `id` `` / `*` / `a\|b` | 1 | inert |

Die Shell war also **nie** das Split-Risiko, das der Kommentar behauptete. Sie kostete einen
zusätzlichen Fork pro Aufruf und ein zweites Parsen von Argumenten, die das Programm ohnehin
verbatim bekommen hat. Der neue Kommentar sagt genau das — und der Test
„Dart haelt das Argument auch dann zusammen, wenn es eine Shell baut" (mit echtem
`Process.run(..., runInShell: true)`) sichert die Aussage im Code ab, damit sie nicht wieder zur
Behauptung wird.

## Der Nebenbefund im Disk-Analyzer

Der alte Ablauf war:

```dart
runCommandWithCustomArguments("k4dirstat", [path]);   // feuert UNBEDINGT
ensureApplicationInstallation(["k4dirstat"]);            // danach erst der Check
if (commandQueue.isEmpty) {
  runCommandWithCustomArguments("k4dirstat", [path]);   // und nochmal
}
```

Ein nicht installiertes Programm wurde also **zweimal** gestartet (beim ersten Mal erfolglos),
und `ensureApplicationInstallation` lief nicht awaited — der Queue-Stand konnte daher noch gar
nicht gefüllt sein, wenn er gelesen wurde. Neu: Prüfung zuerst und awaited, Start genau einmal,
`context.mounted` nach dem Await, der Queue-Eintrag bleibt argv-form mit absolutem Pfad.

## TDD-Beleg

**RED (vor der Implementierung)** — zwei Stufen, beide protokolliert:

*Stufe A — Shell-Defaults* (`red-stageA-shell-defaults.txt`): Die Tests compile-ten gegen den
Altstand und schlugen mit Assertion-Fehlern fehl — der Default war `true`, erwartet wurde `false`.

*Stufe B — Tiefe und Analyzer* (`red-stageB-depth-and-analyzer.txt`): Die Klemme existierte noch
nicht, der Test referencing sie schlug mit Compile-Fehler fehl — genau die erwartete rote Phase
für ein noch nicht existierendes Symbol.

**GREEN:** `flutter test test/wp_s3_hygiene_test.dart` → alle Tests grün; die Testdatei enthält
15 Tests in vier Gruppen:

| Gruppe | Testfälle |
|---|---|
| Der Default der Kommandoebene ist: keine Shell | `runCommandWithCustomArguments` ohne Shell · `runProcess` reicht `false` durch · `runCommand` (String-Form) ohne Shell |
| Ein Pfad mit Leerzeichen bleibt ein Argument | Pfad kommt als ein argv-Element an · Dart haelt das Argument auch mit Shell zusammen (Dokumentationstest) · Shell-Metazeichen bleiben inert (Dokumentationstest) |
| Die Rekursionstiefe ist geklemmt | zu klein → 1 · zu gross → 10 · plausibel → unverändert · Textwert → Fallback, löst nichts aus · fehlender Config-Wert → Default · Textzahl wird angenommen · Nicht-Zahlen werden verworfen |
| Der Disk-Analyzer startet nach der Installationsprüfung | Start erfolgt erst nach der Prüfung; kein Start, wenn das Programm fehlt |

## Gate-Protokoll

`bash /workspace/tools/run-mla-gates.sh` — echte Exitcodes, Log: `gates-full.log`.

| Gate | Ergebnis |
|---|---|
| `flutter pub get` | OK |
| `bash tool/check-versions.sh` | OK |
| `dart format --output=none --set-exit-if-changed lib test` | OK — 124 Dateien, 0 geändert |
| `flutter analyze` | OK — *No issues found!* |
| `flutter test` | OK — 244 Tests (230 Baseline + 14 neue) |
| Python-Unit-Tests (`additional/python`) | OK — 62 Tests |
| GTK-Token-Gate | OK — 96 Tests (2 skipped) |
| `packages/la_core` (analyze / format / test) | OK — 0 Findings, 25 Dateien, 68 Tests |

**Summenzeile: `ALLE GATES GRUEN`, `GATES_EXIT=0`.**

## Konventionen geprüft

- Conventional Commit, deutschsprachiger Body, Issue-Referenz ✓
- `dart format` vor dem Commit ✓ (Format-Gate grün)
- Logging über `lib/services/logger.dart`, kein `print` ✓
- `unawaited_futures` beachtet (Aufrufer in `unawaited(...)`) ✓
- Keine Secrets ✓
- **polkit-Trinität unberührt**: `org.linux-assistant.operations.policy`,
  `lib/services/linux.dart` `_privilegedEntryPoints` und der `build-deb.sh`-chmod sind in
  diesem Commit nicht geändert ✓
- Kein Versions-Bump, kein Tag, kein Release, kein Merge nach `main` ✓

## Bewusste Entscheidungen

1. **Die Klemme rechnet auf `BigInt`.** Ein Wert wie `"99999999999999999999"` wird auf 10
   gesenkt und nicht auf eine Zufallszahl gekürzt. `BigInt.tryParse` akzeptiert nur Ziffern mit
   optionalem Vorzeichen — kein `"3.5"`, kein `"0x10"`, kein Text mit Metazeichen.
2. **`openDiskSpaceAnalyzer` ist jetzt `Future<void>`** und wird vom Aufrufer in
   `unawaited(...)` gewrappt. Das ist die einzige Signaturänderung; es gibt genau einen Aufrufer.
3. **Die Queue-Einträge wurden nicht angefasst.** Sie waren bereits argv-form mit absolutem
   Pfad (`/usr/bin/k4dirstat`) — der Fixplan verlangt ausdrücklich, sie unverändert zu lassen.
4. **`runInShell: false` steht an den drei direkten Analyzer-Aufrufen explizit**, auch obwohl
   der Default jetzt schon `false` ist. Damit ist der Aufruf unabhängig vom Default und
   überlebt eine künftige Default-Änderung.

## Offene Punkte

- **Kein `runInShell: true` mehr in `lib/`** — die App startet keinen Prozess mehr über eine
  Shell. Für die beiden `runCommandWithCustomArguments`-Aufrufe in `lib/layouts/hub/` und
  `lib/services/action_handler.dart` ist das Verhalten unverändert (Dart quotet ohnehin
  elementweise), der zusätzliche Fork pro Aufruf entfällt.
- **Der manuelle Abnahmeschritt** (Issue #51, RV-1 Probe 1 und 2) bleibt offen: die
  GUI-basierten Nachweise brauchen ein echtes Desktop-System.
- **Kein CI-Eingriff.** `.github/workflows/build.yml` wurde nicht angefasst; die CI läuft
  `flutter build linux` erst **nach** den Tests, daher ist der vergiftete-`build/`-Fall dort
  nicht vorhanden.
