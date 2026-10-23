import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:linux_assistant/helpers/command_helper.dart';
import 'package:linux_assistant/services/linux.dart';
import 'package:linux_assistant/services/logger.dart';

/// Which systemd manager a failed unit belongs to.
///
/// A desktop has two: the system manager (root, `systemctl`) and the user
/// manager (`systemctl --user`). Both can hold failed units, and a service
/// that only lives in the user manager is invisible to the system one.
enum FailedUnitScope { system, user }

/// One failed systemd unit.
@immutable
class FailedUnit {
  const FailedUnit({
    required this.unit,
    required this.description,
    required this.scope,
  });

  /// The unit name, e.g. `restic-backup.service`.
  final String unit;

  /// The unit's description, e.g. "Backup and restore service". May be empty
  /// — systemd leaves the field out for units without a description.
  final String description;

  /// Which manager reported the unit.
  final FailedUnitScope scope;
}

/// Collects the failed systemd units of both scopes.
///
/// The list changes far more slowly than the CPU numbers, so this polls on
/// its own slow timer instead of riding on the three-second stats poll —
/// two `systemctl` calls per tick would be a lot of process spawns for a
/// number that usually stays at zero.
class FailedUnitsService {
  static final FailedUnitsService _instance = FailedUnitsService._();

  factory FailedUnitsService() => _instance;

  FailedUnitsService._();

  /// How often the failed units are re-read while a consumer is listening.
  static const Duration defaultInterval = Duration(seconds: 30);

  /// `systemctl` is always in `/usr/bin` on a systemd system.
  static const String systemctlPath = "/usr/bin/systemctl";

  final ValueNotifier<List<FailedUnit>?> units =
      ValueNotifier<List<FailedUnit>?>(null);

  Duration interval = defaultInterval;

  Timer? _timer;
  int _subscribers = 0;

  /// Both default to true so that a consumer outside the hub keeps working
  /// without opting in. The hub sets them to false as soon as the dashboard
  /// is not the section on screen.
  bool _sectionActive = true;
  bool _windowVisible = true;

  /// Guards against overlapping reads: `systemctl` on a busy system can take
  /// longer than the interval, and stacked runs would pile up.
  bool _reading = false;

  @visibleForTesting
  int get subscriberCount => _subscribers;

  /// Read-only view of the section flag, so the coupling between the hub
  /// and this service can be asserted without running `systemctl`.
  @visibleForTesting
  bool get sectionActive => _sectionActive;

  bool get _shouldPoll => _subscribers > 0 && _sectionActive && _windowVisible;

  /// Registers interest. The first subscriber triggers an immediate read.
  void acquire() {
    _subscribers++;
    _sync();
  }

  /// Drops interest. The last release stops the timer.
  void release() {
    if (_subscribers == 0) {
      return;
    }
    _subscribers--;
    _sync();
  }

  /// Whether the view on screen shows the failed units at all.
  void setSectionActive(bool active) {
    if (_sectionActive == active) {
      return;
    }
    _sectionActive = active;
    _sync();
  }

  /// Whether the window is on screen.
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
        _timer = Timer.periodic(interval, (_) => refresh());
        refresh();
      }
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Re-reads both scopes and publishes the result.
  ///
  /// A scope that cannot be read (no systemd, no user session) contributes an
  /// empty list instead of failing the whole read: half an answer is better
  /// than none, and the tile says what it knows.
  Future<void> refresh() async {
    if (_reading) {
      return;
    }
    _reading = true;
    try {
      final system = await _readScope(FailedUnitScope.system);
      final user = await _readScope(FailedUnitScope.user);
      units.value = [...system, ...user];
    } catch (e) {
      logError("Could not read the failed systemd units", e);
    } finally {
      _reading = false;
    }
  }

  Future<List<FailedUnit>> _readScope(FailedUnitScope scope) async {
    final List<String> args = scope == FailedUnitScope.user
        ? ["--user", "list-units", "--failed", "-o", "json"]
        : ["list-units", "--failed", "-o", "json"];

    final CommandResult result = await Linux.runProcess(
      systemctlPath,
      args,
      // The C locale keeps the JSON keys and the unit names untranslated.
      environment: {"LC_ALL": "C"},
      runInShell: false,
    );

    if (!result.success) {
      logInfo("systemctl (${scope.name}) did not answer: ${result.error}");
      return const [];
    }

    return parseUnitsJson(result.output, scope);
  }

  /// Parses the JSON of `systemctl list-units --failed -o json`.
  ///
  /// systemd writes `{"units": [ … ]}`; the array alone is accepted as well,
  /// because that is what the `--output=json` of some other tools produces
  /// and a defensive parser costs nothing here.
  static List<FailedUnit> parseUnitsJson(String raw, FailedUnitScope scope) {
    if (raw.trim().isEmpty) {
      return const [];
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      logError("systemctl did not return valid JSON", e);
      return const [];
    }

    List<Object?> entries = const [];
    if (decoded is List) {
      entries = decoded;
    } else if (decoded is Map) {
      final Object? units = decoded["units"];
      if (units is List) {
        entries = units;
      }
    }

    final failed = <FailedUnit>[];
    for (final entry in entries) {
      if (entry is! Map) {
        continue;
      }
      final String unit = (entry["unit"] ?? "").toString().trim();
      if (unit.isEmpty) {
        continue;
      }
      final String description = (entry["description"] ?? "").toString().trim();
      failed.add(
        FailedUnit(unit: unit, description: description, scope: scope),
      );
    }
    return failed;
  }

  /// Test seam: drops all state and stops the timer.
  @visibleForTesting
  void resetForTesting({List<FailedUnit>? seed}) {
    _timer?.cancel();
    _timer = null;
    _subscribers = 0;
    _sectionActive = true;
    _windowVisible = true;
    _reading = false;
    units.value = seed;
  }
}
