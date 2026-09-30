import 'core_logger.dart';
import 'event_bus.dart';
import 'probe.dart';

/// Raised for an unknown or duplicate probe id.
class ProbeRegistryError implements Exception {
  ProbeRegistryError(this.message);

  final String message;

  @override
  String toString() => 'ProbeRegistryError: $message';
}

/// Static probe registration and execution (#93).
///
/// Injection mirrors `ModuleRegistry({required ModuleActivator activator})`:
/// the [EventBus] and the [CoreLogger] come from the caller, so `la_core`
/// stays free of process and UI concerns.
class ProbeRegistry {
  ProbeRegistry({required EventBus bus, CoreLogger logger = const NullLogger()})
    : _bus = bus,
      _logger = logger;

  final EventBus _bus;
  final CoreLogger _logger;
  final Map<String, Probe> _probes = {};

  void register(Probe probe) {
    if (_probes.containsKey(probe.id)) {
      throw ProbeRegistryError('duplicate probe id: ${probe.id}');
    }
    _probes[probe.id] = probe;
  }

  Probe probe(String id) {
    final found = _probes[id];
    if (found == null) {
      throw ProbeRegistryError('unknown probe id: $id');
    }
    return found;
  }

  /// Runs the probe with [id], logs the outcome and publishes the result on
  /// [CoreTopics.probeResult].
  Future<ProbeResult> run(String id) async {
    final probe = this.probe(id);
    _logger.debug('probe run: $id');
    final result = await probe.run();
    _logger.info('probe $id -> ${result.level.name}');
    _bus.publish(CoreTopics.probeResult, result);
    return result;
  }
}
