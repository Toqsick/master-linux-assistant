import 'dart:async';

import 'package:flutter/foundation.dart';
// `MemoryInfo` now lives in the Flutter-free core (#93); the import puts it in
// this library's own scope, the export keeps `package:linux_assistant/...` a
// working entry point for it (an export alone does not import).
import 'package:la_core/la_core.dart' show MemoryInfo;
import 'package:linux_assistant/linux/linux_filesystem.dart';
import 'package:linux_assistant/linux/linux_process.dart';
import 'package:linux_assistant/linux/linux_system.dart';
import 'package:linux_assistant/services/linux.dart';

export 'package:la_core/la_core.dart' show MemoryInfo;

/// One snapshot of the machine's state.
@immutable
class SystemStats {
  /// CPU load over the last minute, normalized by thread count. 0.0 to ~1.0,
  /// but can exceed 1.0 on an overloaded machine.
  final double cpuLoad;
  final MemoryInfo? memory;
  final List<DeviceInfo> disks;
  final int processCount;
  final int zombieCount;
  final List<ProcessStat> topByCpu;
  final List<ProcessStat> topByMemory;
  final Uptime? uptime;

  /// Rolling history for sparklines, oldest first.
  final List<double> cpuHistory;
  final List<double> memoryHistory;

  /// Null until the first successful poll.
  final DateTime? updatedAt;

  /// Set when the last poll threw, so the UI can show stale data honestly
  /// rather than silently freezing.
  final String? error;

  const SystemStats({
    this.cpuLoad = 0,
    this.memory,
    this.disks = const [],
    this.processCount = 0,
    this.zombieCount = 0,
    this.topByCpu = const [],
    this.topByMemory = const [],
    this.uptime,
    this.cpuHistory = const [],
    this.memoryHistory = const [],
    this.updatedAt,
    this.error,
  });

  bool get hasData => updatedAt != null;
}

/// Polls the system once per interval and shares the result with every widget
/// that needs it.
///
/// Each dashboard tile used to own a `Timer.periodic` that called `setState`
/// with an empty body, which re-ran the tile's `Future` and forked `df`, `ps`
/// or `free` again. With eight tiles on screen that is eight process spawns per
/// tick. This service polls once and notifies listeners.
///
/// Polling only runs while it is actually worth something. Three conditions
/// have to hold at once:
///
/// * at least one widget has [acquire]d,
/// * the section on screen consumes stats ([setSectionActive]), and
/// * the window is visible ([setWindowVisible]).
///
/// The reference count alone is not enough. The hub keeps every visited section
/// alive inside an `IndexedStack`, so those widgets are never disposed and
/// [release] is never reached — without the two flags the timer would keep
/// forking eight processes every three seconds for as long as the app is open,
/// minimized or not.
class SystemStatsService {
  static final SystemStatsService _instance = SystemStatsService._();

  factory SystemStatsService() => _instance;

  SystemStatsService._();

  static const int historyLength = 60;
  static const Duration defaultInterval = Duration(seconds: 3);

  final ValueNotifier<SystemStats> stats =
      ValueNotifier<SystemStats>(const SystemStats());

  Duration interval = defaultInterval;

  Timer? _timer;
  int _subscribers = 0;

  /// Both default to true so that consumers outside the hub — the launcher's
  /// `SystemStatus` row, for instance — keep working without opting in.
  bool _sectionActive = true;
  bool _windowVisible = true;

  /// Guards against overlapping polls: on a busy machine `ps` can take longer
  /// than the interval, and stacking runs would make it worse.
  bool _polling = false;

  bool get isRunning => _timer != null;

  bool get _shouldPoll => _subscribers > 0 && _sectionActive && _windowVisible;

  @visibleForTesting
  int get subscriberCount => _subscribers;

  /// Registers interest.
  void acquire() {
    _subscribers++;
    _sync();
  }

  /// Drops interest.
  void release() {
    if (_subscribers == 0) {
      return;
    }
    _subscribers--;
    _sync();
  }

  /// Whether the view on screen displays system stats at all. The security and
  /// search sections do not, and polling for them is pure waste.
  void setSectionActive(bool active) {
    if (_sectionActive == active) {
      return;
    }
    _sectionActive = active;
    _sync();
  }

  /// Whether the window is on screen. Set from the hub's window listener.
  void setWindowVisible(bool visible) {
    if (_windowVisible == visible) {
      return;
    }
    _windowVisible = visible;
    _sync();
  }

  void _sync() {
    if (_shouldPoll) {
      if (_timer == null) {
        _start();
      }
    } else {
      _stop();
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => refresh());
    // Don't make the first tile wait a full interval for content — this also
    // covers coming back from a minimized window, where the last snapshot is
    // as old as the time spent away.
    refresh();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Collects a fresh snapshot. Safe to call directly for a manual reload.
  Future<void> refresh() async {
    if (_polling) {
      return;
    }
    _polling = true;
    final previous = stats.value;
    try {
      final results = await Future.wait<Object?>([
        LinuxSystem.getCpuAverageLoad(),
        // No shell: this runs every three seconds, and with `runInShell` the
        // call forks a shell in addition to `free` itself.
        Linux.runCommandWithCustomArguments("free", ["-m"],
            hostOnFlatpak: false, runInShell: false),
        LinuxFilesystem.disks(),
        LinuxProcess.processCount(),
        LinuxProcess.zombieCount(),
        LinuxProcess.topProcessesByCpu(5),
        LinuxProcess.topProcessesByMemory(5),
        _uptimeOrNull(),
      ]);

      final cpuLoad = results[0] as double;
      final memory = MemoryInfo.parseFreeOutput(results[1] as String);

      stats.value = SystemStats(
        cpuLoad: cpuLoad,
        memory: memory ?? previous.memory,
        disks: results[2] as List<DeviceInfo>,
        processCount: results[3] as int,
        zombieCount: results[4] as int,
        topByCpu: results[5] as List<ProcessStat>,
        topByMemory: results[6] as List<ProcessStat>,
        uptime: results[7] as Uptime? ?? previous.uptime,
        cpuHistory: _appendToHistory(previous.cpuHistory, cpuLoad),
        memoryHistory: _appendToHistory(
          previous.memoryHistory,
          (memory ?? previous.memory)?.usedRatio ?? 0,
        ),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      // Keep the last good snapshot visible and record why it stopped updating.
      stats.value = SystemStats(
        cpuLoad: previous.cpuLoad,
        memory: previous.memory,
        disks: previous.disks,
        processCount: previous.processCount,
        zombieCount: previous.zombieCount,
        topByCpu: previous.topByCpu,
        topByMemory: previous.topByMemory,
        uptime: previous.uptime,
        cpuHistory: previous.cpuHistory,
        memoryHistory: previous.memoryHistory,
        updatedAt: previous.updatedAt,
        error: e.toString(),
      );
    } finally {
      _polling = false;
    }
  }

  /// `uptime` parsing is brittle across distributions, and a single tile is not
  /// worth failing the whole snapshot for.
  Future<Uptime?> _uptimeOrNull() async {
    try {
      return await LinuxSystem.uptime();
    } catch (_) {
      return null;
    }
  }

  static List<double> _appendToHistory(List<double> history, double value) {
    final next = List<double>.from(history)..add(value);
    if (next.length > historyLength) {
      next.removeRange(0, next.length - historyLength);
    }
    return next;
  }

  /// Test seam: drops all state and stops any timer.
  @visibleForTesting
  void resetForTesting({SystemStats? seed}) {
    _stop();
    _subscribers = 0;
    _sectionActive = true;
    _windowVisible = true;
    _polling = false;
    stats.value = seed ?? const SystemStats();
  }
}
