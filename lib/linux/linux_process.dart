import 'package:la_core/la_core.dart' as core;
import 'package:linux_assistant/services/linux.dart';

export 'package:la_core/la_core.dart' show ProcessStat;

abstract class LinuxProcess {
  static Future<List<core.ProcessStat>> _getTopProcesses(
      String metric, int count) async {
    var cmdResult = await Linux.runCommandWithCustomArguments(
        "/usr/bin/ps", ["-eo", "$metric,args", "--sort=-$metric"]);

    return parsePsOutput(cmdResult, count);
  }

  /// Delegates to the pure parser in `la_core` (#93).
  ///
  /// Lines that carry a metric but no command are skipped rather than throwing;
  /// `ps` emits those for kernel threads on some systems.
  static List<core.ProcessStat> parsePsOutput(String cmdResult, int count) =>
      core.parsePsOutput(cmdResult, count);

  static Future<int> processCount() async {
    var cmdResult =
        await Linux.runCommandWithCustomArguments("/usr/bin/ps", ["-e"]);

    return cmdResult.split("\n").skip(1).length;
  }

  static Future<List<core.ProcessStat>> topProcessesByCpu(int count) async =>
      await _getTopProcesses("pcpu", count);

  static Future<List<core.ProcessStat>> topProcessesByMemory(int count) async =>
      await _getTopProcesses("pmem", count);

  static Future<int> zombieCount() async {
    var cmdResult = await Linux.runCommandWithCustomArguments(
        "/usr/bin/ps", ["-eo", "stat"]);

    return cmdResult.split("\n").where((x) => x.trim() == "Z").length;
  }
}
