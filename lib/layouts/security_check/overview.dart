import 'dart:io';

import 'package:flutter/material.dart';
import 'package:linux_assistant/enums/distros.dart';
import 'package:linux_assistant/helpers/command_helper.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/layouts/hermes_tokens.dart';
import 'package:linux_assistant/layouts/mint_y.dart';
import 'package:linux_assistant/layouts/security_check/security_check_outcome.dart';
import 'package:linux_assistant/layouts/security_check/security_finding.dart';
import 'package:linux_assistant/services/linux.dart';
import 'package:linux_assistant/services/security_scan_cache.dart';
import 'package:linux_assistant/services/main_search_loader.dart';
import 'package:linux_assistant/widgets/hermes/hermes_badge.dart';
import 'package:linux_assistant/widgets/hermes/hermes_card.dart';

/// Standalone security page, reached from search.
class SecurityCheckOverview extends StatelessWidget {
  const SecurityCheckOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return MintYPage(
      title: AppLocalizations.of(context)!.securityCheck,
      customContentElement: const Expanded(child: SecurityCheckContent()),
      bottom: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MintYButtonNavigate(
            route: const MainSearchLoader(),
            text: Text(AppLocalizations.of(context)!.backToSearch,
                style: MintY.heading4),
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// The security findings, read-only.
///
/// This area inspects and explains; it never changes the system. Where an
/// earlier version offered a "Fix" button that installed a firewall or altered
/// home directory permissions, it now shows the command and leaves the decision
/// — and the execution — with the user.
class SecurityCheckContent extends StatefulWidget {
  const SecurityCheckContent({super.key, this.cache});

  /// Where the last result is stored. Injectable so a test does not write
  /// into the developer's own cache.
  final SecurityScanCache? cache;

  @override
  State<SecurityCheckContent> createState() => _SecurityCheckContentState();
}

class _SecurityCheckContentState extends State<SecurityCheckContent> {
  /// The scan reaches root through pkexec. It must not start on its own: a
  /// password dialog because someone opened a page is not an option. The
  /// future stays null until the user presses the button.
  Future<CommandResult>? _checkerOutput;

  late final SecurityScanCache _cache = widget.cache ?? SecurityScanCache();

  /// The result of the last scan, read from the cache when the page opens.
  /// Null means: no scan has ever been run on this system.
  SecurityScanSnapshot? _lastSnapshot;

  @override
  void initState() {
    super.initState();
    _loadCachedResult();
  }

  /// Reads the cached result of the last scan.
  ///
  /// Only the cache is touched here — no scan is started. A page that is
  /// opened shows what the last scan found, not a new scan.
  Future<void> _loadCachedResult() async {
    final SecurityScanSnapshot? snapshot = await _cache.read();
    if (!mounted) return;
    setState(() => _lastSnapshot = snapshot);
  }

  /// Runs the scan and stores its result in the cache.
  ///
  /// The write happens before the result is shown, so a scan that the user
  /// saw is also a scan that survives a restart.
  Future<CommandResult> _runAndStore() async {
    final CommandResult result = await _runChecker();
    if (classifySecurityCheck(result) == SecurityCheckOutcome.success) {
      final SecurityScanSnapshot snapshot = SecurityScanSnapshot.fromOutput(
        result.output,
        timestamp: DateTime.now(),
      );
      await _cache.write(snapshot);
      if (mounted) setState(() => _lastSnapshot = snapshot);
    }
    return result;
  }

  static Future<CommandResult> _runChecker() {
    final home = "--home=${Platform.environment['HOME']}";
    final distro = Linux.currentenvironment.distribution;

    // A family name, not a script name. The privileged side picks the file
    // itself, so no path this page computes crosses into root.
    String family;
    if (distro == DISTROS.OPENSUSE) {
      family = "opensuse";
    } else if (distro == DISTROS.FEDORA) {
      family = "fedora";
    } else if ([DISTROS.ARCH, DISTROS.MANJARO, DISTROS.ENDEAVOUR]
        .contains(distro)) {
      family = "arch";
    } else {
      family = "debian";
    }

    return Linux.runPrivilegedPythonScriptDetailed(
        "read_security_report.py", ["--family=$family", home]);
  }

  void _reload() {
    // Block body: an arrow function would hand the Future of
    // _runAndStore() back to setState, which rejects a callback that returns
    // a Future.
    setState(() {
      _checkerOutput = _runAndStore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final Future<CommandResult>? running = _checkerOutput;

    // No scan is running: show what the last one found, or that there was
    // none. The button to start a scan is part of the banner below.
    if (running == null) {
      return _idleView(context);
    }

    return FutureBuilder<CommandResult>(
      future: running,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return MintYLoadingPage(text: l10n.analysingSystemSecurity);
        }

        final result = snapshot.data!;
        switch (classifySecurityCheck(result)) {
          case SecurityCheckOutcome.success:
            break;
          case SecurityCheckOutcome.noRootRights:
            return _rootRequired(context);
          case SecurityCheckOutcome.scriptError:
            return _scriptFailed(context, result);
        }

        return ListView(
          padding: const EdgeInsets.all(HermesTokens.space4),
          children: [
            _readOnlyBanner(context),
            const SizedBox(height: HermesTokens.space4),
            for (final finding in _buildFindings(context, result.output))
              SecurityFindingTile(finding: finding),
          ],
        );
      },
    );
  }

  /// The page before a scan has been started: the cached result of the last
  /// scan, or the hint that there was none.
  Widget _idleView(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = HermesTokens.of(context);
    final SecurityScanSnapshot? snapshot = _lastSnapshot;

    return ListView(
      padding: const EdgeInsets.all(HermesTokens.space4),
      children: [
        _readOnlyBanner(context),
        const SizedBox(height: HermesTokens.space4),
        if (snapshot == null)
          Text(
            l10n.securityScanNotRunYet,
            style: TextStyle(color: t.muted, fontSize: 12, height: 1.5),
          )
        else ...[
          Text(
            l10n.securityScanLastRun(_formatAge(context, snapshot.timestamp)),
            style: TextStyle(color: t.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: HermesTokens.space2),
          for (final finding in _buildFindings(context, snapshot.output))
            SecurityFindingTile(finding: finding),
        ],
        const SizedBox(height: HermesTokens.space4),
        Text(
          l10n.securityScanRootHint,
          style: TextStyle(color: t.muted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  /// The age of a cached result, in the coarsest unit that still says
  /// something ("5 min ago" rather than "5 minutes and 12 seconds ago").
  String _formatAge(BuildContext context, DateTime timestamp) {
    final l10n = AppLocalizations.of(context)!;
    final SecurityScanAge age =
        SecurityScanAge.between(timestamp, DateTime.now());
    switch (age.unit) {
      case SecurityScanAgeUnit.justNow:
        return l10n.securityScanAgeJustNow;
      case SecurityScanAgeUnit.minutes:
        return l10n.securityScanAgeMinutes(age.count);
      case SecurityScanAgeUnit.hours:
        return l10n.securityScanAgeHours(age.count);
      case SecurityScanAgeUnit.days:
        return l10n.securityScanAgeDays(age.count);
    }
  }

  Widget _readOnlyBanner(BuildContext context) {
    final t = HermesTokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    return HermesCard(
      spineColor: t.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HermesBadge(
                icon: Icons.visibility_outlined,
                tone: HermesTone.accent,
                text: l10n.readOnly,
              ),
              const Spacer(),
              TextButton.icon(
                key: const Key("security-scan-run"),
                onPressed: _reload,
                icon: const Icon(Icons.refresh, size: 14),
                label: Text(l10n.securityScanRunCheck),
              ),
            ],
          ),
          const SizedBox(height: HermesTokens.space2),
          Text(
            l10n.securityReadOnlyIntro,
            style: TextStyle(color: t.muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _rootRequired(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HermesTokens.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.securityCheckFailedBecauseNoRoot,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HermesTokens.space4),
            TextButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  /// Root was granted and the checker still failed. Showing the "you need root
  /// rights" page here is a lie — and it was this exact combination that hid
  /// the deb822 parsing crash behind a permissions message.
  Widget _scriptFailed(BuildContext context, CommandResult result) {
    final l10n = AppLocalizations.of(context)!;
    final t = HermesTokens.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(HermesTokens.space4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.securityCheckScriptErrorTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: HermesTokens.space2),
              Text(
                l10n.securityCheckScriptErrorBody,
                style: TextStyle(color: t.muted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: HermesTokens.space3),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(HermesTokens.space2),
                decoration: BoxDecoration(
                  color: t.codeBg,
                  borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
                  border: Border.all(color: t.borderSubtle),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    checkerErrorExcerpt(result),
                    style: TextStyle(
                      fontFamily: "monospace",
                      fontFamilyFallback: const [
                        "DejaVu Sans Mono",
                        "monospace"
                      ],
                      fontSize: 11,
                      color: t.codeText,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: HermesTokens.space3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Turns the checker's line-prefixed output into prioritized findings.
  List<SecurityFinding> _buildFindings(BuildContext context, String output) {
    final l10n = AppLocalizations.of(context)!;
    final lines = output.split("\n");

    final additionalSources = <String>[];
    bool yayInstalled = false;
    int availableUpdatePackages = 0;
    bool homeFolderSecure = true;
    bool firewallNotInstalled = false;
    bool firewallRunning = true;
    bool sshRunning = false;
    bool xrdpRunning = false;
    bool fail2banRunning = true;

    for (final line in lines) {
      if (line.startsWith("additionalsource:")) {
        additionalSources.add(line.replaceFirst("additionalsource: ", ""));
      } else if (line.startsWith("yayinstalled")) {
        yayInstalled = true;
      } else if (line.startsWith("upgradeablepackage:")) {
        availableUpdatePackages++;
      } else if (line.startsWith("homefoldernotsecure:")) {
        homeFolderSecure = false;
      } else if (line.startsWith("firewallinactive")) {
        firewallRunning = false;
      } else if (line.startsWith("nofirewall")) {
        firewallNotInstalled = true;
      } else if (line.startsWith("xrdprunning")) {
        xrdpRunning = true;
      } else if (line.startsWith("sshrunning")) {
        sshRunning = true;
      } else if (line.startsWith("fail2bannotrunning")) {
        fail2banRunning = false;
      }
    }

    final findings = <SecurityFinding>[];

    // --- Network ---
    if (firewallNotInstalled) {
      findings.add(SecurityFinding(
        severity: FindingSeverity.high,
        title: l10n.noFirewallRecognized,
        why: l10n.whyFirewall,
        command: "sudo ufw status verbose",
      ));
    } else if (!firewallRunning) {
      findings.add(SecurityFinding(
        severity: FindingSeverity.high,
        title: l10n.firewallIsInactive,
        why: l10n.whyFirewall,
        command: "sudo ufw status verbose",
      ));
    } else {
      findings.add(SecurityFinding(
        severity: FindingSeverity.ok,
        title: l10n.firewallIsRunning,
      ));
    }

    if (xrdpRunning) {
      findings.add(SecurityFinding(
        severity: FindingSeverity.high,
        title: l10n.xrdpRunningOnYourComputer,
        why: l10n.whyXrdp,
        command: "systemctl status xrdp",
      ));
    }

    if (sshRunning) {
      findings.add(SecurityFinding(
        severity: fail2banRunning ? FindingSeverity.info : FindingSeverity.high,
        title: l10n.sshFoundOnYourComputer,
        why: l10n.whySsh,
        command: "sudo ss -tlnp | grep ':22'",
      ));
      if (!fail2banRunning) {
        findings.add(SecurityFinding(
          severity: FindingSeverity.high,
          title: l10n.noFail2BanFound,
          why: l10n.whyFail2ban,
          command: "systemctl is-active fail2ban",
        ));
      }
    }

    // --- Home folder ---
    if (!homeFolderSecure) {
      findings.add(SecurityFinding(
        severity: FindingSeverity.medium,
        title: l10n.homeFolderRightsNotOkay,
        why: l10n.whyHomeFolder,
        command: "ls -ld ~",
      ));
    } else {
      findings.add(SecurityFinding(
        severity: FindingSeverity.ok,
        title: l10n.homeFolderRightsOkay,
      ));
    }

    // --- Updates ---
    if (availableUpdatePackages > 0) {
      findings.add(SecurityFinding(
        severity: FindingSeverity.medium,
        title: "$availableUpdatePackages ${l10n.xPackagesShouldBeUpdated}",
        why: l10n.whyUpdates,
        command: _updateListCommand(),
      ));
    } else {
      findings.add(SecurityFinding(
        severity: FindingSeverity.ok,
        title: l10n.systemIsUpToDate,
      ));
    }

    // --- Software sources ---
    if (additionalSources.isNotEmpty) {
      findings.add(SecurityFinding(
        severity: FindingSeverity.medium,
        title: l10n.additionalSoftwareSourcesDetected,
        why: l10n.whySources,
        details: additionalSources,
        command: _sourcesCommand(),
      ));
    } else if (!yayInstalled) {
      findings.add(SecurityFinding(
        severity: FindingSeverity.ok,
        title: l10n.noAdditionalSoftwareSourcesFound,
      ));
    }

    if (yayInstalled) {
      findings.add(SecurityFinding(
        severity: FindingSeverity.medium,
        title: l10n.yayInstalled,
        why: l10n.whyYay,
        command: "pacman -Qi yay",
      ));
    }

    // Most severe first, so the important lines are never below the fold.
    findings.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return findings;
  }

  static String _updateListCommand() {
    switch (Linux.currentenvironment.distribution) {
      case DISTROS.FEDORA:
        return "dnf check-update";
      case DISTROS.OPENSUSE:
        return "zypper list-updates";
      case DISTROS.ARCH:
      case DISTROS.MANJARO:
      case DISTROS.ENDEAVOUR:
        return "checkupdates";
      default:
        return "apt list --upgradable";
    }
  }

  static String _sourcesCommand() {
    switch (Linux.currentenvironment.distribution) {
      case DISTROS.FEDORA:
        return "dnf repolist enabled";
      case DISTROS.OPENSUSE:
        return "zypper repos";
      case DISTROS.ARCH:
      case DISTROS.MANJARO:
      case DISTROS.ENDEAVOUR:
        return "grep -H '^\\[' /etc/pacman.conf";
      default:
        return "ls -l /etc/apt/sources.list.d/";
    }
  }
}
