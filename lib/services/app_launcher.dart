import 'dart:io';

import '../helpers/command_helper.dart';
import 'config_handler.dart';

/// Ergebnis eines Browser-Launches.
enum BrowserLaunchResult {
  /// Konfigurierter oder XDG-Standardbrowser wurde gestartet.
  launchedPreferred,

  /// Fallback auf eine bekannte Browser-Binary aus der Liste.
  launchedFallback,

  /// Nichts gefunden – UI sollte Fehlermeldung zeigen.
  failed,
}

/// Bekannte Browser-Binaries in Prioritätsreihenfolge (letzter Fallback).
/// Der validierte Konfigurationswert (`preferred_browser`) wird dieser
/// Liste vorgestellt.
const List<String> kKnownBrowsers = [
  'brave',
  'brave-browser',
  'firefox',
  'chromium',
  'chromium-browser',
  'google-chrome',
  'falkon',
];

/// Startet externe Anwendungen (Browser etc.) detached vom App-Prozess.
///
/// Browser-Priorität (Release V0.8.2): `preferred_browser` (Allowlist-
/// geprüft) → XDG-Standardbrowser (`xdg-settings` + `.desktop`-Prüfung,
/// dann detached `gtk-launch` beziehungsweise `xdg-open` für URLs) →
/// [kKnownBrowsers] als letzter Fallback.
///
/// CLI-first: nutzt `which` zur Erkennung und startet Prozesse mit
/// [ProcessStartMode.detached], damit die App nicht blockiert und der
/// Browser die App überlebt.
///
/// Testbar: [whichRunner], [processStarter], [outputReader],
/// [desktopEntryExists] und [configuredBrowser] sind injizierbar.
class AppLauncher {
  /// Signatur für `which`-Aufrufe (injizierbar für Tests).
  static Future<bool> Function(String binary) _which = _defaultWhich;

  /// Signatur für Prozess-Starts (injizierbar für Tests).
  static Future<bool> Function(String binary, List<String> args) _starter =
      _defaultStarter;

  /// Signatur für Befehle, deren Ausgabe gebraucht wird (xdg-settings).
  static Future<String?> Function(String cmd, List<String> args) _outputReader =
      _defaultOutputReader;

  /// Signatur für die .desktop-Existenzprüfung (injizierbar für Tests).
  static bool Function(String desktopId) _desktopEntryExists =
      desktopEntryExistsIn;

  /// Signatur für den Config-Zugriff auf `preferred_browser`.
  static String? Function() _configuredBrowser = _defaultConfiguredBrowser;

  /// Überschreibt Prozess- und Config-Zugriffe – nur für Tests verwenden!
  static void debugOverride({
    Future<bool> Function(String binary)? whichRunner,
    Future<bool> Function(String binary, List<String> args)? processStarter,
    Future<String?> Function(String cmd, List<String> args)? outputReader,
    bool Function(String desktopId)? desktopEntryExists,
    String? Function()? configuredBrowser,
  }) {
    _which = whichRunner ?? _defaultWhich;
    _starter = processStarter ?? _defaultStarter;
    _outputReader = outputReader ?? ((_, __) async => null);
    _desktopEntryExists = desktopEntryExists ?? desktopEntryExistsIn;
    _configuredBrowser = configuredBrowser ?? _defaultConfiguredBrowser;
  }

  /// Setzt Test-Overrides zurück.
  static void resetOverrides() {
    _which = _defaultWhich;
    _starter = _defaultStarter;
    _outputReader = _defaultOutputReader;
    _desktopEntryExists = desktopEntryExistsIn;
    _configuredBrowser = _defaultConfiguredBrowser;
  }

  static Future<bool> _defaultWhich(String binary) async {
    try {
      final result = await Process.run('which', [binary]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _defaultStarter(String binary, List<String> args) async {
    try {
      await Process.start(binary, args, mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _defaultOutputReader(
      String cmd, List<String> args) async {
    final result = await CommandHelper.runWithArguments(cmd, args);
    if (!result.success) return null;
    final output = result.output.trim();
    return output.isEmpty ? null : output;
  }

  /// Prüft, ob ein Binary im PATH verfügbar ist.
  static Future<bool> isAvailable(String binary) => _which(binary);

  /// Gibt den ersten verfügbaren Browser aus der Prioritätsliste zurück.
  /// Berücksichtigt den validierten Konfigurationswert (`preferred_browser`).
  static Future<String?> detectBrowser() async {
    final configured = sanitizePreferredBrowser(_configuredBrowser());
    final candidates = [
      if (configured != null && configured.isNotEmpty) configured,
      ...kKnownBrowsers,
    ];
    for (final bin in candidates) {
      if (await _which(bin)) return bin;
    }
    return null;
  }

  /// Validiert den rohen `preferred_browser`-Config-Wert (WP-B1, #47):
  /// trim, Allowlist-Membership in [kKnownBrowsers], Pfade abgelehnt.
  /// Ungültige Werte ergeben `null` → stiller Fallback auf die XDG-Stufe.
  static String? sanitizePreferredBrowser(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty || value.contains('/')) return null;
    return kKnownBrowsers.contains(value) ? value : null;
  }

  /// Liest die Desktop-ID des XDG-Standardbrowsers via `xdg-settings`.
  /// Ungültige oder fehlende Antworten ergeben `null`.
  static Future<String?> defaultBrowserDesktopId() async {
    final output =
        await _outputReader('xdg-settings', ['get', 'default-web-browser']);
    if (output == null) return null;
    final desktopId = output.trim();
    return _validDesktopId(desktopId) ? desktopId : null;
  }

  /// Prüft, ob eine .desktop-Datei unter `<xdgDataDirs>/applications/`
  /// existiert. Ohne [xdgDataDirs] werden XDG_DATA_HOME und XDG_DATA_DIRS
  /// aus der Umgebung gelesen (Defaults: `~/.local/share` und
  /// `/usr/local/share:/usr/share`).
  static bool desktopEntryExistsIn(String desktopId,
      {List<String>? xdgDataDirs}) {
    if (!_validDesktopId(desktopId)) return false;
    final dirs = xdgDataDirs ?? _defaultXdgDataDirs();
    for (final dir in dirs) {
      if (File('$dir/applications/$desktopId').existsSync()) return true;
    }
    return false;
  }

  /// Startet den Browser. [url] ist optional (Default: Startseite).
  ///
  /// Ablauf (Release V0.8.2):
  /// 1. Validierter `preferred_browser` → [BrowserLaunchResult.launchedPreferred]
  /// 2. XDG-Standardbrowser: `xdg-settings` + `.desktop`-Prüfung, dann
  ///    `gtk-launch` (ohne URL) beziehungsweise `xdg-open` (mit URL)
  ///    → [BrowserLaunchResult.launchedPreferred]
  /// 3. Erste verfügbare Binary aus [kKnownBrowsers]
  ///    → [BrowserLaunchResult.launchedFallback]
  /// 4. Alles fehlgeschlagen → [BrowserLaunchResult.failed]
  static Future<BrowserLaunchResult> launchBrowser({String? url}) async {
    final args = url != null ? [url] : <String>[];

    final preferred = sanitizePreferredBrowser(_configuredBrowser());
    if (preferred != null && await _which(preferred)) {
      if (await _starter(preferred, args)) {
        return BrowserLaunchResult.launchedPreferred;
      }
    }

    final desktopId = await defaultBrowserDesktopId();
    if (desktopId != null && _desktopEntryExists(desktopId)) {
      if (url != null) {
        if (await _starter('xdg-open', [url])) {
          return BrowserLaunchResult.launchedPreferred;
        }
      } else {
        final appId = desktopId.endsWith('.desktop')
            ? desktopId.substring(0, desktopId.length - '.desktop'.length)
            : desktopId;
        if (await _starter('gtk-launch', [appId])) {
          return BrowserLaunchResult.launchedPreferred;
        }
      }
    }

    final fallback = await detectBrowser();
    if (fallback != null && await _starter(fallback, args)) {
      return BrowserLaunchResult.launchedFallback;
    }
    return BrowserLaunchResult.failed;
  }

  /// Startet eine beliebige Anwendung detached (für spätere Werkzeuge,
  /// z. B. „Im Terminal öffnen" im Dateimanager).
  static Future<bool> launchApp(String binary, {List<String> args = const []}) {
    return _starter(binary, args);
  }

  /// Desktop-IDs sind Dateinamen ohne Pfadtrenner und ohne `..`-Sprünge.
  static bool _validDesktopId(String desktopId) {
    if (!desktopId.endsWith('.desktop')) return false;
    if (desktopId.contains('/') || desktopId.contains('..')) return false;
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*\.desktop$').hasMatch(desktopId);
  }

  static List<String> _defaultXdgDataDirs() {
    final env = Platform.environment;
    final home = env['HOME'];
    final configuredDataHome = env['XDG_DATA_HOME'];
    final dataHome = configuredDataHome != null && configuredDataHome.isNotEmpty
        ? configuredDataHome
        : (home != null ? '$home/.local/share' : null);
    final configuredDataDirs = env['XDG_DATA_DIRS'];
    final dirsRaw = configuredDataDirs != null && configuredDataDirs.isNotEmpty
        ? configuredDataDirs
        : '/usr/local/share:/usr/share';
    return [
      if (dataHome != null) dataHome,
      ...dirsRaw.split(':').where((dir) => dir.isNotEmpty),
    ];
  }

  static String? _defaultConfiguredBrowser() {
    try {
      return ConfigHandler().getValueUnsafe('preferred_browser', '');
    } catch (_) {
      return null; // ConfigHandler nicht initialisiert (z. B. in Tests)
    }
  }
}
