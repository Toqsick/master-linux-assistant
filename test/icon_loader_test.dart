// WP-B2 (#45): the icon loader must hand the path to the helper as plain
// argv.
//
// The loader used to embed the path in a quoted string inside the argument
// (`--file='<path>'`), and the Python helper stripped the quotes again. The
// two only agreed because the one caller added exactly the quotes the one
// helper removed.
//
// The fix makes the contract explicit: the caller owns the encoding, the
// helper passes the value through. Two things follow from it:
//
// 1. the shell is no longer part of the path. It was never a split risk —
//    Dart quotes every argv element, so a path with a space stayed one
//    argument — but it was an unnecessary intermediary, and the repo's
//    established pattern is `runInShell: false` (six call sites in
//    `linux.dart`).
// 2. the helper no longer rewrites the value. A caller that passes the
//    plain path — which is what the loader does now — would have had a
//    path ending in a quote character truncated by the old shim. The pair
//    therefore has to change together.
//
// These tests pin both halves of that contract: the argv the loader builds,
// and the `runInShell` flag it uses.

import 'package:flutter_test/flutter_test.dart';
import 'package:linux_assistant/helpers/command_helper.dart';
import 'package:linux_assistant/services/icon_loader.dart';

/// Records what the icon loader would have started instead of starting it.
class _RecordingRunner implements CommandRunner {
  final List<List<String>> argumentLists = <List<String>>[];
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
    argumentLists.add(List<String>.of(arguments));
    runInShellFlags.add(runInShell);
    // "not found" keeps the loader on its default-icon branch, so the test
    // never touches the file system for an icon.
    return const CommandResult(true, "not found", "");
  }
}

void main() {
  late _RecordingRunner runner;

  setUp(() {
    runner = _RecordingRunner();
    CommandHelper.runner = runner;
    // The loader is a singleton with a widget cache; a cached entry would
    // skip the command entirely and make the test pass for the wrong reason.
    IconLoader().cache.clear();
  });

  tearDown(() {
    CommandHelper.runner = CommandHelper.processRunner;
    IconLoader().cache.clear();
  });

  group('IconLoader hands the path over as plain argv', () {
    test('a file path arrives as one argument, without quotes', () async {
      const String path = "/home/user/My Documents/annual report.txt";

      await IconLoader().getIconForAppOrFile(path);

      expect(runner.argumentLists, hasLength(1));
      final List<String> arguments = runner.argumentLists.single;
      expect(arguments, contains("--file=$path"));
      // The path must not be split over several arguments.
      expect(
          arguments.where((String a) => a.startsWith("--file=")), hasLength(1));
      // And it must not carry the quotes the old shim stripped again.
      expect(arguments, isNot(contains("--file='$path'")));
    });

    test('a path ending in a quote character survives unchanged', () async {
      const String path = "/home/user/odd name'.txt";

      await IconLoader().getIconForAppOrFile(path);

      expect(runner.argumentLists.single, contains("--file=$path"));
    });

    test('the folder lookup passes its path without quotes', () async {
      await IconLoader().getIconForAppOrFile("folder");

      expect(runner.argumentLists.single, contains("--file=/tmp/"));
      expect(runner.argumentLists.single, isNot(contains("--file='/tmp/'")));
    });

    test('the application lookup passes its code without quotes', () async {
      await IconLoader().getIconForAppOrFile("firefox");

      expect(runner.argumentLists.single, contains("--icon=firefox"));
    });
  });

  group('IconLoader does not run the helper through a shell', () {
    test('the file lookup runs without a shell', () async {
      await IconLoader().getIconForAppOrFile("/home/user/report.txt");

      expect(runner.runInShellFlags.single, isFalse);
    });

    test('the folder lookup runs without a shell', () async {
      await IconLoader().getIconForAppOrFile("folder");

      expect(runner.runInShellFlags.single, isFalse);
    });

    test('the application lookup runs without a shell', () async {
      await IconLoader().getIconForAppOrFile("firefox");

      expect(runner.runInShellFlags.single, isFalse);
    });
  });
}
