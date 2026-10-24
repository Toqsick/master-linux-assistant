import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:linux_assistant/helpers/command_helper.dart';
import 'package:linux_assistant/services/app_launcher.dart';
import 'package:linux_assistant/services/linux.dart';
import 'package:linux_assistant/services/logger.dart';

/// What the system says about the default browser.
///
/// Two sources that can disagree: `xdg-settings get default-web-browser`
/// (what the desktop settings call the default) and `gio mime
/// x-scheme-handler/https` (what actually opens an HTTPS link). When they
/// differ, the user clicks a link and gets a different browser than the one
/// the desktop advertises — that is worth a warning.
@immutable
class BrowserStatus {
  const BrowserStatus({
    this.defaultDesktopId,
    this.httpsHandlerDesktopId,
    this.handlerKnown = false,
  });

  /// The desktop id of the standard browser, e.g. `firefox.desktop`.
  /// Null when the desktop environment does not name one.
  final String? defaultDesktopId;

  /// The desktop id that handles `x-scheme-handler/https`. Null when no
  /// handler is registered.
  final String? httpsHandlerDesktopId;

  /// Whether the HTTPS handler could be determined at all.
  ///
  /// `gio` is not installed on every minimal system and answers with an
  /// error when no handler is registered. In that case there is nothing to
  /// compare, so no warning is shown.
  final bool handlerKnown;

  /// Whether the HTTPS handler differs from the standard browser.
  bool get mismatch {
    if (!handlerKnown) {
      return false;
    }
    final standard = defaultDesktopId;
    final handler = httpsHandlerDesktopId;
    if (standard == null || handler == null) {
      return false;
    }
    return !_sameDesktopId(standard, handler);
  }

  /// Two ids are the same when they differ only in the `.desktop` suffix or
  /// in case — `firefox` and `firefox.desktop` name the same application.
  static bool _sameDesktopId(String a, String b) {
    return _stripDesktopSuffix(a).toLowerCase() ==
        _stripDesktopSuffix(b).toLowerCase();
  }

  static String _stripDesktopSuffix(String id) {
    return id.toLowerCase().endsWith(".desktop")
        ? id.substring(0, id.length - ".desktop".length)
        : id;
  }
}

/// Reads the default browser and the HTTPS handler.
///
/// The reading is read-only: nothing is written, no settings are changed.
/// The desktop id comes from [AppLauncher.defaultBrowserDesktopId], the same
/// source the browser launcher uses, so the dashboard cannot disagree with
/// what the app does.
class BrowserStatusService {
  static final BrowserStatusService _instance = BrowserStatusService._();

  factory BrowserStatusService() => _instance;

  BrowserStatusService._();

  /// The default browser changes rarely, so the timer is deliberately slow.
  static const Duration defaultInterval = Duration(minutes: 5);

  /// `gio` lives in `/usr/bin` on every distribution that ships it.
  static const String gioPath = "/usr/bin/gio";

  /// The first line of `gio mime` names the default handler:
  /// `Default application for ?<type>?: <desktop-id>`.
  static const String kGioDefaultApplicationPrefix = "Default application for";

  final ValueNotifier<BrowserStatus?> status =
      ValueNotifier<BrowserStatus?>(null);

  Duration interval = defaultInterval;

  Timer? _timer;
  int _subscribers = 0;

  /// Both default to true so that a consumer outside the hub keeps working
  /// without opting in. The hub sets them to false as soon as the dashboard
  /// is not the section on screen.
  bool _sectionActive = true;
  bool _windowVisible = true;

  bool _reading = false;

  @visibleForTesting
  int get subscriberCount => _subscribers;

  /// Read-only view of the section flag, so the coupling between the hub
  /// and this service can be asserted without running `gio`.
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

  /// Whether the view on screen shows the browser status at all.
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

  /// Re-reads both sources and publishes the result.
  Future<void> refresh() async {
    if (_reading) {
      return;
    }
    _reading = true;
    try {
      final String? standard = await AppLauncher.defaultBrowserDesktopId();
      final String? handler = await _readHttpsHandler();
      status.value = BrowserStatus(
        defaultDesktopId: standard,
        httpsHandlerDesktopId: handler,
        handlerKnown: handler != null,
      );
    } catch (e) {
      logError("Could not read the browser status", e);
    } finally {
      _reading = false;
    }
  }

  /// `gio mime x-scheme-handler/https` prints
  /// `x-scheme-handler/https: firefox.desktop` — or several ids, separated
  /// by semicolons, when more than one application can handle the scheme.
  Future<String?> _readHttpsHandler() async {
    final CommandResult result = await Linux.runProcess(
      gioPath,
      ["mime", "x-scheme-handler/https"],
      environment: {"LC_ALL": "C"},
      runInShell: false,
    );

    if (!result.success) {
      // `gio` exits with 1 when no handler is registered and prints the
      // reason to stderr. That is an answer, not an error.
      logInfo("gio did not name an HTTPS handler: ${result.error}");
      return null;
    }

    return parseGioMimeHandler(result.output);
  }

  /// Extracts the handler desktop id from the output of `gio mime`.
  ///
  /// The real output of `gio mime x-scheme-handler/https` looks like this
  /// (measured on gio 2.74):
  ///
  ///     Default application for ?x-scheme-handler/https?: brave-browser.desktop
  ///     No registered applications
  ///     No recommended applications
  ///
  /// Only the first line names the default handler. The other two sections
  /// list applications that can open the type without being the default —
  /// the dashboard wants the default, so they are ignored.
  ///
  /// Returns null when the output carries no handler for the scheme.
  static String? parseGioMimeHandler(String raw) {
    for (final line in raw.split('\n')) {
      final String trimmed = line.trim();
      if (!trimmed.startsWith(kGioDefaultApplicationPrefix)) {
        continue;
      }
      final int separator = trimmed.indexOf(':');
      if (separator < 0) {
        continue;
      }
      final String value = trimmed.substring(separator + 1).trim();
      if (value.isEmpty) {
        return null;
      }
      final String first = value.split(';').first.trim();
      return first.isEmpty ? null : first;
    }
    return null;
  }

  /// Test seam: drops all state and stops the timer.
  @visibleForTesting
  void resetForTesting({BrowserStatus? seed}) {
    _timer?.cancel();
    _timer = null;
    _subscribers = 0;
    _sectionActive = true;
    _windowVisible = true;
    _reading = false;
    status.value = seed;
  }
}
