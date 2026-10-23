import 'dart:convert';
import 'dart:io';

import 'package:linux_assistant/layouts/security_check/security_check_outcome.dart';
import 'package:linux_assistant/services/logger.dart';

/// The directory the app keeps its cached data in, below the XDG cache home.
const String kSecurityScanCacheDirectoryName = "linux-assistant";

/// The file the result of the last security scan is stored in.
const String kSecurityScanCacheFileName = "security-last.json";

/// The format version of the cache file.
///
/// A file with a different version is ignored rather than misread: the app
/// then shows "no result yet" instead of interpreting fields that mean
/// something else by now.
const int kSecurityScanCacheVersion = 1;

/// The result of one security scan, as it is kept between app runs.
///
/// The [tokens] are the checker's own lines — "firewallinactive",
/// "upgradeablepackage: foo-1.2", … — and not the sentences the UI shows.
/// The sentences are derived from the tokens again on every start, so a result
/// that was cached in German still reads correctly after the user switched the
/// app to Finnish.
class SecurityScanSnapshot {
  const SecurityScanSnapshot({required this.tokens, required this.timestamp});

  /// The checker's output lines, one finding per line.
  final List<String> tokens;

  /// When the scan ran.
  final DateTime timestamp;

  /// The cached result in the shape the checker's output has: one token per
  /// line. This is what the finding parser reads.
  String get output => tokens.join("\n");

  /// Takes the checker's raw stdout and keeps the finding lines.
  ///
  /// The success marker is not a finding and neither are blank lines; both
  /// would only make the cache bigger. Everything else is kept verbatim, so a
  /// checker that learns a new token does not need a change here.
  factory SecurityScanSnapshot.fromOutput(String output,
      {required DateTime timestamp}) {
    final List<String> tokens = <String>[];
    for (final String line in output.split("\n")) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty || trimmed == kSecurityCheckSuccessMarker) {
        continue;
      }
      tokens.add(trimmed);
    }
    return SecurityScanSnapshot(tokens: tokens, timestamp: timestamp);
  }

  /// The on-disk shape of a snapshot.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "version": kSecurityScanCacheVersion,
      // UTC, so the file stays readable after the user changes the timezone
      // or crosses a border.
      "timestamp": timestamp.toUtc().toIso8601String(),
      "tokens": tokens,
    };
  }

  /// Reads a snapshot back.
  ///
  /// Returns null for anything this build cannot make sense of: a truncated
  /// file, a foreign format, a version from the future, a timestamp that is
  /// not a timestamp. A cache is a convenience, never a reason to fail.
  static SecurityScanSnapshot? fromJson(Map<String, dynamic> json) {
    final Object? version = json["version"];
    if (version is! int || version != kSecurityScanCacheVersion) {
      return null;
    }

    final Object? rawTokens = json["tokens"];
    if (rawTokens is! List) {
      return null;
    }
    final List<String> tokens = <String>[];
    for (final Object? token in rawTokens) {
      if (token is! String) {
        return null;
      }
      tokens.add(token);
    }

    final Object? rawTimestamp = json["timestamp"];
    if (rawTimestamp is! String) {
      return null;
    }
    final DateTime? timestamp = DateTime.tryParse(rawTimestamp);
    if (timestamp == null) {
      return null;
    }

    return SecurityScanSnapshot(tokens: tokens, timestamp: timestamp);
  }
}

/// How coarse the age of a cached result is shown.
enum SecurityScanAgeUnit {
  /// Less than a minute old.
  justNow,

  minutes,
  hours,
  days,
}

/// The age of a cached result, rounded down to the unit the UI shows.
class SecurityScanAge {
  const SecurityScanAge(this.unit, this.count);

  final SecurityScanAgeUnit unit;

  /// How many of [unit] have passed. Always 0 for [SecurityScanAgeUnit.justNow].
  final int count;

  /// How old [timestamp] is, seen from [now].
  ///
  /// A timestamp in the future — a changed clock, a mixed-up timezone — counts
  /// as "just now" instead of producing a negative age.
  factory SecurityScanAge.between(DateTime timestamp, DateTime now) {
    final Duration age = now.difference(timestamp);
    if (age.isNegative || age.inMinutes < 1) {
      return const SecurityScanAge(SecurityScanAgeUnit.justNow, 0);
    }
    if (age.inHours < 1) {
      return SecurityScanAge(SecurityScanAgeUnit.minutes, age.inMinutes);
    }
    if (age.inHours < 24) {
      return SecurityScanAge(SecurityScanAgeUnit.hours, age.inHours);
    }
    return SecurityScanAge(SecurityScanAgeUnit.days, age.inDays);
  }
}

/// The last scan result on disk.
///
/// The location follows the XDG base directory spec: `$XDG_CACHE_HOME` when it
/// is set, otherwise `~/.cache`. The file is a cache, not configuration: it
/// may be deleted at any time, and the app has to survive its absence.
class SecurityScanCache {
  SecurityScanCache({Directory? directory})
      : _directory = directory ?? defaultDirectory();

  final Directory _directory;

  /// The directory the cache file lives in.
  Directory get directory => _directory;

  /// The file the result is stored in.
  File get file => File("${_directory.path}/$kSecurityScanCacheFileName");

  /// `$XDG_CACHE_HOME/linux-assistant`, or `~/.cache/linux-assistant` when the
  /// variable is unset or empty.
  static Directory defaultDirectory({Map<String, String>? environment}) {
    final Map<String, String> env = environment ?? Platform.environment;
    final String? xdg = env["XDG_CACHE_HOME"];
    final String base = (xdg != null && xdg.trim().isNotEmpty)
        ? xdg.trim()
        : "${env["HOME"] ?? "."}/.cache";
    return Directory("$base/$kSecurityScanCacheDirectoryName");
  }

  /// The stored result, or null when there is none or it is unusable.
  ///
  /// Never throws: a broken cache file must not keep the page from opening —
  /// the user can always run a new scan.
  Future<SecurityScanSnapshot?> read() async {
    try {
      final File cacheFile = file;
      if (!await cacheFile.exists()) {
        return null;
      }
      final String content = await cacheFile.readAsString();
      if (content.trim().isEmpty) {
        return null;
      }
      final Object? decoded = jsonDecode(content);
      if (decoded is! Map) {
        return null;
      }
      return SecurityScanSnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } catch (error) {
      logError("Could not read the cached security scan", error);
      return null;
    }
  }

  /// Stores [snapshot] and replaces the previous result.
  ///
  /// Written to a sibling first and renamed afterwards: an app that dies
  /// mid-write must not leave a half-written file behind that no longer
  /// parses. A cache that cannot be written is not worth an error dialog —
  /// the scan itself already worked.
  Future<void> write(SecurityScanSnapshot snapshot) async {
    try {
      await _directory.create(recursive: true);
      final String content = jsonEncode(snapshot.toJson());
      final File temporary =
          File("${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp");
      await temporary.writeAsString(content, flush: true);
      await temporary.rename(file.path);
    } catch (error) {
      logError("Could not write the cached security scan", error);
    }
  }
}
