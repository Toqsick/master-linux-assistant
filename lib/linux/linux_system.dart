import 'dart:io';

import 'package:la_core/la_core.dart' as core;
import 'package:linux_assistant/helpers/command_helper.dart';
import 'package:linux_assistant/services/logger.dart';

export 'package:la_core/la_core.dart' show Uptime;

abstract class LinuxSystem {
  static Future<bool> hasSwap() async {
    var cmdResult =
        await CommandHelper.run("/usr/bin/free", env: {"LC_ALL": "C"});
    if (!cmdResult.success) {
      throw Exception(cmdResult.error);
    }

    return cmdResult.output.toLowerCase().contains("swap");
  }

  /// Might be inaccurate
  static Future<core.Uptime> uptime() async {
    var cmdResult =
        await CommandHelper.run("/usr/bin/uptime", env: {"LC_ALL": "C"});

    if (!cmdResult.success) {
      throw Exception(cmdResult.output);
    }

    return parseUptime(cmdResult.output);
  }

  /// Delegates to the pure parser in `la_core` (#93).
  static core.Uptime parseUptime(String output) => core.parseUptime(output);

  /// Cached: the CPU thread count cannot change while the app is running, and
  /// the polling dashboard would otherwise fork `nproc` on every tick.
  static int? _cachedThreadCount;

  static Future<int> getCpuThreadCount() async {
    final cached = _cachedThreadCount;
    if (cached != null) {
      return cached;
    }
    var cmdResult = await CommandHelper.run("/usr/bin/nproc");
    if (!cmdResult.success) {
      logError("Command failed", cmdResult.error);
    }
    final count = int.parse(cmdResult.output);
    _cachedThreadCount = count;
    return count;
  }

  /// Returns the average load of the CPU of the last minute
  /// Values are between 0 and 1
  ///
  /// Read straight from procfs rather than through `cat`: this runs on every
  /// poll tick, and forking a process to read a virtual file is the kind of
  /// cost that only shows up as battery drain.
  static Future<double> getCpuAverageLoad() async {
    final double load =
        parseLoadAvg(await File("/proc/loadavg").readAsString());
    int cpuCount = await getCpuThreadCount();
    return load / cpuCount;
  }

  /// Delegates to the pure parser in `la_core` (#93): the one-minute figure
  /// from the first column of `/proc/loadavg`.
  static double parseLoadAvg(String content) => core.parseLoadAvg(content);
}
