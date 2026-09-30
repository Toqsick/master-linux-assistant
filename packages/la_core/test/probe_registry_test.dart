import 'package:la_core/la_core.dart';
import 'package:test/test.dart';

class _FakeProbe implements Probe {
  _FakeProbe(this.id, {this.result});

  @override
  final String id;
  final ProbeResult? result;
  int runs = 0;

  @override
  Future<ProbeResult> run() async {
    runs++;
    return result ?? ProbeResult(level: ProbeSeverity.ok, key: id);
  }
}

class _RecordingLogger implements CoreLogger {
  final List<String> log = [];

  @override
  void debug(String message) => log.add('debug:$message');

  @override
  void info(String message) => log.add('info:$message');

  @override
  void warn(String message, [Object? error]) => log.add('warn:$message');

  @override
  void error(String message, [Object? error, StackTrace? stack]) =>
      log.add('error:$message');
}

void main() {
  test('register wirft bei doppelter id', () {
    final registry = ProbeRegistry(bus: EventBus());
    registry.register(_FakeProbe('probe.x'));
    expect(
      () => registry.register(_FakeProbe('probe.x')),
      throwsA(isA<ProbeRegistryError>()),
    );
  });

  test('probe(unbekannt) wirft ProbeRegistryError', () {
    final registry = ProbeRegistry(bus: EventBus());
    expect(() => registry.probe('ghost'), throwsA(isA<ProbeRegistryError>()));
  });

  test('run(unbekannt) wirft ProbeRegistryError', () async {
    final registry = ProbeRegistry(bus: EventBus());
    await expectLater(
      registry.run('ghost'),
      throwsA(isA<ProbeRegistryError>()),
    );
  });

  test('run(id) publiziert genau ein ProbeResult und protokolliert', () async {
    final bus = EventBus();
    final published = <ProbeResult>[];
    bus.subscribe(CoreTopics.probeResult, published.add);

    final logger = _RecordingLogger();
    final registry = ProbeRegistry(bus: bus, logger: logger);
    final probe = _FakeProbe(
      'probe.x',
      result: const ProbeResult(level: ProbeSeverity.warn, key: 'probe.x'),
    );
    registry.register(probe);

    final result = await registry.run('probe.x');

    expect(result.level, ProbeSeverity.warn);
    expect(probe.runs, 1);
    expect(published, hasLength(1));
    expect(published.single.key, 'probe.x');
    expect(logger.log, isNotEmpty);
    expect(logger.log.any((entry) => entry.contains('probe.x')), isTrue);
  });

  test('NullLogger ist der Default und die Probe laeuft trotzdem', () async {
    final bus = EventBus();
    final published = <ProbeResult>[];
    bus.subscribe(CoreTopics.probeResult, published.add);

    final registry = ProbeRegistry(bus: bus);
    registry.register(_FakeProbe('probe.y'));

    final result = await registry.run('probe.y');

    expect(result.key, 'probe.y');
    expect(published, hasLength(1));
  });
}
