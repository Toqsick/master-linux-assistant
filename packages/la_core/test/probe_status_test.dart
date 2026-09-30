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
    expect(
      () => const ProbeStatus<int>.unknown().markStale(),
      throwsStateError,
    );
    expect(
      () => const ProbeStatus<int>.running().markStale(),
      throwsStateError,
    );
    expect(
      () => const ProbeStatus<int>.failed('x').markStale(),
      throwsStateError,
    );
  });

  test('stale cannot go stale again and has no path back to ok', () {
    final stale = ProbeStatus<int>.ok(42, observed).markStale();
    expect(() => stale.markStale(), throwsStateError);
    // ok entsteht nur frisch: ProbeStatus.ok(data, observedAt).
  });

  test('value equality covers all four fields', () {
    expect(
      ProbeStatus<int>.ok(42, observed),
      ProbeStatus<int>.ok(42, observed),
    );
    expect(
      ProbeStatus<int>.ok(42, observed).markStale(),
      isNot(ProbeStatus<int>.ok(42, observed)),
    );
  });
}
