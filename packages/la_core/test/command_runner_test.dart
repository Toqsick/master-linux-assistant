import 'package:la_core/la_core.dart';
import 'package:test/test.dart';

void main() {
  test('CommandResult: positionale Reihenfolge success/output/error', () {
    const r = CommandResult(true, 'out', 'err');
    expect(r.success, isTrue);
    expect(r.output, 'out');
    expect(r.error, 'err');
    // Default, damit Aufrufer ohne Exit-Code nicht brechen.
    expect(r.exitCode, 0);
  });

  test('CommandResult: expliziter Exit-Code bleibt erhalten', () {
    const r = CommandResult(false, '', 'boom', 127);
    expect(r.success, isFalse);
    expect(r.error, 'boom');
    expect(r.exitCode, 127);
  });

  test('CommandException traegt message/exitCode/stderr', () {
    final e = CommandException('nope', exitCode: 1, stderr: 'err');
    expect(e.message, 'nope');
    expect(e.exitCode, 1);
    expect(e.stderr, 'err');
    expect(e.toString(), contains('nope'));
  });

  test('CommandException: optionale Felder sind null', () {
    final e = CommandException('nope');
    expect(e.exitCode, isNull);
    expect(e.stderr, isNull);
  });
}
