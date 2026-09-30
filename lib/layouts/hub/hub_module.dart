import 'package:flutter/material.dart';
import 'package:la_core/la_core.dart' show ModuleDescriptor, ModuleKind;
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/layouts/hermes_tokens.dart';
import 'package:linux_assistant/layouts/hub/dashboard_section.dart';
import 'package:linux_assistant/layouts/hub/storage_section.dart';
import 'package:linux_assistant/layouts/linux_health/overview.dart';
import 'package:linux_assistant/layouts/main_screen/main_search.dart';
import 'package:linux_assistant/layouts/security_check/overview.dart';
import 'package:linux_assistant/layouts/tools/file_manager.dart';
import 'package:linux_assistant/layouts/tools/quick_notes.dart';
import 'package:linux_assistant/layouts/tools/system_monitor.dart';
import 'package:linux_assistant/models/environment.dart';

/// The sections reachable from the sidebar.
enum HubSection { dashboard, search, storage, health, security }

/// Quick-access tools in the sidebar's "Werkzeuge" section.
///
/// Two kinds live here: [HubTool.browser] fires a detached process launch and
/// never changes the active section, while screen-based tools
/// ([HubTool.quickNotes], [HubTool.fileManager], [HubTool.systemMonitor])
/// render inside the hub frame like a section – the frame then tracks them in
/// its `_screenTool` field.
enum HubTool { browser, quickNotes, fileManager, systemMonitor }

/// Feature tier, the vocabulary `MANIFEST.md` defines for this repo.
///
/// Nothing reads it yet: it is the seam issue #86 hangs the real navigation
/// (and a tier-ordered sidebar) on, pinned here so the nine modules cannot
/// drift apart in the meantime.
enum HubTier { core, qol, n2h }

/// What a screen may ask the shell to do.
///
/// Deliberately one method: a screen that wants to send the user somewhere
/// else (the dashboard's storage and security tiles today, #86 tomorrow) gets
/// exactly that and nothing more.
abstract interface class HubNavigator {
  void openSection(HubSection section);
}

/// Builds the widget for a module. No [BuildContext]: none of the nine
/// screens needs one at construction time.
typedef HubScreenBuilder = Widget Function(HubNavigator nav);

/// Resolves a module's sidebar and top-bar title.
///
/// A function rather than a key string on purpose: `l.hubStorage` is checked
/// by the compiler, so a renamed or missing ARB getter is a build error
/// instead of a blank label at runtime.
typedef HubTitle = String Function(AppLocalizations l10n);

/// Whether a module can be offered on this machine.
typedef HubAvailability = bool Function(Environment environment);

/// One navigable module: the Flutter half of a [ModuleDescriptor].
///
/// Composition, not inheritance — the pure descriptor stays a field. Extending
/// it would drag `la_core` into a Flutter-carrying class and turn every later
/// core change into a breaking change for the UI.
@immutable
class HubModule {
  const HubModule({
    required this.descriptor,
    required this.icon,
    required this.tier,
    required this.title,
    required this.screenBuilder,
    this.usesStats = false,
    this.isAvailable = alwaysAvailable,
  });

  /// The Flutter-free half, passed through unchanged (#59/#60 in `packages/la_core`).
  final ModuleDescriptor descriptor;

  final IconData icon;
  final HubTier tier;
  final HubTitle title;

  /// Never null. [HubTool.browser] is a launch module and returns
  /// `const SizedBox.shrink()`; its wiring hangs on [startsProcess], not on a
  /// missing builder.
  final HubScreenBuilder screenBuilder;

  /// Whether the section displays live system stats. Drives
  /// `SystemStatsService.setSectionActive` — polling a screen that shows no
  /// numbers is pure waste.
  final bool usesStats;

  final HubAvailability isAvailable;

  String get id => descriptor.id;
  String get titleKey => descriptor.titleKey;
  ModuleKind get kind => descriptor.kind;

  /// True for modules that only start a detached process and never occupy the
  /// content area.
  bool get startsProcess => descriptor.kind == ModuleKind.launch;

  /// Probe and action ids, passed through for #62 / #74. Nothing calls them yet.
  Set<String> get probes => descriptor.probeIds;
  Set<String> get actions => descriptor.actionIds;

  static bool alwaysAvailable(Environment _) => true;
}

/// The one place a module's enum value becomes a module.
///
/// Throws instead of returning null: a miss here means a module was added to
/// an enum without a registry entry, and that should be loud.
HubModule hubModuleOf(Object key) {
  if (key is! Enum) {
    throw StateError('hubModuleOf expects an enum value, got $key.');
  }
  final HubModule? module = hubModules[key.name];
  if (module == null) {
    throw StateError(
      'No HubModule registered for ${key.runtimeType}.${key.name}. '
      'Add it to hubModules in lib/layouts/hub/hub_module.dart.',
    );
  }
  return module;
}

/// The module registry.
///
/// Adding a module is one entry here plus its screen — no `switch` to extend.
/// Keys are the enum names; [hubModuleOf] is the only reader.
final Map<String, HubModule> hubModules = <String, HubModule>{
  'dashboard': HubModule(
    descriptor: const ModuleDescriptor(
      id: 'dashboard',
      titleKey: 'dashboard',
      viewId: 'dashboard',
      kind: ModuleKind.section,
    ),
    icon: Icons.dashboard_outlined,
    tier: HubTier.core,
    title: (l10n) => l10n.dashboard,
    usesStats: true,
    screenBuilder: (nav) => DashboardSection(
      onOpenStorage: () => nav.openSection(HubSection.storage),
      onOpenSecurity: () => nav.openSection(HubSection.security),
    ),
  ),
  'search': HubModule(
    descriptor: const ModuleDescriptor(
      id: 'search',
      titleKey: 'hubSearch',
      viewId: 'search',
      kind: ModuleKind.section,
    ),
    icon: Icons.search,
    tier: HubTier.core,
    title: (l10n) => l10n.hubSearch,
    // The search screen carries the memory/disk status row.
    usesStats: true,
    screenBuilder: (_) => MainSearch(embedded: true),
  ),
  'storage': HubModule(
    descriptor: const ModuleDescriptor(
      id: 'storage',
      titleKey: 'hubStorage',
      viewId: 'storage',
      kind: ModuleKind.section,
    ),
    icon: Icons.storage,
    tier: HubTier.core,
    title: (l10n) => l10n.hubStorage,
    usesStats: true,
    screenBuilder: (_) => const StorageSection(),
  ),
  'health': HubModule(
    descriptor: const ModuleDescriptor(
      id: 'health',
      titleKey: 'linuxHealth',
      viewId: 'health',
      kind: ModuleKind.section,
    ),
    icon: Icons.favorite_outline,
    tier: HubTier.core,
    title: (l10n) => l10n.linuxHealth,
    usesStats: true,
    screenBuilder: (_) => const Padding(
      padding: EdgeInsets.all(HermesTokens.space4),
      child: LinuxHealthContent(),
    ),
  ),
  'security': HubModule(
    descriptor: const ModuleDescriptor(
      id: 'security',
      titleKey: 'securityCheck',
      viewId: 'security',
      kind: ModuleKind.section,
    ),
    icon: Icons.shield_outlined,
    tier: HubTier.core,
    title: (l10n) => l10n.securityCheck,
    screenBuilder: (_) => const SecurityCheckContent(),
  ),
  // Launches a detached browser process; never becomes the active content key.
  'browser': HubModule(
    descriptor: const ModuleDescriptor(
      id: 'browser',
      titleKey: 'browser',
      viewId: 'browser',
      kind: ModuleKind.launch,
    ),
    icon: Icons.public,
    tier: HubTier.qol,
    title: (l10n) => l10n.browser,
    screenBuilder: (_) => const SizedBox.shrink(),
  ),
  'quickNotes': HubModule(
    descriptor: const ModuleDescriptor(
      id: 'quickNotes',
      titleKey: 'quickNotes',
      viewId: 'quickNotes',
      kind: ModuleKind.tool,
    ),
    icon: Icons.edit_note,
    tier: HubTier.qol,
    title: (l10n) => l10n.quickNotes,
    screenBuilder: (_) => const QuickNotesPage(),
  ),
  'fileManager': HubModule(
    descriptor: const ModuleDescriptor(
      id: 'fileManager',
      titleKey: 'fileManager',
      viewId: 'fileManager',
      kind: ModuleKind.tool,
    ),
    icon: Icons.folder_open,
    tier: HubTier.qol,
    title: (l10n) => l10n.fileManager,
    screenBuilder: (_) => const FileManagerPage(),
  ),
  // The system monitor shows live stats, but from its own 1-second sampler –
  // the shared 3-second poll stays off for tool screens.
  'systemMonitor': HubModule(
    descriptor: const ModuleDescriptor(
      id: 'systemMonitor',
      titleKey: 'systemMonitor',
      viewId: 'systemMonitor',
      kind: ModuleKind.tool,
    ),
    icon: Icons.monitor_heart,
    tier: HubTier.qol,
    title: (l10n) => l10n.systemMonitor,
    screenBuilder: (_) => const SystemMonitorPage(),
  ),
};
