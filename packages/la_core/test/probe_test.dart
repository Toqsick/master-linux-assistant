import 'package:la_core/la_core.dart';
import 'package:test/test.dart';

void main() {
  test('ProbeResult.describe enthaelt Level und Key', () {
    const r = ProbeResult(level: ProbeSeverity.warn, key: 'mem.free');
    expect(r.describe(), startsWith('warn:mem.free'));
  });

  test('ProbeSeverity deckt ok/warn/crit/unknown ab', () {
    expect(
      ProbeSeverity.values.map((l) => l.name),
      containsAll(<String>['ok', 'warn', 'crit', 'unknown']),
    );
  });

  test('SelfProbe liefert ok mit key probe.self', () async {
    final r = await SelfProbe().run();
    expect(r.level, ProbeSeverity.ok);
    expect(r.key, 'probe.self');
  });
}
