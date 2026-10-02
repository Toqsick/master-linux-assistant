import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linux_assistant/services/app_launcher.dart';

/// Hermetische Test-Umgebung: fängt alle injizierbaren Zugriffe des
/// [AppLauncher] ab und zeichnet jeden gestarteten Prozess und jeden
/// ausgelesenen Befehl auf.
class LauncherFake {
  /// `'$binary ${args.join(' ')}'` jedes gestarteten Prozesses.
  final started = <String>[];

  /// Jeder via [AppLauncher.debugOverride] umgeleitete Lese-Befehl.
  final readCommands = <String>[];

  /// Ergebnis von `which <binary>`; fehlender Eintrag = `false`.
  Map<String, bool> whichResults = {};

  /// Ergebnis eines Starts; fehlender Eintrag = `true`.
  Map<String, bool> startResults = {};

  /// Ausgabe von `xdg-settings get default-web-browser`.
  String? xdgSettingsOutput;

  /// `false` = xdg-settings schlägt fehl (keine Ausgabe).
  bool xdgSettingsSucceeds = true;

  /// Existiert die .desktop-Datei des XDG-Standardbrowsers?
  bool desktopExists = true;

  /// Roher `preferred_browser`-Config-Wert.
  String? configured;

  void install() {
    AppLauncher.debugOverride(
      whichRunner: (bin) async => whichResults[bin] ?? false,
      processStarter: (bin, args) {
        started.add('$bin ${args.join(' ')}'.trim());
        return Future.value(startResults[bin] ?? true);
      },
      outputReader: (cmd, args) {
        readCommands.add('$cmd ${args.join(' ')}');
        if (!xdgSettingsSucceeds) return Future.value(null);
        return Future.value(xdgSettingsOutput);
      },
      desktopEntryExists: (_) => desktopExists,
      configuredBrowser: () => configured,
    );
  }
}

void main() {
  tearDown(AppLauncher.resetOverrides);

  group('AppLauncher.detectBrowser', () {
    test('findet Brave, wenn verfügbar', () async {
      AppLauncher.debugOverride(
        whichRunner: (bin) async => bin == 'brave',
        processStarter: (_, __) async => true,
      );
      expect(await AppLauncher.detectBrowser(), 'brave');
    });

    test('fällt auf brave-browser zurück, wenn brave fehlt', () async {
      AppLauncher.debugOverride(
        whichRunner: (bin) async => bin == 'brave-browser',
        processStarter: (_, __) async => true,
      );
      expect(await AppLauncher.detectBrowser(), 'brave-browser');
    });

    test('gibt null zurück, wenn kein Browser gefunden', () async {
      AppLauncher.debugOverride(
        whichRunner: (_) async => false,
        processStarter: (_, __) async => false,
      );
      expect(await AppLauncher.detectBrowser(), isNull);
    });
  });

  group('AppLauncher.defaultBrowserDesktopId', () {
    test('liest die Desktop-ID aus xdg-settings', () async {
      final fake = LauncherFake()
        ..xdgSettingsOutput = 'brave-origin.desktop'
        ..install();
      expect(
          await AppLauncher.defaultBrowserDesktopId(), 'brave-origin.desktop');
      expect(fake.readCommands.single, 'xdg-settings get default-web-browser');
    });

    test('liefert null, wenn xdg-settings fehlschlägt', () async {
      LauncherFake()
        ..xdgSettingsSucceeds = false
        ..install();
      expect(await AppLauncher.defaultBrowserDesktopId(), isNull);
    });

    test('liefert null bei leerer Ausgabe', () async {
      LauncherFake()
        ..xdgSettingsOutput = ''
        ..install();
      expect(await AppLauncher.defaultBrowserDesktopId(), isNull);
    });

    test('liefert null bei ungültiger Desktop-ID (Boundary)', () async {
      LauncherFake()
        ..xdgSettingsOutput = '../evil.desktop'
        ..install();
      expect(await AppLauncher.defaultBrowserDesktopId(), isNull);
    });
  });

  group('AppLauncher.desktopEntryExistsIn', () {
    test('true, wenn der Eintrag in applications/ liegt', () async {
      final tmp = await Directory.systemTemp.createTemp('mla_xdg_test');
      addTearDown(() => tmp.deleteSync(recursive: true));
      Directory('${tmp.path}/applications').createSync(recursive: true);
      File('${tmp.path}/applications/brave-origin.desktop')
          .writeAsStringSync('[Desktop Entry]\n');
      expect(
        AppLauncher.desktopEntryExistsIn('brave-origin.desktop',
            xdgDataDirs: [tmp.path]),
        isTrue,
      );
    });

    test('false, wenn kein Daten-Verzeichnis den Eintrag enthält', () async {
      final tmp = await Directory.systemTemp.createTemp('mla_xdg_test');
      addTearDown(() => tmp.deleteSync(recursive: true));
      Directory('${tmp.path}/applications').createSync(recursive: true);
      expect(
        AppLauncher.desktopEntryExistsIn('brave-origin.desktop',
            xdgDataDirs: [tmp.path]),
        isFalse,
      );
    });
  });

  group('AppLauncher.launchBrowser', () {
    test('startet den XDG-Standardbrowser statt der ersten Listen-Binary',
        () async {
      final fake = LauncherFake()
        ..whichResults = {'google-chrome': true}
        ..xdgSettingsOutput = 'brave-origin.desktop'
        ..desktopExists = true
        ..install();
      final result = await AppLauncher.launchBrowser();
      expect(result, BrowserLaunchResult.launchedPreferred);
      expect(fake.started.single, 'gtk-launch brave-origin');
      expect(fake.started.join(' ').contains('google-chrome'), isFalse);
    });

    test('öffnet URLs über xdg-open, wenn ein XDG-Standard gesetzt ist',
        () async {
      final fake = LauncherFake()
        ..xdgSettingsOutput = 'brave-origin.desktop'
        ..install();
      final result =
          await AppLauncher.launchBrowser(url: 'https://example.com');
      expect(result, BrowserLaunchResult.launchedPreferred);
      expect(fake.started.single, 'xdg-open https://example.com');
    });

    test('preferred_browser gewinnt über den XDG-Standard', () async {
      final fake = LauncherFake()
        ..configured = 'firefox'
        ..whichResults = {'firefox': true}
        ..xdgSettingsOutput = 'brave-origin.desktop'
        ..install();
      final result =
          await AppLauncher.launchBrowser(url: 'https://example.com');
      expect(result, BrowserLaunchResult.launchedPreferred);
      expect(fake.started.single, 'firefox https://example.com');
      expect(fake.readCommands, isEmpty);
    });

    test('fällt auf die Binary-Liste zurück, wenn xdg-settings nichts liefert',
        () async {
      final fake = LauncherFake()
        ..xdgSettingsSucceeds = false
        ..whichResults = {'brave-browser': true}
        ..install();
      final result = await AppLauncher.launchBrowser();
      expect(result, BrowserLaunchResult.launchedFallback);
      expect(fake.started.single, 'brave-browser');
    });

    test('debug override does not run xdg-settings without an output reader',
        () async {
      final started = <String>[];
      AppLauncher.debugOverride(
        whichRunner: (binary) async => binary == 'brave',
        processStarter: (binary, _) async {
          started.add(binary);
          return true;
        },
        configuredBrowser: () => null,
      );

      expect(
        await AppLauncher.launchBrowser(),
        BrowserLaunchResult.launchedFallback,
      );
      expect(started, ['brave']);
    });

    test('fällt auf die Binary-Liste zurück, wenn die .desktop-Datei fehlt',
        () async {
      final fake = LauncherFake()
        ..xdgSettingsOutput = 'brave-origin.desktop'
        ..desktopExists = false
        ..whichResults = {'chromium': true}
        ..install();
      final result = await AppLauncher.launchBrowser();
      expect(result, BrowserLaunchResult.launchedFallback);
      expect(fake.started.single, 'chromium');
    });

    test('ignoriert einen Pfad als preferred_browser (WP-B1-Boundary)',
        () async {
      final fake = LauncherFake()
        ..configured = '/usr/bin/brave'
        ..whichResults = {'/usr/bin/brave': true}
        ..xdgSettingsOutput = 'brave-origin.desktop'
        ..install();
      final result = await AppLauncher.launchBrowser();
      expect(result, BrowserLaunchResult.launchedPreferred);
      expect(fake.started.single, 'gtk-launch brave-origin');
    });

    test('übergibt die URL auch an den Binary-Listen-Fallback', () async {
      final fake = LauncherFake()
        ..xdgSettingsSucceeds = false
        ..whichResults = {'chromium': true}
        ..install();
      final result =
          await AppLauncher.launchBrowser(url: 'https://example.com');
      expect(result, BrowserLaunchResult.launchedFallback);
      expect(fake.started.single, 'chromium https://example.com');
    });

    test('failed, wenn keine Stufe zum Ziel führt', () async {
      LauncherFake()
        ..xdgSettingsSucceeds = false
        ..startResults = {'brave': false, 'xdg-open': false}
        ..install();
      expect(await AppLauncher.launchBrowser(), BrowserLaunchResult.failed);
    });
  });

  group('AppLauncher.sanitizePreferredBrowser', () {
    test('lässt allowlisteten Wert durch', () {
      expect(AppLauncher.sanitizePreferredBrowser('brave'), 'brave');
    });

    test('trimmt umgebende Leerzeichen', () {
      expect(AppLauncher.sanitizePreferredBrowser('  brave  '), 'brave');
    });

    test('lehnt nicht-allowlistete Binary-Namen ab (fällt still auf Fallback)',
        () {
      expect(AppLauncher.sanitizePreferredBrowser('not-a-browser'), isNull);
    });

    test('lehnt Pfade ab (WP-B1: which würde sie sonst auflösen)', () {
      expect(AppLauncher.sanitizePreferredBrowser('/usr/bin/brave'), isNull);
    });
  });

  group('AppLauncher.launchApp', () {
    test('startet beliebige Binaries detached', () async {
      String? startedBin;
      AppLauncher.debugOverride(
        processStarter: (bin, args) async {
          startedBin = bin;
          return true;
        },
      );
      expect(await AppLauncher.launchApp('nautilus'), isTrue);
      expect(startedBin, 'nautilus');
    });

    test('gibt false bei Startfehler zurück', () async {
      AppLauncher.debugOverride(processStarter: (_, __) async => false);
      expect(await AppLauncher.launchApp('nonexistent'), isFalse);
    });
  });
}
