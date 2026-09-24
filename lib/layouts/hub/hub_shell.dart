import 'package:flutter/material.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/layouts/hermes_tokens.dart';
import 'package:linux_assistant/layouts/hub/dashboard_section.dart';
import 'package:linux_assistant/layouts/hub/storage_section.dart';
import 'package:linux_assistant/layouts/linux_health/overview.dart';
import 'package:linux_assistant/layouts/main_screen/main_search.dart';
import 'package:linux_assistant/layouts/security_check/overview.dart';
import 'package:linux_assistant/layouts/settings/settings_start.dart';
import 'package:linux_assistant/layouts/tools/file_manager.dart';
import 'package:linux_assistant/layouts/tools/quick_notes.dart';
import 'package:linux_assistant/layouts/tools/system_monitor.dart';
import 'package:linux_assistant/main.dart';
import 'package:linux_assistant/services/app_launcher.dart';
import 'package:linux_assistant/services/system_stats_service.dart';
import 'package:linux_assistant/services/theme_controller.dart';
import 'package:linux_assistant/widgets/hermes/hermes_nav_item.dart';
import 'package:window_manager/window_manager.dart';

/// The sections reachable from the sidebar.
enum HubSection { dashboard, search, storage, health, security }

/// Quick-access tools in the sidebar's "Werkzeuge" section.
///
/// Two kinds live here: [HubTool.browser] fires a detached process launch and
/// never changes the active section, while screen-based tools
/// ([HubTool.quickNotes], [HubTool.fileManager], [HubTool.systemMonitor])
/// render inside the hub frame like a section – the frame then tracks them in
/// [_screenTool].
enum HubTool { browser, quickNotes, fileManager, systemMonitor }

/// Whether a section displays live system stats.
///
/// Sections that do not are told to the [SystemStatsService] so it can stop
/// polling instead of collecting numbers nobody is looking at.
bool _sectionUsesStats(HubSection section) {
  switch (section) {
    case HubSection.dashboard:
    case HubSection.storage:
    case HubSection.health:
      return true;
    case HubSection.search:
      // The search screen carries the memory/disk status row.
      return true;
    case HubSection.security:
      return false;
  }
}

/// The persistent frame of the hub: sidebar, top bar and the active section.
///
/// Sections are swapped inside the frame rather than pushed onto the
/// [Navigator]. The app's existing convention is to "go back" by pushing the
/// destination again, which grows the history without bound; keeping section
/// changes out of the navigator avoids adding to that.
class HubShell extends StatefulWidget {
  const HubShell({super.key, this.initialSection = HubSection.dashboard});

  final HubSection initialSection;

  /// Set while a hub is mounted, so the global hotkey can jump straight to the
  /// search section instead of only raising the window.
  static VoidCallback? onSearchRequested;

  @override
  State<HubShell> createState() => _HubShellState();
}

class _HubShellState extends State<HubShell>
    with WindowListener, WidgetsBindingObserver {
  static const double _sidebarWidth = 260;
  static const double _railWidth = 56;

  /// Below this width the sidebar collapses to an icon rail.
  static const double _collapseBreakpoint = 1000;

  late HubSection _section = widget.initialSection;

  /// Set while a screen-based tool (e.g. Quick Notes) occupies the content
  /// area. The last visited [_section] is kept so leaving the tool returns
  /// exactly where the user was.
  HubTool? _screenTool;

  /// Sections and screen tools are created on first visit and then kept
  /// alive. Building them all up front would start every section's polling
  /// and let the search field steal focus while the dashboard is on screen.
  final Map<Object, Widget> _built = {};

  @override
  void initState() {
    super.initState();
    // While the hub is open, dismissing a search result should return here
    // rather than minimizing the window.
    MainSearch.onDismiss = _returnToDashboard;
    HubShell.onSearchRequested = _focusSearch;
    windowManager.addListener(this);
    // Two independent signals for the same question, because neither is
    // reliable alone on Linux: window_manager's minimize event needs a window
    // manager that reports the state change, and the Flutter lifecycle state
    // is not delivered by every desktop either.
    WidgetsBinding.instance.addObserver(this);
    SystemStatsService().setSectionActive(_sectionUsesStats(_section));
  }

  @override
  void dispose() {
    if (MainSearch.onDismiss == _returnToDashboard) {
      MainSearch.onDismiss = null;
    }
    if (HubShell.onSearchRequested == _focusSearch) {
      HubShell.onSearchRequested = null;
    }
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    // Leave the service in the state a non-hub screen expects.
    SystemStatsService().setSectionActive(true);
    SystemStatsService().setWindowVisible(true);
    super.dispose();
  }

  // Minimizing is the case that matters: the hub keeps every visited section
  // alive, so nothing else would ever stop the three-second poll.
  @override
  void onWindowMinimize() => SystemStatsService().setWindowVisible(false);

  @override
  void onWindowRestore() => SystemStatsService().setWindowVisible(true);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    SystemStatsService().setWindowVisible(
      state == AppLifecycleState.resumed || state == AppLifecycleState.inactive,
    );
  }

  void _focusSearch() => _select(HubSection.search);

  void _returnToDashboard() => _select(HubSection.dashboard);

  void _select(HubSection section) {
    if (!mounted || (_section == section && _screenTool == null)) {
      return;
    }
    setState(() {
      _section = section;
      _screenTool = null;
    });
    SystemStatsService().setSectionActive(_sectionUsesStats(section));
  }

  /// Hands the content area to a screen-based tool. The underlying section
  /// stays selected underneath, so returning to it loses no state.
  ///
  /// Note: the system monitor shows live stats, but from its own 1-second
  /// sampler – the shared 3-second poll stays off for tool screens.
  void _selectTool(HubTool tool) {
    if (!mounted || _screenTool == tool) {
      return;
    }
    setState(() => _screenTool = tool);
    // Tool screens show no live stats – stop the poll like a stats-less
    // section would.
    SystemStatsService().setSectionActive(false);
  }

  /// Starts the configured or XDG default browser as a detached process.
  ///
  /// Feedback mirrors the [BrowserLaunchResult]: silent on preferred launch,
  /// informational snackbar on the known-browsers list fallback, error
  /// snackbar when no browser could be found or started at all.
  Future<void> _launchBrowser() async {
    final result = await AppLauncher.launchBrowser();
    if (!mounted) return;
    switch (result) {
      case BrowserLaunchResult.launchedPreferred:
        break; // Nothing to report – the browser window is the feedback.
      case BrowserLaunchResult.launchedFallback:
        _showSnack(_tr(context,
            de: 'Standard-Browser nicht ermittelbar – ersatzweise bekannten Browser gestartet.',
            en: 'Default browser unavailable – started a known browser instead.'));
        break;
      case BrowserLaunchResult.failed:
        _showSnack(_tr(context,
            de: 'Kein Browser gefunden.', en: 'No browser found.'));
        break;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _titleOf(BuildContext context, HubSection section) {
    final l10n = AppLocalizations.of(context)!;
    switch (section) {
      case HubSection.dashboard:
        return l10n.dashboard;
      case HubSection.search:
        return l10n.hubSearch;
      case HubSection.storage:
        return l10n.hubStorage;
      case HubSection.health:
        return l10n.linuxHealth;
      case HubSection.security:
        return l10n.securityCheck;
    }
  }

  IconData _iconOf(HubSection section) {
    switch (section) {
      case HubSection.dashboard:
        return Icons.dashboard_outlined;
      case HubSection.search:
        return Icons.search;
      case HubSection.storage:
        return Icons.storage;
      case HubSection.health:
        return Icons.favorite_outline;
      case HubSection.security:
        return Icons.shield_outlined;
    }
  }

  IconData _iconOfTool(HubTool tool) {
    switch (tool) {
      case HubTool.browser:
        return Icons.public;
      case HubTool.quickNotes:
        return Icons.edit_note;
      case HubTool.fileManager:
        return Icons.folder_open;
      case HubTool.systemMonitor:
        return Icons.monitor_heart;
    }
  }

  String _titleOfTool(BuildContext context, HubTool tool) {
    switch (tool) {
      case HubTool.browser:
        return _tr(context, de: 'Browser', en: 'Browser');
      case HubTool.quickNotes:
        return _tr(context, de: 'Quick Notes', en: 'Quick Notes');
      case HubTool.fileManager:
        return _tr(context, de: 'Dateimanager', en: 'File manager');
      case HubTool.systemMonitor:
        return _tr(context, de: 'Systemmonitor', en: 'System monitor');
    }
  }

  /// Minimal de/en lookup for the Werkzeuge section.
  ///
  /// TODO(l10n): Move these strings into the .arb files
  /// (`tools`, `browser`, `quickNotes`, `fileManager`, `systemMonitor`) and
  /// regenerate with `flutter gen-l10n`. The .arb files are ~40 KB each and
  /// were not editable via API at implementation time.
  static String _tr(BuildContext context,
      {required String de, required String en}) {
    return Localizations.localeOf(context).languageCode == 'de' ? de : en;
  }

  Widget _buildSection(HubSection section) {
    switch (section) {
      case HubSection.dashboard:
        return DashboardSection(
          onOpenStorage: () => _select(HubSection.storage),
          onOpenSecurity: () => _select(HubSection.security),
        );
      case HubSection.search:
        return MainSearch(embedded: true);
      case HubSection.storage:
        return const StorageSection();
      case HubSection.health:
        return const Padding(
          padding: EdgeInsets.all(HermesTokens.space4),
          child: LinuxHealthContent(),
        );
      case HubSection.security:
        return const SecurityCheckContent();
    }
  }

  Widget _contentFor(Object key) {
    if (key is HubTool) {
      switch (key) {
        case HubTool.quickNotes:
          return const QuickNotesPage();
        case HubTool.fileManager:
          return const FileManagerPage();
        case HubTool.systemMonitor:
          return const SystemMonitorPage();
        case HubTool.browser:
          // Never on screen: the browser tool launches an external process
          // and is never assigned as the active content key.
          return const SizedBox.shrink();
      }
    }
    return _buildSection(key as HubSection);
  }

  Widget _content() {
    final Object active = _screenTool ?? _section;
    _built.putIfAbsent(active, () => _contentFor(active));
    final visited = _built.keys.toList();

    return IndexedStack(
      index: visited.indexOf(active),
      children: [
        for (final key in visited)
          // Stops animations in screens that are currently off screen. The
          // system monitor relies on this: its sampler is Ticker-driven, so
          // leaving the tool stops its 1-second polling for free.
          TickerMode(
            enabled: key == active,
            child: _built[key]!,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = HermesTokens.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool collapsed = constraints.maxWidth < _collapseBreakpoint;

        return Scaffold(
          backgroundColor: t.bg,
          body: Row(
            children: [
              _sidebar(context, t, collapsed),
              Expanded(
                child: Column(
                  children: [
                    _topBar(context, t),
                    Expanded(child: _content()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sidebar(BuildContext context, HermesTokens t, bool collapsed) {
    final l10n = AppLocalizations.of(context)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: collapsed ? _railWidth : _sidebarWidth,
      decoration: BoxDecoration(
        color: t.sidebar,
        border: Border(
          right: BorderSide(color: t.border, width: HermesTokens.borderWidth),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(context, t, collapsed),
          Divider(color: t.borderSubtle, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: HermesTokens.space2,
                vertical: HermesTokens.space2,
              ),
              children: [
                for (final section in HubSection.values)
                  HermesNavItem(
                    icon: _iconOf(section),
                    label: _titleOf(context, section),
                    selected: _screenTool == null && _section == section,
                    collapsed: collapsed,
                    onTap: () => _select(section),
                  ),
                // Werkzeuge-Sektion (Admin-Hub, Spec: docs/design/feature-spec-admin-hub.md).
                // Browser startet detached (kein Sectionswechsel); Quick Notes,
                // Dateimanager und Systemmonitor rendern im Hub-Frame
                // (Screen-Tools).
                if (!collapsed) _sectionLabel(context, t),
                for (final tool in HubTool.values)
                  HermesNavItem(
                    icon: _iconOfTool(tool),
                    label: _titleOfTool(context, tool),
                    selected: _screenTool == tool,
                    collapsed: collapsed,
                    onTap: () => _onToolTap(tool),
                  ),
              ],
            ),
          ),
          Divider(color: t.borderSubtle, height: 1),
          Padding(
            padding: const EdgeInsets.all(HermesTokens.space2),
            child: HermesNavItem(
              icon: Icons.settings_outlined,
              label: l10n.settings,
              selected: false,
              collapsed: collapsed,
              onTap: () => showDialog(
                context: context,
                builder: (context) => const SettingsStart(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onToolTap(HubTool tool) {
    switch (tool) {
      case HubTool.browser:
        _launchBrowser();
        break;
      case HubTool.quickNotes:
        _selectTool(HubTool.quickNotes);
        break;
      case HubTool.fileManager:
        _selectTool(HubTool.fileManager);
        break;
      case HubTool.systemMonitor:
        _selectTool(HubTool.systemMonitor);
        break;
    }
  }

  /// Section header in the style of the storage screen's
  /// "EINGEBUNDENE DATENTRÄGER": small, muted, uppercase, letter-spaced.
  Widget _sectionLabel(BuildContext context, HermesTokens t) {
    return Padding(
      padding: const EdgeInsets.only(
        left: HermesTokens.space2,
        right: HermesTokens.space2,
        top: HermesTokens.space3,
        bottom: HermesTokens.space1,
      ),
      child: Text(
        _tr(context, de: 'WERKZEUGE', en: 'TOOLS'),
        style: TextStyle(
          color: t.muted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _brand(BuildContext context, HermesTokens t, bool collapsed) {
    final logo = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.accentHover, t.accent],
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        "LA",
        style: TextStyle(
          color: t.onAccent,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(HermesTokens.space3),
      child: collapsed
          ? Center(child: logo)
          : Row(
              children: [
                logo,
                const SizedBox(width: HermesTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Linux Assistant",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.strong,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (currentLinuxAssistantVersion.isNotEmpty)
                        Text(
                          "v$currentLinuxAssistantVersion",
                          style: TextStyle(color: t.muted, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _topBar(BuildContext context, HermesTokens t) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ThemeController();

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: HermesTokens.space4),
      decoration: BoxDecoration(
        color: t.sidebar,
        border: Border(
          bottom: BorderSide(color: t.border, width: HermesTokens.borderWidth),
        ),
      ),
      child: Row(
        children: [
          Text(
            _screenTool != null
                ? _titleOfTool(context, _screenTool!)
                : _titleOf(context, _section),
            style: TextStyle(
              color: t.strong,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (_section != HubSection.search)
            IconButton(
              onPressed: () => _select(HubSection.search),
              icon: const Icon(Icons.search, size: 18),
              color: t.muted,
              tooltip: l10n.hubSearch,
            ),
          IconButton(
            onPressed: () => SystemStatsService().refresh(),
            icon: const Icon(Icons.refresh, size: 18),
            color: t.muted,
            tooltip: l10n.reload,
          ),
          IconButton(
            onPressed: () async {
              await controller.cycleThemeMode();
            },
            icon: Icon(_themeIcon(controller.themeMode), size: 18),
            color: t.muted,
            tooltip: l10n.switchTheme,
          ),
        ],
      ),
    );
  }

  static IconData _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }
}
