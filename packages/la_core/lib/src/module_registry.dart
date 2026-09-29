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
  ModuleRegistry({required ModuleActivator activator}) : _activator = activator;

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
