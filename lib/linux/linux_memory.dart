import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:linux_assistant/services/logger.dart';

/// How hard the memory is under pressure right now.
enum MemoryPressureLevel {
  /// The kernel does not report the pressure (no PSI support).
  unknown,

  /// Some tasks waited for memory, but rarely and briefly.
  normal,

  /// Waiting for memory is measurable.
  elevated,

  /// Waiting for memory dominates — the machine is thrashing.
  high,
}

/// The memory pressure the kernel reports through PSI
/// (`/proc/pressure/memory`).
///
/// PSI is the honest answer to "is the memory tight": the share of the last
/// 60 seconds in which at least one task had to wait for memory. The RAM
/// quote says nothing about that — a machine can be at 30 % RAM usage and
/// still be swapping badly, and it can be at 95 % RAM usage and completely
/// relaxed.
@immutable
class MemoryPressure {
  const MemoryPressure({
    required this.someAvg60,
    required this.fullAvg60,
    required this.level,
  });

  /// `some avg60` — the share of the last minute in which at least one task
  /// was stalled on memory.
  final double someAvg60;

  /// `full avg60` — the share of the last minute in which *all* tasks were
  /// stalled on memory. Much rarer, and much worse.
  final double fullAvg60;

  final MemoryPressureLevel level;
}

/// The zram device's accounting numbers.
///
/// zram is a compressed RAM disk: the swap data is 7.2 GB in its
/// uncompressed form and occupies 2.1 GB of the real disk. Reporting it as
/// one number ("swap: 7.2 GB of 16 GB") would hide the compression, so the
/// two sizes are kept apart.
@immutable
class ZramInfo {
  const ZramInfo({
    required this.devices,
    required this.originalBytes,
    required this.compressedBytes,
    required this.capacityBytes,
  });

  /// The zram devices that were found, e.g. `["zram0"]`.
  final List<String> devices;

  /// `orig_data_size` — the size the stored data has in its uncompressed
  /// form.
  final int originalBytes;

  /// `compr_data_size` — the size the stored data occupies after
  /// compression.
  final int compressedBytes;

  /// `disksize` — the size the device would take on the disk.
  final int capacityBytes;

  /// The data that is actually stored, in its uncompressed size.
  int get usedBytes => originalBytes;
}

/// Reads the memory pressure and the zram accounting from procfs and sysfs.
///
/// The parsing functions are pure, so the thresholds and the number formats
/// can be tested without a machine that has PSI or zram.
abstract class LinuxMemory {
  /// `/proc/pressure/memory` — the PSI lines for memory.
  static const String pressurePath = "/proc/pressure/memory";

  /// The block devices directory; the zram devices live in it.
  static const String blockDevicePath = "/sys/block";

  /// From this share of stalled time on, the pressure counts as elevated.
  static const double elevatedThreshold = 5.0;

  /// From this share of stalled time on, the pressure counts as high.
  static const double highThreshold = 15.0;

  /// `full avg60` is much rarer than `some avg60`; this share of it is
  /// already "high", because at that point every task waits.
  static const double fullHighThreshold = 5.0;

  /// Reads `/proc/pressure/memory`.
  ///
  /// Returns null when the kernel does not provide PSI (CONFIG PSI off) or
  /// the file cannot be read. The caller then knows nothing about the
  /// pressure instead of knowing "0 %".
  static Future<MemoryPressure?> memoryPressure() async {
    try {
      final String raw = await File(pressurePath).readAsString();
      return parsePressure(raw);
    } catch (e) {
      logInfo("No memory pressure information available: $e");
      return null;
    }
  }

  /// Parses the contents of `/proc/pressure/memory`.
  ///
  /// The file has two lines:
  ///
  /// ```
  /// some avg10=0.00 avg60=0.00 avg300=0.00 total=0
  /// full avg10=0.00 avg60=0.00 avg300=0.00 total=0
  /// ```
  ///
  /// `some` counts the time in which at least one task waited for memory,
  /// `full` the time in which all of them waited. Only `avg60` is read — it
  /// is the window a human can act on.
  static MemoryPressure? parsePressure(String raw) {
    double? some;
    double? full;

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final List<String> fields = trimmed.split(RegExp(r'\s+'));
      final String kind = fields.first;
      if (kind != "some" && kind != "full") {
        continue;
      }
      final double? avg60 = _readAvg60(fields);
      if (avg60 == null) {
        continue;
      }
      if (kind == "some") {
        some = avg60;
      } else {
        full = avg60;
      }
    }

    if (some == null && full == null) {
      return null;
    }

    final double someValue = some ?? 0;
    final double fullValue = full ?? 0;

    return MemoryPressure(
      someAvg60: someValue,
      fullAvg60: fullValue,
      level: levelFor(someAvg60: someValue, fullAvg60: fullValue),
    );
  }

  /// Turns the two PSI figures into a level.
  static MemoryPressureLevel levelFor({
    required double someAvg60,
    required double fullAvg60,
  }) {
    if (someAvg60 >= highThreshold || fullAvg60 >= fullHighThreshold) {
      return MemoryPressureLevel.high;
    }
    if (someAvg60 >= elevatedThreshold) {
      return MemoryPressureLevel.elevated;
    }
    return MemoryPressureLevel.normal;
  }

  static double? _readAvg60(List<String> fields) {
    for (final field in fields.skip(1)) {
      if (!field.startsWith("avg60=")) {
        continue;
      }
      return double.tryParse(field.substring("avg60=".length));
    }
    return null;
  }

  /// Reads the zram devices of this machine.
  ///
  /// Returns null when the machine has no zram device at all.
  static Future<ZramInfo?> zramInfo() async {
    final List<String> devices;
    try {
      devices = Directory(blockDevicePath)
          .listSync()
          .whereType<Directory>()
          .map((dir) => dir.path.split('/').last)
          .where((name) => name.startsWith("zram"))
          .toList()
        ..sort();
    } catch (e) {
      logInfo("Could not read $blockDevicePath: $e");
      return null;
    }

    if (devices.isEmpty) {
      return null;
    }

    int original = 0;
    int compressed = 0;
    int capacity = 0;
    var found = false;

    for (final device in devices) {
      final String base = "$blockDevicePath/$device";
      final mmStat = await _readFile("$base/mm_stat");
      final diskSize = await _readFile("$base/disksize");
      if (mmStat == null && diskSize == null) {
        continue;
      }
      found = true;
      if (mmStat != null) {
        final sizes = parseZramMmStat(mmStat);
        original += sizes?.$1 ?? 0;
        compressed += sizes?.$2 ?? 0;
      }
      // disksize is optional: a zram device that is not readable yet still
      // counts towards the compressed sizes, it just has no capacity.
      if (diskSize != null) {
        capacity += parseZramDiskSize(diskSize) ?? 0;
      }
    }

    if (!found) {
      return null;
    }

    return ZramInfo(
      devices: devices,
      originalBytes: original,
      compressedBytes: compressed,
      capacityBytes: capacity,
    );
  }

  /// Parses `/sys/block/zram*/mm_stat`.
  ///
  /// The first two numbers are the interesting ones: the size of the stored
  /// data before compression and after it. The rest is the kernel's internal
  /// bookkeeping and is ignored.
  static (int, int)? parseZramMmStat(String raw) {
    final List<String> fields = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((field) => field.isNotEmpty)
        .toList();
    if (fields.length < 2) {
      return null;
    }
    final int? original = int.tryParse(fields[0]);
    final int? compressed = int.tryParse(fields[1]);
    if (original == null || compressed == null) {
      return null;
    }
    return (original, compressed);
  }

  /// Parses `/sys/block/zram*/disksize` — the size the device reserves on
  /// the disk, in bytes.
  static int? parseZramDiskSize(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }

  static Future<String?> _readFile(String path) async {
    try {
      return await File(path).readAsString();
    } catch (e) {
      logInfo("Could not read $path: $e");
      return null;
    }
  }
}
