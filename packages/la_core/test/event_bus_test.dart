import 'package:la_core/la_core.dart';
import 'package:test/test.dart';

const Topic<int> _ints = Topic<int>('test.ints');
const Topic<String> _strings = Topic<String>('test.strings');

void main() {
  test('subscribe + publish erreicht den Listener', () {
    final bus = EventBus();
    final got = <int>[];
    bus.subscribe(_ints, got.add);

    bus.publish(_ints, 7);

    expect(got, [7]);
  });

  test('cancel() ist idempotent und stoppt die Zustellung', () {
    final bus = EventBus();
    final got = <int>[];
    final sub = bus.subscribe(_ints, got.add);

    bus.publish(_ints, 1);
    sub.cancel();
    sub.cancel(); // zweiter Aufruf ist kein Fehler
    bus.publish(_ints, 2);

    expect(got, [1]);
    expect(bus.subscriberCount, 0);
  });

  test('publish ohne Abonnenten ist ein No-Op', () {
    final bus = EventBus();
    expect(() => bus.publish(_ints, 1), returnsNormally);
  });

  test('verschiedene Topics bleiben getrennt', () {
    final bus = EventBus();
    final ints = <int>[];
    final strings = <String>[];
    bus.subscribe(_ints, ints.add);
    bus.subscribe(_strings, strings.add);

    bus.publish(_strings, 'x');

    expect(strings, ['x']);
    expect(ints, isEmpty);
  });

  test('werfender Listener -> onListenerError, die uebrigen laufen weiter', () {
    final errors = <Object>[];
    final bus = EventBus(onListenerError: (e, s) => errors.add(e));
    final got = <int>[];
    bus.subscribe(_ints, (v) => throw StateError('boom'));
    bus.subscribe(_ints, got.add);

    bus.publish(_ints, 1);

    expect(errors, hasLength(1));
    expect(errors.single, isA<StateError>());
    expect(got, [1]);
  });

  test('ohne onListenerError propagiert der Fehler', () {
    final bus = EventBus();
    bus.subscribe(_ints, (v) => throw StateError('boom'));

    expect(() => bus.publish(_ints, 1), throwsA(isA<StateError>()));
  });

  test('Nutzung nach dispose() wirft EventBusError', () {
    final bus = EventBus();
    bus.dispose();

    expect(() => bus.subscribe(_ints, (v) {}), throwsA(isA<EventBusError>()));
    expect(() => bus.publish(_ints, 1), throwsA(isA<EventBusError>()));
  });

  test('Listener, der sich waehrend publish abmeldet, verfaelscht die '
      'laufende Zustellung nicht', () {
    final bus = EventBus();
    final got = <int>[];
    late Subscription sub;
    sub = bus.subscribe(_ints, (v) {
      got.add(v);
      sub.cancel();
    });
    bus.subscribe(_ints, (v) => got.add(v * 10));

    bus.publish(_ints, 3);

    expect(got, [3, 30]);
  });

  test('subscriberCount zaehlt Abos ueber Topics hinweg', () {
    final bus = EventBus();
    expect(bus.subscriberCount, 0);

    final a = bus.subscribe(_ints, (v) {});
    final b = bus.subscribe(_strings, (v) {});
    expect(bus.subscriberCount, 2);

    a.cancel();
    expect(bus.subscriberCount, 1);
    b.cancel();
    expect(bus.subscriberCount, 0);
  });
}
