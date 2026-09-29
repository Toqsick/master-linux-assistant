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

class _NoopActivator implements ModuleActivator {
  @override
  Future<void> start(ModuleDescriptor module) async {}

  @override
  Future<void> stop(ModuleDescriptor module) async {}
}

void main() {
  test('register wirft bei doppelter ID', () {
    final r = ModuleRegistry(activator: _NoopActivator());
    r.register(mod('a'));
    expect(
      () => r.register(mod('a')),
      throwsA(isA<ModuleRegistryError>()),
    );
  });

  test('validate wirft bei unbekannter Abhaengigkeit ghost', () {
    final r = ModuleRegistry(activator: _NoopActivator());
    r.register(mod('a', requires: {'ghost'}));
    expect(
      () => r.validate(),
      throwsA(
        isA<ModuleRegistryError>().having(
          (e) => e.message,
          'message',
          contains('ghost'),
        ),
      ),
    );
  });

  test('validate erkennt Zyklus a -> b -> a', () {
    final r = ModuleRegistry(activator: _NoopActivator());
    r.register(mod('a', requires: {'b'}));
    r.register(mod('b', requires: {'a'}));
    expect(
      () => r.validate(),
      throwsA(isA<ModuleRegistryError>()),
    );
  });

  test(
      'nach validate ist neue Registrierung moeglich und erneutes validate '
      'wirft nicht', () {
    final r = ModuleRegistry(activator: _NoopActivator());
    r.register(mod('a'));
    r.validate();
    r.register(mod('b'));
    expect(r.validate, returnsNormally);
  });
}
