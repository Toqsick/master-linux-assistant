// Guards the one branch of the search that starts a process on something the
// user only clicked: an executable file surfaced from the recent-files or
// favorites index. Running it is a real action, so it has to be confirmed
// first — and declining has to leave the search list exactly as it was.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/models/action_entry.dart';
import 'package:linux_assistant/services/action_handler.dart';
import 'package:linux_assistant/services/config_handler.dart';

/// Wraps the harness in the app's localizations: the confirmation dialog reads
/// its strings from there.
Widget _host(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en', '')],
    locale: const Locale('en', ''),
    home: Scaffold(body: child),
  );
}

/// Stand-in for a search result card: clicking it hands the entry to the action
/// handler the same way the real card does.
class _EntryButton extends StatelessWidget {
  const _EntryButton({required this.entry, required this.callback});

  final ActionEntry entry;
  final VoidCallback callback;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => unawaited(
            ActionHandler.handleActionEntry(entry, callback, context)),
        child: const Text("entry"),
      ),
    );
  }
}

void main() {
  const String file = "/home/user/Downloads/payload.sh";

  late Directory sandbox;
  late List<String> executed;
  late List<String> opened;
  late int cleared;

  ActionEntry entry() => ActionEntry(
      name: "payload.sh", description: file, action: "openfile:$file");

  /// Runs the widget test against a handler whose three process calls are
  /// captured instead of performed.
  Future<void> pumpEntry(WidgetTester tester,
      {required bool isExecutable}) async {
    ActionHandler.debugOverride(
      executableChecker: (_) async => isExecutable,
      terminalRunner: (path) async => executed.add(path),
      fileOpener: (exec, arguments) async =>
          opened.add(<String>[exec, ...arguments].join(" ")),
    );
    await tester.pumpWidget(
        _host(_EntryButton(entry: entry(), callback: () => cleared++)));
  }

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync("la-action-handler-test");
    final ConfigHandler config = ConfigHandler();
    config.resetForTesting(directory: sandbox);
    // Keeps the handler out of the config file: with self-learning on it writes
    // `opened.<action>` before reaching the branch under test, and that file
    // I/O never completes inside a widget test's fake async zone.
    config.setValueUnsafe("self_learning_search", false);

    executed = [];
    opened = [];
    cleared = 0;
  });

  tearDown(() {
    ActionHandler.resetOverrides();
    ConfigHandler().resetForTesting();
    if (sandbox.existsSync()) {
      sandbox.deleteSync(recursive: true);
    }
  });

  group("openfile: on an executable file", () {
    testWidgets("asks first, and starts the file only once confirmed",
        (tester) async {
      await pumpEntry(tester, isExecutable: true);

      await tester.tap(find.text("entry"));
      await tester.pumpAndSettle();

      // While the question is open, nothing may have started yet.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(executed, isEmpty);
      // The dialog has to name the file: the terminal window only shows it
      // once the process is already running.
      expect(find.textContaining(file), findsOneWidget);

      await tester.tap(find.text("Execute in terminal"));
      await tester.pumpAndSettle();

      expect(executed, <String>[file]);
      expect(opened, isEmpty);
      expect(cleared, 1);
    });

    testWidgets("starts nothing when declined and keeps the search open",
        (tester) async {
      await pumpEntry(tester, isExecutable: true);

      await tester.tap(find.text("entry"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Cancel"));
      await tester.pumpAndSettle();

      expect(executed, isEmpty);
      expect(opened, isEmpty);
      // The list stays where it was: the user said no, so nothing is dismissed.
      expect(cleared, 0);
    });
  });

  group("openfile: on a regular file", () {
    testWidgets("opens it with the default application without asking",
        (tester) async {
      await pumpEntry(tester, isExecutable: false);

      await tester.tap(find.text("entry"));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(opened, <String>["xdg-open $file"]);
      expect(executed, isEmpty);
      expect(cleared, 1);
    });
  });
}
