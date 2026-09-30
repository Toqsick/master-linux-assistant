// Characterization tests for the hub navigation (issue #60, acceptance
// criterion "Verhalten unverändert").
//
// These are written against TODAY's production code and must stay green,
// unchanged, after `hub_shell.dart` is rebuilt from switch blocks onto a
// registry. If one turns red after the rebuild, the rebuild changed behaviour.
//
// Hermeticity notes:
//  * The "Search" and "Security Check" sections are never tapped here: Search
//    loads the search index through `main_search_loader`, and Security Check
//    starts `pkexec` on mount (lib/layouts/security_check/overview.dart:54).
//  * No `pumpAndSettle` anywhere — the system monitor (and section screens)
//    can hold live tickers/timers that never settle.
//  * QuickNotes/FileManager do real file IO under the fake clock, so those
//    pumps go through `drainRealIo`; their contents are never asserted.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linux_assistant/layouts/hub/dashboard_section.dart';
import 'package:linux_assistant/layouts/hub/storage_section.dart';
import 'package:linux_assistant/layouts/tools/quick_notes.dart';
import 'package:linux_assistant/services/app_launcher.dart';
import 'package:linux_assistant/services/system_stats_service.dart';
import 'package:linux_assistant/widgets/hermes/hermes_nav_item.dart';

import 'hub_test_harness.dart';

/// The ten sidebar rows in tree order (English locale).
///
/// The first nine come from `_titleOf`/`_titleOfTool`; "Setting" is the
/// separate entry after the divider (`l10n.settings`) and deliberately lives
/// outside the module list.
const List<String> kSidebarLabels = <String>[
  'Dashboard',
  'Search',
  'Storage',
  'Linux health',
  'Security Check',
  'Browser',
  'Quick Notes',
  'File manager',
  'System monitor',
  'Setting',
];

/// The labels that count as "section entry + settings" in H5 — i.e. every
/// sidebar row except the four tools.
const Set<String> kSectionAndSettingsLabels = <String>{
  'Dashboard',
  'Search',
  'Storage',
  'Linux health',
  'Security Check',
  'Setting',
};

List<HermesNavItem> _navItems(WidgetTester tester) =>
    tester.widgetList<HermesNavItem>(find.byType(HermesNavItem)).toList();

HermesNavItem _navItem(WidgetTester tester, String label) =>
    _navItems(tester).firstWhere((i) => i.label == label);

Finder _navTap(String label) => find.widgetWithText(HermesNavItem, label);

IndexedStack _stack(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byType(IndexedStack));

void main() {
  setUp(() {
    // Order matters: resetForTesting restores `_windowVisible = true`
    // (system_stats_service.dart:252-260), so the visibility flag has to be
    // flipped afterwards. With windowVisible == false `_shouldPoll` stays
    // false and no Timer.periodic / ps/df/free fork ever starts.
    SystemStatsService().resetForTesting();
    SystemStatsService().setWindowVisible(false);
  });

  tearDown(() {
    AppLauncher.resetOverrides();
    SystemStatsService().resetForTesting();
  });

  testWidgets('H1 sidebar shows the nine modules and settings in order',
      (tester) async {
    useDesktopView(tester);
    await tester.pumpWidget(buildHubHost());
    await tester.pump();

    expect(
      _navItems(tester).map((i) => i.label).toList(),
      kSidebarLabels,
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('H2 each module carries its own icon', (tester) async {
    useDesktopView(tester);
    await tester.pumpWidget(buildHubHost());
    await tester.pump();

    const expected = <String, IconData>{
      'Dashboard': Icons.dashboard_outlined,
      'Search': Icons.search,
      'Storage': Icons.storage,
      'Linux health': Icons.favorite_outline,
      'Security Check': Icons.shield_outlined,
      'Browser': Icons.public,
      'Quick Notes': Icons.edit_note,
      'File manager': Icons.folder_open,
      'System monitor': Icons.monitor_heart,
    };
    for (final entry in expected.entries) {
      expect(_navItem(tester, entry.key).icon, entry.value, reason: entry.key);
    }

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'H3 "TOOLS" appears once, between the last section and first tool',
      (tester) async {
    useDesktopView(tester);
    await tester.pumpWidget(buildHubHost());
    await tester.pump();

    expect(find.text('TOOLS'), findsOneWidget);
    final double toolsY = tester.getCenter(find.text('TOOLS')).dy;
    final double securityY = tester.getCenter(find.text('Security Check')).dy;
    final double browserY = tester.getCenter(find.text('Browser')).dy;
    expect(toolsY, greaterThan(securityY));
    expect(toolsY, lessThan(browserY));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('H4 switching to Storage moves the stack, ticker and selection',
      (tester) async {
    useDesktopView(tester);
    await tester.pumpWidget(buildHubHost());
    await tester.pump();

    expect(_stack(tester).index, 0);

    await tester.tap(_navTap('Storage'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(_stack(tester).index, 1);
    expect(topBarTitle(tester), 'Storage');

    // The IndexedStack children are TickerMode wrappers (hub_shell.dart:302-320).
    TickerMode tickerFor(Type type) => tester.widget<TickerMode>(
          find
              .ancestor(
                of: find.byType(type, skipOffstage: false),
                matching: find.byType(TickerMode, skipOffstage: false),
              )
              .first,
        );
    expect(tickerFor(StorageSection).enabled, isTrue);
    expect(tickerFor(DashboardSection).enabled, isFalse);

    expect(_navItem(tester, 'Storage').selected, isTrue);
    expect(_navItem(tester, 'Dashboard').selected, isFalse);

    // The nav row reports its selected state to accessibility
    // (hermes_nav_item.dart:76).
    final handle = tester.ensureSemantics();
    final int storageIndex =
        _navItems(tester).indexWhere((i) => i.label == 'Storage');
    final node =
        tester.getSemantics(find.byType(HermesNavItem).at(storageIndex));
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
    handle.dispose();

    await tester.tap(_navTap('Dashboard'));
    await tester.pump();
    expect(_stack(tester).index, 0);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('H5 Quick Notes is a screen tool and selects no section',
      (tester) async {
    useDesktopView(tester);
    await tester.pumpWidget(buildHubHost());
    await tester.pump();

    await tester.tap(_navTap('Quick Notes'));
    await tester.pump();
    // QuickNotesPage runs real file IO from initState — drain it.
    await drainRealIo(tester);

    expect(topBarTitle(tester), 'Quick Notes');
    expect(find.byType(QuickNotesPage), findsOneWidget);

    for (final item in _navItems(tester)) {
      if (kSectionAndSettingsLabels.contains(item.label)) {
        expect(item.selected, isFalse, reason: item.label);
      }
    }
    // The tool row itself is the selected one while its screen is open.
    expect(_navItem(tester, 'Quick Notes').selected, isTrue);

    await tester.tap(_navTap('Dashboard'));
    await tester.pump();
    expect(_stack(tester).index, 0);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('H6 Browser launches a process but never changes the section',
      (tester) async {
    useDesktopView(tester);
    final launched = <String>[];
    AppLauncher.debugOverride(
      whichRunner: (binary) async => binary == 'brave',
      processStarter: (binary, args) async {
        launched.add(binary);
        return true;
      },
    );

    await tester.pumpWidget(buildHubHost());
    await tester.pump();

    final int childrenBefore = _stack(tester).children.length;

    await tester.tap(_navTap('Browser'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(launched, contains('brave'));
    // No new screen was registered — the browser is not a screen tool.
    expect(_stack(tester).children.length, childrenBefore);
    expect(_navItem(tester, 'Dashboard').selected, isTrue);
    expect(topBarTitle(tester), 'Dashboard');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('H7 a narrow window collapses the sidebar to an icon rail',
      (tester) async {
    useDesktopView(tester, width: 900, height: 800);
    await tester.pumpWidget(buildHubHost());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(_navItems(tester).every((i) => i.collapsed), isTrue);
    // No module label is rendered inside a nav row any more (the top bar's
    // title text is a separate, non-nav Text and does not count).
    for (final label in kSidebarLabels) {
      expect(find.widgetWithText(HermesNavItem, label), findsNothing,
          reason: label);
    }
    // ... but the icons are all there.
    expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
    expect(find.byIcon(Icons.favorite_outline), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.byIcon(Icons.public), findsOneWidget);
    expect(find.byIcon(Icons.edit_note), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
    expect(find.byIcon(Icons.monitor_heart), findsOneWidget);
    // The "TOOLS" section header is suppressed in rail mode.
    expect(find.text('TOOLS'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('H8 the tool titles come from the German locale', (tester) async {
    useDesktopView(tester);
    await tester.pumpWidget(buildHubHost(
      locale: const Locale('de', ''),
      supportedLocales: const [Locale('de', '')],
    ));
    await tester.pump();

    expect(find.text('Dateimanager'), findsOneWidget);
    expect(find.text('Systemmonitor'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  // H9 was added after the rebuild: it needs `SystemStatsService.sectionActive`,
  // the read-only getter the rebuild introduced. H1..H8 above are unchanged and
  // were green against the switch-based code — this one could not be.
  //
  // The coupling is only observable through that getter (the alternative is
  // watching for real ps/df/free forks), so the flag stands in for "the poll
  // runs". Security Check and System monitor are avoided on purpose: pkexec on
  // mount, and a Ticker-driven sampler.
  testWidgets('H9 a stats section turns the poll on, a screen tool off',
      (tester) async {
    useDesktopView(tester);
    await tester.pumpWidget(buildHubHost());
    await tester.pump();

    expect(SystemStatsService().sectionActive, isTrue,
        reason: 'dashboard consumes stats');

    await tester.tap(_navTap('Quick Notes'));
    await tester.pump();
    await drainRealIo(tester);
    expect(SystemStatsService().sectionActive, isFalse,
        reason: 'a tool screen shows no live stats');

    await tester.tap(_navTap('Dashboard'));
    await tester.pump();
    await drainRealIo(tester);
    expect(SystemStatsService().sectionActive, isTrue,
        reason: 'returning to a section resumes the poll');

    await tester.pumpWidget(const SizedBox());
  });
}
