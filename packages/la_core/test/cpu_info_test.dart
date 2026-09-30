import 'package:la_core/la_core.dart';
import 'package:test/test.dart';

/// Fake runner: counts calls and replays a canned [CommandResult].
class _CountingRunner implements CommandRunner {
  _CountingRunner(this.result);

  final CommandResult result;
  int calls = 0;
  String? lastCommand;
  List<String>? lastArguments;

  @override
  Future<CommandResult> run(
    String command,
    List<String> arguments, {
    Map<String, String>? environment,
    bool asRoot = false,
    bool hostOnFlatpak = true,
    bool runInShell = false,
  }) async {
    calls++;
    lastCommand = command;
    lastArguments = arguments;
    return result;
  }
}

void main() {
  test('zwei Aufrufe an derselben Instanz = genau EIN Runner-Aufruf', () async {
    final runner = _CountingRunner(const CommandResult(true, '8\n', ''));
    final cpu = CpuInfo(runner: runner);

    expect(await cpu.threadCount(), 8);
    expect(await cpu.threadCount(), 8);
    expect(runner.calls, 1);
    expect(runner.lastCommand, '/usr/bin/nproc');
  });

  test('zwei Instanzen teilen KEINEN Cache', () async {
    final runner = _CountingRunner(const CommandResult(true, '4', ''));
    final a = CpuInfo(runner: runner);
    final b = CpuInfo(runner: runner);

    expect(await a.threadCount(), 4);
    expect(await b.threadCount(), 4);
    expect(runner.calls, 2);
  });

  test('fehlgeschlagener Lauf wirft CommandException', () async {
    final runner = _CountingRunner(const CommandResult(false, '', 'nope', 1));
    final cpu = CpuInfo(runner: runner);

    await expectLater(
      cpu.threadCount(),
      throwsA(isA<CommandException>().having((e) => e.exitCode, 'exitCode', 1)),
    );
  });

  test('unparsbare Ausgabe wirft CommandException', () async {
    final runner = _CountingRunner(const CommandResult(true, 'keine Zahl', ''));
    final cpu = CpuInfo(runner: runner);

    await expectLater(cpu.threadCount(), throwsA(isA<CommandException>()));
  });
}
