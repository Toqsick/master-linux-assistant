import 'package:flutter/material.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/layouts/hermes_tokens.dart';
import 'package:linux_assistant/layouts/hub/hub_grid.dart';
import 'package:linux_assistant/linux/linux_filesystem.dart';
import 'package:linux_assistant/linux/linux_memory.dart';
import 'package:linux_assistant/models/action_entry.dart';
import 'package:linux_assistant/services/action_entry_list_service.dart';
import 'package:linux_assistant/services/action_handler.dart';
import 'package:linux_assistant/services/browser_status_service.dart';
import 'package:linux_assistant/services/failed_units_service.dart';
import 'package:linux_assistant/services/linux.dart';
import 'package:linux_assistant/services/system_stats_service.dart';
import 'package:linux_assistant/widgets/hermes/hermes_badge.dart';
import 'package:linux_assistant/widgets/hermes/hermes_card.dart';
import 'package:linux_assistant/widgets/hermes/hermes_sparkline.dart';
import 'package:linux_assistant/widgets/hermes/hermes_stat_tile.dart';

/// The hub's landing view: what the machine is doing right now, plus the
/// actions people reach for most.
class DashboardSection extends StatefulWidget {
  const DashboardSection({super.key, this.onOpenSecurity, this.onOpenStorage});

  final VoidCallback? onOpenSecurity;
  final VoidCallback? onOpenStorage;

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  /// Action codes surfaced as quick-action tiles.
  ///
  /// Pulled from the existing catalog by code rather than redeclared here, so
  /// the labels, icons and translations stay in one place.
  static const List<String> _quickActionCodes = [
    "update_system",
    "open_software_center",
    "disk_cleaner",
    "power_mode",
    "open_systeminformation",
    "hard_info",
  ];

  /// How many failed units the tile lists before it summarizes the rest.
  static const int _maxListedFailedUnits = 3;

  final SystemStatsService _service = SystemStatsService();
  final FailedUnitsService _failedUnits = FailedUnitsService();
  final BrowserStatusService _browserStatus = BrowserStatusService();
  List<ActionEntry> _quickActions = [];

  @override
  void initState() {
    super.initState();
    _service.acquire();
    _failedUnits.acquire();
    _browserStatus.acquire();
    _loadQuickActions();
  }

  @override
  void dispose() {
    _service.release();
    _failedUnits.release();
    _browserStatus.release();
    super.dispose();
  }

  Future<void> _loadQuickActions() async {
    final entries = await ActionEntryListService.getEntries();
    final byCode = <String, ActionEntry>{};
    for (final entry in entries) {
      if (_quickActionCodes.contains(entry.action) &&
          !byCode.containsKey(entry.action)) {
        byCode[entry.action] = entry;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _quickActions = [
        for (final code in _quickActionCodes)
          if (byCode.containsKey(code)) byCode[code]!,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = HermesTokens.of(context);

    return ValueListenableBuilder<SystemStats>(
      valueListenable: _service.stats,
      builder: (context, stats, _) {
        return ListView(
          padding: const EdgeInsets.all(HermesTokens.space4),
          children: [
            if (stats.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: HermesTokens.space3),
                child: HermesCard(
                  spineColor: t.warning,
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, size: 16, color: t.warning),
                      const SizedBox(width: HermesTokens.space2),
                      Expanded(
                        child: Text(
                          l10n.statsUnavailable,
                          style: TextStyle(color: t.muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _identityCard(context, stats),
            const SizedBox(height: HermesTokens.space4),
            HubGrid(
              children: [
                _cpuTile(context, stats),
                _memoryTile(context, stats),
                _processesTile(context, stats),
                _storageTile(context, stats),
                _failedServicesTile(context),
              ],
            ),
            const SizedBox(height: HermesTokens.space4),
            HermesSectionHeader(text: l10n.quickActions),
            _quickActionsGrid(context),
          ],
        );
      },
    );
  }

  Widget _identityCard(BuildContext context, SystemStats stats) {
    final l10n = AppLocalizations.of(context)!;
    final t = HermesTokens.of(context);
    final env = Linux.currentenvironment;
    final uptime = stats.uptime;
    final rebootRequired = stats.reboot?.required ?? false;

    return HermesCard(
      spineColor: t.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "${env.username}@${env.hostname}",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.strong,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (uptime != null)
                HermesBadge(
                  icon: Icons.schedule,
                  tone: HermesTone.accent,
                  text: "${l10n.uptimeLabel} "
                      "${uptime.value}${_uptimeUnit(context, uptime.unit)}",
                ),
              // The badge disappears with the marker file, i.e. after the
              // reboot that was asked for.
              if (rebootRequired) ...[
                const SizedBox(width: HermesTokens.space2),
                HermesBadge(
                  icon: Icons.restart_alt,
                  tone: HermesTone.warning,
                  text: l10n.rebootRequiredBadge,
                ),
              ],
            ],
          ),
          const SizedBox(height: HermesTokens.space3),
          Wrap(
            spacing: HermesTokens.space4,
            runSpacing: HermesTokens.space2,
            children: [
              _fact(context, Icons.info_outline, env.osPrettyName),
              _fact(context, Icons.settings,
                  "${l10n.kernelLabel} ${env.kernelVersion}"),
              _fact(context, Icons.desktop_windows,
                  "${l10n.desktopLabel} ${env.desktop.name}"),
              _fact(context, Icons.memory, env.cpuModel),
              _fact(context, Icons.monitor, env.gpuModel),
              _browserFact(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fact(BuildContext context, IconData icon, String text) {
    final t = HermesTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: t.accent),
        const SizedBox(width: HermesTokens.space1),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: t.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Which browser the desktop calls the standard one, and a warning when
  /// HTTPS links open in a different one.
  ///
  /// Read-only: the dashboard never changes the browser settings.
  Widget _browserFact(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = HermesTokens.of(context);

    return ValueListenableBuilder<BrowserStatus?>(
      valueListenable: _browserStatus.status,
      builder: (context, status, _) {
        if (status == null) {
          // Not read yet — no claim about the browser until there is one.
          return const SizedBox.shrink();
        }

        final standard = status.defaultDesktopId;
        if (standard == null) {
          return _fact(context, Icons.public, l10n.browserDefaultUnknown);
        }

        if (status.mismatch) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber, size: 14, color: t.warning),
              const SizedBox(width: HermesTokens.space1),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  l10n.browserHandlerMismatch(
                    status.httpsHandlerDesktopId ?? "",
                    standard,
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.warning, fontSize: 12),
                ),
              ),
            ],
          );
        }

        return _fact(context, Icons.public, l10n.browserDefaultIs(standard));
      },
    );
  }

  Widget _cpuTile(BuildContext context, SystemStats stats) {
    final l10n = AppLocalizations.of(context)!;
    final t = HermesTokens.of(context);
    final percent = (stats.cpuLoad * 100);

    return HermesStatTile(
      label: l10n.cpuUsage,
      icon: Icons.speed,
      value: stats.hasData ? percent.toStringAsFixed(0) : null,
      unit: "%",
      tone: percent >= 90 ? HermesTone.error : HermesTone.accent,
      visual: HermesSparkline(
        values: stats.cpuHistory,
        color: percent >= 90 ? t.error : t.accent,
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final process in stats.topByCpu.take(3))
            HermesMetaRow(
              label: process.processName,
              value: "${process.metricValue}%",
            ),
        ],
      ),
    );
  }

  Widget _memoryTile(BuildContext context, SystemStats stats) {
    final l10n = AppLocalizations.of(context)!;
    final t = HermesTokens.of(context);
    final memory = stats.memory;
    final ratio = memory?.usedRatio ?? 0;
    final pressure = stats.memoryPressure;
    final zram = stats.zram;
    final tone = _memoryTone(pressure, ratio);

    return HermesStatTile(
      label: l10n.memoryUsage,
      icon: Icons.developer_board,
      value: memory != null ? (ratio * 100).toStringAsFixed(0) : null,
      unit: "%",
      // The pressure decides the tone, not the RAM quote: 40 % RAM with
      // memory stalls is a problem, 95 % RAM without stalls is not.
      tone: tone,
      badge: memory != null
          ? HermesBadge(
              dense: true,
              text: "${_gb(memory.usedMb)} / ${_gb(memory.totalMb)}",
            )
          : null,
      visual: HermesSparkline(
        values: stats.memoryHistory,
        color: tone == HermesTone.error
            ? t.error
            : tone == HermesTone.warning
                ? t.warning
                : t.accent,
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HermesMetaRow(
            label: l10n.memoryPressureLabel,
            value: pressure == null
                ? l10n.memoryPressureUnavailable
                : "${pressure.someAvg60.toStringAsFixed(1)} %",
            valueTone: _pressureTone(context, pressure),
          ),
          // zram and the disk swap are two different things and get two
          // rows: the compressed RAM disk and the swap on the disk.
          if (zram != null)
            HermesMetaRow(
              label: l10n.zramLabel,
              value: "${_gbFromBytes(zram.originalBytes)}"
                  " → ${_gbFromBytes(zram.compressedBytes)}",
            ),
          if (memory != null && memory.hasSwap)
            HermesMetaRow(
              label: l10n.diskSwapLabel,
              value: "${_gb(memory.swapUsedMb)} / ${_gb(memory.swapTotalMb)}",
            ),
        ],
      ),
    );
  }

  /// The tone of the memory tile.
  ///
  /// PSI decides it. Only when the kernel does not report the pressure does
  /// the RAM quote step in as a fallback.
  static HermesTone _memoryTone(MemoryPressure? pressure, double ratio) {
    switch (pressure?.level) {
      case MemoryPressureLevel.high:
        return HermesTone.error;
      case MemoryPressureLevel.elevated:
        return HermesTone.warning;
      case MemoryPressureLevel.normal:
        return HermesTone.accent;
      case MemoryPressureLevel.unknown:
      case null:
        return ratio >= 0.9 ? HermesTone.warning : HermesTone.accent;
    }
  }

  Color? _pressureTone(BuildContext context, MemoryPressure? pressure) {
    if (pressure == null) {
      return null;
    }
    final t = HermesTokens.of(context);
    switch (pressure.level) {
      case MemoryPressureLevel.high:
        return t.error;
      case MemoryPressureLevel.elevated:
        return t.warning;
      case MemoryPressureLevel.normal:
      case MemoryPressureLevel.unknown:
        return null;
    }
  }

  Widget _processesTile(BuildContext context, SystemStats stats) {
    final l10n = AppLocalizations.of(context)!;

    return HermesStatTile(
      label: l10n.processesLabel,
      icon: Icons.account_tree,
      value: stats.hasData ? "${stats.processCount}" : null,
      tone: stats.zombieCount > 0 ? HermesTone.warning : HermesTone.accent,
      badge: stats.zombieCount > 0
          ? HermesBadge(
              dense: true,
              tone: HermesTone.warning,
              text: "${stats.zombieCount} ${l10n.zombiesLabel}",
            )
          : null,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final process in stats.topByMemory.take(3))
            HermesMetaRow(
              label: process.processName,
              value: "${process.metricValue}%",
            ),
        ],
      ),
    );
  }

  Widget _storageTile(BuildContext context, SystemStats stats) {
    final l10n = AppLocalizations.of(context)!;
    final t = HermesTokens.of(context);

    final DeviceInfo? worst = stats.disks.isEmpty
        ? null
        : stats.disks.reduce(
            (a, b) => a.usedPercent >= b.usedPercent ? a : b,
          );
    final bool critical = (worst?.usedPercent ?? 0) > 90;

    return HermesStatTile(
      label: l10n.diskUsage,
      icon: Icons.storage,
      value: worst != null ? "${worst.usedPercent}" : null,
      unit: "%",
      tone: critical ? HermesTone.error : HermesTone.accent,
      onTap: widget.onOpenStorage,
      badge: worst != null
          ? HermesBadge(dense: true, text: worst.mountPoint)
          : null,
      visual: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final disk in stats.disks.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _diskBar(context, disk, t),
            ),
        ],
      ),
    );
  }

  Widget _diskBar(BuildContext context, DeviceInfo disk, HermesTokens t) {
    final ratio = (disk.usedPercent / 100).clamp(0.0, 1.0);
    final color = disk.usedPercent > 90 ? t.error : t.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                disk.mountPoint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.muted, fontSize: 11),
              ),
            ),
            Text(
              "${disk.sizeFree} free",
              style: TextStyle(color: t.muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(HermesTokens.radiusPill),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 4,
            backgroundColor: t.surfaceSubtleHover,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  /// The failed systemd units of both scopes.
  ///
  /// The number is the headline; the list below it names the units, their
  /// description and the scope they come from — a failed user unit is a
  /// different problem than a failed system unit.
  Widget _failedServicesTile(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<List<FailedUnit>?>(
      valueListenable: _failedUnits.units,
      builder: (context, units, _) {
        final count = units?.length ?? 0;
        final listed = units?.take(_maxListedFailedUnits) ?? const [];
        final rest = count - listed.length;

        return HermesStatTile(
          label: l10n.failedServicesLabel,
          icon: Icons.report_gmailerrorred_outlined,
          // Null while the first read is still running — a dash is honest,
          // a zero would be a claim nobody made yet.
          value: units == null ? null : "$count",
          tone: count > 0 ? HermesTone.error : HermesTone.accent,
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (units == null)
                const SizedBox.shrink()
              else if (units.isEmpty)
                HermesMetaRow(
                  label: l10n.failedServicesLabel,
                  value: l10n.failedServicesNone,
                )
              else ...[
                for (final unit in listed) _failedUnitRow(context, unit),
                if (rest > 0)
                  HermesMetaRow(
                    label: l10n.failedServicesLabel,
                    value: l10n.failedServicesMore(rest),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _failedUnitRow(BuildContext context, FailedUnit unit) {
    final l10n = AppLocalizations.of(context)!;
    final t = HermesTokens.of(context);
    final scope = unit.scope == FailedUnitScope.user
        ? l10n.failedServicesScopeUser
        : l10n.failedServicesScopeSystem;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unit.unit,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.text,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: HermesTokens.space2),
              HermesBadge(dense: true, text: scope),
            ],
          ),
          if (unit.description.isNotEmpty)
            Text(
              unit.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.muted, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _quickActionsGrid(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = HermesTokens.of(context);

    if (_quickActions.isEmpty) {
      return Text(
        l10n.noQuickActions,
        style: TextStyle(color: t.muted, fontSize: 12),
      );
    }

    return HubGrid(
      minTileWidth: 220,
      children: [
        for (final entry in _quickActions)
          HermesCard(
            padding: const EdgeInsets.all(HermesTokens.space3),
            onTap: () => ActionHandler.handleActionEntry(
              entry,
              () {},
              context,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: t.accentBg,
                    borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                  ),
                  child: Icon(Icons.bolt, size: 16, color: t.accentText),
                ),
                const SizedBox(width: HermesTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (entry.description.isNotEmpty)
                        Text(
                          entry.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.muted, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _gb(int megabytes) =>
      "${(megabytes / 1024).toStringAsFixed(1)}G";

  /// A size in gigabytes, for the values that come in bytes (zram).
  static String _gbFromBytes(int bytes) =>
      "${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB";

  String _uptimeUnit(BuildContext context, String unit) {
    final l10n = AppLocalizations.of(context)!;
    switch (unit) {
      case "m":
        return l10n.uptimeUnitShortMinutes;
      case "h":
        return l10n.uptimeUnitShortHours;
      default:
        return l10n.uptimeUnitShortDays;
    }
  }
}
