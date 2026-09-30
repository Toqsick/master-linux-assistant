import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linux_assistant/enums/browsers.dart';
import 'package:linux_assistant/helpers/command_helper.dart';
import 'package:linux_assistant/enums/desktops.dart';
import 'package:linux_assistant/enums/distros.dart';
import 'package:linux_assistant/enums/softwareManagers.dart';
import 'package:linux_assistant/layouts/disk_cleaner/clean_disk.dart';
import 'package:linux_assistant/layouts/mint_y.dart';
import 'package:linux_assistant/layouts/run_command_queue.dart';
import 'package:linux_assistant/models/action_entry.dart';
import 'package:linux_assistant/models/environment.dart';
import 'package:linux_assistant/models/linux_command.dart';
import 'package:linux_assistant/services/action_entry_list_service.dart';
import 'package:linux_assistant/services/config_handler.dart';
import 'package:linux_assistant/services/hashing.dart';
import 'package:linux_assistant/services/main_search_loader.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/services/logger.dart';

class Linux {
  static Environment currentenvironment = Environment();
  static String executableFolder = "";
  static String pythonScriptsFolder = "";
  static String homeFolder = "";

  /// Here the additonal files are stored, like the python scripts and logos of other applications
  static String additionalFolder = "";

  /// Commands in it can be run at once by [Linux.executeCommandQueue()]
  /// or by opening the page "RunCommandQueue"
  static List<LinuxCommand> commandQueue = [];

  static Future<void> init() async {
    executableFolder = getExecutableFolder();
    homeFolder = getHomeDirectory();
    pythonScriptsFolder =
        "$executableFolder/additional/python/".replaceAll("//", "/");
    additionalFolder = "$executableFolder/additional/".replaceAll("//", "/");

    // If /app/bin exists, we are running in a flatpak, we need this for every command issued
    if (await Directory("/app/bin").exists()) {
      Linux.currentenvironment.runningInFlatpak = true;
      // The execution layer needs to know too; it is what inserts
      // flatpak-spawn in front of every command.
      CommandHelper.processRunner.runningInFlatpak = true;

      // That python scripts are also running in flatpak we need to copy them to the home directory .cache folder.
      // Argument lists, not command strings: a home folder containing a
      // space would split "rm -r /home/john doe/…" into two paths and
      // recursively delete /home/john.
      await runCommandWithCustomArguments(
          "rm", ["-r", "$homeFolder/.cache/linux-assistant"],
          runInShell: false);
      await runCommandWithCustomArguments(
          "cp", ["-r", additionalFolder, "$homeFolder/.cache/linux-assistant"],
          hostOnFlatpak: false, runInShell: false);
      pythonScriptsFolder = "$homeFolder/.cache/linux-assistant/python/";
      additionalFolder = "$homeFolder/.cache/linux-assistant/";
    }

    await loadCurrentEnvironment();
  }

  static String getCacheDirectory() {
    homeFolder = getHomeDirectory();
    String cacheDir = "$homeFolder/.cache/linux-assistant/";
    cacheDir = cacheDir.replaceAll("//", "/");
    // Ensure that the cache directory exists
    Directory(cacheDir).createSync(recursive: true);
    return cacheDir;
  }

  /// Returns the stdout and the stderr.
  ///
  /// If [hostOnFlatpak] is set to false, the command will be issued in the flatpak sandbox, if available.
  static Future<String> runCommand(String command,
      {Map<String, String>? environment, bool hostOnFlatpak = true}) async {
    List<String> arguments = command.split(' ');
    String exec = arguments.removeAt(0);
    String result = await runCommandWithCustomArguments(exec, arguments,
        environment: environment,
        hostOnFlatpak: hostOnFlatpak,
        getErrorMessages: true);
    return result;
  }

  /// Returns the stdout and the stderr.
  ///
  /// If [hostOnFlatpak] is set to false, the command will be issued in the flatpak sandbox, if available.
  ///
  /// [runInShell] defaults to true for compatibility with the existing call
  /// sites. Turning it off halves the number of processes spawned — with it,
  /// every call forks a shell *and* the command — and is safe whenever the
  /// executable is an absolute path and the arguments need no shell handling.
  static Future<String> runCommandWithCustomArguments(
      String exec, List<String> arguments,
      {bool getErrorMessages = false,
      Map<String, String>? environment,
      bool hostOnFlatpak = true,
      bool runInShell = true}) async {
    final CommandResult result = await runProcess(exec, arguments,
        environment: environment,
        hostOnFlatpak: hostOnFlatpak,
        runInShell: runInShell);

    if (result.error.isNotEmpty && getErrorMessages) {
      return result.output + result.error;
    }
    return result.output;
  }

  /// Same execution as [runCommandWithCustomArguments], but the caller gets
  /// the exit code instead of having to guess from the output text.
  ///
  /// Prefer this wherever the question is "did it work": the string oracles
  /// this replaces (`contains("ii  $appCode")`, `contains(" not found.")`,
  /// `split("\n").length > 5`) answer a different question and answer it
  /// differently in every locale.
  static Future<CommandResult> runProcess(String exec, List<String> arguments,
      {Map<String, String>? environment,
      bool hostOnFlatpak = true,
      bool runInShell = true,
      bool asRoot = false}) async {
    exec = expandCommand(exec);

    // Debug only: the stats poller alone issues several commands every few
    // seconds, so an installed build would write to the journal forever.
    if (kDebugMode) {
      logInfo("Running linux command: $exec with arguments: $arguments");
    }

    final CommandResult result = await CommandHelper.runWithArguments(
      exec,
      arguments,
      env: environment,
      asRoot: asRoot,
      hostOnFlatpak: hostOnFlatpak,
      runInShell: runInShell,
    );

    if (kDebugMode && result.error.isNotEmpty) {
      logError("$exec failed", result.error);
    }
    return result;
  }

  /// Runs [exec] and reports only whether it succeeded, in the C locale.
  static Future<bool> commandSucceeds(String exec, List<String> arguments,
      {Map<String, String>? environment}) async {
    final CommandResult result = await runProcess(
      exec,
      arguments,
      environment: {"LC_ALL": "C", ...?environment},
    );
    return result.success;
  }

  /// Expand command for correct use in Linux and Flatpak. Examples:
  ///
  /// - "firefox" -> "/usr/bin/firefox"
  /// - "firefox" -> "/var/run/host/usr/bin/firefox"
  static String expandCommand(String command) {
    // If a local command is used, we don't need to expand it.
    if (command.startsWith(".")) {
      return command;
    }
    if (!command.startsWith("/usr/bin") &&
        !command.startsWith("/sbin") &&
        !command.startsWith("/var/run/host")) {
      command = "/usr/bin/$command";
    }
    return command;
  }

  static String getHomeDirectory() {
    String? home = Platform.environment["HOME"];
    if (home != null) {
      if (!home.endsWith("/")) {
        home += "/";
      }
      return home;
    } else {
      return "";
    }
  }

  static void changeUserPasswordDialog() {
    switch (currentenvironment.distribution) {
      case DISTROS.MXLINUX:
        openUserSettings();
        break;
      default:
    }
    switch (currentenvironment.desktop) {
      case DESKTOPS.CINNAMON:
        openUserSettings();
        break;
      case DESKTOPS.GNOME:
        openUserSettings();
        break;
      case DESKTOPS.XFCE:
        openUserSettings();
        break;
      default:
    }
  }

  static void openUserSettings() {
    switch (currentenvironment.distribution) {
      case DISTROS.MXLINUX:
        runCommand("mx-user");
        break;
      default:
    }
    switch (currentenvironment.desktop) {
      case DESKTOPS.CINNAMON:
        runCommand("cinnamon-settings user");
        break;
      case DESKTOPS.GNOME:
        runCommand("gnome-control-center user-accounts");
        break;
      case DESKTOPS.XFCE:
        runCommand("users-admin");
        break;
      default:
    }
  }

  static void openSystemInformation() {
    switch (currentenvironment.distribution) {
      case DISTROS.MXLINUX:
        runCommand("quick-system-info-gui");
        break;
      default:
    }
    switch (currentenvironment.desktop) {
      case DESKTOPS.CINNAMON:
        runCommand("cinnamon-settings info");
        break;
      case DESKTOPS.GNOME:
        // "info-overview" was renamed in GNOME 45; the old panel name silently
        // opened nothing, which went unnoticed because the exit code was
        // discarded.
        runCommand("gnome-control-center system");
        break;
      case DESKTOPS.XFCE:
        runCommand("xfce4-about");
        break;
      default:
    }
  }

  /// Checks if the file is accessible in /usr/bin or /var/run/host/usr/bin.
  /// (Flatpak compatible)
  ///
  /// Its up to you if you put /usr/bin before the file name or not.
  static bool doesExecutableExist(String executable) {
    executable = expandCommand(executable);
    return File(expandCommand(executable)).existsSync() ||
        File(expandCommand("/var/run/host/$executable")).existsSync();
  }

  /// [callback] is used for clearing and reoading the search.
  static void openOrInstallWarpinator(
      BuildContext context, VoidCallback callback) async {
    bool doesWarpinatorExist = doesExecutableExist("warpinator");
    if (doesWarpinatorExist) {
      unawaited(runCommand("/usr/bin/warpinator"));
      callback();
      return;
    } else {
      unawaited(Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => MintYLoadingPage(
          text: AppLocalizations.of(context)!.loading,
        ),
      )));
      doesWarpinatorExist =
          await isSpecificFlatpakInstalled("org.x.Warpinator");
      if (doesWarpinatorExist) {
        unawaited(runCommand("/usr/bin/flatpak run org.x.Warpinator"));
        callback();
        return;
      }
    }
    // if no warpinator is installed at all:
    await installApplications(["org.x.Warpinator", "warpinator"]);
    if (!context.mounted) return;
    unawaited(Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => RunCommandQueue(
          title: AppLocalizations.of(context)!.installX("Warpinator"),
          route: const MainSearchLoader(),
          message: AppLocalizations.of(context)!
              .installingXDescription("Warpinator")),
    )));
  }

  /// [callback] is used for clearing and reoading the search.
  static void openOrInstallHardInfo(
      BuildContext context, VoidCallback callback) async {
    bool doesAppExist = doesExecutableExist("hardinfo");
    if (doesAppExist) {
      unawaited(runCommand("/usr/bin/hardinfo"));
      callback();
      return;
    } else {
      // if app is not installed:
      await installApplications(["hardinfo"]);
      if (!context.mounted) return;
      unawaited(Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => RunCommandQueue(
            title: AppLocalizations.of(context)!.installX("HardInfo"),
            route: const MainSearchLoader(),
            message: AppLocalizations.of(context)!
                .installingXDescription("HardInfo")),
      )));
    }
  }

  /// [callback] is used for clearing and reoading the search.
  static void openOrInstallRedshift(
      BuildContext context, VoidCallback callback) async {
    bool doesAppExist = doesExecutableExist("redshift-gtk");
    if (doesAppExist) {
      MintY.showMessage(context,
          AppLocalizations.of(context)!.redshiftIsInstalledAlready, callback);

      return;
    } else {
      // if app is not installed:
      await installApplications(["redshift-gtk", "redshift"]);
      if (currentenvironment.desktop == DESKTOPS.KDE) {
        await installApplications(["plasma-applet-redshift-control"]);
      }
      if (!context.mounted) return;
      unawaited(Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => RunCommandQueue(
            title: AppLocalizations.of(context)!.installX("Redshift"),
            route: const MainSearchLoader(),
            message: AppLocalizations.of(context)!
                .installingXDescription("Redshift")),
      )));
    }
  }

  /// Tries to install one of the appCodes. Stops after one was successfully found.
  /// First elements of the list will be priorized.
  /// Doesn't run the command instantly, only puts the commands in to [Linux.commandQueue].
  static Future<void> installApplications(List<String> appCodes,
      {SOFTWARE_MANAGERS? preferredSoftwareManager}) async {
    preferredSoftwareManager ??= currentenvironment.preferredSoftwareManager;

    // Move preferred software manager to the start of the list
    currentenvironment.installedSoftwareManagers
        .insert(0, preferredSoftwareManager);
    currentenvironment.installedSoftwareManagers.removeAt(currentenvironment
        .installedSoftwareManagers
        .lastIndexOf(preferredSoftwareManager));

    for (String appCode in appCodes) {
      for (SOFTWARE_MANAGERS softwareManager
          in currentenvironment.installedSoftwareManagers) {
        if (softwareManager == SOFTWARE_MANAGERS.APT) {
          // Check, if package is available:
          bool available = await isDebPackageAvailable(appCode);
          if (!available) {
            continue;
          }

          commandQueue.add(
            LinuxCommand(
              argv: [
                getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.APT),
                "install",
                appCode,
                "-y"
              ],
              userId: 0,
              environment: {"DEBIAN_FRONTEND": "noninteractive"},
            ),
          );
          return;
        }

        if (softwareManager == SOFTWARE_MANAGERS.ZYPPER) {
          // Check, if package is available:
          bool available = await isZypperPackageAvailable(appCode);
          if (!available) {
            continue;
          }

          commandQueue.add(
            LinuxCommand(
              argv: [
                getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.ZYPPER),
                "--non-interactive",
                "install",
                appCode
              ],
              userId: 0,
              environment: {},
            ),
          );
          return;
        }

        if (softwareManager == SOFTWARE_MANAGERS.DNF) {
          // Check, if package is available:
          bool available = await isDNFPackageAvailable(appCode);
          if (!available) {
            continue;
          }

          commandQueue.add(
            LinuxCommand(
              argv: [
                getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.DNF),
                "install",
                appCode,
                "-y"
              ],
              userId: 0,
              environment: {},
            ),
          );
          return;
        }

        if (softwareManager == SOFTWARE_MANAGERS.PACMAN) {
          // Check, if package is available:
          bool available = await isPacmanPackageAvailable(appCode);
          if (!available) {
            continue;
          }

          commandQueue.add(
            LinuxCommand(
              argv: [
                getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.PACMAN),
                "-S",
                "--needed",
                "--noconfirm",
                appCode
              ],
              userId: 0,
              environment: {},
            ),
          );
          return;
        }

        if (softwareManager == SOFTWARE_MANAGERS.FLATPAK) {
          // Check, if package is available:
          String repo = await isFlatpakAvailable(appCode);
          if (repo == "") {
            continue;
          }

          commandQueue.add(
            LinuxCommand(
              argv: [
                getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.FLATPAK),
                "install",
                repo,
                appCode,
                "--system",
                "-y",
                "--noninteractive"
              ],
              userId: 0,
            ),
          );
          return;
        }

        if (softwareManager == SOFTWARE_MANAGERS.SNAP) {
          // Check, if package is available:
          bool available = await isSnapAvailable(appCode);
          if (!available) {
            continue;
          }

          commandQueue.add(
            LinuxCommand(
              argv: [
                getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.SNAP),
                "install",
                appCode
              ],
              userId: 0,
              environment: {"DEBIAN_FRONTEND": "noninteractive"},
            ),
          );
          return;
        }
      }
    }
  }

  static Future<bool> isSpecificFlatpakInstalled(String appCode) async {
    if (!currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.FLATPAK)) {
      return false;
    }
    // Only accept appCodes with two '.' in it. Example: 'com.example.app'
    if (".".allMatches(appCode).length < 2) {
      return false;
    }
    // `flatpak info` exits non-zero for an app that is not installed. The
    // previous version searched the whole list with `contains`, so
    // "org.x.Warp" reported itself installed because "org.x.Warpinator" was.
    return commandSucceeds(
        getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.FLATPAK),
        ["info", appCode]);
  }

  static Future<bool> isSpecificDebPackageInstalled(appCode) async {
    if (!currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.APT)) {
      return false;
    }
    // dpkg-query exits 1 for an unknown package and prints the status for a
    // known one. The previous version looked for "ii  $appCode" in `dpkg -l`
    // output, which is a table whose column widths depend on the terminal and
    // whose header the package name could appear in.
    final CommandResult result = await runProcess(
      "/usr/bin/dpkg-query",
      ["-W", "-f=\${Status}", appCode],
      environment: {"LC_ALL": "C"},
    );
    return result.success && result.output.contains("install ok installed");
  }

  static Future<bool> isSpecificZypperPackageInstalled(appCode) async {
    if (!currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.ZYPPER)) {
      return false;
    }
    // `rpm -q` answers exactly this question with an exit code. Parsing
    // "Installed: Yes" out of `zypper info` broke on every translated system.
    return commandSucceeds("/usr/bin/rpm", ["-q", appCode]);
  }

  static Future<bool> isSpecificDNFPackageInstalled(appCode) async {
    if (!currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.DNF)) {
      return false;
    }
    return commandSucceeds("/usr/bin/rpm", ["-q", appCode]);
  }

  static Future<bool> isSpecificPacmanPackageInstalled(appCode) async {
    if (!currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.PACMAN)) {
      return false;
    }
    // Positive test. The previous `!output.contains("was not found")` also
    // returned true when the command failed to run at all, and a false
    // positive here queues a removal.
    return commandSucceeds(
        getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.PACMAN),
        ["-Q", appCode]);
  }

  static Future<bool> isSpecificSnapInstalled(appCode) async {
    if (!currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.SNAP)) {
      return false;
    }
    // `snap list <name>` exits 1 when the snap is not installed. `snap info`
    // succeeds for anything in the store, and its output contains
    // "installed: " only when it happens to be installed locally — a
    // distinction the old substring check did not make reliably.
    return commandSucceeds(
        getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.SNAP),
        ["list", appCode]);
  }

  /// Tries to uninstall all appCodes.
  /// If you don't specify the softwareManager it will be tried to remove the application with all Software Managers
  static Future<void> removeApplications(List<String> appCodes,
      {SOFTWARE_MANAGERS? softwareManager}) async {
    for (String appCode in appCodes) {
      if (softwareManager == null || softwareManager == SOFTWARE_MANAGERS.APT) {
        // Deb Package
        bool isDebianPackageInstalled =
            await isSpecificDebPackageInstalled(appCode);
        if ((softwareManager == null ||
                softwareManager == SOFTWARE_MANAGERS.APT) &&
            isDebianPackageInstalled) {
          commandQueue.add(
            LinuxCommand(
              userId: 0,
              argv: [
                getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.APT),
                "remove",
                appCode,
                "-y"
              ],
              environment: {"DEBIAN_FRONTEND": "noninteractive"},
            ),
          );

          commandQueue.add(
            LinuxCommand(
              userId: 0,
              argv: [
                getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.APT),
                "autoremove",
                "-y"
              ],
              environment: {"DEBIAN_FRONTEND": "noninteractive"},
            ),
          );
        }
      }

      // Zypper
      if (softwareManager == null ||
          softwareManager == SOFTWARE_MANAGERS.ZYPPER) {
        bool isZypperPackageInstalled =
            await isSpecificZypperPackageInstalled(appCode);
        if ((softwareManager == null ||
                softwareManager == SOFTWARE_MANAGERS.ZYPPER) &&
            isZypperPackageInstalled) {
          commandQueue.add(
            LinuxCommand(
              userId: 0,
              argv: [
                getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.ZYPPER),
                "--non-interactive",
                "remove",
                appCode
              ],
            ),
          );
        }
      }

      // DNF
      if (softwareManager == null || softwareManager == SOFTWARE_MANAGERS.DNF) {
        bool isPackageInstalled = await isSpecificDNFPackageInstalled(appCode);
        if ((softwareManager == null ||
                softwareManager == SOFTWARE_MANAGERS.DNF) &&
            isPackageInstalled) {
          commandQueue.add(
            LinuxCommand(
              userId: 0,
              argv: [
                getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.DNF),
                "remove",
                appCode,
                "-y"
              ],
            ),
          );
        }
      }

      // Pacman
      if (softwareManager == null ||
          softwareManager == SOFTWARE_MANAGERS.PACMAN) {
        bool isPacmanPackageInstalled =
            await isSpecificPacmanPackageInstalled(appCode);
        if ((softwareManager == null ||
                softwareManager == SOFTWARE_MANAGERS.PACMAN) &&
            isPacmanPackageInstalled) {
          commandQueue.add(
            LinuxCommand(
              userId: 0,
              argv: [
                getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.PACMAN),
                "-Rs",
                "--noconfirm",
                appCode
              ],
            ),
          );
        }
      }

      // Flatpak
      if (softwareManager == null ||
          softwareManager == SOFTWARE_MANAGERS.FLATPAK) {
        bool isFlatpakInstalled = await isSpecificFlatpakInstalled(appCode);
        if ((softwareManager == null ||
                softwareManager == SOFTWARE_MANAGERS.FLATPAK) &&
            isFlatpakInstalled) {
          commandQueue.add(LinuxCommand(
            userId: currentenvironment.currentUserId,
            argv: [
              getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.FLATPAK),
              "remove",
              appCode,
              "-y",
              "--noninteractive"
            ],
          ));
          commandQueue.add(LinuxCommand(
            userId: 0,
            argv: [
              getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.FLATPAK),
              "uninstall",
              appCode,
              "-y",
              "--noninteractive",
              "--system"
            ],
          ));
        }
      }

      // Snap
      if (softwareManager == null ||
          softwareManager == SOFTWARE_MANAGERS.SNAP) {
        bool isSnapInstalled = await isSpecificSnapInstalled(appCode);
        if ((softwareManager == null ||
                softwareManager == SOFTWARE_MANAGERS.SNAP) &&
            isSnapInstalled) {
          commandQueue.add(
            LinuxCommand(
              userId: 0,
              argv: [
                getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.SNAP),
                "remove",
                appCode
              ],
            ),
          );
        }
      }
    }
  }

  // Returns true, if one of these application is installed.
  static Future<bool> areApplicationsInstalled(List<String> appCodes) async {
    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.APT)) {
      for (String appCode in appCodes) {
        bool isDebianPackageInstalled =
            await isSpecificDebPackageInstalled(appCode);
        if (isDebianPackageInstalled) {
          return true;
        }
      }
    }
    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.ZYPPER)) {
      for (String appCode in appCodes) {
        bool isZypperPackageInstalled =
            await isSpecificZypperPackageInstalled(appCode);
        if (isZypperPackageInstalled) {
          return true;
        }
      }
    }
    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.DNF)) {
      for (String appCode in appCodes) {
        bool isPackageInstalled = await isSpecificDNFPackageInstalled(appCode);
        if (isPackageInstalled) {
          return true;
        }
      }
    }
    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.PACMAN)) {
      for (String appCode in appCodes) {
        bool isPacmanPackageInstalled =
            await isSpecificPacmanPackageInstalled(appCode);
        if (isPacmanPackageInstalled) {
          return true;
        }
      }
    }
    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.FLATPAK)) {
      for (String appCode in appCodes) {
        bool isFlatpakInstalled = await isSpecificFlatpakInstalled(appCode);
        if (isFlatpakInstalled) {
          return true;
        }
      }
    }
    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.SNAP)) {
      for (String appCode in appCodes) {
        bool isSnapInstalled = await isSpecificSnapInstalled(appCode);
        if (isSnapInstalled) {
          return true;
        }
      }
    }
    return false;
  }

  static Future<bool> isDebPackageAvailable(String appCode) async {
    String output = await runCommand(
        "${getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.APT)} show $appCode");
    return output.contains("Package: ") &&
        !output.contains("No packages found");
  }

  static Future<bool> isZypperPackageAvailable(String appCode) async {
    // `zypper info` on an unknown package still exits 0 and only says so in
    // prose, which the old `!contains(" not found.")` read in English only.
    // `zypper search --match-exact` exits 104 when nothing matches.
    return commandSucceeds(
        getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.ZYPPER),
        ["--non-interactive", "search", "--match-exact", appCode]);
  }

  static Future<bool> isDNFPackageAvailable(String appCode) async {
    return commandSucceeds(
        getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.DNF),
        ["info", appCode]);
  }

  static Future<bool> isPacmanPackageAvailable(String appCode) async {
    return commandSucceeds(
        getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.PACMAN),
        ["-Si", appCode]);
  }

  /// returns the source under which the Flatpak is available, otherwise empty String
  static Future<String> isFlatpakAvailable(String appCode) async {
    String output = await runCommand(
        "${getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.FLATPAK)} search $appCode");
    if (output.split("\n").length >= 2) {
      List<String> lines = output.split("\n");
      for (String line in lines) {
        if (line.split("\t").contains(appCode)) {
          return line.split("\t").last.replaceAll("\n", "");
        }
      }
    }
    return "";
  }

  static Future<bool> isSnapAvailable(String appCode) async {
    String output = await Linux.runCommand(
        "${getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.SNAP)} info $appCode");
    return output.split("\n").length > 5;
  }

  /// returns true, if at least one of the app codes is available
  static Future<bool> areApplicationsAvailable(List<String> appCodes) async {
    for (String appCode in appCodes) {
      bool available = await isDebPackageAvailable(appCode);
      if (available) {
        return true;
      }
      available = await isZypperPackageAvailable(appCode);
      if (available) {
        return true;
      }
      available = await isDNFPackageAvailable(appCode);
      if (available) {
        return true;
      }
      available = await isSnapAvailable(appCode);
      if (available) {
        return true;
      }
      String repo = await isFlatpakAvailable(appCode);
      if (repo != "") {
        return true;
      }
    }
    return false;
  }

  /// If [installed] == false, it will be ensured that the app is not installed on the system
  /// If [installed] == true, it will be ensured that the app will be installed on the system
  ///
  /// Tries to install at least one appCode in [appCodes] or tries to remove all appCodes
  /// Doesn't run the command instantly, only puts the commands in to the commandQueue.
  static Future<void> ensureApplicationInstallation(List<String> appCodes,
      {bool installed = true}) async {
    bool initial = await areApplicationsInstalled(appCodes);
    // print("App: $appCodes initial: $initial installed: $installed");
    if (installed && !initial) {
      await installApplications(appCodes);
    } else if (!installed && initial) {
      await removeApplications(appCodes);
    }
  }

  /// After calling this function the command queue should be run
  static Future<void> setUpFlatpak() async {
    await ensureApplicationInstallation(["flatpak"]);
    commandQueue.add(LinuxCommand(userId: 0, argv: [
      "/usr/bin/flatpak",
      "remote-add",
      "--if-not-exists",
      "flathub",
      "https://flathub.org/repo/flathub.flatpakrepo"
    ]));
    // We set this temporally to easily add flatpaks to the system. It will be written to config at next startup (if the installation of flatpak really succeded)
    Linux.currentenvironment.installedSoftwareManagers
        .add(SOFTWARE_MANAGERS.FLATPAK);
  }

  static void openWebbrowserSeach(String searchterm) {
    searchterm = searchterm.replaceAll(" ", "+");
    runCommand("/usr/bin/xdg-open https://duckduckgo.com/?q=$searchterm");
  }

  static void openWebbrowserWithSite(String website) {
    if (!website.startsWith("http")) {
      website = "https://$website";
    }
    runCommand("/usr/bin/xdg-open $website");
  }

  static Future<void> getAllFolderEntriesOfUser(BuildContext context) async {
    // Resolved before the first await: the caller does not await this method,
    // so by the time the scan finishes the context may already be deactivated.
    final String openLabel = AppLocalizations.of(context)!.openX;

    List<String> folders = [];
    homeFolder = getHomeDirectory();

    // Three guards, all of which were missing and all of which have bitten
    // somebody: `-maxdepth` (a home with node_modules or a synced cloud folder
    // otherwise yields hundreds of thousands of directories), no `-L` (a
    // symlink to / or to an unresponsive network mount used to send this off
    // into the whole filesystem), and a quoted path (a space in the home
    // directory used to split the command apart).
    final int depth =
        ConfigHandler().getValueUnsafe("folder_recursion_depth", 3);
    final String home = homeFolder.endsWith("/")
        ? homeFolder.substring(0, homeFolder.length - 1)
        : homeFolder;

    await Linux.runCommandWithCustomArguments(
      "bash",
      [
        "-c",
        "find '${home.replaceAll("'", r"'\''")}' -maxdepth $depth -type d"
      ],
      environment: {"PWD": "/"},
    ).then((value) {
      folders =
          value.split("\n").where((element) => element.isNotEmpty).toList();
    });

    // Get Bookmarks:
    if (currentenvironment.desktop != DESKTOPS.KDE) {
      String home = getHomeDirectory();
      String bookmarksLocation = "$home/.config/gtk-3.0/bookmarks";
      String bookmarksString = await runCommand("cat $bookmarksLocation");
      List<String> bookmarkCandidates = bookmarksString.split("\n");
      for (String bookmarkCandidate in bookmarkCandidates) {
        String bookmark = bookmarkCandidate.split(" ")[0];
        if (bookmark.startsWith("file://")) {
          if (!bookmark.endsWith("/")) {
            bookmark = "$bookmark/";
          }
          String folder = bookmark.replaceFirst("file://", "");

          // Sometimes broken bookmarks are also available at systems. Filter them out.
          if (Directory(folder).existsSync()) {
            folders.add(folder);
          }
        }
      }
    } else if (currentenvironment.desktop == DESKTOPS.KDE) {
      List<String> lines =
          await File("${getHomeDirectory()}/.local/share/user-places.xbel")
              .readAsLines();
      for (String line in lines) {
        if (line.contains("<bookmark href=\"file://")) {
          folders.add(line
              .replaceAll("<bookmark href=\"file://", "")
              .replaceAll("\">", ""));
        }
      }
    }

    List<ActionEntry> actionEntries = [];
    for (String folder in folders) {
      List<String> elements = folder.split("/");
      if (elements.length < 2) {
        continue;
      }
      String folderName = elements[elements.length - 1];
      if (folderName.trim() == "") {
        folderName = elements[elements.length - 2];
      }
      folder = folder.trim();
      if (!folder.endsWith("/")) {
        folder = "$folder/";
      }
      ActionEntry entry = ActionEntry(
          name: folderName,
          description: "$openLabel $folder",
          action: "openfolder:$folder");
      entry.priority = -10;
      actionEntries.add(entry);
    }
    await ActionEntryListService.addEntries(actionEntries);
  }

  // Get all available applications, which are installed and .destop files are present.
  static Future<void> getAllAvailableApplications() async {
    String applicationsString = await runCommandWithCustomArguments("python3", [
      "$pythonScriptsFolder/get_applications.py",
      "--lang=${currentenvironment.language}",
      "--desktop=${currentenvironment.desktop.toString()}"
    ]);

    List<String> applications = applicationsString.split('\n');
    List<ActionEntry> actionEntries = [];
    for (String applicationString in applications) {
      List<String> values = applicationString.split('\t');

      if (values.length < 3) {
        continue;
      }

      ActionEntry entry = ActionEntry(
          name: values[1],
          description: values[2],
          action: "openapp:${values[0]}");

      if (values.length >= 4) {
        entry.iconURI = values[3];
      }

      if (values.length >= 5) {
        entry.keywords = values[4].split(';');
      }
      entry.priority = -5;
      actionEntries.add(entry);
    }
    // return actionEntries;
    await ActionEntryListService.addEntries(actionEntries);
  }

  static Future<void> getRecentFiles(BuildContext context) async {
    // Resolved before the await — see [getAllFolderEntriesOfUser].
    final String openLabel = AppLocalizations.of(context)!.openX;
    String recentFileString = await runPythonScript("get_recent_files.py");
    List<String> recentFiles = recentFileString.split("\n");
    List<ActionEntry> actionEntries = [];
    for (String recentFile in recentFiles) {
      String fileName = recentFile.split("/").last;
      ActionEntry actionEntry = ActionEntry(
          name: fileName,
          description: "$openLabel $recentFile",
          action: "openfile:$recentFile");
      actionEntry.priority = -15;
      actionEntries.add(actionEntry);
    }
    // return actionEntries;
    await ActionEntryListService.addEntries(actionEntries);
  }

  /// Picks the closest known distribution for one this build does not know,
  /// using the `ID` and `ID_LIKE` fields of `/etc/os-release`.
  ///
  /// `ID_LIKE` is a space separated list ordered from closest to furthest, so
  /// it is scanned in order: `ID_LIKE="ubuntu debian"` resolves to Ubuntu.
  static DISTROS distroFromIdLike(String id, String idLike) {
    for (final String token in [id, ...idLike.split(" ")]) {
      switch (token.trim().toLowerCase()) {
        case "ubuntu":
          return DISTROS.UBUNTU;
        case "debian":
          return DISTROS.DEBIAN;
        case "arch":
          return DISTROS.ARCH;
        case "fedora":
        case "rhel":
          return DISTROS.FEDORA;
        case "suse":
        case "opensuse":
          return DISTROS.OPENSUSE;
      }
    }
    return DISTROS.DEBIAN;
  }

  static Future<Environment> getCurrentEnvironment() async {
    String commandOutput = await runPythonScript("get_environment.py");
    List<String> lines = commandOutput.split("\n");
    Environment newEnvironment = Environment();

    // get OS:
    if (lines[0].contains("Linux Mint")) {
      newEnvironment.distribution = DISTROS.LINUX_MINT;
    } else if (lines[0].toLowerCase().contains("pop!_os")) {
      newEnvironment.distribution = DISTROS.POPOS;
    } else if (lines[0].toLowerCase().contains("opensuse")) {
      newEnvironment.distribution = DISTROS.OPENSUSE;
    } else if (lines[0].toLowerCase().contains("kde neon")) {
      newEnvironment.distribution = DISTROS.KDENEON;
    } else if (lines[0].toLowerCase().contains("mxlinux")) {
      newEnvironment.distribution = DISTROS.MXLINUX;
    } else if (lines[0].toLowerCase().contains("zorin")) {
      newEnvironment.distribution = DISTROS.ZORINOS;
    } else if (lines[0].toLowerCase().contains("ubuntu")) {
      newEnvironment.distribution = DISTROS.UBUNTU;
    } else if (lines[0].toLowerCase().contains("debian")) {
      newEnvironment.distribution = DISTROS.DEBIAN;
    } else if (lines[0].toLowerCase().contains("lmde")) {
      newEnvironment.distribution = DISTROS.LMDE;
    } else if (lines[0].toLowerCase().contains("fedora")) {
      newEnvironment.distribution = DISTROS.FEDORA;
    } else if (lines[0].toLowerCase().contains("arch")) {
      newEnvironment.distribution = DISTROS.ARCH;
    } else if (lines[0].toLowerCase().contains("manjaro")) {
      newEnvironment.distribution = DISTROS.MANJARO;
    } else if (lines[0].toLowerCase().contains("endeavour")) {
      newEnvironment.distribution = DISTROS.ENDEAVOUR;
    } else {
      // Unknown distribution. Rather than leaving the field's Debian default
      // standing silently, use the family the distribution declares itself —
      // an Ubuntu derivative behaves far more like Ubuntu than like Debian
      // when it comes to package names and the software centre.
      newEnvironment.distribution = distroFromIdLike(
        lines.length > 6 ? lines[6] : "",
        lines.length > 7 ? lines[7] : "",
      );
    }

    // get version:
    newEnvironment.versionString = lines[1];
    // Only use first two numbers of version number
    List<String> splitVer = lines[1].split(".");
    if (splitVer.length >= 2) {
      lines[1] = "${splitVer[0]}.${splitVer[1]}";
    } else {
      lines[1] = splitVer[0];
    }
    if (double.tryParse(lines[1]) == null) {
      newEnvironment.version = -1.0;
    } else {
      newEnvironment.version = double.parse(lines[1]);
    }

    // get desktop:
    if (lines[2].toLowerCase().contains("gnome")) {
      newEnvironment.desktop = DESKTOPS.GNOME;
    } else if (lines[2].toLowerCase().contains("cinnamon")) {
      newEnvironment.desktop = DESKTOPS.CINNAMON;
    } else if (lines[2].toLowerCase().contains("kde")) {
      newEnvironment.desktop = DESKTOPS.KDE;
    } else if (lines[2].toLowerCase().contains("xfce")) {
      newEnvironment.desktop = DESKTOPS.XFCE;
    }

    // get language
    newEnvironment.language = lines[3];

    // get default browser
    if (lines[4].toLowerCase().contains("brave")) {
      newEnvironment.browser = BROWSERS.BRAVE;
    } else if (lines[4].toLowerCase().contains("chrome")) {
      newEnvironment.browser = BROWSERS.CHROME;
    } else if (lines[4].toLowerCase().contains("chromium")) {
      newEnvironment.browser = BROWSERS.CHROMIUM;
    } else if (lines[4].toLowerCase().contains("edge")) {
      newEnvironment.browser = BROWSERS.EDGE;
    } else if (lines[4].toLowerCase().contains("firefox")) {
      newEnvironment.browser = BROWSERS.FIREFOX;
    } else if (lines[4].toLowerCase().contains("opera")) {
      newEnvironment.browser = BROWSERS.OPERA;
    } else if (lines[4].toLowerCase().contains("librewolf")) {
      newEnvironment.browser = BROWSERS.LIBREWOLF;
    } else if (lines[4].toLowerCase().contains("waterfox")) {
      newEnvironment.browser = BROWSERS.WATERFOX;
    } else if (lines[4].toLowerCase().contains("torbrowser") ||
        lines[4].toLowerCase().contains("tor-browser")) {
      newEnvironment.browser = BROWSERS.TORBROWSER;
    }
    newEnvironment.wayland = lines[5].contains("wayland");

    for (int i = 0; i < SOFTWARE_MANAGERS.values.length; i++) {
      // Check if executable exists from root and from flatpak
      if (doesExecutableExist(
          getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.values[i]))) {
        newEnvironment.installedSoftwareManagers
            .add(SOFTWARE_MANAGERS.values[i]);
      }
    }

    // are we running in flatpak? We already got this from Linux.init()
    newEnvironment.runningInFlatpak = currentenvironment.runningInFlatpak;

    newEnvironment.currentUserId = await getUserIdOfCurrentUser();
    newEnvironment.hostname = await getHostname();
    newEnvironment.username = await getUsername();
    newEnvironment.groups = await getGroupsOfCurrentUser();
    newEnvironment.osPrettyName = await Linux.getOsPrettyName();
    newEnvironment.kernelVersion = await getKernelVersion();
    newEnvironment.cpuModel = await getCpuModel();
    newEnvironment.gpuModel = await getGpuModel();

    return newEnvironment;
  }

  static Future<List<String>> getGroupsOfCurrentUser() async {
    String groups = await runCommand("groups");
    return groups.split(" ");
  }

  static String getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS input) {
    switch (input) {
      case SOFTWARE_MANAGERS.FLATPAK:
        return "/usr/bin/flatpak";
      case SOFTWARE_MANAGERS.SNAP:
        return "/usr/bin/snap";
      case SOFTWARE_MANAGERS.APT:
        return "/usr/bin/apt";
      case SOFTWARE_MANAGERS.ZYPPER:
        return "/usr/bin/zypper";
      case SOFTWARE_MANAGERS.DNF:
        return "/usr/bin/dnf";
      case SOFTWARE_MANAGERS.PACMAN:
        return "/usr/bin/pacman";
    }
  }

  // Returns local path when app is run in debug
  static String getExecutableFolder() {
    if (kDebugMode) {
      String pwd = "";
      if (Platform.environment['PWD'] != null) {
        pwd = Platform.environment['PWD']!;
        pwd += "/";
      }
      return pwd;
    }
    String wholePath = Platform.resolvedExecutable;
    List<String> parts = wholePath.split("/");
    parts.removeLast(); // remove executable file
    String returnValue = "";
    for (String part in parts) {
      if (part.trim().isEmpty) {
        continue;
      }
      returnValue = "$returnValue/$part";
    }
    returnValue = "$returnValue/";
    return returnValue;
  }

  /// Only adds commands to the command queue
  static Future<void> installMultimediaCodecs() async {
    switch (currentenvironment.distribution) {
      case DISTROS.DEBIAN:
      case DISTROS.MXLINUX:
        // await Linux.runCommandAndGetStdout(
        //     "pkexec /usr/bin/apt-add-repository contrib");
        // await Linux.runCommandAndGetStdout(
        //     "pkexec ${getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.APT)} update");
        // await Linux.runCommandAndGetStdout(
        //     "pkexec ${getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.APT)} install vlc libavcodec-extra libdvd-pkg -y",
        //     environment: {"DEBIAN_FRONTEND": "noninteractive"});

        // Currently do not add other repositories without warning, so we won't install libdvd-pkg
        commandQueue.add(LinuxCommand(userId: 0, argv: [
          getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.APT),
          "install",
          "vlc",
          "libavcodec-extra",
          "-y"
        ], environment: {
          "DEBIAN_FRONTEND": "noninteractive"
        }));
        break;
      case DISTROS.LINUX_MINT:
      case DISTROS.LMDE:
        commandQueue.add(LinuxCommand(userId: 0, argv: [
          getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.APT),
          "install",
          "mint-meta-codecs",
          "-y"
        ], environment: {
          "DEBIAN_FRONTEND": "noninteractive"
        }));
        break;
      case DISTROS.UBUNTU:
      case DISTROS.POPOS:
      case DISTROS.ZORINOS:
      case DISTROS.KDENEON:
        commandQueue.add(LinuxCommand(userId: 0, argv: [
          getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.APT),
          "install",
          "ubuntu-restricted-extras",
          "-y"
        ], environment: {
          "DEBIAN_FRONTEND": "noninteractive"
        }));
        break;
      case DISTROS.OPENSUSE:
        String file = await getEtcOsRelease();
        bool tumbleweed = file.toLowerCase().contains("tumbleweed");

        if (tumbleweed) {
          commandQueue.add(LinuxCommand(
            userId: 0,
            argv: [
              getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.ZYPPER),
              "--non-interactive",
              "addrepo",
              "-cfp",
              "90",
              "https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/",
              "packman"
            ],
          ));
        } else {
          // LEAP:
          // String releasever = "";
          // if (Platform.environment.containsKey("releasever")) {
          //   releasever = Platform.environment["releasever"]!;
          // }
          commandQueue.add(LinuxCommand(
            userId: 0,
            argv: [
              getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.ZYPPER),
              "--non-interactive",
              "addrepo",
              "-cfp",
              "90",
              "https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_\$releasever/",
              "packman"
            ],
          ));
        }

        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: [
            getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.ZYPPER),
            "--non-interactive",
            "refresh"
          ],
        ));
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: [
            getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.ZYPPER),
            "--non-interactive",
            "dist-upgrade",
            "--from",
            "packman",
            "--allow-vendor-change"
          ],
        ));
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: [
            getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.ZYPPER),
            "--non-interactive",
            "install",
            "--from",
            "packman",
            "ffmpeg",
            // Written as gstreamer-plugins-{good,bad,ugly,libav} before:
            // brace expansion is bash, and there is no bash in this path.
            "gstreamer-plugins-good",
            "gstreamer-plugins-bad",
            "gstreamer-plugins-ugly",
            "gstreamer-plugins-libav",
            "libavcodec-full",
            "vlc-codecs"
          ],
        ));

        break;
      case DISTROS.FEDORA:
        // sudo dnf install gstreamer1-plugins-{bad-\*,good-\*,base} gstreamer1-plugin-openh264 gstreamer1-plugin-libav --exclude=gstreamer1-plugins-bad-free-devel
        // sudo dnf install lame\* --exclude=lame-devel
        // sudo dnf group upgrade --with-optional Multimedia
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: [
            getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.DNF),
            "install",
            // Braces expanded here (see above). The remaining `*` is dnf's
            // own glob, which it applies to package names itself.
            "gstreamer1-plugins-bad-*",
            "gstreamer1-plugins-good-*",
            "gstreamer1-plugins-base",
            "gstreamer1-plugin-openh264",
            "gstreamer1-plugin-libav",
            "--exclude=gstreamer1-plugins-bad-free-devel",
            "-y"
          ],
        ));
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: [
            getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.DNF),
            "install",
            "lame*",
            "--exclude=lame-devel",
            "-y"
          ],
        ));
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: [
            getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.DNF),
            "group",
            "upgrade",
            "--with-optional",
            "Multimedia",
            "-y"
          ],
        ));
        break;
      case DISTROS.ARCH:
      case DISTROS.MANJARO:
      case DISTROS.ENDEAVOUR:
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: [
            getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.PACMAN),
            "-S",
            "--needed",
            "--noconfirm",
            "vlc",
            "gstreamer",
            "libdvdcss",
            "libdvdread",
            "libdvdnav",
            "ffmpeg",
            "gst-plugins-base",
            "gst-plugins-good",
            "gst-plugins-bad",
            "gst-plugins-ugly"
          ],
        ));
        break;
    }
  }

  /// The only two scripts this app is allowed to run as root.
  ///
  /// Each has its own polkit action in
  /// `org.linux-assistant.operations.policy`, annotated with its own
  /// `exec.path`. Anything not on this list has no action and pkexec would
  /// refuse it — the check here exists so a mistake shows up as an assertion
  /// during development rather than as a confusing dialog on a user's machine.
  static const List<String> _privilegedEntryPoints = [
    "run_multiple_commands.py",
    "read_security_report.py",
  ];

  /// Python script has to be in the additional/python folder.
  /// Example: [filename] = example.py
  ///
  /// Runs as the current user. Root goes through [runPrivilegedPythonScript].
  static Future<String> runPythonScript(String filename,
      {List<String> arguments = const [], bool getErrorMessages = true}) async {
    List<String> commandList = ["$pythonScriptsFolder$filename", ...arguments];

    logInfo("Run python script: python3 $commandList");

    // No shell: arguments are --key=value pairs that must reach the script
    // verbatim. The keyword search used to hand-shell-quote its argument,
    // which a keyword containing a single quote unwound into command
    // execution. expandCommand yields an absolute python3 path, which is
    // the documented precondition for turning the shell off.
    return runCommandWithCustomArguments("python3", commandList,
        getErrorMessages: getErrorMessages,
        environment: Platform.environment,
        runInShell: false);
  }

  /// Runs one of the [_privilegedEntryPoints] as root through pkexec.
  ///
  /// pkexec is given the script itself, not a launcher. The previous version
  /// always invoked `run_script.py <name>`, which meant one polkit action
  /// covered every script in the directory and the password dialog could not
  /// name what it was authorising.
  static Future<String> runPrivilegedPythonScript(String filename,
      {List<String> arguments = const [], bool getErrorMessages = true}) async {
    assert(_privilegedEntryPoints.contains(filename),
        "$filename has no polkit action; add one before calling it as root");

    List<String> commandList = ["$pythonScriptsFolder$filename", ...arguments];

    logInfo("Run privileged python script: pkexec $commandList");

    // No shell: with runInShell the argv is space-joined unquoted, so a HOME
    // like "/home/john doe" would truncate --home=… mid-path (and any shell
    // metacharacter in it would run). expandCommand yields absolute paths,
    // which is the documented precondition for turning the shell off.
    final result = await runProcess("pkexec", commandList,
        environment: Platform.environment, runInShell: false);
    if (result.error.isNotEmpty && getErrorMessages) {
      return result.output + result.error;
    }
    return result.output;
  }

  /// Same script and polkit action as [runPrivilegedPythonScript], but the
  /// caller sees the exit code.
  ///
  /// pkexec exits 126 when the dialog is dismissed and 127 when authorization
  /// is denied, while a checker that crashed after a successful authorization
  /// exits with its own non-zero code. Without the exit code those two look
  /// identical to the caller, which is how the security page ended up blaming
  /// missing root rights for a script bug.
  static Future<CommandResult> runPrivilegedPythonScriptDetailed(
      String filename, List<String> arguments) async {
    assert(_privilegedEntryPoints.contains(filename),
        "$filename has no polkit action; add one before calling it as root");

    final List<String> commandList = [
      "$pythonScriptsFolder$filename",
      ...arguments
    ];

    logInfo("Run privileged python script: pkexec $commandList");

    return runProcess("pkexec", commandList,
        environment: Platform.environment, runInShell: false);
  }

  /// Restricted to the display class on purpose. A bare `lshw` probes PCI, USB,
  /// SCSI and DMI and routinely takes seconds; `-C display` answers the only
  /// question asked here and returns immediately.
  static Future<bool> isNvidiaCardInstalledOnSystem() async {
    String output = await runCommand("lshw -C display");
    output = output.toLowerCase();
    return output.contains("nvidia");
  }

  static Future<bool> isNouveauCurrentGraphicsDriver() async {
    String output = await runCommand("lspci -nnk");
    output = output.toLowerCase();
    return output.contains("kernel driver in use: nouveau");
  }

  /// Puts all commands into [Linux.commandQueue]
  static Future<void> applyAutomaticConfigurationAfterInstallation(
      {bool applyUpdatesSinceRelease = true,
      bool installMultimediaCodecs_ = true,
      bool setupAutomaticSnapshots = true,
      bool installNvidiaDriversAutomatically = true,
      bool setupAutomaticUpdates = true}) async {
    if (applyUpdatesSinceRelease) {
      await updateAllPackages();
    }
    if (installMultimediaCodecs_) {
      await installMultimediaCodecs();
    }
    if (setupAutomaticSnapshots) {
      await enableAutomaticSnapshots();
    }
    if (installNvidiaDriversAutomatically) {
      commandQueue.add(LinuxCommand(userId: 0, argv: [
        "/usr/bin/python3",
        "${executableFolder}additional/python/install_nvidia_driver.py"
      ]));
    }
    if (setupAutomaticUpdates) {
      await enableAutomaticUpdates();
    }
  }

  /// Only appends commands to [commandQueue]
  static Future<void> enableAutomaticUpdates() async {
    switch (currentenvironment.distribution) {
      case DISTROS.OPENSUSE:
        await ensureApplicationInstallation(
            ["yast2-online-update-configuration"]);
        commandQueue.add(LinuxCommand(userId: 0, argv: [
          "/usr/bin/ln",
          "-s",
          "/usr/lib/YaST2/bin/online_update",
          "/etc/cron.daily/"
        ]));
        break;
      default:
        commandQueue.add(LinuxCommand(userId: 0, argv: [
          "/usr/bin/python3",
          "${executableFolder}additional/python/setup_automatic_updates_debian.py"
        ]));
        if (currentenvironment.distribution == DISTROS.LINUX_MINT) {
          /// Set com.linuxmint.updates auto-update-cinnamon-spices true
          commandQueue.add(
              LinuxCommand(userId: currentenvironment.currentUserId, argv: [
            "/usr/bin/gsettings",
            "set",
            "com.linuxmint.updates",
            "auto-update-cinnamon-spices",
            "true"
          ]));

          /// Set com.linuxmint.updates auto-update-flatpaks true
          commandQueue.add(
              LinuxCommand(userId: currentenvironment.currentUserId, argv: [
            "/usr/bin/gsettings",
            "set",
            "com.linuxmint.updates",
            "auto-update-flatpaks",
            "true"
          ]));
        }
    }
  }

  /// Only appends commands to [commandQueue]
  static Future<void> enableAutomaticSnapshots() async {
    await ensureApplicationInstallation(["timeshift"]);
    String additional = "";
    if ([DISTROS.ARCH, DISTROS.MANJARO, DISTROS.ENDEAVOUR]
        .contains(currentenvironment.distribution)) {
      additional = "--daily";
    }
    commandQueue.add(LinuxCommand(userId: 0, argv: [
      "/usr/bin/python3",
      "${executableFolder}additional/python/setup_automatic_snapshots.py",
      additional
    ]));
  }

  /// Only appends commands to [commandQueue]
  static Future<void> updateAllPackages() async {
    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.APT)) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/apt", "update"],
        environment: {"DEBIAN_FRONTEND": "noninteractive"},
      ));
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/apt", "dist-upgrade", "-y"],
        environment: {"DEBIAN_FRONTEND": "noninteractive"},
      ));
    } else if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.DNF)) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: [
          getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.DNF),
          "update",
          "--refresh",
          "-y"
        ],
      ));
    } else if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.ZYPPER)) {
      String file = await getEtcOsRelease();
      if (file.toLowerCase().contains("tumbleweed")) {
        // Tumbleweed
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: [
            getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.ZYPPER),
            "--non-interactive",
            "dup"
          ],
        ));
      } else {
        // Leap or other
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: [
            getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.ZYPPER),
            "--non-interactive",
            "up"
          ],
        ));
      }
    } else if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.PACMAN)) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: [
          getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.PACMAN),
          "-Syu",
          "--noconfirm"
        ],
      ));
    }

    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.FLATPAK)) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/flatpak", "upgrade", "-y"],
        environment: {"DEBIAN_FRONTEND": "noninteractive"},
      ));
    }

    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.SNAP)) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/snap", "refresh"],
        environment: {"DEBIAN_FRONTEND": "noninteractive"},
      ));
    }
  }

  static Future<String> getEtcOsRelease() async {
    return await File("/etc/os-release").readAsString();
  }

  static Future<void> getFavoriteFiles(BuildContext context) async {
    // Resolved before the await — see [getAllFolderEntriesOfUser].
    final String openLabel = AppLocalizations.of(context)!.openX;
    String output = await runPythonScript("get_favorite_files.py");
    output = output.trim();
    List<String> list = output.split("\n");

    List<ActionEntry> actionEntries = [];
    for (String e in list) {
      String fileName = e.split("/").last;
      ActionEntry actionEntry = ActionEntry(
          name: fileName, description: "$openLabel $e", action: "openfile:$e");
      actionEntry.priority = -5;
      actionEntries.add(actionEntry);
    }
    // return actionEntries;
    await ActionEntryListService.addEntries(actionEntries);
  }

  /// Serializes [commandQueue] for the root helper.
  ///
  /// One JSON object per line: `{"uid": 0, "argv": [...], "env": {...},
  /// "shell": false}`. The previous format was a hand-rolled
  /// `"uid";"cmd";"K='V'";` line that the Python side split on `";"` and `=`,
  /// so it lost data on any value containing a quote or an equals sign — and
  /// the command itself arrived as a string that had to be re-parsed.
  @visibleForTesting
  static String serializeCommandQueue(List<LinuxCommand> queue) {
    return queue.map((command) => jsonEncode(command.toJson())).join("\n");
  }

  static Future<String> executeCommandQueue() async {
    if (commandQueue.isEmpty) {
      return "No actions in queue.";
    }

    String string = serializeCommandQueue(commandQueue);

    // Not a security measure: both the path and the hash are argv from the
    // unprivileged caller, so anyone able to pass one can pass the other. It
    // catches a truncated or half-written file, nothing more.
    String checksum = Hashing.getMd5OfString(string);

    String filepath = '$homeFolder/.cache/linux_assistant_commands';
    File file = File(filepath);
    // Awaited: the root helper re-hashes this file, and racing the write is
    // what produced the sporadic "Checksum test failed!".
    await file.writeAsString(string, flush: true);

    String output = await runPrivilegedPythonScript("run_multiple_commands.py",
        arguments: ["--md5=$checksum", "--path=$filepath"]);

    return output;
  }

  static void clearCommandQueue() {
    commandQueue.clear();
  }

  static Future<int> getUserIdOfCurrentUser() async {
    String output = await Linux.runCommand("id -u");
    return int.parse(output);
  }

  /// Only returns results if keyword is longer than 3 and there are under 100 results.
  static Future<List<ActionEntry>> getInstallableAptPackagesForKeyword(
      BuildContext context, String keyword) async {
    if (keyword.length <= 3) {
      return [];
    }
    String output = await runPythonScript("search_available_apt_packages.py",
        arguments: ["--keyword=$keyword"], getErrorMessages: false);
    output = output.trim();
    List<String> lines = output.split("\n");

    // Cancel search, if too many search results.
    if (lines.length > 100) {
      return [];
    }

    // The apt search runs a Python subprocess; the search field that asked for
    // these entries can be gone by the time they arrive.
    if (!context.mounted) {
      return [];
    }

    List<ActionEntry> results = [];
    for (String line in lines) {
      if (line.trim() == "") {
        continue;
      }
      results.add(ActionEntry(
        iconWidget: Icon(
          Icons.download_rounded,
          size: 48,
          color: MintY.currentColor,
        ),
        name: AppLocalizations.of(context)!.installX(line),
        description: "Install via apt",
        action: "apt-install:$line",
        priority: -20,
      ));
    }
    return results;
  }

  static Future<List<ActionEntry>> getInstallableSnapPackagesForKeyword(
      String keyword) async {
    if (keyword.length <= 3) {
      return [];
    }
    String output = await runCommandWithCustomArguments(
        getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.SNAP),
        ["find", "--narrow", keyword]);
    output = output.trim();
    List<String> lines = output.split("\n");
    // Remove the first line (this is the heading)
    lines.removeAt(0);

    // Cancel search, if too many search results.
    if (lines.length > 100) {
      return [];
    }

    List<ActionEntry> results = [];
    for (String line in lines) {
      // Get the only the first word of the line (with regex), not with .split(" ")
      String snapName = line.split(" ")[0];
      // print the Unicode code point of every single character
      if (snapName.trim() == "") {
        continue;
      }
      results.add(ActionEntry(
        iconWidget: Icon(
          Icons.archive,
          size: 48,
          color: MintY.currentColor,
        ),
        name: "Install $snapName",
        description: "Install via snap",
        action: "snap-install:$snapName",
        priority: -21,
      ));
    }
    return results;
  }

  static Future<List<ActionEntry>> getInstallableFlatpakPackagesForKeyword(
      String keyword) async {
    if (keyword.length <= 3) {
      return [];
    }
    String output = await runCommandWithCustomArguments(
        getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.FLATPAK),
        ["search", keyword, "--columns=application,name,description"]);
    output = output.trim();
    List<String> lines = output.split("\n");

    if (output.contains("No matches found")) {
      return [];
    }

    if (lines.length > 100) {
      return [];
    }

    List<ActionEntry> results = [];
    for (String line in lines) {
      List<String> lineParts = line.split("\t");
      if (lineParts.length < 3) {
        continue;
      }
      String appID = lineParts[0].trim();
      String appName = lineParts[1].trim();
      String appDescription = lineParts[2].trim();
      results.add(ActionEntry(
        iconWidget: Icon(
          Icons.archive,
          size: 48,
          color: MintY.currentColor,
        ),
        name: "Install $appName (Flatpak)",
        description: appDescription,
        action: "flatpak-install:$appID",
        priority: -20,
      ));
    }

    return results;
  }

  /// Only returns results if keyword is longer than 3 and there are under 100 results.
  static Future<List<ActionEntry>> getInstallableZypperPackagesForKeyword(
      String keyword) async {
    if (keyword.length <= 3) {
      return [];
    }
    String output = await runCommandWithCustomArguments(
        getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.ZYPPER),
        ["--non-interactive", "search", keyword]);
    output = output.trim();
    List<String> lines = output.split("\n");

    // Cancel search, if too many search results.
    if (lines.length > 104) {
      return [];
    }

    List<ActionEntry> results = [];
    for (String line in lines) {
      if (line.trim() == "" || line.split("|").length < 4) {
        continue;
      }
      List<String> lineParts = line.split("|");
      String packageName = lineParts[1].trim();

      // Skip table head
      if (packageName == "Name") {
        continue;
      }

      // if already installed, skip entry
      if (lineParts[0].trim() == "i") {
        continue;
      }

      results.add(ActionEntry(
          iconWidget: Icon(
            Icons.archive,
            size: 48,
            color: MintY.currentColor,
          ),
          name: "Install $packageName",
          description: "Install via zypper",
          action: "zypper-install:$packageName",
          priority: -20));
    }
    return results;
  }

  static Future<List<ActionEntry>> getInstallableDNFPackagesForKeyword(
      String keyword) async {
    if (keyword.length <= 3) {
      return [];
    }
    String output = await runCommandWithCustomArguments(
        getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.DNF),
        ["search", keyword],
        environment: {"LC_ALL": "C"});
    output = output.trim();
    List<String> lines = output.split("\n");

    // Cancel search, if too many search results.
    if (lines.length > 100) {
      return [];
    }

    List<List<String>> allInstalledPackages = await getInstalledDNFPackages();

    List<ActionEntry> results = [];
    for (String line in lines) {
      if (line.trim() == "") {
        continue;
      }
      String pkgName = line.split(".")[0];
      if (pkgName.contains(" ")) {
        continue;
      }

      // if already installed, skip entry
      bool alreadyInstalled = false;
      for (List<String> installedPackage in allInstalledPackages) {
        if (installedPackage[0] == pkgName) {
          alreadyInstalled = true;
          break;
        }
      }
      if (alreadyInstalled) {
        continue;
      }

      results.add(ActionEntry(
        iconWidget: Icon(
          Icons.download_rounded,
          size: 48,
          color: MintY.currentColor,
        ),
        name: "Install $pkgName",
        description: "Install via dnf",
        action: "dnf-install:$pkgName",
        priority: -20,
      ));
    }
    return results;
  }

  static Future<List<ActionEntry>> getInstallablePacmanPakagesForKeyword(
      keyword) {
    if (keyword.length <= 3) {
      return Future.value([]);
    }
    return runCommandWithCustomArguments(
        getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.PACMAN),
        ["-Ss", keyword]).then((output) {
      output = output.trim();
      List<String> lines = output.split("\n");

      // Cancel search, if too many search results.
      if (lines.length > 100) {
        return [];
      }

// $ pacman -Ss htop
// extra/bashtop 0.9.25-1
//     Linux resource monitor

      List<ActionEntry> results = [];
      for (String line in lines) {
        if (line.trim() == "") {
          continue;
        }
        List<String> lineParts = line.split(" ");
        String packageName = lineParts[0].trim();
        if (!packageName.contains("/")) {
          continue;
        }
        packageName = packageName.split("/")[1];
        results.add(ActionEntry(
          iconWidget: Icon(
            Icons.download_rounded,
            size: 48,
            color: MintY.currentColor,
          ),
          name: "Install $packageName",
          description: "Install via pacman",
          action: "pacman-install:$packageName",
          priority: -20,
        ));
      }
      return results;
    });
  }

  static Future<List<String>> getInstalledAPTPackages() async {
    if (!currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.APT)) {
      return [];
    }
    List<String> returnValue = [];

    /// Run: /usr/bin/dpkg --get-selections | /usr/bin/awk '!/deinstall|purge|hold/' | /usr/bin/cut -f1 | /usr/bin/tr '\n' ' '
    String output = await Linux.runCommandWithCustomArguments("/usr/bin/dpkg", [
      "--get-selections",
    ]);

    List<String> lines = output.split("\n");

    for (String line in lines) {
      if (line.contains("install")) {
        returnValue.add(line.replaceFirst("install", "").trim());
      }
    }
    return returnValue;
  }

  /// Returns List of [package name, description]
  static Future<List<List<String>>> getInstalledZypperPackages() async {
    if (!currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.ZYPPER)) {
      return [];
    }
    List<List<String>> returnValue = [];

    /// Run: zypper se --installed-only
    String output =
        await Linux.runCommandWithCustomArguments("/usr/bin/zypper", [
      "se",
      "--installed-only",
    ]);

    List<String> lines = output.split("\n");

    for (String line in lines) {
      List<String> lineParts = line.split("|");
      if (lineParts.length < 4) {
        continue;
      }
      String packageName = lineParts[1].trim();
      String description = lineParts[2].trim();
      returnValue.add([packageName, description]);
    }
    return returnValue;
  }

  /// Returns List of [package name]
  static Future<List<List<String>>> getInstalledDNFPackages() async {
    if (!currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.DNF)) {
      return [];
    }
    List<List<String>> returnValue = [];

    /// Run: zypper se --installed-only
    String output = await Linux.runCommandWithCustomArguments(
      "/usr/bin/dnf",
      [
        "list",
        "installed",
      ],
      environment: {"LC_ALL": "C"},
    );

    List<String> lines = output.split("\n");

    for (String line in lines) {
      // Remove all double spaces with regex
      line = line.replaceAll(RegExp(r"\s+"), " ");
      line = line.trim();

      List<String> lineParts = line.split(" ");

      if (lineParts.length != 3) {
        continue;
      }
      String packageName = lineParts[0].trim();
      packageName = packageName.split(".")[0];
      returnValue.add([packageName]);
    }
    return returnValue;
  }

  /// Returns List of [package name]
  static Future<List<String>> getInstalledPacmanPackages() async {
    if (!currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.PACMAN)) {
      return [];
    }
    List<String> returnValue = [];

    /// Run: pacman -Q
    String output = await Linux.runCommandWithCustomArguments(
      "/usr/bin/pacman",
      [
        "-Q",
      ],
    );

    List<String> lines = output.split("\n");

    for (String line in lines) {
      List<String> lineParts = line.split(" ");
      if (lineParts.length < 2) {
        continue;
      }
      String packageName = lineParts[0].trim();
      returnValue.add(packageName);
    }
    return returnValue;
  }

  /// Return value: List of [app id, app name, app description];
  static Future<List<List<String>>> getInstalledFlatpaks() async {
    if (!currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.FLATPAK)) {
      return [];
    }
    List<List<String>> returnValue = [];
    String installedFlatpaks = await Linux.runCommandWithCustomArguments(
        "/usr/bin/flatpak",
        ["list", "--app", "--columns=application,name,description"]);
    List<String> lines = installedFlatpaks.split("\n");
    for (String line in lines) {
      if (line.isNotEmpty) {
        List<String> app = line.split("\t");
        returnValue.add(app);
      }
    }
    return returnValue;
  }

  /// Return value: List of app id;
  static Future<List<String>> getInstalledSnaps() async {
    if (!currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.SNAP)) {
      return [];
    }
    List<String> returnValue = [];
    String installedSnaps =
        await Linux.runCommandWithCustomArguments("/usr/bin/snap", ["list"]);
    List<String> lines = installedSnaps.split("\n");

    /// Remove the heading line of the output of the command
    lines.removeAt(0);

    for (String line in lines) {
      if (line.isNotEmpty) {
        returnValue.add(line.split(" ")[0]);
      }
    }
    return returnValue;
  }

  /// For all package managers including flatpak and snap
  static Future<void> getUninstallEntries(context) async {
    List<ActionEntry> returnValue = [];
    Future<List<String>> installedAptPackagesFuture = getInstalledAPTPackages();
    Future<List<List<String>>> installedZypperPackagesFuture =
        getInstalledZypperPackages();
    Future<List<List<String>>> installedDNFPackagesFuture =
        getInstalledDNFPackages();
    Future<List<String>> installedPackagesPacmanFuture =
        getInstalledPacmanPackages();
    Future<List<List<String>>> installedFlatpaksFuture = getInstalledFlatpaks();
    Future<List<String>> installedSnapsFuture = getInstalledSnaps();

    /// APT
    List<String> installedAptPackages = await installedAptPackagesFuture;
    for (String aptPackage in installedAptPackages) {
      returnValue.add(
        ActionEntry(
          name: AppLocalizations.of(context)!.uninstallApp(aptPackage),
          description: "(APT)",
          action: "apt-uninstall:$aptPackage",
          iconWidget: Icon(
            Icons.delete,
            size: 48,
            color: MintY.currentColor,
          ),
          priority: -10,
          excludeFromSearchProposal: true,
        ),
      );
    }

    /// Zypper
    List<List<String>> installedZypperPackages =
        await installedZypperPackagesFuture;
    for (List<String> zypperEntry in installedZypperPackages) {
      if (zypperEntry.length < 2) {
        logInfo("Wrong zypper entry: $zypperEntry");
        continue;
      }
      returnValue.add(
        ActionEntry(
          name: AppLocalizations.of(context)!.uninstallApp(zypperEntry[0]),
          description: "${zypperEntry[1]} (Zypper)",
          action: "zypper-uninstall:${zypperEntry[0]}",
          iconWidget: Icon(
            Icons.delete,
            size: 48,
            color: MintY.currentColor,
          ),
          priority: -10,
          excludeFromSearchProposal: true,
        ),
      );
    }

    /// DNF
    List<List<String>> installedDNFPackages = await installedDNFPackagesFuture;
    for (List<String> dnfEntry in installedDNFPackages) {
      if (dnfEntry.isEmpty) {
        logInfo("Wrong dnf entry: $dnfEntry");
        continue;
      }
      returnValue.add(
        ActionEntry(
          name: AppLocalizations.of(context)!.uninstallApp(dnfEntry[0]),
          description: "(DNF)",
          action: "dnf-uninstall:${dnfEntry[0]}",
          iconWidget: Icon(
            Icons.delete,
            size: 48,
            color: MintY.currentColor,
          ),
          priority: -10,
          excludeFromSearchProposal: true,
        ),
      );
    }

    /// Pacman
    List<String> installedPacmanPackages = await installedPackagesPacmanFuture;
    for (String pacmanEntry in installedPacmanPackages) {
      returnValue.add(
        ActionEntry(
          name: AppLocalizations.of(context)!.uninstallApp(pacmanEntry),
          description: "(Pacman)",
          action: "pacman-uninstall:$pacmanEntry",
          iconWidget: Icon(
            Icons.delete,
            size: 48,
            color: MintY.currentColor,
          ),
          priority: -10,
          excludeFromSearchProposal: true,
        ),
      );
    }

    /// Flatpak
    List<List<String>> installedFlatpaks = await installedFlatpaksFuture;

    /// flatpak entry: app-id, app name, description
    for (List<String> flatpakEntry in installedFlatpaks) {
      if (flatpakEntry.length < 3) {
        logInfo("Wrong flatpak entry: $flatpakEntry");
        continue;
      }
      returnValue.add(
        ActionEntry(
          name: AppLocalizations.of(context)!.uninstallApp(flatpakEntry[1]),
          description: "${flatpakEntry[2]} (Flatpak)",
          action: "flatpak-uninstall:${flatpakEntry[0]}",
          iconWidget: Icon(
            Icons.delete,
            size: 48,
            color: MintY.currentColor,
          ),
          priority: -10,
          excludeFromSearchProposal: true,
        ),
      );
    }

    /// Snap
    List<String> installedSnaps = await installedSnapsFuture;
    for (String snap in installedSnaps) {
      returnValue.add(
        ActionEntry(
          name: AppLocalizations.of(context)!.uninstallApp(snap),
          description: "(Snap)",
          action: "snap-uninstall:$snap",
          iconWidget: Icon(
            Icons.delete,
            size: 48,
            color: MintY.currentColor,
          ),
          priority: -10,
          excludeFromSearchProposal: true,
        ),
      );
    }

    await ActionEntryListService.addEntries(returnValue);
  }

  /// Used while startup of the application
  static Future<void> loadCurrentEnvironment() async {
    currentenvironment = await getCurrentEnvironment();
    ConfigHandler configHandler = ConfigHandler();
    await configHandler.ensureConfigIsLoaded();

    String distribution = configHandler.getValueUnsafe("distribution", "");
    if (distribution.isNotEmpty) {
      currentenvironment.distribution = getEnumFromString(distribution);
    }

    currentenvironment.version =
        configHandler.getValueUnsafe("version", currentenvironment.version);
    currentenvironment.versionString = configHandler.getValueUnsafe(
        "versionString", currentenvironment.versionString);
    String desktop = configHandler.getValueUnsafe("desktop", "");
    if (desktop.isNotEmpty) {
      currentenvironment.desktop = getDektopEnumOfString(desktop);
    }
    currentenvironment.browser =
        configHandler.getValueUnsafe("browser", currentenvironment.browser);
    currentenvironment.language =
        configHandler.getValueUnsafe("language", currentenvironment.language);

    // Deliberately not awaited. Its only consumer is the icon workaround in
    // `SystemIcon`, which reads the flag whenever it builds — waiting for two
    // hardware probes here would delay the first frame for everyone, on a
    // question that matters to a minority of machines.
    unawaited(detectGraphicsSituation());
  }

  /// Fills [Environment.nvidiaCardAndNouveauRunning] in the background.
  static Future<void> detectGraphicsSituation() async {
    try {
      final results = await Future.wait([
        isNvidiaCardInstalledOnSystem(),
        isNouveauCurrentGraphicsDriver(),
      ]);
      currentenvironment.nvidiaCardAndNouveauRunning = results[0] && results[1];
    } catch (_) {
      // Leave the default (false). A failed probe must not keep the app from
      // starting, and the flag only selects between two icon rendering paths.
    }
  }

  /// Returns new list of found folder entries.
  static List<ActionEntry> getFoldersOfActionEntries(
      BuildContext context, List<ActionEntry> currentEntries) {
    List<String> allPaths = [];

    for (var element in currentEntries) {
      if (element.action.startsWith("openfile:")) {
        String path = element.action.replaceFirst("openfile:", "");
        List<String> singleFolders = path.split("/");
        singleFolders.removeLast(); // We don't need the filename.

        // Build every path.
        for (int i = 0; i < singleFolders.length; i++) {
          String path = "/";
          for (int j = 0; j <= i; j++) {
            if ((singleFolders[j] != "")) {
              path += "${singleFolders[j]}/";
            }
          }
          if (!allPaths.contains(path)) {
            allPaths.add(path);
          }
        }
      }
    }

    List<ActionEntry> newEntries = [];
    for (var path in allPaths) {
      List<String> elements = path.split("/");
      if (elements.length > 1) {
        String name = elements[elements.length - 2];
        path = path.trim();
        if (!path.endsWith("/")) {
          path = "$path/";
        }
        ActionEntry newEntry = ActionEntry(
            name: name,
            description: "${AppLocalizations.of(context)!.openX} $path",
            action: "openfolder:$path",
            priority: -10.0);
        newEntries.add(newEntry);
      }
    }
    return newEntries;
  }

  static Future<void> getBrowserBookmarks(BuildContext context) async {
    // Resolved before the await — see [getAllFolderEntriesOfUser].
    final String openLabel = AppLocalizations.of(context)!.openX;
    String outputString = await runPythonScript("get_bookmarks.py");
    List<String> lines = outputString.split("\n");
    List<ActionEntry> returnValue = [];
    for (String line in lines) {
      List<String> elements = line.split("\t");
      if (elements.length == 2) {
        returnValue.add(ActionEntry(
            name: elements[0],
            description: "$openLabel ${elements[1]}",
            action: "openwebsite:${elements[1]}",
            priority: -5.0));
      }
    }
    // return returnValue;
    await ActionEntryListService.addEntries(returnValue);
  }

  static Future<bool> isDarkThemeEnabled() async {
    switch (currentenvironment.desktop) {
      case DESKTOPS.CINNAMON:
        String output = await runCommand(
            "/usr/bin/gsettings get org.cinnamon.desktop.interface gtk-theme");
        return output.toLowerCase().contains("dark");
      case DESKTOPS.GNOME:
        String output = await runCommand(
            "gsettings get org.gnome.desktop.interface gtk-theme");
        String output2 = await runCommand(
            "gsettings get org.gnome.desktop.interface color-scheme");
        return output.toLowerCase().contains("dark") ||
            output2.toLowerCase().contains("dark");
      case DESKTOPS.XFCE:
        String output =
            await runCommand("xfconf-query -c xfwm4 -p /general/theme");
        return output.toLowerCase().contains("dark");
      case DESKTOPS.KDE:
        String kdeGlobals =
            "${Linux.getHomeDirectory()}/.config/kdedefaults/kdeglobals";

        if (await File(kdeGlobals).exists()) {
          String contents = await File(kdeGlobals).readAsString();
          return contents.toLowerCase().contains("dark");
        } else {
          return false;
        }
    }
  }

  /// Registers the "bring me up" shortcut with the desktop.
  ///
  /// Returns whether the script reported success. It used to be `static void`
  /// with the Future dropped on the floor, so a desktop the script does not
  /// support — or a `gi` import that failed — looked exactly like success.
  static Future<bool> activateSystemHotkeyForLinuxAssistant() async {
    final CommandResult result = await runProcess(
      "python3",
      [
        "${pythonScriptsFolder}setup_keybinding.py",
        if (getHotkeyModifier() == "<Alt>") "--alt",
      ],
      environment: Platform.environment,
    );

    if (!result.success) {
      logError("Registering the desktop shortcut failed", result.error);
    }
    return result.success;
  }

  static String getHotkeyModifier() {
    if (currentenvironment.desktop == DESKTOPS.KDE) {
      return "<Alt>";
    }
    switch (currentenvironment.distribution) {
      case DISTROS.POPOS:
      case DISTROS.ZORINOS:
      case DISTROS.UBUNTU:
        return "<Alt>";
      default:
        // No trailing space: every caller interpolates this into "{modifier}
        // + <Q>", so the old value rendered a double space.
        return "<Super/Windows>";
    }
  }

  static bool usesCurrentEnvironmentDebPackages() {
    switch (currentenvironment.distribution) {
      case DISTROS.DEBIAN:
      case DISTROS.MXLINUX:
      case DISTROS.LINUX_MINT:
      case DISTROS.LMDE:
      case DISTROS.POPOS:
      case DISTROS.ZORINOS:
      case DISTROS.KDENEON:
      case DISTROS.UBUNTU:
        return true;

      default:
        return false;
    }
  }

  static bool usesCurrentEnvironmentRPMPackages() {
    switch (currentenvironment.distribution) {
      case DISTROS.OPENSUSE:
      case DISTROS.FEDORA:
        return true;
      default:
        return false;
    }
  }

  /// removes all rights for others at the home folder
  static Future<void> fixHomeFolderPermissions() async {
    unawaited(runCommandWithCustomArguments(
      "/usr/bin/chmod",
      ["o-rwx", Linux.getHomeDirectory()],
    ));
    unawaited(runCommandWithCustomArguments(
      "/usr/bin/chmod",
      ["g-w", Linux.getHomeDirectory()],
    ));
  }

  static Future<void> openAdditionalSoftwareSourcesSettings() async {
    if (File("/usr/bin/software-properties-gtk").existsSync()) {
      unawaited(runCommand("/usr/bin/software-properties-gtk"));
      return;
    }
    switch (currentenvironment.distribution) {
      case DISTROS.UBUNTU:
      case DISTROS.ZORINOS:
        unawaited(runCommand("/usr/bin/software-properties-gtk"));
        break;
      case DISTROS.LINUX_MINT:
      case DISTROS.LMDE:
        unawaited(
            runCommandWithCustomArguments("/usr/bin/pkexec", ["mintsources"]));
        break;
      case DISTROS.OPENSUSE:
        unawaited(runCommandWithCustomArguments(
            "xdg-su", ["-c", "/sbin/yast2 repositories"]));
        break;
      case DISTROS.MXLINUX:
        unawaited(runCommand("/usr/bin/mx-repo-manager"));
        break;
      case DISTROS.KDENEON:
        unawaited(runCommand("/usr/bin/plasma-discover"));
        break;
      case DISTROS.DEBIAN:
      case DISTROS.POPOS:
        unawaited(runCommandWithCustomArguments(
            "xdg-open", ["/etc/apt/sources.list.d/"]));
        break;
      case DISTROS.FEDORA:
        unawaited(runCommand("gnome-software"));
        break;
      default:
    }
  }

  static Future<bool> isFileExecutable(String filePath) async {
    var stat = await FileStat.stat(filePath);
    // stat of a deleted path reports mode 0, and toRadixString(8) of that is
    // "0" — too short for the substring below. Happens when a recent-files
    // entry points at a file removed since indexing.
    if (stat.type == FileSystemEntityType.notFound) {
      return false;
    }
    var mode = stat.mode.toRadixString(8).substring(3);

    // Example values for variable 'mode': '755', '644' etc.
    // If any of the three numbers is uneven, the file is marked as executable.
    return int.parse(mode[0]) % 2 != 0 ||
        int.parse(mode[1]) % 2 != 0 ||
        int.parse(mode[2]) % 2 != 0;
  }

  static Future<void> runExecutableInTerminal(String executablePath) async {
    String term = await Linux.runPythonScript("get_terminal_emulator.py");
    if ((term = term.trim()) == "gnome-terminal") {
      unawaited(
          Linux.runCommandWithCustomArguments(term, ["--", executablePath]));
    } else {
      unawaited(
          Linux.runCommandWithCustomArguments(term, ["-e", executablePath]));
    }
  }

  static void shutdown({int minutes = 0}) {
    Linux.runCommand("/sbin/shutdown $minutes");
  }

  static Future<String> getUsername() async {
    final int id = currentenvironment.currentUserId;
    return (await runCommand("id -nu $id")).trim();
  }

  static Future<String> getHostname() async {
    if (File("/etc/hostname").existsSync()) {
      return (await File("/etc/hostname").readAsString()).trim();
    } else {
      return (await runCommand("hostname")).trim();
    }
  }

  static Future<String> getOsPrettyName() async {
    String filePathAddition = "";
    if (currentenvironment.runningInFlatpak) {
      filePathAddition = "/var/run/host";
    }

    try {
      return (await File("$filePathAddition/etc/os-release").readAsString())
          .split("\n")
          .firstWhere((x) => x.startsWith("PRETTY_NAME"))
          .split('"')
          .elementAt(1);
    } catch (e) {
      return "";
    }
  }

  static Future<String> getCpuModel() async {
    try {
      final List<String> cpuinfo =
          (await File("/proc/cpuinfo").readAsString()).split("\n");

      int cores = cpuinfo.where((x) => x.contains("model name")).length;
      String model = cpuinfo
          .firstWhere((x) => x.contains("model name"))
          .replaceFirst("model name", "")
          .replaceFirst(":", "")
          .replaceFirst("CPU", "")
          .replaceFirst("with Radeon Graphics", "")
          // Remove everything in parentheses
          .replaceAll(RegExp(r'\s?\(([^\)]+)\)'), "")
          // Remove clock speed
          .replaceAll(RegExp(r'\s?[@].*'), "")
          .trim();

      return "$model ($cores)";
    } catch (e) {
      return "";
    }
  }

  static Future<String> getGpuModel() async {
    // If glxinfo is not installed we are doing this with lspci:
    // lspci -k | grep -A 2 -E "(VGA|3D)"
    if (!File("/usr/bin/glxinfo").existsSync()) {
      String output =
          // await runCommand("bash -c \"lspci -k | grep -A 2 -E '(VGA|3D)'\"");
          await runCommandWithCustomArguments(
              "bash", ["-c", "lspci -k | grep -A 2 -E '(VGA|3D)'"]);
      List<String> lines = output.split("\n");
      for (String line in lines) {
        if (line.contains("VGA") || line.contains("3D")) {
          return line.split(":").last.trim();
        }
      }
    }

    try {
      return (await runCommand("glxinfo -B"))
          .split("\n")
          .firstWhere((x) => x.startsWith("OpenGL renderer string"))
          .replaceFirst("OpenGL renderer string:", "")
          .replaceFirst("Mesa DRI", "")
          // Remove everything in parentheses
          .replaceAll(RegExp(r'\s?\(([^\)]+)\)'), "")
          // Remove everything after /
          .replaceAll(RegExp(r'[\/].*'), "")
          .trim();
    } catch (e) {
      return "";
    }
  }

  static Future<String> getKernelVersion() async {
    try {
      return (await File("/proc/version").readAsString())
          .split(" ")
          .elementAt(2)
          .split("-")
          .elementAt(0);
    } catch (e) {
      return "";
    }
  }

  /// Opens the disk space analyzer of the current environment.
  /// If the tool is not installed, it will be installed.
  /// Options are baobab and k4dirstat.
  static void openDiskSpaceAnalyzer(context, path) {
    if (currentenvironment.desktop == DESKTOPS.KDE) {
      runCommandWithCustomArguments("k4dirstat", [path]);
      ensureApplicationInstallation(["k4dirstat"]);
      if (commandQueue.isEmpty) {
        runCommandWithCustomArguments("k4dirstat", [path]);
      } else {
        commandQueue.add(LinuxCommand(
          userId: currentenvironment.currentUserId,
          argv: ["/usr/bin/k4dirstat", "$path"],
        ));
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => RunCommandQueue(
              title: AppLocalizations.of(context)!.installX("k4dirstat"),
              route: MainSearchLoader()),
        ));
      }
    } else {
      ensureApplicationInstallation(["baobab"]);
      if (commandQueue.isEmpty) {
        runCommandWithCustomArguments("baobab", [path]);
      } else {
        commandQueue.add(LinuxCommand(
          userId: currentenvironment.currentUserId,
          argv: ["/usr/bin/baobab", "$path"],
        ));
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => RunCommandQueue(
              title: AppLocalizations.of(context)!.installX("baobab"),
              route: MainSearchLoader()),
        ));
      }
    }
  }

  static void cleanDiskspace(context, path) {
    if (path == "/") {
      if (currentenvironment.installedSoftwareManagers
          .contains(SOFTWARE_MANAGERS.APT)) {
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: ["/usr/bin/apt", "autoremove", "-y"],
          environment: {"DEBIAN_FRONTEND": "noninteractive"},
        ));
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: ["/usr/bin/apt", "clean", "-y"],
          environment: {"DEBIAN_FRONTEND": "noninteractive"},
        ));
      }
      if (currentenvironment.installedSoftwareManagers
          .contains(SOFTWARE_MANAGERS.ZYPPER)) {
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: ["/usr/bin/zypper", "clean", "-a"],
        ));
      }
      if (currentenvironment.installedSoftwareManagers
          .contains(SOFTWARE_MANAGERS.DNF)) {
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: ["/usr/bin/dnf", "clean", "all"],
        ));
      }
      if (currentenvironment.installedSoftwareManagers
          .contains(SOFTWARE_MANAGERS.PACMAN)) {
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: ["/usr/bin/pacman", "-Sc", "--noconfirm"],
        ));
      }
      if (currentenvironment.installedSoftwareManagers
          .contains(SOFTWARE_MANAGERS.FLATPAK)) {
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: ["/usr/bin/flatpak", "uninstall", "--unused", "-y"],
        ));
      }
      if (currentenvironment.installedSoftwareManagers
          .contains(SOFTWARE_MANAGERS.SNAP)) {
        commandQueue.add(emptyDirectoryCommand("/var/lib/snapd/cache"));
      }
      if (currentenvironment.distribution != DISTROS.FEDORA) {
        // Empties /var/tmp, does not remove it. `rm -rf /var/tmp/` took the
        // directory with it, along with its 1777 mode and sticky bit, and
        // anything that expected it to exist found a missing path or, worse,
        // a fresh 755 root-owned one recreated by the next writer.
        commandQueue.add(emptyDirectoryCommand("/var/tmp"));
      }
      commandQueue.add(
          emptyDirectoryCommand("${getHomeDirectory()}.local/share/Trash"));
    }
    commandQueue.add(emptyDirectoryCommand("$path/.Trash-1000"));
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => RunCommandQueue(
          title: AppLocalizations.of(context)!.cleanDiskspace,
          route: CleanDiskPage(
            mountpoint: path,
          )),
    ));
  }

  static Future<void> installAndConfigureFirewall(context, route) async {
    switch (currentenvironment.distribution) {
      case DISTROS.OPENSUSE:
      case DISTROS.FEDORA:
        await installApplications(["firewalld"]);
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: ["/usr/bin/systemctl", "enable", "firewalld", "--now"],
        ));
        unawaited(Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => RunCommandQueue(
                  title: AppLocalizations.of(context)!.cleanDiskspace,
                  route: route,
                ))));
        break;
      default:
        await installApplications(["gufw"]);
        commandQueue.add(LinuxCommand(
          userId: 0,
          argv: ["/usr/sbin/ufw", "enable"],
          environment: {"PATH": getPATH()},
        ));
    }
    unawaited(Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => RunCommandQueue(
              title: AppLocalizations.of(context)!.settingUpFirewall,
              route: route,
            ))));
  }

  static String getPATH() {
    // Get the PATH variable via the environment
    String? output = Platform.environment["PATH"];
    if (output == null || output.isEmpty) {
      return "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/sbin";
    }
    return output;
  }

  static void fixPackageManager(context) {
    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.APT)) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/dpkg", "--configure", "-a"],
        environment: {"DEBIAN_FRONTEND": "noninteractive", "PATH": getPATH()},
      ));
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/apt", "install", "-f", "-y"],
        environment: {"DEBIAN_FRONTEND": "noninteractive"},
      ));
    }
    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.ZYPPER)) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: [
          "/usr/bin/zypper",
          "--non-interactive",
          "--gpg-auto-import-keys",
          "ref"
        ],
      ));
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: [
          "/usr/bin/zypper",
          "--non-interactive",
          "--gpg-auto-import-keys",
          "up"
        ],
      ));
    }
    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.DNF)) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/dnf", "check"],
      ));
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/dnf", "install", "-y"],
      ));
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => RunCommandQueue(
          title: AppLocalizations.of(context)!.fixPackageManager,
          route: MainSearchLoader()),
    ));
  }

  static bool isStringBashCommand(String input) {
    // Get the first word of the string
    String firstWord = input.split(" ").first;
    // Check if the first word is found in a path of the system
    List<String> paths = getPATH().split(":");
    for (String path in paths) {
      if (File("$path/$firstWord").existsSync()) {
        return true;
      }
    }
    return false;
  }

  static void openCommandInTerminal(command) {
    command =
        "echo 'Running command: $command'; $command; echo 'Closing in 10 seconds...'; sleep 10";
    // Write the command into a temporary file
    String cacheDir = getCacheDirectory();
    String tempFile = "$cacheDir/temp_command.sh";
    File(tempFile).writeAsStringSync(command);

    logInfo("Opening command in terminal: $command");

    // Ordered by desktop preference, with xterm as the last resort. The
    // previous version dispatched on the desktop alone and only reached the
    // xterm fallback through a `default:` clause that the exhaustive DESKTOPS
    // enum made unreachable — so a KDE box without konsole simply did nothing.
    final List<List<String>> candidates = [];
    switch (currentenvironment.desktop) {
      case DESKTOPS.KDE:
        candidates.add(["konsole", "-e", "bash", "-c", command]);
        break;
      case DESKTOPS.GNOME:
      case DESKTOPS.CINNAMON:
        candidates.add(["kgx", "-e", "bash", "-c", command]);
        candidates.add(["gnome-terminal", "--", "bash", "-c", command]);
        break;
      case DESKTOPS.XFCE:
        candidates.add(["xfce4-terminal", "-e", "bash $tempFile"]);
        break;
    }
    candidates.add(["xterm", "-e", "bash", "-c", command]);

    for (final List<String> candidate in candidates) {
      final String executable = candidate.first;
      if (File("/usr/bin/$executable").existsSync()) {
        runCommandWithCustomArguments(executable, candidate.sublist(1));
        return;
      }
    }
    logError("No known terminal emulator found to run: $command");
  }

  static void setupSnapAndSnapStore(context) {
    if (currentenvironment.distribution == DISTROS.LINUX_MINT) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/rm", "/etc/apt/preferences.d/nosnap.pref"],
      ));
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/apt-get", "update"],
      ));
    }

    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.APT)) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/apt-get", "install", "-y", "snapd"],
        environment: {"DEBIAN_FRONTEND": "noninteractive"},
      ));
    }
    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.DNF)) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/dnf", "install", "-y", "snapd"],
      ));
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/ln", "-s", "/var/lib/snapd/snap", "/snap"],
      ));
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/snap", "install", "snapd"],
      ));
    }
    // Arch: https://snapcraft.io/install/snapd/arch
    // pacman -S git --noconfirm
    // Clone it to the tmp folder
    // git clone https://aur.archlinux.org/snapd.git
    // cd snapd
    // makepkg -si --noconfirm
    // sudo systemctl enable --now snapd.socket
    // sudo ln -s /var/lib/snapd/snap /snap
    // sudo snap install snapd
    if (currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.PACMAN)) {
      installApplications(["git"],
          preferredSoftwareManager: SOFTWARE_MANAGERS.PACMAN);
      // One of the few commands that really needs a shell: it changes
      // directory between two steps. The script is a constant — nothing is
      // interpolated into it.
      commandQueue.add(LinuxCommand(
        userId: currentenvironment.currentUserId,
        useShell: true,
        argv: const [
          "set -e; "
              "git clone https://aur.archlinux.org/snapd.git /tmp/snapd; "
              "cd /tmp/snapd; "
              "makepkg -si --noconfirm",
        ],
        environment: {"PATH": getPATH(), "HOME": getHomeDirectory()},
      ));
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/systemctl", "enable", "--now", "snapd.socket"],
      ));
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/ln", "-s", "/var/lib/snapd/snap", "/snap"],
      ));
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/snap", "install", "snapd"],
      ));
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/rm", "-rf", "/tmp/snapd"],
      ));
    }
    // openSUSE is a bit more complicated: https://snapcraft.io/install/snapd/opensuse
    // if (currentenvironment.installedSoftwareManagers
    //     .contains(SOFTWARE_MANAGERS.ZYPPER)) {
    //   commandQueue.add(LinuxCommand(
    //     userId: 0,
    //     argv: ["/usr/bin/zypper", "install", "-y", "snapd"],
    //   ));
    // }

    commandQueue.add(LinuxCommand(
      userId: 0,
      argv: ["/usr/bin/snap", "install", "snap-store"],
    ));

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => RunCommandQueue(
          title: AppLocalizations.of(context)!.setupSnap,
          message: AppLocalizations.of(context)!.setupSnapDescription,
          route: MainSearchLoader()),
    ));
  }

  /// Checks if the current user is in the group sudo
  static bool hasCurrentUserAdministratorRights() {
    return currentenvironment.groups.contains("sudo");
  }

  /// Adds the current user to sudo group
  static void makeCurrentUserToAdministrator(context) {
    commandQueue.add(LinuxCommand(
      userId: 0,
      argv: ["/usr/sbin/usermod", "-aG", "sudo", (currentenvironment.username)],
    ));

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => RunCommandQueue(
          title: AppLocalizations.of(context)!.makeAdministrator,
          message: AppLocalizations.of(context)!.makeAdministratorDescription,
          route: MainSearchLoader()),
    ));
  }

  static Future<void> openSoftwareCenter(context) async {
    switch (currentenvironment.distribution) {
      case DISTROS.LINUX_MINT:
      case DISTROS.LMDE:
        unawaited(runCommand("/usr/bin/mintinstall"));
        break;
      case DISTROS.UBUNTU:
      case DISTROS.ZORINOS:
      case DISTROS.POPOS:
        unawaited(runCommand("/usr/bin/gnome-software"));
        break;
      case DISTROS.FEDORA:
        unawaited(runCommand("/usr/bin/gnome-software"));
        break;
      case DISTROS.OPENSUSE:
        if (currentenvironment.desktop == DESKTOPS.KDE) {
          unawaited(runCommand("/usr/bin/plasma-discover"));
        } else {
          unawaited(runCommand("/usr/bin/gnome-software"));
        }
        break;
      case DISTROS.MXLINUX:
        unawaited(runCommand("/usr/bin/mx-packageinstaller"));
        break;
      case DISTROS.KDENEON:
        unawaited(runCommand("/usr/bin/plasma-discover"));
        break;
      case DISTROS.DEBIAN:
        unawaited(runCommand("/usr/bin/synaptic"));
        break;
      default:
        unawaited(runCommand("/usr/bin/gnome-software"));
    }
  }

  static bool isCdromSourceEnabledInDebian() {
    if (![DISTROS.DEBIAN, DISTROS.MXLINUX, DISTROS.LMDE]
        .contains(currentenvironment.distribution)) {
      return false;
    }
    if (File("/etc/apt/sources.list").existsSync()) {
      String fileString = File("/etc/apt/sources.list").readAsStringSync();
      for (String line in fileString.split("\n")) {
        if (line.contains("cdrom") && !line.trim().startsWith("#")) {
          return true;
        }
      }
    }
    return false;
  }

  static void disableCdromSourceInDebian(context) {
    if ([DISTROS.DEBIAN, DISTROS.MXLINUX, DISTROS.LMDE]
        .contains(currentenvironment.distribution)) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/sed", "-i", "/cdrom/d", "/etc/apt/sources.list"],
      ));
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => RunCommandQueue(
            title: AppLocalizations.of(context)!.disableCdromSource,
            message:
                AppLocalizations.of(context)!.disableCdromSourceDescription,
            route: MainSearchLoader()),
      ));
    }
  }

  static Map<String, dynamic> getGrubSettings() {
    String grubFileContent = File("/etc/default/grub").readAsStringSync();
    List<String> lines = grubFileContent.split("\n");
    Map<String, String> settingsFileMap = {};
    for (String line in lines) {
      if (line.contains("=") && !line.trim().startsWith("#")) {
        List<String> parts = line.split("=");
        settingsFileMap[parts[0]] = parts[1];
      }
    }

    Map<String, dynamic> returnValue = {};
    returnValue["grubVisible"] =
        settingsFileMap["GRUB_TIMEOUT_STYLE"] == "menu" ||
            settingsFileMap["GRUB_TIMEOUT_STYLE"] == null;
    returnValue["enableBigFont"] = settingsFileMap["GRUB_GFXMODE"] == "640x480";
    if (settingsFileMap["GRUB_TIMEOUT"] == null) {
      settingsFileMap["GRUB_TIMEOUT"] = "0";
    }
    returnValue["timeout"] =
        int.tryParse(settingsFileMap["GRUB_TIMEOUT"]!) ?? 0;
    returnValue["startLastBootedOne"] =
        settingsFileMap["GRUB_DEFAULT"] == "saved";

    return returnValue;
  }

  static void ensureGrubSettings(context, bool grubVisible, bool enableBigFont,
      int timeout, bool startLastBootedOne) {
    String grubTimeoutStyle = grubVisible ? "menu" : "hidden";
    String grubTimeout = timeout.toString();
    String grubDefault = startLastBootedOne ? "saved" : "0";
    String grubSaveDefault = startLastBootedOne ? "true" : "false";
    String grubGfxmode = enableBigFont ? "640x480" : "";

    if (grubTimeoutStyle == "menu" && timeout < 1) {
      grubTimeout = "1";
    }

    if (grubTimeoutStyle == "hidden" && timeout < 0) {
      grubTimeout = "0";
    }

    ensureOptionInConfigFile(
        "GRUB_TIMEOUT_STYLE", grubTimeoutStyle, "/etc/default/grub");
    ensureOptionInConfigFile("GRUB_TIMEOUT", grubTimeout, "/etc/default/grub");
    ensureOptionInConfigFile("GRUB_DEFAULT", grubDefault, "/etc/default/grub");
    ensureOptionInConfigFile(
        "GRUB_SAVEDEFAULT", grubSaveDefault, "/etc/default/grub");
    ensureOptionInConfigFile("GRUB_GFXMODE", grubGfxmode, "/etc/default/grub");

    if (currentenvironment.distribution != DISTROS.FEDORA) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/sbin/grub-mkconfig", "-o", "/boot/grub/grub.cfg"],
      ));
    } else {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/sbin/grub2-mkconfig", "-o", "/boot/grub2/grub.cfg"],
      ));
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => RunCommandQueue(
          title: AppLocalizations.of(context)!.grubConfiguration,
          route: MainSearchLoader()),
    ));
  }

  /// Used for config files like /etc/default/grub.
  ///
  /// Only adds the commands to the command queue to ensure that the key is set to the value.
  /// If the value is empty, the key will be removed from the file.
  /// Escapes a value for the right-hand side of a `sed` s/// expression.
  ///
  /// argv keeps a value out of the *shell*, but a sed script is a second
  /// parser: an unescaped `/` ends the expression and an unescaped `&` means
  /// "the whole match". Every value that reaches this function today is a
  /// constant, which is exactly the kind of assumption that stops holding.
  static String sedEscapeReplacement(String value) => value
      .replaceAll(r"\", r"\\")
      .replaceAll("&", r"\&")
      .replaceAll("/", r"\/")
      .replaceAll("\n", r"\n");

  /// Escapes a value used as a sed address or pattern.
  static String sedEscapePattern(String value) => value.replaceAllMapped(
      RegExp(r"[\\^$.*/\[\]]"), (match) => "\\${match[0]}");

  static void ensureOptionInConfigFile(String key, String value, String path) {
    final String keyPattern = sedEscapePattern(key);

    /// Remove the key from the file if the value is empty
    if (value.isEmpty) {
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: ["/usr/bin/sed", "-i", "/$keyPattern/d", path],
      ));
      return;
    }

    bool settingFound = false;
    // Check if the key is already in the file and is not commented out
    String fileContent = File(path).readAsStringSync();
    List<String> lines = fileContent.split("\n");
    for (String line in lines) {
      if (line.contains("$key=") && !line.trim().startsWith("#")) {
        settingFound = true;
        break;
      }
    }

    if (!settingFound) {
      // Add the key to the file. The redirection needs a shell; the values do
      // not go into the script text but into $1 and $2, so a value containing
      // a quote or a semicolon stays data.
      commandQueue.add(LinuxCommand(
        userId: 0,
        useShell: true,
        argv: ["printf '%s\\n' \"\$1\" >> \"\$2\"", "$key=$value", path],
      ));
    } else {
      // Replace the key in the file
      commandQueue.add(LinuxCommand(
        userId: 0,
        argv: [
          "/usr/bin/sed",
          "-i",
          "s/$keyPattern=.*/$keyPattern=${sedEscapeReplacement(value)}/",
          path
        ],
      ));
    }
  }

  /// Deletes everything inside [directory] but keeps the directory itself.
  ///
  /// `find … -delete` rather than a `rm -rf` of the directory: several of the
  /// paths cleaned here are system directories whose existence, ownership and
  /// mode other software depends on.
  static LinuxCommand emptyDirectoryCommand(String directory) {
    return LinuxCommand(
      userId: 0,
      argv: [
        "/usr/bin/find",
        directory,
        "-mindepth",
        "1",
        "-maxdepth",
        "1",
        "-exec",
        "/usr/bin/rm",
        "-rf",
        "--",
        "{}",
        "+",
      ],
    );
  }

  static void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }
}
