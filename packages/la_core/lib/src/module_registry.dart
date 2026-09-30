import 'dart:async';

import 'event_bus.dart';
import 'module_descriptor.dart';

enum ModuleState { registered, starting, started, stopping, stopped }

/// Richtung der unter [ModuleRegistry._inflight] angemeldeten Operation.
/// Nur gleichgerichtete Aufrufe teilen sich eine Future; Gegenrichtungen
/// laufen nacheinander (geordnetes Last-Wins, Issue #110).
enum _Direction { activate, deactivate }

/// Laufender Vorgang einer Modul-ID. Der Vorgang wird ueber [complete] bzw.
/// [fail] abgeschlossen; Nachfolger in Gegenrichtung warten auf [operation].
class _Inflight {
  _Inflight(this.direction);

  final _Direction direction;
  final Completer<void> _done = Completer<void>();

  Future<void> get operation => _done.future;

  void complete() {
    if (!_done.isCompleted) _done.complete();
  }

  void fail(Object error, StackTrace stackTrace) {
    if (!_done.isCompleted) _done.completeError(error, stackTrace);
  }
}

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
  ModuleRegistry({required ModuleActivator activator, EventBus? bus})
    : _activator = activator,
      _bus = bus;

  final ModuleActivator _activator;

  /// Optional: when set, a newly registered module is announced on
  /// [CoreTopics.moduleRegistered]. `null` keeps the registry silent, so the
  /// existing callers and tests stay unchanged.
  final EventBus? _bus;
  final Map<String, ModuleDescriptor> _modules = {};
  final Map<String, ModuleState> _states = {};
  final Map<String, bool> _visible = {};

  /// Laufende Operation je Modul-ID. Vorher lag hier nur eine Future, wodurch
  /// ein `activate` eine laufende Deaktivierung still als eigenes Ergebnis
  /// teilte und ein Modul ueber einem bereits gestoppten Abhaengigen starten
  /// konnte (Issue #110).
  final Map<String, _Inflight> _inflight = {};
  final List<String> _activationOrder = [];
  bool _validated = false;

  void register(ModuleDescriptor descriptor) {
    if (_modules.containsKey(descriptor.id)) {
      throw ModuleRegistryError('duplicate module id: ${descriptor.id}');
    }
    _modules[descriptor.id] = descriptor;
    _states[descriptor.id] = ModuleState.registered;
    _validated = false;
    _bus?.publish(CoreTopics.moduleRegistered, descriptor);
  }

  List<ModuleDescriptor> get descriptors => List.unmodifiable(_modules.values);
  bool isRegistered(String id) => _modules.containsKey(id);
  ModuleDescriptor? operator [](String id) => _modules[id];
  ModuleState stateOf(String id) =>
      _states[id] ?? (throw ModuleRegistryError('unknown module id: $id'));
  bool isVisible(String id) => _visible[id] ?? false;

  void validate() {
    for (final d in _modules.values) {
      for (final dep in d.requires) {
        if (!_modules.containsKey(dep)) {
          throw ModuleRegistryError('${d.id} requires unknown module: $dep');
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
          'dependency cycle: ${[...path, id].join(' -> ')}',
        );
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

  Future<void> activate(String id) {
    if (!_modules.containsKey(id)) {
      throw ModuleRegistryError('unknown module id: $id');
    }
    if (!_validated) validate();
    return _enqueue(id, _Direction.activate);
  }

  /// Reiht eine Operation fuer [id] ein. Gleichgerichtete Aufrufe teilen sich
  /// die laufende Future (Single-Flight); ein Gegenrichtungs-Aufruf wartet auf
  /// den laufenden Vorgang und startet danach — geordnetes Last-Wins, damit
  /// `activate` nach einem `deactivate` tatsaechlich wieder startet (Issue
  /// #110).
  Future<void> _enqueue(String id, _Direction direction) {
    final existing = _inflight[id];
    if (existing == null) {
      final entry = _Inflight(direction);
      _inflight[id] = entry;
      unawaited(_run(id, direction, entry));
      return entry.operation;
    }
    if (existing.direction == direction) return existing.operation;

    final entry = _Inflight(direction);
    _inflight[id] = entry;
    unawaited(
      existing.operation
          // Das Ergebnis des Vorgaengers ist nur fuer die Reihenfolge
          // relevant; ein Fehler dort gehoert seinem Aufrufer, nicht dem
          // Nachfolger.
          .then<void>((_) {}, onError: (Object _, StackTrace _) {})
          .then((_) => _run(id, direction, entry)),
    );
    return entry.operation;
  }

  /// Fuehrt die angemeldete Operation aus und schliesst [entry] ab. Fehler
  /// laufen auf die Future des Eintrags, damit der `unawaited`-Start in
  /// [_enqueue] keinen unbehandelten Fehler erzeugt.
  Future<void> _run(String id, _Direction direction, _Inflight entry) async {
    try {
      if (direction == _Direction.activate) {
        await _activateSubtree(id);
      } else {
        await _deactivateWithDependents(id);
      }
      entry.complete();
    } catch (error, stackTrace) {
      entry.fail(error, stackTrace);
    } finally {
      // Nur den eigenen Eintrag raeumen: eine bereits eingereihte
      // Gegenrichtung haengt unter demselben Key und wartet auf uns.
      if (identical(_inflight[id], entry)) {
        _inflight.remove(id);
      }
    }
  }

  Future<void> _activateSubtree(String id) async {
    for (final depId in _dependenciesOf(id)) {
      // Auch bei laufendem Vorgang anmelden: ist das eine Deaktivierung,
      // reiht sich der Start dahinter ein und startet das Dep danach neu,
      // statt still ueber einem gestoppten Dep zu starten (Issue #110).
      final pending = _inflight[depId];
      if (pending != null || _states[depId] != ModuleState.started) {
        await _enqueue(depId, _Direction.activate);
      }
      _requireStarted(id, depId);
    }
    if (_states[id] == ModuleState.started) return;
    _states[id] = ModuleState.starting;
    await _activator.start(_modules[id]!);
    // Re-Check nach dem Await: waehrend des Starts kann ein Dep gestoppt
    // worden sein. Dann nicht als started stehen bleiben, sondern den Start
    // zurueckrollen und laut werfen (Requires-Invariante).
    for (final depId in _dependenciesOf(id)) {
      final pending = _inflight[depId];
      final depWillStop =
          pending != null && pending.direction == _Direction.deactivate;
      if (_states[depId] != ModuleState.started || depWillStop) {
        await _rollbackStart(id);
        throw ModuleRegistryError(
          '$id requires $depId, which is no longer started',
        );
      }
    }
    _states[id] = ModuleState.started;
    _activationOrder.add(id);
  }

  void _requireStarted(String id, String depId) {
    if (_states[depId] != ModuleState.started) {
      throw ModuleRegistryError('$id requires $depId, which is not started');
    }
  }

  /// Rollt einen Start zurueck, dessen Abhaengigkeiten waehrend des Starts
  /// gestoppt wurden: das Modul laeuft, darf aber nicht als gestartet gefuehrt
  /// werden.
  Future<void> _rollbackStart(String id) async {
    _states[id] = ModuleState.stopping;
    await _activator.stop(_modules[id]!);
    _states[id] = ModuleState.stopped;
    _activationOrder.remove(id);
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
    return _enqueue(id, _Direction.deactivate);
  }

  Future<void> _deactivateWithDependents(String id) async {
    // Snapshot: _stopModule entfernt aus _activationOrder (lazy .reversed
    // wuerde sonst Concurrent Modification werfen).
    for (final active in List.of(_activationOrder).reversed) {
      if (active == id) break;
      if (_states[active] == ModuleState.started &&
          _transitivelyDependsOn(active, id)) {
        await _stopModule(active);
      }
    }
    // _inflight raeumt ausschliesslich _run: der eigene Eintrag traegt die
    // Future, auf die eine bereits eingereihte Gegenrichtung wartet.
    if (_states[id] == ModuleState.started) {
      await _stopModule(id);
    }
  }

  Future<void> _stopModule(String id) async {
    _states[id] = ModuleState.stopping;
    await _activator.stop(_modules[id]!);
    _states[id] = ModuleState.stopped;
    _activationOrder.remove(id);
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
        await _enqueue(id, _Direction.deactivate);
      }
    }
  }

  void setVisible(String id, bool visible) {
    if (_states[id] != ModuleState.started) {
      throw ModuleRegistryError(
        'setVisible($id, $visible): module not started',
      );
    }
    _visible[id] = visible;
  }
}
