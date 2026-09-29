import 'dart:async';

import 'package:la_core/la_core.dart';
import 'package:test/test.dart';

ModuleDescriptor mod(String id, {Set<String>? requires}) {
  return ModuleDescriptor(
    id: id,
    titleKey: 'title.$id',
    viewId: 'view.$id',
    kind: ModuleKind.tool,
    requires: requires ?? const <String>{},
  );
}

class RecordingActivator implements ModuleActivator {
  RecordingActivator({this.gate});

  final List<String> log = [];

  /// Wenn gesetzt, wartet [start] auf dieses Gate (Single-Flight-Tests).
  final Completer<void>? gate;

  @override
  Future<void> start(ModuleDescriptor module) async {
    log.add('start ${module.id}');
    final g = gate;
    if (g != null) {
      await g.future;
    }
  }

  @override
  Future<void> stop(ModuleDescriptor module) async {
    log.add('stop ${module.id}');
  }
}

void main() {
  test('activate startet Abhaengigkeiten in Topo-Reihenfolge a -> b -> c',
      () async {
    final activator = RecordingActivator();
    final r = ModuleRegistry(activator: activator);
    r.register(mod('a', requires: {'b'}));
    r.register(mod('b', requires: {'c'}));
    r.register(mod('c'));

    await r.activate('a');

    expect(activator.log, ['start c', 'start b', 'start a']);
  });

  test('geteilte Abhaengigkeit startet genau einmal (lazy)', () async {
    final activator = RecordingActivator();
    final r = ModuleRegistry(activator: activator);
    r.register(mod('a', requires: {'c'}));
    r.register(mod('b', requires: {'c'}));
    r.register(mod('c'));

    await r.activate('a');
    await r.activate('b');

    expect(
      activator.log.where((entry) => entry == 'start c'),
      hasLength(1),
    );
    expect(activator.log, ['start c', 'start a', 'start b']);
  });

  test('Single-Flight: zwei activate vor gate.complete() starten nur einmal',
      () async {
    final gate = Completer<void>();
    final activator = RecordingActivator(gate: gate);
    final r = ModuleRegistry(activator: activator);
    r.register(mod('a'));

    final first = r.activate('a');
    final second = r.activate('a');
    expect(activator.log, ['start a']);

    gate.complete();
    await first;
    await second;
    expect(activator.log, ['start a']);
  });

  test('deactivate stoppt aktive Abhaengige rueckwaerts vor dem Ziel',
      () async {
    final activator = RecordingActivator();
    final r = ModuleRegistry(activator: activator);
    r.register(mod('x', requires: {'y'}));
    r.register(mod('z', requires: {'y'}));
    r.register(mod('y'));

    await r.activate('x');
    await r.activate('z');
    expect(activator.log, ['start y', 'start x', 'start z']);
    activator.log.clear();

    await r.deactivate('y');

    expect(activator.log, ['stop z', 'stop x', 'stop y']);
  });

  test('setVisible wirft vor Start und wirkt danach', () async {
    final r = ModuleRegistry(activator: RecordingActivator());
    r.register(mod('a'));

    expect(
      () => r.setVisible('a', true),
      throwsA(isA<ModuleRegistryError>()),
    );
    expect(r.isVisible('a'), isFalse);

    await r.activate('a');
    r.setVisible('a', true);
    expect(r.isVisible('a'), isTrue);
    r.setVisible('a', false);
    expect(r.isVisible('a'), isFalse);
  });

  test('stateOf: registered -> starting -> started -> stopped', () async {
    final gate = Completer<void>();
    final activator = RecordingActivator(gate: gate);
    final r = ModuleRegistry(activator: activator);
    r.register(mod('a'));

    expect(r.stateOf('a'), ModuleState.registered);

    unawaited(r.activate('a'));
    await Future<void>.delayed(Duration.zero);
    expect(r.stateOf('a'), ModuleState.starting);

    gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(r.stateOf('a'), ModuleState.started);

    await r.deactivate('a');
    expect(r.stateOf('a'), ModuleState.stopped);
  });

  test('deactivateAll stoppt in umgekehrter Aktivierungsreihenfolge', () async {
    final activator = RecordingActivator();
    final r = ModuleRegistry(activator: activator);
    r.register(mod('a', requires: {'b'}));
    r.register(mod('b', requires: {'c'}));
    r.register(mod('c'));

    await r.activate('a');
    activator.log.clear();

    await r.deactivateAll();

    expect(activator.log, ['stop a', 'stop b', 'stop c']);
  });
}
