import 'package:flutter/material.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/layouts/mint_y.dart';
import 'package:linux_assistant/linux/linux_filesystem.dart';
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

  @override
  void initState() {
    super.initState();
    _service.acquire();
  }

  @override
  void dispose() {
    _service.release();
    super.dispose();
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
