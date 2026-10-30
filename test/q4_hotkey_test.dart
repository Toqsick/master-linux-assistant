import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linux_assistant/helpers/command_helper.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/layouts/main_screen/action_entry_card.dart';
import 'package:linux_assistant/layouts/main_screen/main_search.dart';
import 'package:linux_assistant/layouts/mint_y.dart';
import 'package:linux_assistant/models/action_entry.dart';
import 'package:linux_assistant/services/action_entry_list_service.dart';
import 'package:linux_assistant/services/config_handler.dart';
import 'package:linux_assistant/services/hotkey_diagnostics.dart';
import 'package:linux_assistant/services/linux.dart';

/// Tests for the Q4 rework of the keyboard shortcut (#58).
///
/// Two things are proved here:
///
/// 1. The report of the desktop's keybinding settings is parsed the way the
///    python script writes it — and a broken answer does not become an
///    exception.
/// 2. The keys of the search field work as plain Flutter shortcuts. That is
///    the proof that the global hotkey grab is really gone: the app does not
///    take the keys any more, the field itself reacts to them.
///
/// Everything runs hermetic: no desktop, no real process. The script call is
/// answered by a fake [CommandRunner] — the seam the app already has — and
/// the search screen runs against an in-memory entry list.
void main() {
  group("the report of the desktop", () {
    test("a valid report is parsed into the object the page shows", () {
      final String raw = jsonEncode({
        "desktop": "gnome",
        "session": "wayland",
        "binding": "<Super>q",
        "registered": true,
        "orphans": [
          {
            "path": "/org/gnome/settings-daemon/plugins/media-keys/"
                "custom-keybindings/custom3/",
            "binding": "<Super>q",
          }
        ],
      });

      final HotkeyReport report = HotkeyReport.parse(raw);

      expect(report.desktop, "gnome");
      expect(report.session, "wayland");
      expect(report.binding, "<Super>q");
      expect(report.registered, isTrue);
      expect(report.hasError, isFalse);
      expect(report.orphans, hasLength(1));
      expect(report.orphans.first.path, endsWith("custom3/"));
      expect(report.orphans.first.binding, "<Super>q");
    });

    test("a report without orphans is not an error", () {
      final HotkeyReport report = HotkeyReport.parse(jsonEncode({
        "desktop": "cinnamon",
        "session": "x11",
        "binding": "<Alt>q",
        "registered": true,
        "orphans": <Object>[],
      }));

      expect(report.registered, isTrue);
      expect(report.orphans, isEmpty);
      expect(report.hasError, isFalse);
    });

    test("broken JSON becomes a report that says 'not registered'", () {
      // No exception, no crash: the page has to be able to show this.
      final HotkeyReport report = HotkeyReport.parse("{ this is not json");

      expect(report.registered, isFalse);
      expect(report.hasError, isTrue);
      expect(report.error, isNotEmpty);
      expect(report.orphans, isEmpty);
    });

    test("empty output becomes a report that says 'not registered'", () {
      final HotkeyReport report = HotkeyReport.parse("   \n  ");

      expect(report.registered, isFalse);
      expect(report.hasError, isTrue);
    });

    test("JSON that is not an object becomes a report, not an exception", () {
      final HotkeyReport report = HotkeyReport.parse("[1, 2, 3]");

      expect(report.registered, isFalse);
      expect(report.hasError, isTrue);
    });

    test("missing fields do not crash and do not claim a shortcut", () {
      final HotkeyReport report = HotkeyReport.parse('{"desktop": "gnome"}');

      expect(report.desktop, "gnome");
      expect(report.session, "");
      expect(report.binding, "");
      // A missing field must never be read as "registered".
      expect(report.registered, isFalse);
      expect(report.orphans, isEmpty);
      expect(report.hasError, isFalse);
    });

    test("fields of the wrong type do not crash", () {
      final HotkeyReport report = HotkeyReport.parse(jsonEncode({
        "desktop": 42,
        "session": null,
        "binding": <String>["<Super>q"],
        "registered": "yes",
        "orphans": "not a list",
      }));

      expect(report.desktop, "");
      expect(report.session, "");
      expect(report.binding, "");
      expect(report.registered, isFalse);
      expect(report.orphans, isEmpty);
    });

    test("orphans of the wrong type are skipped, the rest is kept", () {
      final HotkeyReport report = HotkeyReport.parse(jsonEncode({
        "desktop": "gnome",
        "registered": true,
        "orphans": [
          "not an object",
          {"path": "/a/b/custom1/", "binding": "<Super>q"},
        ],
      }));

      expect(report.orphans, hasLength(1));
      expect(report.orphans.first.path, "/a/b/custom1/");
    });

    test("a JSON object in a noisy output is still found", () {
      // A warning of a wrapper script in front of the report must not make
      // the whole answer unusable.
      final HotkeyReport report = HotkeyReport.parse(
        "warning: something happened\n"
        '{"desktop": "xfce", "session": "x11", "binding": "<Super>q", '
        '"registered": true, "orphans": []}\n',
      );

      expect(report.desktop, "xfce");
      expect(report.registered, isTrue);
      expect(report.hasError, isFalse);
    });
  });

  group("reading the report from the script", () {
    late _FakeRunner runner;

    setUp(() {
      runner = _FakeRunner();
      CommandHelper.runner = runner;
      Linux.pythonScriptsFolder = "/opt/linux-assistant/additional/python/";
    });

    tearDown(() {
      CommandHelper.runner = CommandHelper.processRunner;
      Linux.pythonScriptsFolder = "";
    });

    test("the script is called with --report and its answer is parsed",
        () async {
      runner.result = () => const CommandResult(
            true,
            '{"desktop": "gnome", "session": "wayland", "binding": "<Super>q",'
                ' "registered": true, "orphans": []}',
            "",
          );

      final HotkeyReport report = await const HotkeyDiagnostics().loadReport();

      expect(report.registered, isTrue);
      expect(report.binding, "<Super>q");

      // The script is called with an argument list, never with a shell
      // string — and with the report mode, not with the registering one.
      expect(runner.calls, hasLength(1));
      expect(runner.calls.single.first, endsWith("python3"));
      expect(runner.calls.single[1], endsWith("setup_keybinding.py"));
      expect(runner.calls.single[2], "--report");
      expect(runner.calls.single, isNot(contains("--alt")));
    });

    test("a failing script becomes a report that says 'not registered'",
        () async {
      runner.result = () => const CommandResult(
            false,
            "",
            "No supported desktop found in XDG_CURRENT_DESKTOP=''",
          );

      final HotkeyReport report = await const HotkeyDiagnostics().loadReport();

      expect(report.registered, isFalse);
      expect(report.hasError, isTrue);
      expect(report.error, contains("No supported desktop"));
    });

    test("output that is not JSON becomes a report, not an exception",
        () async {
      runner.result = () => const CommandResult(true, "Traceback ...", "");

      final HotkeyReport report = await const HotkeyDiagnostics().loadReport();

      expect(report.registered, isFalse);
      expect(report.hasError, isTrue);
    });

    test("the cleanup calls the script with --cleanup", () async {
      runner.result = () => const CommandResult(true, "", "");

      final bool ok = await const HotkeyDiagnostics().cleanupOrphans();

      expect(ok, isTrue);
      expect(runner.calls.single[1], endsWith("setup_keybinding.py"));
      expect(runner.calls.single[2], "--cleanup");
    });

    test("a failing cleanup is reported as a failure", () async {
      runner.result = () => const CommandResult(false, "", "boom");

      final bool ok = await const HotkeyDiagnostics().cleanupOrphans();

      expect(ok, isFalse);
    });
  });

  group("the keys of the search field", () {
    late Directory sandbox;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync("mla_q4_hotkey_");
      ConfigHandler().resetForTesting(directory: sandbox);
      ActionEntryListService.clearEntries();
      // The priorities are different on purpose: the search sorts by
      // priority, and a stable order is what the assertions below are
      // about.
      ActionEntryListService.addEntries([
        ActionEntry(
          name: "Alpha result",
          description: "The first result",
          action: "alpha",
          priority: 30,
        ),
        ActionEntry(
          name: "Beta result",
          description: "The second result",
          action: "beta",
          priority: 20,
        ),
        ActionEntry(
          name: "Gamma result",
          description: "The third result",
          action: "gamma",
          priority: 10,
        ),
      ]);
    });

    tearDown(() {
      ConfigHandler().resetForTesting();
      ActionEntryListService.clearEntries();
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
    });

    testWidgets("arrow down moves the selection in the result list",
        (tester) async {
      _useDesktopView(tester);
      await tester.pumpWidget(_searchHost());
      await tester.pump();
      _swallowCardOverflow(tester);

      await tester.enterText(find.byType(TextField), "resu");
      await tester.pump();
      await tester.pump();
      _swallowCardOverflow(tester);

      // The list is there and the first entry is selected.
      expect(find.byType(ActionEntryCard), findsWidgets);
      expect(_selectedAction(tester), "alpha");

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(_selectedAction(tester), "beta");

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(_selectedAction(tester), "gamma");

      // The last entry of the list is the web search the search screen adds
      // for every term.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(_selectedAction(tester), "websearch:resu");

      // The list does not run past its end.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(_selectedAction(tester), "websearch:resu");

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(_selectedAction(tester), "gamma");

      await _tearDownSearch(tester);
    });

    testWidgets("escape empties the search field", (tester) async {
      _useDesktopView(tester);
      await tester.pumpWidget(_searchHost());
      await tester.pump();
      _swallowCardOverflow(tester);

      await tester.enterText(find.byType(TextField), "resu");
      await tester.pump();
      await tester.pump();
      _swallowCardOverflow(tester);

      expect(_searchText(tester), "resu");
      expect(find.byType(ActionEntryCard), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(_searchText(tester), isEmpty);
      // The result list is gone with the search term.
      expect(find.byType(ActionEntryCard), findsNothing);

      await _tearDownSearch(tester);
    });

    testWidgets("the keys only work while the search field has the focus",
        (tester) async {
      _useDesktopView(tester);
      await tester.pumpWidget(_searchHost());
      await tester.pump();
      _swallowCardOverflow(tester);

      await tester.enterText(find.byType(TextField), "resu");
      await tester.pump();
      await tester.pump();
      _swallowCardOverflow(tester);

      expect(_selectedAction(tester), "alpha");

      // Without the focus on the field, the key belongs to nobody: the
      // shortcut sits on the field, not on the window.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(_selectedAction(tester), "alpha");

      await _tearDownSearch(tester);
    });
  });
}

/// The app's own shell around the search screen.
Widget _searchHost() {
  return MaterialApp(
    theme: MintY.theme(),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en', '')],
    home: MainSearch(),
  );
}

/// Takes the search screen down at the end of a test.
///
/// The widgets that are on screen while the search is empty start processes,
/// and the start of a process is a timer. A timer that is still running when
/// the test ends counts as a failure, so it gets its turn before the tree
/// goes away.
Future<void> _tearDownSearch(WidgetTester tester) async {
  // A millisecond of fake time lets the timers of zero length run out: the
  // start of a process is one of them, and the disk space row starts one
  // every time it comes back into the screen.
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pumpWidget(const SizedBox());
  _swallowCardOverflow(tester);
}

/// Takes the layout overflow of the recommendation card out of the way.
///
/// The card at the bottom of the search screen gives its title no width
/// limit, so it overflows with the test font — every character is a full
/// font size wide there. That is a layout problem of the card and not of the
/// key handling, and the card is not part of this change, so the overflow is
/// taken out of the way here. Every other exception is a test failure.
void _swallowCardOverflow(WidgetTester tester) {
  const List<String> known = [
    "A RenderFlex overflowed",
    // The widget inspector trips over the tree that is being torn down
    // while it describes the overflow above.
    "Looking up a deactivated widget's ancestor is unsafe",
  ];
  while (true) {
    final Object? exception = tester.takeException();
    if (exception == null) {
      return;
    }
    final String text = exception.toString();
    if (!known.any(text.contains)) {
      throw exception;
    }
  }
}

/// Pins the test window to a desktop size.
///
/// The search screen puts its field and its buttons in one row. In the
/// default test surface (800x600) that row does not fit, and the overflow is
/// reported as a test error — the same overflow a user would never see on a
/// real desktop.
void _useDesktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The action of the entry that is currently selected, null when none is.
String? _selectedAction(WidgetTester tester) {
  final Iterable<ActionEntryCard> cards =
      tester.widgetList<ActionEntryCard>(find.byType(ActionEntryCard));
  for (final ActionEntryCard card in cards) {
    if (card.selected) {
      return card.actionEntry.action;
    }
  }
  return null;
}

/// The text in the search field.
String _searchText(WidgetTester tester) {
  final TextField field = tester.widget<TextField>(find.byType(TextField));
  return field.controller?.text ?? "";
}

/// A [CommandRunner] that answers with a prepared result and records the
/// calls. The script is never really started.
class _FakeRunner implements CommandRunner {
  /// Builds the result for one call.
  CommandResult Function() result = () => const CommandResult(true, "", "");

  /// Every call, as the argument list the runner received.
  final List<List<String>> calls = [];

  @override
  Future<CommandResult> run(
    String command,
    List<String> arguments, {
    Map<String, String>? environment,
    bool asRoot = false,
    bool hostOnFlatpak = true,
    bool runInShell = false,
  }) async {
    calls.add([command, ...arguments]);
    return result();
  }
}
