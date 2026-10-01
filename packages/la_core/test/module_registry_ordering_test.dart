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

/// Aktivator mit Gates je `'<verb>:<id>'`. Echte Completer statt Fake-Async:
/// dart:io-Streams stallen unter Fake-Async (Repo-Lektion aus E.4).
class GatedActivator implements ModuleActivator {
  GatedActivator({this.gates = const <String, Completer<void>>{}});

  final Map<String, Completer<void>> gates;
  final List<String> log = [];

  @override
  Future<void> start(ModuleDescriptor module) async {
    log.add('start ${module.id}');
    final gate = gates['start:${module.id}'];
    if (gate != null) {
      await gate.future;
    }
  }

  @override
  Future<void> stop(ModuleDescriptor module) async {
    log.add('stop ${module.id}');
    final gate = gates['stop:${module.id}'];
    if (gate != null) {
      await gate.future;
    }
  }
}

void main() {
  test('activate nach laufendem deactivate derselben ID endet started '
      '(geordnetes Last-Wins)', () async {
    final stopGate = Completer<void>();
    final activator = GatedActivator(gates: {'stop:a': stopGate});
    final registry = ModuleRegistry(activator: activator);
    registry.register(mod('a'));

    await registry.activate('a');
    expect(activator.log, ['start a']);

    final stopping = registry.deactivate('a');
    expect(registry.stateOf('a'), ModuleState.stopping);

    // Reiht sich hinter das laufende deactivate ein, statt dessen Future
    // still als eigenes Ergebnis zu teilen.
    final restarting = registry.activate('a');
    stopGate.complete();
    await stopping;
    await restarting;

    expect(registry.stateOf('a'), ModuleState.started);
    expect(activator.log, ['start a', 'stop a', 'start a']);
  });

  test(
    'deactivate nach laufendem activate derselben ID endet stopped',
    () async {
      final startGate = Completer<void>();
      final activator = GatedActivator(gates: {'start:a': startGate});
      final registry = ModuleRegistry(activator: activator);
      registry.register(mod('a'));

      final starting = registry.activate('a');
      expect(registry.stateOf('a'), ModuleState.starting);
      expect(activator.log, ['start a']);

      final stopping = registry.deactivate('a');
      startGate.complete();
      await starting;
      await stopping;

      expect(registry.stateOf('a'), ModuleState.stopped);
      expect(activator.log, ['start a', 'stop a']);
    },
  );

  test('activate eines Abhaengigen startet den Dep nach dessen laufendem '
      'deactivate neu, statt ueber ihm zu starten', () async {
    final stopGate = Completer<void>();
    final activator = GatedActivator(gates: {'stop:b': stopGate});
    final registry = ModuleRegistry(activator: activator);
    registry.register(mod('a', requires: {'b'}));
    registry.register(mod('b'));

    await registry.activate('b');
    expect(activator.log, ['start b']);

    final stopping = registry.deactivate('b');
    expect(registry.stateOf('b'), ModuleState.stopping);

    final activating = registry.activate('a');
    stopGate.complete();
    await stopping;
    await activating;

    expect(registry.stateOf('b'), ModuleState.started);
    expect(registry.stateOf('a'), ModuleState.started);
    expect(activator.log, ['start b', 'stop b', 'start b', 'start a']);
  });

  test('gestartetes Modul ueber inzwischen gestopptem Dep wird zurueckgerollt '
      'und wirft', () async {
    final startGate = Completer<void>();
    final stopGate = Completer<void>();
    final activator = GatedActivator(
      gates: {'start:a': startGate, 'stop:b': stopGate},
    );
    final registry = ModuleRegistry(activator: activator);
    registry.register(mod('a', requires: {'b'}));
    registry.register(mod('b'));

    await registry.activate('b');

    // a haengt im Start, ist damit noch nicht in _activationOrder — ein
    // deactivate von b findet es dort nicht als Abhaengigen.
    final activating = registry.activate('a');
    expect(registry.stateOf('a'), ModuleState.starting);

    final stopping = registry.deactivate('b');
    expect(registry.stateOf('b'), ModuleState.stopping);
    stopGate.complete();
    await stopping;
    expect(registry.stateOf('b'), ModuleState.stopped);

    // Der Start laeuft jetzt durch, findet aber einen gestoppten Dep vor.
    startGate.complete();
    await expectLater(activating, throwsA(isA<ModuleRegistryError>()));

    expect(registry.stateOf('a'), ModuleState.stopped);
    expect(activator.log, ['start b', 'start a', 'stop b', 'stop a']);
  });

  test('paralleles activate zweier Abhaengiger startet den gemeinsamen Dep '
      'genau einmal', () async {
    final startGate = Completer<void>();
    final activator = GatedActivator(gates: {'start:c': startGate});
    final registry = ModuleRegistry(activator: activator);
    registry.register(mod('a', requires: {'c'}));
    registry.register(mod('b', requires: {'c'}));
    registry.register(mod('c'));

    final first = registry.activate('a');
    final second = registry.activate('b');
    expect(activator.log, ['start c']);

    startGate.complete();
    await first;
    await second;

    expect(activator.log.where((entry) => entry == 'start c'), hasLength(1));
    expect(registry.stateOf('c'), ModuleState.started);
    expect(registry.stateOf('a'), ModuleState.started);
    expect(registry.stateOf('b'), ModuleState.started);
  });

  test('deactivateAll stoppt ein Modul im Uebergang, statt es zu '
      'ueberspringen (Last-Wins)', () async {
    final stopGate = Completer<void>();
    final activator = GatedActivator(gates: {'stop:a': stopGate});
    final registry = ModuleRegistry(activator: activator);
    registry.register(mod('a'));

    await registry.activate('a');
    expect(activator.log, ['start a']);

    // Deaktivierung laeuft, Gate haelt sie auf: Modul ist stopping, aber
    // weiterhin in _activationOrder.
    final stopping = registry.deactivate('a');
    expect(registry.stateOf('a'), ModuleState.stopping);

    // Gegenrichtung reiht sich richtungsbewusst hinter der Deaktivierung ein.
    final restarting = registry.activate('a');

    // Zeitlich letzter Aufruf: alles stoppen. Das Modul ist im Uebergang
    // (stopping + gequeute Aktivierung) und darf nicht uebersprungen werden.
    final allStopped = registry.deactivateAll();

    stopGate.complete();
    await stopping;
    await restarting;
    await allStopped;

    expect(registry.stateOf('a'), ModuleState.stopped);
    expect(activator.log, ['start a', 'stop a', 'start a', 'stop a']);
  });
}
