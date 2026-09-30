# SDD-Plan: #94 — Gemeinsame Fixtures + Fehler-/Stale-Modelle

- **Datum:** 2026-09-30 · **Issue:** #94 ([Next 0.0.3], milestone `MLA-Next 0.0.3 – Fixtures & Baseline`)
- **Branch:** `feature/mla-94-fixtures` · **Basis-SHA:** `e4c1346` (main, nach Merge PR #107)
- **Freigabe:** Plan am 2026-09-30 via ExitPlanMode genehmigt (vorher User-Freigabe für Merge PR #107 + Close #93 erteilt und ausgeführt)
- **Quellen:** `docs/mla-next/ISSUES.md` #94-Sektion, `docs/mla-next/IPC_CONTRACT.md`, `docs/mla-next/AGENT_PLAN.md` (:19, :25), `docs/mla-next/MILESTONES.md` 0.0.3

## Global Constraints (für jeden Task verbindlich)

1. **Gates je Task frisch ausführen und im Report belegen:** Working-Dir ist immer `/home/bratan/10-Projekte/10-active/linux-assistant`.
   - Python: `cd additional/python && python3 -m unittest discover -s tests -t .` → `OK`
   - la_core: `cd packages/la_core && dart pub get && dart format --output=none --set-exit-if-changed lib test && dart analyze && dart test` (Reihenfolge wichtig: `pub get` vor `dart format`, sonst falsche Language-Version)
   - Flutter-Root: `dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test` (nur bei Tasks, die Root-Dateien ändern)
2. **la_core ist pure Dart** — keine Flutter-Imports, kein `dart:ui`.
3. **Keine privilegierten Kommandos.** Die polkit-Trinität (`_privilegedEntryPoints`, Policy `exec.path`, `chmod +x` in build-deb.sh) bleibt unberührt.
4. Repo-Konventionen: `unawaited_futures` enforced, kein `print` in `lib/`, Conventional-Commits mit `(#94)`-Suffix, deutschsprachige Commit-Bodies wie im Repo üblich.
5. **Kein Push, kein Merge, kein Release** — Branch bleibt lokal bis zur Abschluss-Entscheidung durch den User.
6. Commit nur die Dateien des eigenen Tasks; `git status` vor jedem Commit prüfen (`.superpowers/` und `build/` nie committen).
7. TDD-Pflicht: Test zuerst schreiben, **laufen sehen (RED beobachten)**, dann implementieren, dann GREEN. Ausnahme: Tasks, die reine Daten/Dokumentation anlegen — dort gilt das RED des Verzeichnis-Scans (Task 1) bzw. der Neuzustand leerer Testsuiten als Beleg.

## Design-Entscheidungen (vom Controller gesetzt, nicht zur Diskussion im Implementer)

- **Ablageort:** `test/fixtures/` im Repo-Root (so vom Issue benannt). Lesepfade: Flutter-Tests `test/fixtures/…` (CWD=Root), la_core-Tests `../../test/fixtures/…` (CWD=`packages/la_core`), Python via `os.path` vom Repo-Root.
- **Zwei Fixture-Arten, beide ins selbe Verzeichnis:** (a) echte, geschwärzte Zorin-Ausgaben `zorin_*.txt`, (b) synthetische Edge-Vektoren `<parser>_<case>.txt` (in `test/fixtures/README.md` als synthetisch gekennzeichnet). Ein-Literale wie `""` oder `"some error\n"` bleiben inline (Robustheits-Assertions, keine Daten).
- **Schwärzungsregeln** (in README dokumentiert): `/home/<name>` → `/home/user`; `/media/<name>/…` → `/media/user/…`; Usernamen in `ps`-Args → `user`; URLs/Hosts → `https://example.invalid/x` bzw. entfernen; IPs → entfernen (kommen in den fünf Outputs nicht vor). Deutsche Dezimalkommas (`7,8G`) bleiben erhalten (Locale-Realismus). `/home/user` und `/media/user` sind die einzigen erlaubten `/home`- bzw. `/media`-Segmente; `example.invalid` ist der erlaubte URL-Platzhalter.
- **Zustandsmodell:** `packages/la_core/lib/src/probe_status.dart`, Export über `packages/la_core/lib/la_core.dart`. `stale` entsteht **nur** über `markStale()` aus `ok`; es gibt keinen Konstruktor und keine Methode, die `stale` ohne frische Observation zu `ok` macht.
- **Boundary:** `test/system_monitor_service_test.dart` (synthetische `/proc`-Konstanten) bleibt unberührt — Bestandskonsolidierung ist QA3/#87. Kein GTK-UI-Code (A2/#92 und spätere). IPC-Contract-Fixtures (JSON-RPC pos/neg) sind laut `IPC_CONTRACT.md:22` ein späteres Task-Paket.

---

## Task 1 — Fixture-Bibliothek + Leak-Check (TDD)

**Ziel:** `test/fixtures/` enthält echte geschwärzte Zorin-Ausgaben + synthetische Edge-Vektoren; ein Python-Leak-Check läuft in CI mit und ist auf allen Fixtures leer; Schwärzung ist in `test/fixtures/README.md` dokumentiert.

### 1a. Leak-Check-Test zuerst (RED)

Neue Datei `additional/python/tests/test_fixture_leak_check.py` (stdlib `unittest`, Stil wie `additional/python/tests/test_command_queue.py`; Repo-Root via `os.path` von `__file__` aus auflösen).

Struktur:

```python
import os
import re
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FIXTURE_DIR = os.path.join(REPO_ROOT, "test", "fixtures")

def find_leaks(text: str) -> list:
    """Gibt Listen-Funde als Strings zurück; leer = sauber."""
    # Muster-Kategorien (Reihenfolge egal):
    # 1. IPv4: vier 0-255-Oktetts
    # 2. IPv6-Heuristik: enthaelt '::' plus Hex/Ziffern
    # 3. /home/<x> und /media/<x> mit x != 'user'
    # 4. URL/Domain mit TLD-Allowlist (com,net,org,io,dev,de,eu,info,biz,co,me,app,xyz,example)
    # 5. user@host
    # Post-Filter: 'example.invalid' ist der erlaubte Platzhalter und wird ignoriert.
    ...
```

(`find_leaks` ist der zu implementierende Kern; die Kategorien sind Pflicht, die konkreten Regexes entwickelt der Implementer TDD-getrieben gegen die Vektoren unten.)

Testfälle (verbindliche Vektoren):

```python
class LeakDetection(unittest.TestCase):
    MUST_FLAG = [
        "192.168.178.23",
        "2001:db8::1",
        "connect to 10.0.0.5:5432",
        "/home/bratan/secret.txt",
        "/media/braten/USB",
        "curl https://internal.corp.example/health",
        "ssh git@github.com",
    ]
    MUST_NOT_FLAG = [
        " 14:23:01 up  3:45,  1 user,  load average: 0.52, 0.58",
        "udev            7,8G     0  7,8G   0% /dev",
        "/usr/lib/firefox/firefox",
        "libGL.so.1",
        "python3.12",
        "/home/user/notes.txt",
        "/media/user/USB",
        "https://example.invalid/x",
        "/dev/nvme0n1p2",
        "%CPU COMMAND",
    ]
```

Dazu `class FixturesClean(unittest.TestCase)`: iteriert **nur `*.txt`** unter `FIXTURE_DIR` (README.md wird nicht gescannt, weil es die Regeln selbst enthält — im Test-Docstring begründen), assertet `find_leaks(content) == []` pro Datei und dass mindestens die fünf `zorin_*.txt` existieren.

**RED-Nachweis:** `python3 -m unittest discover -s tests -t . -v` → `FixturesClean` schlägt fehl (Verzeichnis existiert nicht); `LeakDetection` darf von Anfang an grün sein.

### 1b. Fixtures capturieren + schwärzen (alles unprivilegiert, exakt die Produktions-Aufrufe)

| Datei | Capture-Kommando | Quelle der Parität |
|---|---|---|
| `zorin_df.txt` | `df -h` (ohne LC_ALL — Produktionsdefault) | `lib/linux/linux_filesystem.dart:9` |
| `zorin_ps.txt` | `ps -eo pcpu,args --sort=-pcpu` | `lib/linux/linux_process.dart:10` (metric=pcpu) |
| `zorin_uptime.txt` | `LC_ALL=C /usr/bin/uptime` | `lib/linux/linux_system.dart:22` |
| `zorin_free.txt` | `LC_ALL=C /usr/bin/free` | `lib/linux/linux_system.dart:11` |
| `zorin_loadavg.txt` | `cat /proc/loadavg` | `lib/linux/linux_system.dart:53` |

- `zorin_ps.txt`: wenn länger als ~60 Zeilen, auf die ersten 60 kürzen und in README als dokumentierte Abweichung vermerken (sonst vollständig).
- Schwärzung gemäß Global-Constraint-Regeln; danach **manuell** nach Usernamen/Rechnernamen/UID-Artefakten durchsehen.
- Synthetische Edge-Vektoren anlegen (Inhalt = die heutigen Inline-Samples aus `test/system_parsers_test.dart`, unverändert übernommen): `df_duplicate_device.txt` (:37-42), `df_mountpoint_spaces.txt` (:53-56), `ps_kernel_thread_line.txt` (:89-105 inkl. der `0.0`-Zeile), `uptime_minutes.txt` (:121-122 nur Output-Teil `09:12:44 up  0:27, …`), `uptime_min_wording.txt` (:128-129 Output-Teil), `uptime_days.txt` (:135-136 Output-Teil), `free_no_swap.txt` (:161-165).
- `test/fixtures/README.md`: Zweck, Capture-Kommandos (Tabelle oben), Schwärzungsregeln, Kennzeichnung echt/synthetisch je Datei, Hinweis dass der Leak-Check heuristisch ist und keine manuelle Durchsicht ersetzt, und wie beide Tracks lesen (Pfad-Konventionen — Flutter `test/fixtures/…`, la_core `../../test/fixtures/…`, Python/GTK über Repo-Root).

**GREEN:** `python3 -m unittest discover -s tests -t .` → `OK` (49 bestehende + neue; genaue Zahl im Report). Zusätzlich `find_leaks` auf jeder Fixture-Datei demonstrativ leer (steht im Test).

**Commit:** `feat(mla): gemeinsame Fixture-Bibliothek mit Leak-Check (#94)` — Dateien: `test/fixtures/*`, `additional/python/tests/test_fixture_leak_check.py`.

---

## Task 2 — ProbeStatus-Zustandsmodell in la_core (TDD)

**Ziel:** `unknown/running/ok/stale/failed` als getrennte Zustände in la_core; `ok → stale` nur explizit; `stale` wird nie stillschweigend `ok`.

### 2a. Tests zuerst: `packages/la_core/test/probe_status_test.dart`

Vollständige Soll-Tests (gerne umbenannt/aufgegliedert, Semantik unverändert):

```dart
import 'package:la_core/la_core.dart';
import 'package:test/test.dart';

void main() {
  final observed = DateTime.utc(2026, 9, 30, 12, 0);

  test('unknown carries no data, timestamp or error', () {
    const status = ProbeStatus<int>.unknown();
    expect(status.state, ProbeState.unknown);
    expect(status.data, isNull);
    expect(status.observedAt, isNull);
    expect(status.error, isNull);
  });

  test('running carries no data', () {
    const status = ProbeStatus<int>.running();
    expect(status.state, ProbeState.running);
    expect(status.data, isNull);
  });

  test('ok carries data and observation time', () {
    final status = ProbeStatus<int>.ok(42, observed);
    expect(status.state, ProbeState.ok);
    expect(status.data, 42);
    expect(status.observedAt, observed);
    expect(status.error, isNull);
  });

  test('failed carries an error and no data', () {
    const status = ProbeStatus<int>.failed('probe crashed');
    expect(status.state, ProbeState.failed);
    expect(status.error, 'probe crashed');
    expect(status.data, isNull);
  });

  test('ok -> stale keeps data and observation time', () {
    final stale = ProbeStatus<int>.ok(42, observed).markStale();
    expect(stale.state, ProbeState.stale);
    expect(stale.data, 42);
    expect(stale.observedAt, observed);
  });

  test('markStale is only valid from ok', () {
    expect(() => const ProbeStatus<int>.unknown().markStale(), throwsStateError);
    expect(() => const ProbeStatus<int>.running().markStale(), throwsStateError);
    expect(() => const ProbeStatus<int>.failed('x').markStale(), throwsStateError);
  });

  test('stale cannot go stale again and has no path back to ok', () {
    final stale = ProbeStatus<int>.ok(42, observed).markStale();
    expect(() => stale.markStale(), throwsStateError);
    // ok entsteht nur frisch: ProbeStatus.ok(data, observedAt).
  });

  test('value equality covers all four fields', () {
    expect(ProbeStatus<int>.ok(42, observed), ProbeStatus<int>.ok(42, observed));
    expect(ProbeStatus<int>.ok(42, observed).markStale(),
        isNot(ProbeStatus<int>.ok(42, observed)));
  });
}
```

**RED:** `dart test` → Compile-Fehler (`ProbeStatus` existiert nicht) ist der RED-Nachweis.

### 2b. Implementierung: `packages/la_core/lib/src/probe_status.dart`

```dart
/// Observation states shared by probes, jobs and the GTK client (#94).
///
/// [ProbeState.stale] is a UI/transport state: it is reached only through
/// [ProbeStatus.markStale] from [ProbeState.ok] and keeps the last payload.
/// There is no path that silently turns `stale` back into `ok` — a fresh
/// observation constructs a new `ok` value (`IPC_CONTRACT.md`).
enum ProbeState { unknown, running, ok, stale, failed }

final class ProbeStatus<T> {
  final ProbeState state;
  final T? data;
  final DateTime? observedAt;
  final String? error;

  const ProbeStatus.unknown()
      : state = ProbeState.unknown,
        data = null,
        observedAt = null,
        error = null;

  const ProbeStatus.running()
      : state = ProbeState.running,
        data = null,
        observedAt = null,
        error = null;

  const ProbeStatus.ok(T this.data, DateTime this.observedAt)
      : state = ProbeState.ok,
        error = null;

  const ProbeStatus.failed(String this.error)
      : state = ProbeState.failed,
        data = null,
        observedAt = null;

  const ProbeStatus._stale(T this.data, DateTime this.observedAt)
      : state = ProbeState.stale,
        error = null;

  /// Explicit `ok -> stale` transition; keeps data and observedAt.
  ProbeStatus<T> markStale() {
    if (state != ProbeState.ok) {
      throw StateError(
          'markStale() is only valid on ok, not on ${state.name}.');
    }
    return ProbeStatus._stale(data as T, observedAt!);
  }

  @override
  bool operator ==(Object other) =>
      other is ProbeStatus<T> &&
      other.state == state &&
      other.data == data &&
      other.observedAt == observedAt &&
      other.error == error;

  @override
  int get hashCode => Object.hash(state, data, observedAt, error);

  @override
  String toString() =>
      'ProbeStatus(${state.name}${data != null ? ', data: $data' : ''}'
      '${observedAt != null ? ', observedAt: $observedAt' : ''}'
      '${error != null ? ', error: $error' : ''})';
}
```

Barrel `packages/la_core/lib/la_core.dart` ergänzen: `export 'src/probe_status.dart';` (alphabetisch einsortieren).

**GREEN + Gates:** `dart pub get && dart format --output=none --set-exit-if-changed lib test && dart analyze && dart test` → 52 bestehende + 8 neue Tests `OK`, Analyzer ohne Findings.

**Commit:** `feat(la_core): ProbeStatus-Zustandsmodell für Fehler- und Stale-Fälle (#94)`

---

## Task 3 — Parser-Tests beider Tracks lesen die gemeinsamen Fixtures

**Ziel:** `test/system_parsers_test.dart` (App) und `packages/la_core/test/parsers_test.dart` (la_core) laden ihre Multi-Zeilen-Samples aus `test/fixtures/` — die Inline-Duplikate verschwinden, Erwartungswerte werden an die echten Captures angepinnt.

**Schritte:**

1. Beide Testdateien lesen; jedes Multi-Zeilen-Sample einer der Fixture-Dateien aus Task 1 zuordnen ( Soll-Zuordnung: die fünf `zorin_*.txt` für die Happy-Path-Tests, die synthetischen Vektoren für die Edge-Tests — die Zuordnung steht schon in Task 1b).
2. In beiden Dateien: `import 'dart:io';` ergänzen und das Inline-Sample ersetzen durch z. B.
   - App: `final output = File('test/fixtures/zorin_df.txt').readAsStringSync();`
   - la_core: `final output = File('../../test/fixtures/zorin_df.txt').readAsStringSync();`
   (`const output` → `final output`; Tests bleiben synchron — `readAsStringSync` reicht, kein async nötig.)
3. Erwartungswerte der Happy-Path-Asserts an die echten Fixture-Inhalte anpassen (Fixture-Datei ist committet und damit stabil — exakte Werte pinnen, z. B. `usedPercent` der Root-Partition aus `zorin_df.txt`, `totalMb` aus `zorin_free.txt`, `uptime.value/unit` aus `zorin_uptime.txt`, erste Zeile `metricValue`/`processName` aus `zorin_ps.txt`, Load-1-Wert aus `zorin_loadavg.txt`). Struktur-Asserts (Pseudo-Dateisysteme gefiltert, `/` vorhanden, Länge ≤ count) beibehalten.
4. Den Doc-Comment in `packages/la_core/test/parsers_test.dart` (:4-8, „inlined on purpose … blocked by #94") ersetzen durch einen Verweis auf `test/fixtures/README.md`.
5. One-Literale (`""`, `"some error\n"`, `"header\nMem: not a number\n"`, Loadavg-Whitespace-Zeile) bleiben inline.

**Gates (beide Suiten):**
- `flutter test` → alle grün (heute 184; Zahl kann sich durch Umbau leicht ändern — exakte Zahl reporten)
- `cd packages/la_core && dart test` → alle grün
- `dart format --output=none --set-exit-if-changed lib test` (Root) + la_core-Format-Gate

**Commit:** `test(mla): Parser-Tests beider Tracks lesen die gemeinsamen Fixtures (#94)`

---

## Task 4 — GTK-/Python-Track-Nachweis in der Fixture-README

**Ziel:** Akzeptanz „beide Tracks lesen sie" ist ohne UI-Code dokumentiert und belegt.

**Schritte:** In `test/fixtures/README.md` einen Abschnitt „GTK-/Python-Track" ergänzen: Pfad-Konvention (Python löst den Repo-Root zur Laufzeit auf — GitHub-Checkout wie im Leak-Check, `prototype/gtk/`-Adapter lesen denselben Pfad), Verweis darauf, dass `additional/python/tests/test_fixture_leak_check.py` den Python-Lesezugriff täglich in CI beweist, und dass echte GTK-Datenadapter Gegenstand von A2/#92 und Folgetasks sind. Kein Code in `prototype/gtk/`.

**Gate:** README ist sinnvoll strukturiert (Abschnittsüberschriften rendern); keine Test-Gates betroffen.

**Commit:** `docs(mla): Fixture-Nutzung des GTK-Tracks dokumentieren (#94)`

---

## Task 5 — Abschluss: Handoff, Spiegel, Gates (Controller-getrieben)

1. `docs/mla-next/VERIFY.md`: neue Sektion „Handoff #94" (Basis-SHA `e4c1346`, Pfade, Failing-First-Evidenz je Task, Reviewer-1/Reviewer-2-Ergebnisse, wirklich ausgeführte Gates mit Ausgaben, rote/skipped Gates, Rückfallplan `git revert` der Task-Commits).
2. `docs/mla-next/ISSUES.md` #94-Sektion: Abnahme- und Handoff-Boxen mit Evidence abhaken.
3. Alle Gates komplett frisch (Root + la_core + Python + `tool/check-versions.sh`).
4. Final-Whole-Branch-Review (`e4c1346..HEAD`) durch zwei parallele Reviewer (Correctness + Completeness), Fix-Loop bei Critical/Important.
5. Ledger-Update; danach `finishing-a-development-branch`-Entscheidung (PR erstellen / parken) per User-Rückfrage.

**Commit:** `docs(mla): Handoff #94 Fixtures und Zustands-Modelle (#94)`

---

## Rückfallplan

`git revert` der Task-Commits (siehe Ledger); kein Force-Push, Branch ist nicht gepusht. Task 2 ist isoliert (nur la_core-Neudatei + Barrel-Zeile), Task 1/3 greifen ineinander (gemeinsame Fixture-Dateien) und werden gemeinsam revertiert.
