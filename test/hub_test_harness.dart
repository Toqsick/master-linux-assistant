// Shared host for the hub-navigation characterization tests (issue #60).
//
// Deliberately has no `main()` and no `test()` calls: it is imported by
// `hub_navigation_test.dart`, which owns the cases H1..H8. The cases are
// written against today's production code (`hub_shell.dart` with its switch
// blocks) and must stay green, unchanged, after that file is rebuilt on a
// registry.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/layouts/hub/hub_shell.dart';
import 'package:linux_assistant/layouts/mint_y.dart';

/// The app's real theme and localization wiring around a [HubShell].
///
/// Mirrors the `_host(...)` helper in `hermes_widgets_test.dart:18`, with the
/// locale/supported-locales lifted to parameters so the German case (H8) can
/// reuse it.
Widget buildHubHost({
  Locale locale = const Locale('en', ''),
  List<Locale> supportedLocales = const [Locale('en', '')],
  HubSection initialSection = HubSection.dashboard,
}) {
  return MaterialApp(
    theme: MintY.theme(),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: supportedLocales,
    locale: locale,
    home: Scaffold(body: HubShell(initialSection: initialSection)),
  );
}

/// Pins the test window to a desktop size.
///
/// Without this the surface is 800x600 logical pixels by default, which is
/// below the sidebar's `_collapseBreakpoint` (1000, hub_shell.dart:75) and
/// would render the icon rail instead of the labelled sidebar.
void useDesktopView(WidgetTester tester,
    {double width = 1200, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Real file IO started from the fake-async test zone needs several
/// drain-and-pump rounds to work through its await chain; one round only
/// advances it by a single hop (same pattern as `_drainRealIo` in
/// `quick_notes_widget_test.dart:12`).
Future<void> drainRealIo(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Text of the top bar's title.
///
/// `fontSize: 15` together with `FontWeight.w600` is set by exactly one Text
/// in the app — `HubShell._topBar` (hub_shell.dart:529-538). No section reuses
/// that combination, so the first such Text is unambiguously the title.
String topBarTitle(WidgetTester tester) {
  final Text title = tester.widgetList<Text>(find.byType(Text)).firstWhere(
        (t) =>
            t.style?.fontSize == 15 && t.style?.fontWeight == FontWeight.w600,
      );
  return title.data ?? '';
}
