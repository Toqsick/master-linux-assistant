// Characterization tests for the hub module registry introduced by issue #60.
//
// `lib/layouts/hub/hub_module.dart` replaced the eight `switch` blocks that
// used to live in `hub_shell.dart`: the enums `HubSection`/`HubTool` moved into
// that file and `hub_shell.dart` re-exports them, and each enum value is now a
// `HubModule` in the top-level `hubModules` map. These cases pin the registry
// itself — bijection with the enums, the exact shape the switches encoded, the
// screen types they built, the `la_core` contract, the probes/actions
// pass-through, the ARB binding of every title, and the availability filter.
//
// Pure Dart: widgets are constructed but never mounted (no `testWidgets`), so
// the two sections that are un-pumpable (security runs pkexec on mount) are
// still covered through their `screenBuilder` return type.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_core/la_core.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/layouts/hub/dashboard_section.dart';
import 'package:linux_assistant/layouts/hub/hub_module.dart';
import 'package:linux_assistant/layouts/hub/storage_section.dart';
import 'package:linux_assistant/layouts/linux_health/overview.dart';
import 'package:linux_assistant/layouts/main_screen/main_search.dart';
import 'package:linux_assistant/layouts/security_check/overview.dart';
import 'package:linux_assistant/layouts/tools/file_manager.dart';
import 'package:linux_assistant/layouts/tools/quick_notes.dart';
import 'package:linux_assistant/layouts/tools/system_monitor.dart';
import 'package:linux_assistant/models/environment.dart';

/// A navigator that ignores everything: none of the nine `screenBuilder`s may
/// call back during construction, and a local stub keeps the case hermetic.
class _NoopNavigator implements HubNavigator {
  const _NoopNavigator();

  @override
  void openSection(HubSection section) {}
}

/// A no-op activator for the `ModuleRegistry` contract case.
class _NoopActivator implements ModuleActivator {
  @override
  Future<void> start(ModuleDescriptor module) async {}

  @override
  Future<void> stop(ModuleDescriptor module) async {}
}

/// Reads an ARB file into a `key -> value` map, dropping the `@`-prefixed
/// metadata entries (same idiom as `l10n_test.dart:23`).
Map<String, String> _arbStrings(String path) {
  final Map<String, dynamic> arb =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final MapEntry<String, dynamic> e in arb.entries)
      if (!e.key.startsWith('@') && e.value is String) e.key: e.value as String,
  };
}

/// The descriptor every ad-hoc `HubModule` in these cases shares.
const ModuleDescriptor _probeDescriptor = ModuleDescriptor(
  id: 'probe',
  titleKey: 'probe',
  viewId: 'probe',
  kind: ModuleKind.tool,
  probeIds: {'disk', 'ram'},
  actionIds: {'restart', 'flush'},
);

void main() {
  group('T1 bijection', () {
    test('hubModules keys mirror HubSection then HubTool, exactly nine', () {
      final List<String> expected = [
        for (final HubSection s in HubSection.values) s.name,
        for (final HubTool t in HubTool.values) t.name,
      ];
      expect(hubModules.keys.toList(), expected);
      expect(hubModules.length, 9);

      // module.id is the map key; titleKey is only a non-empty string here —
      // T2 pins the exact key each id carries.
      for (final MapEntry<String, HubModule> e in hubModules.entries) {
        expect(e.value.id, e.key);
        expect(e.value.titleKey, isNotEmpty);
      }
    });
  });

  group('T2 shape', () {
    test('icon, titleKey, kind, flags and tier match the deleted switches', () {
      final Map<
          String,
          ({
            IconData icon,
            String titleKey,
            ModuleKind kind,
            bool usesStats,
            bool startsProcess,
            HubTier tier,
          })> shape = {
        'dashboard': (
          icon: Icons.dashboard_outlined,
          titleKey: 'dashboard',
          kind: ModuleKind.section,
          usesStats: true,
          startsProcess: false,
          tier: HubTier.core,
        ),
        'search': (
          icon: Icons.search,
          titleKey: 'hubSearch',
          kind: ModuleKind.section,
          usesStats: true,
          startsProcess: false,
          tier: HubTier.core,
        ),
        'storage': (
          icon: Icons.storage,
          titleKey: 'hubStorage',
          kind: ModuleKind.section,
          usesStats: true,
          startsProcess: false,
          tier: HubTier.core,
        ),
        'health': (
          icon: Icons.favorite_outline,
          titleKey: 'linuxHealth',
          kind: ModuleKind.section,
          usesStats: true,
          startsProcess: false,
          tier: HubTier.core,
        ),
        'security': (
          icon: Icons.shield_outlined,
          titleKey: 'securityCheck',
          kind: ModuleKind.section,
          usesStats: false,
          startsProcess: false,
          tier: HubTier.core,
        ),
        'browser': (
          icon: Icons.public,
          titleKey: 'browser',
          kind: ModuleKind.launch,
          usesStats: false,
          startsProcess: true,
          tier: HubTier.qol,
        ),
        'quickNotes': (
          icon: Icons.edit_note,
          titleKey: 'quickNotes',
          kind: ModuleKind.tool,
          usesStats: false,
          startsProcess: false,
          tier: HubTier.qol,
        ),
        'fileManager': (
          icon: Icons.folder_open,
          titleKey: 'fileManager',
          kind: ModuleKind.tool,
          usesStats: false,
          startsProcess: false,
          tier: HubTier.qol,
        ),
        'systemMonitor': (
          icon: Icons.monitor_heart,
          titleKey: 'systemMonitor',
          kind: ModuleKind.tool,
          usesStats: false,
          startsProcess: false,
          tier: HubTier.qol,
        ),
      };

      expect(shape.length, hubModules.length);
      for (final MapEntry<String, HubModule> e in hubModules.entries) {
        final module = e.value;
        final want = shape[e.key]!;
        expect(module.icon, want.icon, reason: 'icon for ${e.key}');
        expect(module.titleKey, want.titleKey, reason: 'titleKey for ${e.key}');
        expect(module.kind, want.kind, reason: 'kind for ${e.key}');
        expect(module.usesStats, want.usesStats,
            reason: 'usesStats for ${e.key}');
        expect(module.startsProcess, want.startsProcess,
            reason: 'startsProcess for ${e.key}');
        expect(module.tier, want.tier, reason: 'tier for ${e.key}');
      }
    });
  });

  group('T3 screen type', () {
    const HubNavigator nav = _NoopNavigator();

    test('each id builds the widget its switch arm used to return', () {
      // hubModuleOf() takes the enum value (it throws on a bare String id).
      final Map<Enum, Type> expected = {
        HubSection.dashboard: DashboardSection,
        HubSection.search: MainSearch,
        HubSection.storage: StorageSection,
        HubSection.health: Padding,
        HubSection.security: SecurityCheckContent,
        HubTool.browser: SizedBox,
        HubTool.quickNotes: QuickNotesPage,
        HubTool.fileManager: FileManagerPage,
        HubTool.systemMonitor: SystemMonitorPage,
      };

      for (final MapEntry<Enum, Type> e in expected.entries) {
        final Widget widget = hubModuleOf(e.key).screenBuilder(nav);
        expect(widget.runtimeType, e.value,
            reason: 'screen type for ${e.key.name}');
      }

      // The health section is a LinuxHealthContent wrapped in a padded box.
      final Widget health = hubModuleOf(HubSection.health).screenBuilder(nav);
      expect((health as Padding).child, isA<LinuxHealthContent>());
    });
  });

  group('T4 la_core contract', () {
    test('the nine descriptors validate and duplicates are rejected', () {
      final registry = ModuleRegistry(activator: _NoopActivator());
      for (final HubModule module in hubModules.values) {
        registry.register(module.descriptor);
      }
      expect(registry.descriptors.length, 9);
      expect(registry.validate, returnsNormally);

      // validate() must be wired, not silently tolerant: re-registering an id
      // it already holds is a ModuleRegistryError.
      final ModuleDescriptor duplicate = hubModules.values.first.descriptor;
      expect(
        () => registry.register(duplicate),
        throwsA(isA<ModuleRegistryError>()),
      );
    });
  });

  group('T5 pass-through', () {
    test('probes and actions expose exactly the descriptor ids', () {
      const HubModule module = HubModule(
        descriptor: _probeDescriptor,
        icon: Icons.science_outlined,
        tier: HubTier.qol,
        title: _unusedTitle,
        screenBuilder: _emptyScreen,
      );
      expect(module.probes, equals(_probeDescriptor.probeIds));
      expect(module.actions, equals(_probeDescriptor.actionIds));
      expect(module.id, _probeDescriptor.id);
      expect(module.titleKey, _probeDescriptor.titleKey);
      expect(module.kind, _probeDescriptor.kind);
    });
  });

  group('T6 ARB binding', () {
    // One ARB file per supported locale; the delegate resolves each tag.
    const Map<String, String> arbFiles = {
      'en': 'lib/l10n/app_en.arb',
      'de': 'lib/l10n/app_de.arb',
      'it': 'lib/l10n/app_it.arb',
      'fi': 'lib/l10n/linuxassistant_fi.arb',
    };

    test('every title reads the ARB value behind its titleKey', () async {
      final Map<String, String> enArb = _arbStrings(arbFiles['en']!);
      // A misspelt titleKey would have no template entry at all.
      for (final HubModule module in hubModules.values) {
        expect(enArb.containsKey(module.titleKey), isTrue,
            reason: 'titleKey ${module.titleKey} is not in the EN template');
      }

      for (final MapEntry<String, String> locale in arbFiles.entries) {
        final AppLocalizations l10n =
            await AppLocalizations.delegate.load(Locale(locale.key));
        final Map<String, String> arb = _arbStrings(locale.value);

        for (final HubModule module in hubModules.values) {
          // The fi ARB has no entry for the four section keys (dashboard,
          // hubSearch, hubStorage, linuxHealth): the generator falls back to
          // the ENGLISH template, so that fallback is the expected value there.
          final String expected =
              arb[module.titleKey] ?? enArb[module.titleKey]!;
          expect(module.title(l10n), expected,
              reason: '${locale.key}.${module.titleKey}');
        }
      }
    });
  });

  group('T7 availability', () {
    test('all nine are available, and the false path is reachable', () {
      for (final HubModule module in hubModules.values) {
        expect(module.isAvailable(Environment()), isTrue,
            reason: 'availability of ${module.id}');
      }

      // Today every real module uses alwaysAvailable; a local module with a
      // blocking predicate proves the filter branch exists and is honoured.
      final HubModule unavailable = HubModule(
        descriptor: _probeDescriptor,
        icon: Icons.science_outlined,
        tier: HubTier.qol,
        title: _unusedTitle,
        screenBuilder: _emptyScreen,
        isAvailable: (_) => false,
      );
      expect(unavailable.isAvailable(Environment()), isFalse);
    });
  });
}

/// Constant title/screen stubs for the ad-hoc modules (never rendered).
String _unusedTitle(AppLocalizations l10n) => '';
Widget _emptyScreen(HubNavigator nav) => const SizedBox.shrink();
