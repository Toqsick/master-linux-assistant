import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:linux_assistant/services/logger.dart';

/// Whether the system asks for a reboot, and which packages caused it.
///
/// Debian and Ubuntu write `/var/run/reboot-required` when a package upgrade
/// replaced something that is only replaceable with a restart, and
/// `/var/run/reboot-required.pkgs` with the list of packages that caused it.
/// Both files disappear after the reboot, which is exactly the behaviour the
/// dashboard badge needs: it is gone as soon as the machine was restarted.
@immutable
class RebootStatus {
  const RebootStatus({required this.required, this.packages = const []});

  /// The normal case: no reboot is pending.
  static const RebootStatus notRequired = RebootStatus(required: false);

  /// Whether the marker file exists.
  final bool required;

  /// The packages that triggered the reboot request. Empty when the marker
  /// exists but the package list is missing or unreadable — the reboot is
  /// still pending then, we just cannot name the cause.
  final List<String> packages;
}

/// Reads the "reboot required" marker files.
///
/// The parsing is a pure function ([parsePackages]) so it can be tested
/// without a file system; [readStatus] only does the I/O.
class RebootService {
  /// The marker file. `/var/run` is a symlink to `/run` on every current
  /// distribution, but not on every system, so both spellings are tried.
  static const List<String> markerPaths = [
    "/var/run/reboot-required",
    "/run/reboot-required",
  ];

  /// The package list that belongs to the marker file.
  static const List<String> packagePaths = [
    "/var/run/reboot-required.pkgs",
    "/run/reboot-required.pkgs",
  ];

  /// Parses the contents of `reboot-required.pkgs`.
  ///
  /// The file lists one package per line. Debian writes a header comment in
  /// some releases, and trailing blank lines are common — both are dropped,
  /// everything else is a package name.
  static List<String> parsePackages(String raw) {
    final packages = <String>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      packages.add(trimmed);
    }
    return packages;
  }

  /// Reads the marker and the package list.
  ///
  /// Never throws: a missing marker file means "no reboot pending", and an
  /// unreadable package list means "reboot pending, cause unknown". Both
  /// are answers the dashboard can show.
  static Future<RebootStatus> readStatus({
    List<String> markerPaths = RebootService.markerPaths,
    List<String> packagePaths = RebootService.packagePaths,
  }) async {
    final String? marker = _firstExisting(markerPaths);
    if (marker == null) {
      return RebootStatus.notRequired;
    }

    final String? packageFile = _firstExisting(packagePaths);
    if (packageFile == null) {
      logInfo("Reboot marker found, but no package list next to it.");
      return const RebootStatus(required: true);
    }

    try {
      final String raw = await File(packageFile).readAsString();
      return RebootStatus(required: true, packages: parsePackages(raw));
    } catch (e) {
      logError("Could not read $packageFile", e);
      return const RebootStatus(required: true);
    }
  }

  static String? _firstExisting(List<String> paths) {
    for (final path in paths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }
}
