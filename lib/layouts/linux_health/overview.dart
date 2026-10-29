import 'package:flutter/material.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/layouts/mint_y.dart';
import 'package:linux_assistant/linux/linux_filesystem.dart';
import 'package:linux_assistant/services/hotkey_diagnostics.dart';
import 'package:linux_assistant/services/main_search_loader.dart';
import 'package:linux_assistant/services/system_stats_service.dart';
import 'package:linux_assistant/widgets/success_message.dart';
import 'package:linux_assistant/widgets/warning_message.dart';

/// Standalone Linux Health page, reached from search and from the hub.
class LinuxHealthOverview extends StatelessWidget {
  const LinuxHealthOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return MintYPage(
      title: AppLocalizations.of(context)!.linuxHealth,
      customContentElement: const Expanded(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: LinuxHealthContent(),
        ),
      ),
      bottom: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MintYButtonNavigate(
            route: const MainSearchLoader(),
            color: MintY.currentColor,
            text: Text(
              AppLocalizations.of(context)!.backToSearch,
              style: MintY.heading4White,
            ),
          )
        ],
      ),
    );
  }
}

/// The health findings themselves, without any page chrome, so the hub can
/// embed them as a section.
///
/// This used to build seven futures inside `build()` and drive them with a
/// `Timer.periodic` that called an empty `setState`, which re-ran all seven
/// commands every five seconds and leaked the timer unless the user happened to
/// leave through the back button. It now reads the shared snapshot instead.
class LinuxHealthContent extends StatefulWidget {
  const LinuxHealthContent({super.key});

  @override
  State<LinuxHealthContent> createState() => _LinuxHealthContentState();
}

class _LinuxHealthContentState extends State<LinuxHealthContent> {
  final SystemStatsService _service = SystemStatsService();

  /// What the desktop knows about this app's own keyboard shortcut.
  ///
  /// Started next to the stats poll, not inside the poll: the report is a
  /// read of the desktop's settings, and the health page is about the
  /// machine. It must not delay the page, and it must not make the page
  /// flicker either — which is why the row keeps its place while the report
  /// is on its way.
  late Future<HotkeyReport> _hotkeyReport;

  @override
  void initState() {
    super.initState();
    _service.acquire();
    _hotkeyReport = const HotkeyDiagnostics().loadReport();
  }

  @override
  void dispose() {
    _service.release();
    super.dispose();
  }

  /// Reads the report again.
  ///
  /// The future is created outside of the `setState` callback: a callback
  /// that returns a future would be a mistake in a state change, and this
  /// one would also be started twice.
  void _reloadHotkeyReport() {
    final Future<HotkeyReport> report = const HotkeyDiagnostics().loadReport();
    setState(() {
      _hotkeyReport = report;
    });
  }

  /// Removes the orphaned desktop entries and reads the report again.
  Future<bool> _cleanupHotkeyOrphans() async {
    final bool ok = await const HotkeyDiagnostics().cleanupOrphans();
    if (ok && mounted) {
      _reloadHotkeyReport();
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<SystemStats>(
      valueListenable: _service.stats,
      builder: (context, stats, _) {
        if (!stats.hasData) {
          return MintYLoadingPage(text: l10n.analysingLinuxHealth);
        }

        final devices = stats.disks;
        final removableCount = devices.where((x) => x.isRemovable).length;

        final List<Widget> diskWarnings = [
          for (final DeviceInfo device in devices)
            if (device.usedPercent > 90)
              WarningMessage(
                text: "${l10n.diskspaceWarning1}"
                    "${device.filesystem} ${device.mountPoint}"
                    "${l10n.diskspaceWarning2}"
                    "${device.sizeFree}",
              ),
        ];

        final topCPUProcesses = <List<dynamic>>[
          [l10n.cpuUsage, l10n.process],
          for (final stat in stats.topByCpu.take(3))
            ["${stat.metricValue}%", stat.processName],
        ];

        final topMemoryProcesses = <List<dynamic>>[
          [l10n.memoryUsage, l10n.process],
          for (final stat in stats.topByMemory.take(3))
            ["${stat.metricValue}%", stat.processName],
        ];

        final uptime = stats.uptime;
        final hasSwap = stats.memory?.hasSwap ?? false;
        final reboot = stats.reboot;

        return ListView(
          shrinkWrap: true,
          children: [
            HotkeyStatusRow(
              report: _hotkeyReport,
              onCleanup: _cleanupHotkeyOrphans,
            ),
            Text(
              l10n.runtime,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            if (uptime != null)
              _uptimeMessage(context, uptime.unit, uptime.value),
            // The packages that asked for the reboot. The marker file is
            // gone after the reboot, so this line disappears with it.
            if (reboot != null && reboot.required)
              WarningMessage(
                text: reboot.packages.isEmpty
                    ? l10n.rebootRequiredNoPackages
                    : l10n.rebootRequiredPackages(reboot.packages.join(", ")),
              ),
            stats.zombieCount == 0
                ? SuccessMessage(
                    text: l10n.processesWithZombiesMessage(
                        stats.processCount, stats.zombieCount))
                : WarningMessage(
                    text: l10n.processesWithZombiesMessage(
                        stats.processCount, stats.zombieCount)),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          l10n.topMemoryProcesses,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: MintYTable(data: topMemoryProcesses),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          l10n.topCPUProcesses,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: MintYTable(data: topCPUProcesses),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              l10n.memoryAndStorage,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            diskWarnings.isEmpty
                ? SuccessMessage(text: l10n.diskspacePass)
                : Column(children: diskWarnings),
            removableCount == 0
                ? SuccessMessage(text: l10n.removableDevicesPass)
                : WarningMessage(
                    text: l10n.removableDevicesWarning(removableCount)),
            hasSwap
                ? SuccessMessage(text: l10n.swapsPass)
                : WarningMessage(text: l10n.swapsWarning),
          ],
        );
      },
    );
  }

  Widget _uptimeMessage(BuildContext context, String unit, int value) {
    final l10n = AppLocalizations.of(context)!;
    final String unitText;
    switch (unit) {
      case "m":
        unitText = l10n.minutes;
        break;
      case "h":
        unitText = l10n.hours;
        break;
      default:
        unitText = l10n.days;
        break;
    }

    final bool warn = unit == "d" || (unit == "h" && value >= 10);
    return warn
        ? WarningMessage(text: l10n.uptimeWarning(value, unitText))
        : SuccessMessage(text: l10n.uptimePass(value, unitText));
  }
}

/// One line about this app's own keyboard shortcut.
///
/// The desktop's settings are the only place that knows whether the shortcut
/// is really registered — the app does not grab the key itself any more, so
/// it cannot know what the desktop did with it. A report that cannot be read
/// must not take the page down with it: the line then says "unknown" and the
/// page stays where it was.
class HotkeyStatusRow extends StatefulWidget {
  const HotkeyStatusRow({
    super.key,
    required this.report,
    required this.onCleanup,
  });

  /// The report as it is now. A new future means: read it again.
  final Future<HotkeyReport> report;

  /// Removes the orphaned entries. Returns whether it worked.
  final Future<bool> Function() onCleanup;

  @override
  State<HotkeyStatusRow> createState() => _HotkeyStatusRowState();
}

class _HotkeyStatusRowState extends State<HotkeyStatusRow> {
  bool _cleaning = false;
  bool? _cleanupFailed;

  Future<void> _cleanup() async {
    if (_cleaning) {
      return;
    }
    setState(() {
      _cleaning = true;
      _cleanupFailed = null;
    });
    final bool ok = await widget.onCleanup();
    if (!mounted) {
      return;
    }
    setState(() {
      _cleaning = false;
      _cleanupFailed = ok ? null : true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<HotkeyReport>(
      future: widget.report,
      builder: (context, snapshot) {
        final HotkeyReport? report = snapshot.data;
        final int orphanCount = report?.orphans.length ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${l10n.hotkeyTitle}: ${_stateText(report)}",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (report != null && !report.hasError)
                Text(
                  "${report.desktop} · ${report.session}",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (orphanCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.hotkeyOrphanEntries(orphanCount),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                MintYButton(
                  text: Text(
                    l10n.hotkeyCleanup,
                    style: MintY.heading4,
                  ),
                  color: MintY.currentColor,
                  onPressed: _cleaning ? null : _cleanup,
                ),
              ],
              if (_cleanupFailed == true)
                WarningMessage(text: l10n.hotkeyCleanupFailed),
            ],
          ),
        );
      },
    );
  }

  /// What the line says about the shortcut.
  String _stateText(HotkeyReport? report) {
    final l10n = AppLocalizations.of(context)!;
    if (report == null) {
      // The report is still on its way. The line keeps its place, so nothing
      // jumps when the answer arrives.
      return "…";
    }
    if (report.hasError) {
      return l10n.hotkeyUnknown;
    }
    if (!report.registered) {
      return l10n.hotkeyNotRegistered;
    }
    if (report.binding.isEmpty) {
      return l10n.hotkeyUnknown;
    }
    return report.binding;
  }
}
