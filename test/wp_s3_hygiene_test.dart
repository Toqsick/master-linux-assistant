// WP-S3 (#56, #46, #50): das Hygiene-Bundle der Kommandoebene.
//
// Drei Dinge werden hier festgenagelt:
//
// 1. Die Kommandoebene startet per Default *ohne* Shell. Die untere Ebene
//    (`CommandHelper`, `la_core`) hatte den Default bereits auf `false`; die
//    App-Ebene (`Linux.runCommandWithCustomArguments`, `Linux.runProcess`)
//    stand noch auf `true` und startete damit fuer jeden Aufruf eine Shell
//    *und* das Kommando.
// 2. Ein Pfad mit Leerzeichen kommt als EIN argv-Element an. Der alte
//    Kommentar im Code behauptete das Gegenteil ("argv space-joined
//    unquoted") — das war falsch: Dart quotet jedes argv-Element einzeln,
//    wenn es den `sh -c`-String baut. Die Shell war nie ein Split-Risiko,
//    sondern nur ein ueberfluessiger Zwischenschritt.
// 3. Die Rekursionstiefe der Ordnersuche ist geklemmt. Der Wert kommt aus
//    einer Konfigurationsdatei, die der Benutzer schreiben kann; der alte
//    `final int`-Cast machte daraus einen TypeError statt eines Defaults.
//
// Der Test benutzt den Seam `CommandHelper.runner` — es startet kein echter
// Prozess, ausser dort, wo es gerade um das Verhalten der Dart-VM geht.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linux_assistant/enums/desktops.dart';
import 'package:linux_assistant/enums/softwareManagers.dart';
import 'package:linux_assistant/helpers/command_helper.dart';
import 'package:linux_assistant/models/environment.dart';
import 'package:linux_assistant/services/config_handler.dart';
import 'package:linux_assistant/services/folder_recursion_depth.dart';
import 'package:linux_assistant/services/linux.dart';

/// Zeichnet auf, was stattgefunden haette, statt etwas zu starten.
class _RecordingRunner implements CommandRunner {
  /// Das Kommando, so wie es der Runner bekommen hat (bereits expandiert).
  final List<String> commands = <String>[];

  /// Die Argumente je Aufruf.
  final List<List<String>> argumentLists = <List<String>>[];

  /// Das `runInShell`-Flag je Aufruf.
  final List<bool> runInShellFlags = <bool>[];

  @override
  Future<CommandResult> run(
    String command,
    List<String> arguments, {
    Map<String, String>? environment,
    bool asRoot = false,
    bool hostOnFlatpak = true,
    bool runInShell = false,
  }) async {
    commands.add(command);
    argumentLists.add(List<String>.of(arguments));
    runInShellFlags.add(runInShell);
    return const CommandResult(true, "", "");
  }
}

void main() {
  late _RecordingRunner runner;

  setUp(() {
    runner = _RecordingRunner();
    CommandHelper.runner = runner;
  });

  tearDown(() {
    CommandHelper.runner = CommandHelper.processRunner;
  });

  group("Der Default der Kommandoebene ist: keine Shell", () {
    test("runCommandWithCustomArguments startet ohne Shell", () async {
      await Linux.runCommandWithCustomArguments("/usr/bin/true", const []);

      expect(runner.runInShellFlags, hasLength(1));
      expect(runner.runInShellFlags.single, isFalse);
    });

    test("runProcess reicht runInShell: false durch", () async {
      await Linux.runProcess("/usr/bin/true", const []);

      expect(runner.runInShellFlags, hasLength(1));
      expect(runner.runInShellFlags.single, isFalse);
    });

    test("runCommand (String-Form) startet ohne Shell", () async {
      await Linux.runCommand("/usr/bin/true");

      expect(runner.runInShellFlags, hasLength(1));
      expect(runner.runInShellFlags.single, isFalse);
    });
  });

  group("Ein Pfad mit Leerzeichen bleibt ein Argument", () {
    test("der Pfad kommt als ein argv-Element an", () async {
      const String path = "/home/user/My Documents/x.txt";

      await Linux.runCommandWithCustomArguments("/usr/bin/ls", [path]);

      expect(runner.argumentLists, hasLength(1));
      expect(runner.argumentLists.single, hasLength(1));
      expect(runner.argumentLists.single.single, path);
    });

    test(
        "Dart haelt das Argument auch dann zusammen, wenn es eine Shell "
        "baut", () async {
      // Beleg fuer den korrigierten Kommentar im Code: mit
      // `runInShell: true` space-joined Dart das argv nicht, es quotet jedes
      // Element einzeln. Ohne diesen Beleg waere die Korrektur wieder eine
      // Behauptung.
      const String path = "/home/user/My Documents/x.txt";

      final ProcessResult result =
          await Process.run("/usr/bin/echo", [path], runInShell: true);

      expect(result.exitCode, 0);
      expect(result.stdout.toString().trim(), path);
    });

    test("Shell-Metazeichen in einem Argument bleiben inert", () async {
      // Der alte Kommentar behauptete, ein Metazeichen wuerde ausgefuehrt.
      // Dart quotet es, also wird es nur durchgereicht.
      final Directory sandbox =
          Directory.systemTemp.createTempSync("mla_wp_s3_shell_");
      final String payload = "; touch ${sandbox.path}/pwned";
      addTearDown(() {
        if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
      });

      final ProcessResult result =
          await Process.run("/usr/bin/echo", [payload], runInShell: true);

      expect(result.exitCode, 0);
      expect(result.stdout.toString().trim(), payload);
      expect(File("${sandbox.path}/pwned").existsSync(), isFalse);
    });
  });

  group("Die Rekursionstiefe der Ordnersuche ist geklemmt", () {
    late Directory sandbox;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync("mla_wp_s3_depth_");
      ConfigHandler().resetForTesting(directory: sandbox);
    });

    tearDown(() {
      ConfigHandler().resetForTesting();
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test("eine zu kleine Tiefe wird auf 1 gehoben", () {
      ConfigHandler().setValueUnsafe("folder_recursion_depth", 0);

      expect(Linux.folderRecursionDepth(), 1);
    });

    test("eine zu grosse Tiefe wird auf 10 gesenkt", () {
      ConfigHandler().setValueUnsafe("folder_recursion_depth", 999);

      expect(Linux.folderRecursionDepth(), 10);
    });

    test("eine plausible Tiefe bleibt unveraendert", () {
      ConfigHandler().setValueUnsafe("folder_recursion_depth", 3);

      expect(Linux.folderRecursionDepth(), 3);
    });

    test("ein Textwert landet im Fallback und loest nichts aus", () {
      final Directory artifact =
          Directory.systemTemp.createTempSync("mla_wp_s3_inject_");
      addTearDown(() {
        if (artifact.existsSync()) artifact.deleteSync(recursive: true);
      });
      ConfigHandler().setValueUnsafe(
          "folder_recursion_depth", "'; touch ${artifact.path}/pwned");

      // Kein TypeError (der alte `final int`-Cast), sondern der Default.
      expect(Linux.folderRecursionDepth(), 3);
      expect(File("${artifact.path}/pwned").existsSync(), isFalse);
    });

    test("fehlt der Config-Wert, gilt der Default", () {
      expect(Linux.folderRecursionDepth(), kDefaultFolderRecursionDepth);
    });

    test("die Klemme nimmt eine Zahl als Text an", () {
      expect(clampFolderRecursionDepth("5"), 5);
    });

    test("die Klemme verwirft Werte, die keine Zahl sind", () {
      expect(clampFolderRecursionDepth(true), kDefaultFolderRecursionDepth);
      expect(clampFolderRecursionDepth(3.5), kDefaultFolderRecursionDepth);
      expect(clampFolderRecursionDepth(""), kDefaultFolderRecursionDepth);
      expect(clampFolderRecursionDepth(null), kDefaultFolderRecursionDepth);
      expect(clampFolderRecursionDepth(<int>[]), kDefaultFolderRecursionDepth);
    });
  });

  group("Der Disk-Analyzer startet nach der Installationspruefung", () {
    late Environment originalEnvironment;

    setUp(() {
      originalEnvironment = Linux.currentenvironment;
      Linux.currentenvironment = Environment()
        ..desktop = DESKTOPS.KDE
        ..installedSoftwareManagers = [SOFTWARE_MANAGERS.APT];
      Linux.commandQueue.clear();
    });

    tearDown(() {
      Linux.currentenvironment = originalEnvironment;
      Linux.commandQueue.clear();
    });

    testWidgets(
        "der Analyzer startet genau einmal, ohne Shell und nach dem Check",
        (WidgetTester tester) async {
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (BuildContext inner) {
          context = inner;
          return const SizedBox.shrink();
        }),
      ));

      await Linux.openDiskSpaceAnalyzer(context, "/mnt/data stick");

      // Der Installationscheck lief vor dem Start.
      expect(runner.commands, contains("/usr/bin/dpkg-query"));
      final int checkIndex = runner.commands.indexOf("/usr/bin/dpkg-query");
      final int launchIndex = runner.commands.indexOf("/usr/bin/k4dirstat");
      expect(launchIndex, greaterThan(checkIndex));

      // Genau ein Start — der alte Code startete bedingungslos und danach
      // ein zweites Mal.
      expect(runner.commands.where((String c) => c == "/usr/bin/k4dirstat"),
          hasLength(1));

      // Ohne Shell, und der Mountpoint ist ein Argument.
      expect(runner.runInShellFlags[launchIndex], isFalse);
      expect(runner.argumentLists[launchIndex], ["/mnt/data stick"]);
    });
  });
}
