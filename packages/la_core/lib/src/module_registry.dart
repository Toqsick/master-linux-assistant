import 'event_bus.dart';
import 'module_descriptor.dart';

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
    // Snapshot: _stopModule entfernt aus _activationOrder (lazy .reversed
    // wuerde sonst Concurrent Modification werfen).
    for (final active in List.of(_activationOrder).reversed) {
      if (active == id) break;
      if (_states[active] == ModuleState.started &&
          _transitivelyDependsOn(active, id)) {
        await (_inflight[active] ??= _stopModule(active));
      }
    }
    // Direkt stoppen: _inflight[id] enthaelt bereits die Future DIESES
    // Deactivate-Laufs (Eintrag in deactivate()); `??=` wuerde sonst auf
    // uns selbst warten -> Deadlock. Single-Flight bleibt am EntryPoint
    // von deactivate() gewaehrleistet.
    if (_states[id] == ModuleState.started) {
      await _stopModule(id);
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
        'setVisible($id, $visible): module not started',
      );
    }
    _visible[id] = visible;
  }
}
