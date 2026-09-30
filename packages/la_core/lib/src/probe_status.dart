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
        'markStale() is only valid on ok, not on ${state.name}.',
      );
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
