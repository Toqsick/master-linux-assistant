# MLA-Next-Start: Gate 0 + A0-Baseline + la_core-Spike (#59) + Registry-Vertrag (#60)

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development` (pro Task: `scripts/task-brief`, Implementer-Dispatch, `scripts/review-package`, Two-Reviewer laut `superpowers-zcode`, Fix-Loop). Schritte sind Checkboxen. Approved 2026-09-29.

**Ziel:** Handoff §8 Nr. 1–3 vollständig: Gate-0-Verifikation des GTK-Scaffolds auf Zorin, A0-Baseline mit Evidence-Map, #59-Headless-Spike `packages/la_core` und #60-Kern-Registry — alles auf `feature/mla-gtk-scaffold`, PR #89 bleibt Draft.

**Architektur:** Reiner Dart-Kern `packages/la_core` (keine flutter:/GTK-Importe) mit Probe-Vertrag + statischer Modul-Registry (Deskriptor ohne View-Builder; Aktivierung Single-Flight, Stopp rückwärts). GTK-Prototyp bleibt Fixture-Demo; Flutter-App wird nicht angefasst.

**Stack:** Dart ≥3.4 (aus dem Flutter-SDK), `package:test`/`package:lints`; Python3/PyGObject (GTK4 + libadwaita 1) für Gate 0.

## Global Constraints

1. Nie `sudo`/root für GTK-, Dart- oder Agent-Prozesse; polkit-Grenze nicht umgehen.
2. Keine Shell-Strings; Prozesse nur mit validiertem Executable + argv (heute: nur `la_probe`, `mla_app.py`, Gates).
3. Keine Secrets/Tokens/unredigierte Dumps in Logs, Screenshots (nur `/tmp`), Commits.
4. Kein Push, kein Merge, kein Draft-Status-Change an PR #89; kein Push auf Upstream.
5. Nur wirklich gelaufene Gates abhaken — VERIFY.md-Checkboxen nur mit Datum + Beleg (BASELINE.md).
6. Nur neue Dateien (`packages/la_core/**`, `docs/mla-next/BASELINE.md`, Plan-Datei); unverändert bleiben `lib/`, `additional/`, `deb/`, `linux/`, Policies, Packaging. Einzig bestehende Datei mit Änderung: `docs/mla-next/VERIFY.md` (Checkboxen + Datumsnotizen).
7. `la_core`: reines Dart; Fire-and-Forget-Futures in `unawaited(...)`; kein `print` (stdout nur CLI-Ausgabe in `bin/la_probe.dart`).
8. `gh` immer mit `-R Toqsick/master-linux-assistant`.
9. `pkill -f` mit App-Pfad ist verboten (Ledger-Lektion v0.8.0) — Prozesse per gespeicherter PID beenden.
10. Commit-Stil wie Repo (`feat(la_core): …`, `docs(mla): …`), ein Commit pro Task-Abschluss, direkt auf `feature/mla-gtk-scaffold`.

**Ausdrücklich out of scope (Folge-Sessions):** Flutter-Hub-Migration (`hub_shell.dart` → HubModule-Liste, #60-App-Seite), IPC-Schema/Fixtures, Backup #63, CommandHelper/Logger/Parser-Umzug (#59 „Danach"-Teil), build-deb-Integration.

---

### Task 1: Branch auschecken, Ledger, Plandatei

**Files:** Create `docs/superpowers/plans/2026-09-29-mla-next-gate0-a0-la-core-registry.md` (dieser Plan); Modify `.superpowers/sdd/progress.md` (neuer Abschnitt oben, uncommittet — Scratch).
**Interfaces:** Branch-Tip muss `ba048d3` sein (auf `92bef60` = main).

- [x] `git fetch origin feature/mla-gtk-scaffold:feature/mla-gtk-scaffold && git checkout feature/mla-gtk-scaffold`
- [x] `git log --oneline -3` → erwartet `ba048d3`, `4d5c441`, `92bef60`; `git status --short` → leer
- [x] Ledger: neuen Abschnitt über den alten v0.8.0-Inhalt setzen; darunter je Task eine Zeile nach Review
- [x] Plandatei schreiben; Commit `docs(mla): add SDD execution plan (gate 0, baseline, la_core spike + registry)`

### Task 2: Gate 0 — Scaffold-Verifikation, automatisierter Teil

**Files:** Create `docs/mla-next/BASELINE.md`; Modify `docs/mla-next/VERIFY.md`.

- [ ] Umgebung erfassen (Ausgaben 1:1 nach BASELINE.md §1 „Zorin-Matrix"): `$XDG_SESSION_TYPE`, `$XDG_CURRENT_DESKTOP`; `python3 --version`; `python3 -c "import gi; gi.require_version('Gtk','4.0'); gi.require_version('Adw','1'); from gi.repository import Gtk, Adw; print('GTK', Gtk.get_major_version(), Gtk.get_minor_version(), Gtk.get_micro_version(), '/ Adw', Adw.get_major_version(), Adw.get_minor_version(), Adw.get_micro_version())"`; `pkg-config --modversion gtk4 libadwaita-1`; `dart --version`; `flutter --version | head -2`; `. /etc/os-release && echo "$PRETTY_NAME"`
- [ ] `cd prototype/gtk && python3 -m py_compile mla_app.py` → Exit 0, keine Ausgabe; Python-Version notieren
- [ ] Wayland-Start: `python3 mla_app.py & APP=$!; sleep 3; kill -0 $APP && echo "lebt (Wayland, PID $APP)"`; Screenshot `gnome-screenshot -f /tmp/mla-gate0-wayland.png` (Fallback: D-Bus `org.gnome.Shell.Screenshot.Screenshot`); `kill $APP; wait $APP 2>/dev/null` — Kriterium: 3 s am Leben, kein Traceback auf stderr
- [ ] X11-Start: identisch mit `GDK_BACKEND=x11 python3 mla_app.py …`, Screenshot `/tmp/mla-gate0-x11.png`
- [ ] BASELINE.md §2 „Gate 0": Ergebnisse + Rohausgaben; §3 „Manuelle Checkliste (Basti)": Screens (Dashboard/Monitor/Backup/Security) anklicken, Titel + rechte Details + Backup-Status `unknown`, Resize, Tastatur/Fokus, Hell/Dunkel, 100/125/150 % Skalierung
- [ ] VERIFY.md Gate 0: Box 1 (`py_compile`) und Box 2 (Start, Versionen, Wayland/X11) → `[x]` + Notiz `2026-09-29: automatisiert verifiziert, siehe docs/mla-next/BASELINE.md; manuelle Checks offen`; Box 3/4 bleiben `[ ]`; Box 5 → `[x]` mit Notiz (unprivilegierter Start, Fixture-Only, Screenshots nur /tmp). Commit `docs(mla): gate 0 automated verification on zorin (wayland + x11)`

### Task 3: A0 — Baseline & Evidence-Map

**Files:** Modify `docs/mla-next/BASELINE.md`.

- [ ] Repo-Fakten per `gh` (immer `-R Toqsick/master-linux-assistant`): `gh pr view 89 --json state,isDraft,mergeable` (erwartet OPEN/draft/MERGEABLE); `gh issue view 59|60|63 --json number,title,state` (alle offen, Milestone V0.9); `gh run list --limit 3` (Stand notieren)
- [ ] Lokale Gates im Repo-Root, Ausgaben (Zahlen!) nach BASELINE.md §4: `bash tool/check-versions.sh` (Exit 0) → `dart format --output=none --set-exit-if-changed lib test` (Exit 0) → `flutter analyze` („No issues found!") → `flutter test` („All tests passed!", Anzahl notieren; Handoff-Referenz: 184) → `cd additional/python && python3 -m unittest discover -s tests -t .` (OK)
- [ ] §5 „Evidence-Map": Tabelle Aussage → Beleg (Kommando+Output bzw. Datei:Zeile); §6 offene Punkte (GTK-Laufzeit nur bis 3 s Lebenstest verifiziert, keine Interaktion; Messbasis 0.0.3 offen). Commit `docs(mla): add A0 baseline and evidence map`

### Task 4: #59-Spike — `packages/la_core` minimal (TDD)

**Files:** Create `packages/la_core/pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, `lib/la_core.dart`, `lib/src/probe.dart`, `bin/la_probe.dart`, `test/probe_test.dart`.

- [ ] `pubspec.yaml`:
```yaml
name: la_core
description: Master Linux Assistant - reiner Dart-Kern (Spike #59, Registry #60). Keine Flutter-/GTK-Typen.
version: 0.0.1
publish_to: none

environment:
  sdk: ^3.4.0

dev_dependencies:
  lints: ^5.0.0
  test: ^1.25.0
```
`analysis_options.yaml`: `include: package:lints/recommended.yaml`; `.gitignore`: `.dart_tool/` + `build/`
- [ ] **RED:** `test/probe_test.dart` schreiben:
```dart
import 'package:la_core/la_core.dart';
import 'package:test/test.dart';

void main() {
  test('ProbeResult.describe enthaelt Level und Key', () {
    const r = ProbeResult(level: ProbeLevel.warn, key: 'mem.free');
    expect(r.describe(), startsWith('warn:mem.free'));
  });

  test('ProbeLevel deckt ok/warn/crit/unknown ab', () {
    expect(ProbeLevel.values.map((l) => l.name),
        containsAll(<String>['ok', 'warn', 'crit', 'unknown']));
  });

  test('SelfProbe liefert ok mit key probe.self', () async {
    final r = await SelfProbe().run();
    expect(r.level, ProbeLevel.ok);
    expect(r.key, 'probe.self');
  });
}
```
`cd packages/la_core && dart pub get && dart test` → FAIL (lib fehlt)
- [ ] **GREEN:** `lib/src/probe.dart`:
```dart
enum ProbeLevel { ok, warn, crit, unknown }

class ProbeResult {
  const ProbeResult({
    required this.level,
    required this.key,
    this.params = const <String, String>{},
    this.at,
  });

  final ProbeLevel level;
  final String key;
  final Map<String, String> params;
  final DateTime? at;

  String describe() =>
      '${level.name}:$key${at == null ? '' : ' @ ${at!.toIso8601String()}'}';
}

abstract interface class Probe {
  String get id;
  Future<ProbeResult> run();
}

class SelfProbe implements Probe {
  @override
  String get id => 'probe.self';

  @override
  Future<ProbeResult> run() async =>
      ProbeResult(level: ProbeLevel.ok, key: id, at: DateTime.now());
}
```
`lib/la_core.dart`: `export 'src/probe.dart';`; `bin/la_probe.dart`:
```dart
import 'dart:io';

import 'package:la_core/la_core.dart';

const String laProbeVersion = '0.0.1-spike.1';

Future<void> main(List<String> args) async {
  if (args.contains('--version')) {
    stdout.writeln('la_probe $laProbeVersion (dart ${Platform.version})');
    return;
  }
  stdout.writeln((await SelfProbe().run()).describe());
}
```
`dart test` → 3 passed; `dart analyze` → clean; `dart format --output=none --set-exit-if-changed .` → Exit 0
- [ ] Kompilieren + Headless (Issue #59, „Dart aus dem Flutter-SDK" — `dart --version` mit `flutter --version`-Angabe abgleichen): `dart compile exe bin/la_probe.dart -o /tmp/la_probe` → „Generated: /tmp/la_probe"; `env -u DISPLAY -u WAYLAND_DISPLAY /tmp/la_probe --version` → gibt `la_probe 0.0.1-spike.1 (dart …)` aus, Exit 0
- [ ] Messen nach BASELINE.md §7: `stat -c '%s' /tmp/la_probe`; Startzeit 5×: `s=$(date +%s%N); env -u DISPLAY -u WAYLAND_DISPLAY /tmp/la_probe --version >/dev/null; e=$(date +%s%N); echo $(( (e-s)/1000000 )) ms`
- [ ] Sanity: `flutter analyze` im Root unverändert grün (Nested-Paket darf Root-Gate nicht stören; falls doch → `analysis_options.yaml` angleichen). Commit `feat(la_core): minimal headless spike per issue #59 (probe contract, compile exe)`

### Task 5: #60 Registry A — Deskriptor, Registrierung, Validierung (TDD)

**Files:** Create `lib/src/module_descriptor.dart`, `lib/src/module_registry.dart`, `test/module_registry_validate_test.dart`; Modify `lib/la_core.dart` (beide Exports).

- [ ] `module_descriptor.dart`:
```dart
enum ModuleKind { section, tool, launch }

/// Kern-Deskriptor ohne View-Builder (Issue #60): View-Factories
/// leben in den UI-Adaptern und binden ueber [viewId].
class ModuleDescriptor {
  const ModuleDescriptor({
    required this.id,
    required this.titleKey,
    required this.viewId,
    required this.kind,
    this.capabilities = const <String>{},
    this.requires = const <String>{},
    this.probeIds = const <String>{},
    this.actionIds = const <String>{},
    this.subscribedTopics = const <String>{},
  });

  final String id;
  final String titleKey;
  final String viewId;
  final ModuleKind kind;
  final Set<String> capabilities;
  final Set<String> requires;
  final Set<String> probeIds;
  final Set<String> actionIds;
  final Set<String> subscribedTopics;
}
```
- [ ] **RED:** `test/module_registry_validate_test.dart` — Tests: (1) doppelte ID → `throwsA(isA<ModuleRegistryError>())`; (2) unbekannte Abhängigkeit: `.having((e) => e.message, 'message', contains('ghost'))`; (3) Zyklus a→b→a wirft; (4) nach `validate()` neue `register(...)` möglich, erneute `validate()` wirft nicht. Helper: `ModuleDescriptor mod(String id, {Set<String> requires})` und `_NoopActivator` (start/stop no-op).
- [ ] **GREEN:** `module_registry.dart` (Teil 1):
```dart
enum ModuleState { registered, starting, started, stopping, stopped }

abstract interface class ModuleActivator {
  Future<void> start(ModuleDescriptor module);
  Future<void> stop(ModuleDescriptor module);
}

class ModuleRegistryError implements Exception {
  ModuleRegistryError(this.message);
  final String message;
  @override
  String toString() => 'ModuleRegistryError: $message';
}

/// Statische Registrierung; kein Laden fremder Plugins (Issue #60).
class ModuleRegistry {
  ModuleRegistry({required ModuleActivator activator})
      : _activator = activator;

  final ModuleActivator _activator;
  final Map<String, ModuleDescriptor> _modules = {};
  final Map<String, ModuleState> _states = {};
  final Map<String, bool> _visible = {};
  final Map<String, Future<void>> _inflight = {};
  final List<String> _activationOrder = [];
  bool _validated = false;

  void register(ModuleDescriptor descriptor) {
    if (_modules.containsKey(descriptor.id)) {
      throw ModuleRegistryError('duplicate module id: ${descriptor.id}');
    }
    _modules[descriptor.id] = descriptor;
    _states[descriptor.id] = ModuleState.registered;
    _validated = false;
  }

  List<ModuleDescriptor> get descriptors => List.unmodifiable(_modules.values);
  bool isRegistered(String id) => _modules.containsKey(id);
  ModuleDescriptor? operator [](String id) => _modules[id];
  ModuleState stateOf(String id) => _states[id] ??
      (throw ModuleRegistryError('unknown module id: $id'));
  bool isVisible(String id) => _visible[id] ?? false;

  void validate() {
    for (final d in _modules.values) {
      for (final dep in d.requires) {
        if (!_modules.containsKey(dep)) {
          throw ModuleRegistryError(
              '${d.id} requires unknown module: $dep');
        }
      }
    }
    _checkCycles();
    _validated = true;
  }

  void _checkCycles() {
    final mark = <String, int>{}; // fehlend=neu, 1=in Arbeit, 2=fertig
    void visit(String id, List<String> path) {
      final m = mark[id] ?? 0;
      if (m == 2) return;
      if (m == 1) {
        throw ModuleRegistryError(
            'dependency cycle: ${[...path, id].join(' -> ')}');
      }
      mark[id] = 1;
      for (final dep in _modules[id]!.requires) {
        visit(dep, [...path, id]);
      }
      mark[id] = 2;
    }
    for (final id in _modules.keys) {
      visit(id, []);
    }
  }
}
```
- [ ] `dart test` → alle grün (3+4); `dart analyze`/`dart format` Gate; Export ergänzen. Commit `feat(la_core): module descriptor + registry validation per issue #60`

### Task 6: #60 Registry B — Aktivierung & Lifecycle (TDD)

**Files:** Modify `lib/src/module_registry.dart`; Create `test/module_registry_lifecycle_test.dart`.

- [ ] **RED:** Tests mit `RecordingActivator` (`log` Liste; optional `Completer<void> gate`, `start` awaited gate): (1) Topo-Reihenfolge: a→b→c, `activate('a')` → Log `[start c, start b, start a]`; (2) geteilte Abhängigkeit startet genau einmal (Lazy): c von a und b; (3) Single-Flight: zwei `activate('a')` vor `gate.complete()` → `start a` einmal im Log; (4) `deactivate('y')` mit x→y, z→y (beide aktiv) → `[stop z, stop x, stop y]`; (5) `setVisible` wirft `ModuleRegistryError` vor Start, funktioniert danach; (6) `stateOf`: `registered` → `starting` (während gate, via `await Future<void>.delayed(Duration.zero)`) → `started` → nach `deactivate` `stopped`; (7) `deactivateAll()` stoppt in umgekehrter Aktivierungsreihenfolge.
- [ ] **GREEN:** Registry ergänzen:
```dart
  Future<void> activate(String id) {
    if (!_modules.containsKey(id)) {
      throw ModuleRegistryError('unknown module id: $id');
    }
    if (!_validated) validate();
    return _inflight[id] ??= _activateSubtree(id);
  }

  Future<void> _activateSubtree(String id) async {
    for (final depId in _dependenciesOf(id)) {
      if (_states[depId] != ModuleState.started) {
        await (_inflight[depId] ??= _activateSubtree(depId));
      }
    }
    if (_states[id] == ModuleState.started) return;
    _states[id] = ModuleState.starting;
    try {
      await _activator.start(_modules[id]!);
      _states[id] = ModuleState.started;
      _activationOrder.add(id);
    } finally {
      _inflight.remove(id);
    }
  }

  List<String> _dependenciesOf(String id) {
    final out = <String>[];
    void collect(String m, Set<String> seen) {
      for (final dep in _modules[m]!.requires) {
        if (seen.add(dep)) {
          collect(dep, seen);
          out.add(dep);
        }
      }
    }
    collect(id, {id});
    return out;
  }

  Future<void> deactivate(String id) {
    if (!_modules.containsKey(id)) {
      throw ModuleRegistryError('unknown module id: $id');
    }
    return _inflight[id] ??= _deactivateWithDependents(id);
  }

  Future<void> _deactivateWithDependents(String id) async {
    for (final active in _activationOrder.reversed) {
      if (active == id) break;
      if (_states[active] == ModuleState.started &&
          _transitivelyDependsOn(active, id)) {
        await (_inflight[active] ??= _stopModule(active));
      }
    }
    if (_states[id] == ModuleState.started) {
      await (_inflight[id] ??= _stopModule(id));
    } else {
      _inflight.remove(id);
    }
  }

  Future<void> _stopModule(String id) async {
    _states[id] = ModuleState.stopping;
    try {
      await _activator.stop(_modules[id]!);
      _states[id] = ModuleState.stopped;
      _activationOrder.remove(id);
    } finally {
      _inflight.remove(id);
    }
  }

  bool _transitivelyDependsOn(String m, String target, [Set<String>? seen]) {
    seen ??= {};
    for (final dep in _modules[m]!.requires) {
      if (dep == target ||
          (seen.add(dep) && _transitivelyDependsOn(dep, target, seen))) {
        return true;
      }
    }
    return false;
  }

  Future<void> deactivateAll() async {
    for (final id in List.of(_activationOrder).reversed) {
      if (_states[id] == ModuleState.started) {
        await (_inflight[id] ??= _stopModule(id));
      }
    }
  }

  void setVisible(String id, bool visible) {
    if (_states[id] != ModuleState.started) {
      throw ModuleRegistryError(
          'setVisible($id, $visible): module not started');
    }
    _visible[id] = visible;
  }
```
- [ ] `dart test` → alle grün (14 gesamt erwartet: 3 Probe + 4 Validierung + 7 Lifecycle); analyze/format Gate; Commit `feat(la_core): registry lifecycle - single-flight activation, reverse stop per issue #60`

### Task 7: Abschluss — VERIFY abhaken, Root-Gates, Final-Review, Bericht

- [ ] VERIFY.md Gate 1: Box 1 (#59) `[x]` mit Messwerten (Binärgröße/Startzeit → BASELINE §7); Box 2 (#60) `[x]` mit Beleg „14 dart-Tests; Flutter-Navigation unberührt (`git diff --stat 92bef60..HEAD` zeigt kein `lib/`)" + flutter-test-Zahl; Box 3 `[x]` nach frischen Root-Gates. Commit `docs(mla): check off gate 1 spike + registry portions with evidence`
- [ ] Frische Root-Gates (verification-before-completion, Outputs zitieren): `tool/check-versions.sh`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, Python-Tests
- [ ] Final whole-branch review: `review-package 92bef60 HEAD` → `code-reviewer`-Dispatch (kritischster Tier); Critical/Important → EIN Fix-Subagent mit kompletter Findings-Liste → Re-Review
- [ ] Ledger-Abschluss; Bericht an Basti inkl. manueller Gate-0-Checkliste (BASELINE §3) und Hinweis: PR #89 bleibt Draft, Push nur auf Anweisung

## Ausführungsrahmen

- SDD: pro Task Implementer-Dispatch (general-purpose) mit Brief via `scripts/task-brief`, danach `scripts/review-package` + Two-Reviewer parallel (Correctness + Completeness) laut `superpowers-zcode`; Fix-Loop bis clean; Ledger-Zeile je Task. Kein Worktree (Single-User-Repo, sauberer Tree, Branch-Checkout reicht — dokumentierte Abweichung von Phase ISOLATE).
- Fehlende Toolchain (GTK/Adw/Dart) oder rot laufende Baseline-Gates → BLOCKED melden, nicht improvisieren (Handoff-Regel 5).
