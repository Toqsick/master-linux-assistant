// Q1 of issue #58: the security scan runs when the user asks for it, not when
// the page is opened — and its result survives an app restart.
//
// The scan reaches root through pkexec. A password dialog that pops up
// because someone opened a page is not an option, so the behaviour is pinned
// here: opening the page starts nothing, pressing the button starts exactly
// one scan, and the result of that scan lands in the cache.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linux_assistant/helpers/command_helper.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/layouts/mint_y.dart';
import 'package:linux_assistant/layouts/security_check/overview.dart';
import 'package:linux_assistant/services/security_scan_cache.dart';

/// The key of the button that starts the scan.
const Key kRunScanButton = Key("security-scan-run");

/// Records every command instead of running it.
class _RecordingRunner implements CommandRunner {
  _RecordingRunner(this.result);

  final CommandResult result;
  final List<List<String>> calls = <List<String>>[];

  @override
  Future<CommandResult> run(
    String command,
    List<String> arguments, {
    Map<String, String>? environment,
    bool asRoot = false,
    bool hostOnFlatpak = true,
    bool runInShell = false,
  }) async {
    calls.add(<String>[command, ...arguments]);
    return result;
  }
}

/// A successful checker run, as the privileged script prints it.
const String kSuccessfulReport = "firewallinactive\n"
    "upgradeablepackage: linux-assistant-1.0\n"
    "#!script ran successfully.";

/// Real file IO started from the fake-async test zone needs several
/// drain-and-pump rounds to work through its await chain; one round only
/// advances it by a single hop.
Future<void> _drainRealIo(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The page under test, in the app's own theme and localization.
Widget _host(SecurityScanCache cache) {
  return MaterialApp(
    theme: MintY.theme(),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en', '')],
    home: Scaffold(body: SecurityCheckContent(cache: cache)),
  );
}

void main() {
  group("cache location", () {
    test("follows XDG_CACHE_HOME when it is set", () {
      final Directory directory = SecurityScanCache.defaultDirectory(
        environment: <String, String>{
          "XDG_CACHE_HOME": "/tmp/xdg-cache",
          "HOME": "/home/tester",
        },
      );
      expect(directory.path, "/tmp/xdg-cache/linux-assistant");
    });

    test("falls back to ~/.cache when XDG_CACHE_HOME is unset", () {
      final Directory directory = SecurityScanCache.defaultDirectory(
        environment: <String, String>{"HOME": "/home/tester"},
      );
      expect(directory.path, "/home/tester/.cache/linux-assistant");
    });

    test("falls back to ~/.cache when XDG_CACHE_HOME is empty", () {
      final Directory directory = SecurityScanCache.defaultDirectory(
        environment: <String, String>{
          "XDG_CACHE_HOME": "   ",
          "HOME": "/home/tester",
        },
      );
      expect(directory.path, "/home/tester/.cache/linux-assistant");
    });

    test("the result file is security-last.json in that directory", () {
      final SecurityScanCache cache = SecurityScanCache(
        directory: Directory("/tmp/q1-cache/linux-assistant"),
      );
      expect(
          cache.file.path, "/tmp/q1-cache/linux-assistant/security-last.json");
    });
  });

  group("snapshot", () {
    test("keeps the finding lines and drops the success marker", () {
      final SecurityScanSnapshot snapshot = SecurityScanSnapshot.fromOutput(
        "firewallinactive\n\n#!script ran successfully.\nsshrunning\n",
        timestamp: DateTime.utc(2026, 10, 23, 12),
      );
      expect(snapshot.tokens, <String>["firewallinactive", "sshrunning"]);
    });

    test("keeps the payload of a finding", () {
      final SecurityScanSnapshot snapshot = SecurityScanSnapshot.fromOutput(
        "additionalsource: http://example.org/repo\n",
        timestamp: DateTime.utc(2026, 10, 23, 12),
      );
      expect(
          snapshot.tokens.single, "additionalsource: http://example.org/repo");
    });

    test("round-trips through JSON", () {
      final SecurityScanSnapshot snapshot = SecurityScanSnapshot(
        tokens: <String>["firewallinactive", "sshrunning"],
        timestamp: DateTime.utc(2026, 10, 23, 12, 30),
      );

      final SecurityScanSnapshot? restored =
          SecurityScanSnapshot.fromJson(snapshot.toJson());

      expect(restored, isNotNull);
      expect(restored!.tokens, snapshot.tokens);
      expect(restored.timestamp.toUtc(), snapshot.timestamp.toUtc());
    });

    test("the JSON shape is stable", () {
      final SecurityScanSnapshot snapshot = SecurityScanSnapshot(
        tokens: <String>["sshrunning"],
        timestamp: DateTime.utc(2026, 10, 23, 12, 30),
      );

      expect(snapshot.toJson(), <String, dynamic>{
        "version": 1,
        "timestamp": "2026-10-23T12:30:00.000Z",
        "tokens": <String>["sshrunning"],
      });
    });

    test("refuses a file from a different format version", () {
      final Map<String, dynamic> json = SecurityScanSnapshot(
        tokens: <String>["sshrunning"],
        timestamp: DateTime.utc(2026, 10, 23),
      ).toJson();
      json["version"] = 99;

      expect(SecurityScanSnapshot.fromJson(json), isNull);
    });

    test("refuses a file without a usable timestamp", () {
      final Map<String, dynamic> json = SecurityScanSnapshot(
        tokens: <String>["sshrunning"],
        timestamp: DateTime.utc(2026, 10, 23),
      ).toJson();
      json["timestamp"] = "not a timestamp";

      expect(SecurityScanSnapshot.fromJson(json), isNull);
    });

    test("refuses a file whose tokens are not strings", () {
      final Map<String, dynamic> json = SecurityScanSnapshot(
        tokens: <String>["sshrunning"],
        timestamp: DateTime.utc(2026, 10, 23),
      ).toJson();
      json["tokens"] = <Object>[42];

      expect(SecurityScanSnapshot.fromJson(json), isNull);
    });
  });

  group("age", () {
    final DateTime now = DateTime.utc(2026, 10, 23, 12);

    test("less than a minute old is just now", () {
      final SecurityScanAge age = SecurityScanAge.between(
        now.subtract(const Duration(seconds: 42)),
        now,
      );
      expect(age.unit, SecurityScanAgeUnit.justNow);
    });

    test("minutes are counted", () {
      final SecurityScanAge age = SecurityScanAge.between(
        now.subtract(const Duration(minutes: 7, seconds: 30)),
        now,
      );
      expect(age.unit, SecurityScanAgeUnit.minutes);
      expect(age.count, 7);
    });

    test("hours are counted", () {
      final SecurityScanAge age = SecurityScanAge.between(
        now.subtract(const Duration(hours: 5)),
        now,
      );
      expect(age.unit, SecurityScanAgeUnit.hours);
      expect(age.count, 5);
    });

    test("days are counted", () {
      final SecurityScanAge age = SecurityScanAge.between(
        now.subtract(const Duration(days: 3, hours: 2)),
        now,
      );
      expect(age.unit, SecurityScanAgeUnit.days);
      expect(age.count, 3);
    });

    test("a timestamp in the future is just now, not a negative age", () {
      final SecurityScanAge age = SecurityScanAge.between(
        now.add(const Duration(hours: 2)),
        now,
      );
      expect(age.unit, SecurityScanAgeUnit.justNow);
      expect(age.count, 0);
    });

    test("exactly one minute is a minute, not just now", () {
      final SecurityScanAge age = SecurityScanAge.between(
        now.subtract(const Duration(minutes: 1)),
        now,
      );
      expect(age.unit, SecurityScanAgeUnit.minutes);
      expect(age.count, 1);
    });
  });

  group("cache", () {
    late Directory directory;
    late SecurityScanCache cache;

    setUp(() {
      directory = Directory.systemTemp.createTempSync("q1-security-scan");
      cache = SecurityScanCache(directory: directory);
    });

    tearDown(() {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    test("has no result before the first scan", () async {
      expect(await cache.read(), isNull);
    });

    test("writes and reads the result back", () async {
      final SecurityScanSnapshot snapshot = SecurityScanSnapshot(
        tokens: <String>["firewallinactive", "sshrunning"],
        timestamp: DateTime.utc(2026, 10, 23, 12, 30),
      );

      await cache.write(snapshot);

      final SecurityScanSnapshot? restored = await cache.read();
      expect(restored, isNotNull);
      expect(restored!.tokens, snapshot.tokens);
      expect(restored.timestamp.toUtc(), snapshot.timestamp.toUtc());
    });

    test("creates the directory it needs", () async {
      final Directory nested =
          Directory("${directory.path}/deep/inside/linux-assistant");
      final SecurityScanCache nestedCache =
          SecurityScanCache(directory: nested);

      await nestedCache.write(SecurityScanSnapshot(
        tokens: <String>["sshrunning"],
        timestamp: DateTime.utc(2026, 10, 23),
      ));

      expect(nestedCache.file.existsSync(), isTrue);
    });

    test("survives a corrupt file instead of failing", () async {
      cache.file.writeAsStringSync("{not json at all");

      expect(await cache.read(), isNull);
    });

    test("survives an empty file", () async {
      cache.file.writeAsStringSync("   ");

      expect(await cache.read(), isNull);
    });

    test("leaves no temporary file behind", () async {
      await cache.write(SecurityScanSnapshot(
        tokens: <String>["sshrunning"],
        timestamp: DateTime.utc(2026, 10, 23),
      ));

      final List<String> leftovers = directory
          .listSync()
          .map((FileSystemEntity entity) => entity.path.split("/").last)
          .where((String name) => name.endsWith(".tmp"))
          .toList();
      expect(leftovers, isEmpty);
    });

    test("the written file is the documented JSON", () async {
      await cache.write(SecurityScanSnapshot(
        tokens: <String>["firewallinactive"],
        timestamp: DateTime.utc(2026, 10, 23, 12, 30),
      ));

      final Map<String, dynamic> decoded =
          jsonDecode(cache.file.readAsStringSync()) as Map<String, dynamic>;
      expect(decoded["version"], 1);
      expect(decoded["timestamp"], "2026-10-23T12:30:00.000Z");
      expect(decoded["tokens"], <String>["firewallinactive"]);
    });
  });

  group("the page", () {
    late Directory directory;
    late SecurityScanCache cache;
    late _RecordingRunner runner;
    final CommandRunner originalRunner = CommandHelper.runner;

    setUp(() {
      directory = Directory.systemTemp.createTempSync("q1-security-scan");
      cache = SecurityScanCache(directory: directory);
      runner = _RecordingRunner(const CommandResult(
        true,
        kSuccessfulReport,
        "",
        0,
      ));
      CommandHelper.runner = runner;
    });

    tearDown(() {
      CommandHelper.runner = originalRunner;
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    testWidgets("starts no scan when the page is opened", (tester) async {
      await tester.pumpWidget(_host(cache));
      await _drainRealIo(tester);

      expect(runner.calls, isEmpty,
          reason: "the scan reaches root through pkexec; it may only start "
              "when the user asks for it");
    });

    testWidgets("offers the button that starts the scan", (tester) async {
      await tester.pumpWidget(_host(cache));
      await _drainRealIo(tester);

      expect(find.byKey(kRunScanButton), findsOneWidget);
    });

    testWidgets("starts exactly one scan when the button is pressed",
        (tester) async {
      await tester.pumpWidget(_host(cache));
      await _drainRealIo(tester);

      await tester.tap(find.byKey(kRunScanButton));
      await _drainRealIo(tester);

      expect(runner.calls.length, 1);
      expect(runner.calls.single.first, contains("pkexec"));
      expect(runner.calls.single, contains("read_security_report.py"));
    });

    testWidgets("stores the result of the scan in the cache", (tester) async {
      await tester.pumpWidget(_host(cache));
      await _drainRealIo(tester);

      await tester.tap(find.byKey(kRunScanButton));
      await _drainRealIo(tester);

      expect(cache.file.existsSync(), isTrue);
      // Echte Datei-IO muss in einem Widget-Test ueber runAsync laufen: in
      // der Fake-Async-Zone bekommt das Future nie sein IO-Ereignis und der
      // Test haengt bis zum Zeitueberlauf.
      final SecurityScanSnapshot? stored =
          await tester.runAsync<SecurityScanSnapshot?>(() => cache.read());
      expect(stored, isNotNull);
      expect(stored!.tokens, contains("firewallinactive"));
      expect(stored.tokens, isNot(contains("#!script ran successfully.")));
    });

    testWidgets("shows the cached result with its age after a restart",
        (tester) async {
      // What a restart looks like: the cache file is there, the page is not.
      await tester.runAsync(() => cache.write(SecurityScanSnapshot(
            tokens: <String>["firewallinactive"],
            timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          )));

      await tester.pumpWidget(_host(cache));
      await _drainRealIo(tester);

      expect(find.textContaining("5"), findsWidgets,
          reason: "the age of the cached result is shown");
      expect(runner.calls, isEmpty);
    });
  });
}
