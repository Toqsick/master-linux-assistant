import 'command_runner.dart';

/// Reads the CPU thread count through an injected [CommandRunner].
///
/// The cache is deliberately an instance field: the old `static int?` in
/// `lib/linux/linux_system.dart` was shared by the whole VM and could not be
/// isolated in a test. Two instances here share no cache.
class CpuInfo {
  CpuInfo({required CommandRunner runner}) : _runner = runner;

  final CommandRunner _runner;
  int? _cachedThreadCount;

  /// Runs `/usr/bin/nproc` and remembers the result for this instance.
  ///
  /// Throws [CommandException] when the run fails or its output is not a
  /// number, so a broken probe surfaces instead of masquerading as a count.
  Future<int> threadCount() async {
    final cached = _cachedThreadCount;
    if (cached != null) return cached;

    final result = await _runner.run('/usr/bin/nproc', const []);
    if (!result.success) {
      throw CommandException(
        'nproc failed',
        exitCode: result.exitCode,
        stderr: result.error,
      );
    }

    final count = int.tryParse(result.output.trim());
    if (count == null) {
      throw CommandException('nproc output is not a number: ${result.output}');
    }
    _cachedThreadCount = count;
    return count;
  }
}
