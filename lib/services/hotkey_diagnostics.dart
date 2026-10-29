import 'dart:convert';

import 'package:linux_assistant/helpers/command_helper.dart';
import 'package:linux_assistant/services/linux.dart';
import 'package:linux_assistant/services/logger.dart';

/// One orphaned `custom*` entry of the desktop's keybinding list.
///
/// "Orphan" means: the entry belongs to this app — its command is
/// `linux-assistant` — but it is not the entry that is live right now. That
/// happens when the binding was moved (the modifier changed from `<Super>` to
/// `<Alt>`, for example) or when an older setup run left a duplicate behind.
/// The desktop keeps both, and both fire the app.
class HotkeyOrphan {
  const HotkeyOrphan({required this.path, required this.binding});

  /// The gsettings path of the entry, for example
  /// `/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/`.
  final String path;

  /// The key combination the entry is bound to, for example `<Super>q`.
  final String binding;

  factory HotkeyOrphan.fromJson(Map<String, dynamic> json) {
    return HotkeyOrphan(
      path: _asString(json["path"]),
      binding: _asString(json["binding"]),
    );
  }

  @override
  String toString() => "HotkeyOrphan(path: $path, binding: $binding)";
}

/// What the desktop says about this app's own keyboard shortcut.
///
/// The desktop's settings are the only source that can answer whether the
/// shortcut is really there: the app itself no longer grabs the key, so it
/// cannot know what the desktop did with it.
class HotkeyReport {
  const HotkeyReport({
    required this.desktop,
    required this.session,
    required this.binding,
    required this.registered,
    required this.orphans,
    this.error,
  });

  /// The desktop the report was taken on: `gnome`, `cinnamon`, `xfce`, `kde`
  /// or `unknown`.
  final String desktop;

  /// The session type: `wayland`, `x11` or `unknown`.
  final String session;

  /// The key combination the shortcut is bound to, for example `<Super>q`.
  final String binding;

  /// Whether the desktop currently holds our shortcut.
  final bool registered;

  /// The `custom*` entries that point at this app but are not the live one.
  final List<HotkeyOrphan> orphans;

  /// Why the report could not be read. Null when it could.
  final String? error;

  /// Whether the report is a failure report rather than a real one.
  bool get hasError => error != null;

  /// The report of a run that did not produce a usable answer.
  ///
  /// A diagnostic that throws takes the page it is shown on down with it, so
  /// every failure ends up here instead: not registered, and a reason.
  factory HotkeyReport.unavailable(String error) {
    return HotkeyReport(
      desktop: "unknown",
      session: "unknown",
      binding: "",
      registered: false,
      orphans: const [],
      error: error,
    );
  }

  factory HotkeyReport.fromJson(Map<String, dynamic> json) {
    final List<HotkeyOrphan> orphans = [];
    final Object? rawOrphans = json["orphans"];
    if (rawOrphans is List) {
      for (final Object? entry in rawOrphans) {
        if (entry is Map) {
          orphans.add(HotkeyOrphan.fromJson(entry.cast<String, dynamic>()));
        }
      }
    }

    return HotkeyReport(
      desktop: _asString(json["desktop"]),
      session: _asString(json["session"]),
      binding: _asString(json["binding"]),
      // Only a real `true` counts as registered: a missing field must not
      // make the page claim a shortcut that is not there.
      registered: json["registered"] == true,
      orphans: orphans,
    );
  }

  /// Parses the JSON line `setup_keybinding.py --report` writes.
  ///
  /// Never throws. Broken output is a normal answer here — the script may be
  /// missing, the desktop unknown, or the JSON truncated — and the caller
  /// gets a report that says "not registered" plus the reason.
  static HotkeyReport parse(String rawOutput) {
    final String trimmed = rawOutput.trim();
    if (trimmed.isEmpty) {
      return HotkeyReport.unavailable(
        "The keybinding script did not return anything.",
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException catch (error) {
      // The script writes one JSON line, but a warning from a wrapper around
      // it would turn the whole output into unparseable text. The object in
      // between is still worth a try.
      final int start = trimmed.indexOf("{");
      final int end = trimmed.lastIndexOf("}");
      if (start < 0 || end <= start) {
        return HotkeyReport.unavailable(
          "The keybinding script returned invalid JSON: ${error.message}",
        );
      }
      try {
        decoded = jsonDecode(trimmed.substring(start, end + 1));
      } on FormatException catch (innerError) {
        return HotkeyReport.unavailable(
          "The keybinding script returned invalid JSON: ${innerError.message}",
        );
      }
    }

    if (decoded is! Map) {
      return HotkeyReport.unavailable(
        "The keybinding script did not return a JSON object.",
      );
    }

    return HotkeyReport.fromJson(decoded.cast<String, dynamic>());
  }

  @override
  String toString() => "HotkeyReport(desktop: $desktop, session: $session, "
      "binding: $binding, registered: $registered, orphans: ${orphans.length})";
}

/// Reads what the desktop knows about this app's keyboard shortcut.
///
/// The desktop's own mechanism (gsettings, KDE's own files) is the single
/// source of truth since the app stopped grabbing the key itself. This service
/// only asks the script that owns that mechanism and turns its answer into
/// something the UI can show.
class HotkeyDiagnostics {
  const HotkeyDiagnostics();

  /// Asks the script for the current state and parses its answer.
  ///
  /// Never throws: a missing script, an unknown desktop or broken JSON all
  /// end up as a report with `registered: false` and an error text.
  Future<HotkeyReport> loadReport() async {
    final CommandResult result;
    try {
      result = await Linux.getHotkeyReport();
    } catch (error) {
      logError("Reading the hotkey report failed", error);
      return HotkeyReport.unavailable(
        "The keybinding report could not be started: $error",
      );
    }

    if (!result.success) {
      final String reason = result.error.trim().isNotEmpty
          ? result.error.trim()
          : result.output.trim();
      logError("Reading the hotkey report failed", reason);
      return HotkeyReport.unavailable(
        reason.isEmpty
            ? "The keybinding script failed without a message."
            : reason,
      );
    }

    return HotkeyReport.parse(result.output);
  }

  /// Removes the orphaned `custom*` entries.
  ///
  /// What counts as an orphan is decided by the script, never by the app: it
  /// is the only place that knows the desktop's own layout, and an entry that
  /// belongs to another app is untouchable there.
  Future<bool> cleanupOrphans() async {
    try {
      final CommandResult result = await Linux.cleanupHotkeyOrphans();
      if (!result.success) {
        final String reason = result.error.trim().isNotEmpty
            ? result.error.trim()
            : result.output.trim();
        logError("Cleaning up orphaned keybindings failed", reason);
        return false;
      }
      return true;
    } catch (error) {
      logError("Cleaning up orphaned keybindings failed", error);
      return false;
    }
  }
}

/// Reads a string out of a JSON map without trusting the type.
String _asString(Object? value) => value is String ? value : "";
