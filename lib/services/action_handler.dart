import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:linux_assistant/enums/desktops.dart';
import 'package:linux_assistant/enums/softwareManagers.dart';
import 'package:linux_assistant/layouts/after_installation/after_installation_entry.dart';
import 'package:linux_assistant/layouts/disk_cleaner/cleaner_select_disk.dart';
import 'package:linux_assistant/layouts/after_installation/activate_hotkey.dart';
import 'package:linux_assistant/layouts/greeter/introduction.dart';
import 'package:linux_assistant/layouts/linux_health/overview.dart';
import 'package:linux_assistant/layouts/power_mode/power_mode.dart';
import 'package:linux_assistant/layouts/run_command_queue.dart';
import 'package:linux_assistant/layouts/security_check/overview.dart';
import 'package:linux_assistant/layouts/shutdown/shutdown_dialog.dart';
import 'package:linux_assistant/layouts/uninstaller/uninstaller_question.dart';
import 'package:linux_assistant/models/action_entry.dart';
import 'package:linux_assistant/models/linux_command.dart';
import 'package:linux_assistant/services/config_handler.dart';
import 'package:linux_assistant/services/linux.dart';
import 'package:linux_assistant/services/main_search_loader.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';

class ActionHandler {
  /// Checks whether a file is executable (injectable for tests).
  static Future<bool> Function(String filePath) _executableChecker =
      Linux.isFileExecutable;

  /// Runs an executable file in a terminal (injectable for tests).
  static Future<void> Function(String filePath) _terminalRunner =
      Linux.runExecutableInTerminal;

  /// Opens a file with its default application (injectable for tests).
  static Future<void> Function(String exec, List<String> arguments)
      _fileOpener = _defaultFileOpener;

  /// Overrides the calls the `openfile:` branch makes. Tests only!
  ///
  /// Unlike `AppLauncher.debugOverride`, an override replaces only the
  /// functions actually passed. A partial override would otherwise reset the
  /// remaining seams to the real process starts and open a terminal during the
  /// test run.
  static void debugOverride({
    Future<bool> Function(String filePath)? executableChecker,
    Future<void> Function(String filePath)? terminalRunner,
    Future<void> Function(String exec, List<String> arguments)? fileOpener,
  }) {
    if (executableChecker != null) _executableChecker = executableChecker;
    if (terminalRunner != null) _terminalRunner = terminalRunner;
    if (fileOpener != null) _fileOpener = fileOpener;
  }

  /// Resets the test overrides.
  static void resetOverrides() {
    _executableChecker = Linux.isFileExecutable;
    _terminalRunner = Linux.runExecutableInTerminal;
    _fileOpener = _defaultFileOpener;
  }

  static Future<void> _defaultFileOpener(
      String exec, List<String> arguments) async {
    await Linux.runCommandWithCustomArguments(exec, arguments);
  }

  /// Asks before an executable file picked from the search is started.
  ///
  /// The full path is part of the question on purpose: the terminal window that
  /// opens next only shows which file is running once it already is.
  static Future<bool> _confirmExecution(
      BuildContext context, String filePath) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.runFileQuestion(filePath)),
        content: Text(l10n.runFileWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.executeInTerminal),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  /// The callback is usually the clear function.
  static Future<void> handleActionEntry(ActionEntry actionEntry,
      VoidCallback callback, BuildContext context) async {
    if (actionEntry.action.isEmpty) {
      if (actionEntry.handlerFunction != null) {
        actionEntry.handlerFunction!(callback, context);
      }
      return;
    }

    // Save opened for intelligent search
    ConfigHandler configHandler = ConfigHandler();
    if (configHandler.getValueUnsafe("self_learning_search", true)) {
      String newDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String oldList =
          configHandler.getValueUnsafe("opened.${actionEntry.action}", "");
      await configHandler.setValue(
          "opened.${actionEntry.action}", "$oldList$newDate;");
      // The config write is the first async gap in this method; everything
      // below navigates with the caller's context.
      if (!context.mounted) return;
    }

    switch (actionEntry.action) {
      case "change_user_password":
        Linux.changeUserPasswordDialog();
        callback();
        break;
      case "open_systeminformation":
        Linux.openSystemInformation();
        callback();
        break;
      case "open_usersettings":
        Linux.openUserSettings();
        callback();
        break;
      case "open_introduction":
        unawaited(Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const GreeterIntroduction(forceOpen: true)),
        ));
        break;
      case "setup_linux_assistant_shortcut":
        unawaited(Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ActivateHotkeyQuestion(
                    route: const MainSearchLoader(),
                  )),
        ));
        break;
      case "send_files_via_warpinator":
        Linux.openOrInstallWarpinator(context, callback);
        break;
      case "hard_info":
        Linux.openOrInstallHardInfo(context, callback);
        break;
      case "redshift":
        Linux.openOrInstallRedshift(context, callback);
        break;
      case "shutdown":
        unawaited(showDialog(
            context: context, builder: (context) => ShutdownDialog()));
        break;
      case "exit":
        exit(0);
      case "power_mode":
        unawaited(Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PowerMode()),
        ));
        break;
      case "security_check":
        unawaited(Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const SecurityCheckOverview()),
        ));
        break;
      case "linux_health":
        unawaited(Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LinuxHealthOverview()),
        ));
        break;
      case "disk_cleaner":
        unawaited(Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const CleanerSelectDiskPage()),
        ));
        break;
      case "after_installation":
        unawaited(Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const AfterInstallationEntry()),
        ));
        break;
      default:
    }

    if (actionEntry.action.startsWith("websearch:")) {
      Linux.openWebbrowserSeach(
          actionEntry.action.replaceFirst("websearch:", ""));
      callback();
    }

    if (actionEntry.action.startsWith("openwebsite:")) {
      Linux.openWebbrowserWithSite(
          actionEntry.action.replaceFirst("openwebsite:", ""));
      callback();
    }

    if (actionEntry.action.startsWith("openfolder:")) {
      unawaited(Linux.runCommandWithCustomArguments(
          "xdg-open", [actionEntry.action.replaceFirst("openfolder:", "")]));
      callback();
    }

    if (actionEntry.action.startsWith("openfile:")) {
      String file = actionEntry.action.replaceFirst("openfile:", "");
      bool isExecutable = await _executableChecker(file);
      if (isExecutable) {
        // The search surfaces recent files and favorites, so this would run a
        // file the user did not name by hand. Ask before starting it — and on a
        // decline return before the callback, which leaves the search list up.
        if (!context.mounted) return;
        if (!await _confirmExecution(context, file)) return;
        unawaited(_terminalRunner(file));
      } else {
        unawaited(_fileOpener("xdg-open", [file]));
      }

      callback();
    }

    if (actionEntry.action == "update_system") {
      await Linux.updateAllPackages();
      if (!context.mounted) return;
      unawaited(Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => RunCommandQueue(
              title: AppLocalizations.of(context)!.update,
              message: AppLocalizations.of(context)!.updateSystemDescription,
              offerShutdownAfterwards: true,
              route: const MainSearchLoader()))));
    }

    if (actionEntry.action == "install_multimedia_codecs") {
      await Linux.installMultimediaCodecs();
      if (!context.mounted) return;
      unawaited(Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => RunCommandQueue(
              title: AppLocalizations.of(context)!.installMultimediaCodecs,
              message: AppLocalizations.of(context)!
                  .installMultimediaCodecsDescription,
              route: const MainSearchLoader()))));
    }

    if (actionEntry.action == "enable_automatic_updates") {
      await Linux.enableAutomaticUpdates();
      if (!context.mounted) return;
      unawaited(Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => RunCommandQueue(
              title: AppLocalizations.of(context)!
                  .automaticUpdateManagerConfiguration,
              message: AppLocalizations.of(context)!
                  .automaticUpdateManagerConfigurationDescription,
              route: const MainSearchLoader()))));
    }

    if (actionEntry.action == "enable_automatic_snapshots") {
      await Linux.enableAutomaticSnapshots();
      if (!context.mounted) return;
      unawaited(Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => RunCommandQueue(
              title: AppLocalizations.of(context)!
                  .automaticUpdateManagerConfiguration,
              message: AppLocalizations.of(context)!
                  .automaticUpdateManagerConfigurationDescription,
              route: const MainSearchLoader()))));
    }

    if (actionEntry.action.startsWith("apt-install:")) {
      String pkg = actionEntry.action.replaceFirst("apt-install:", "");
      await Linux.installApplications([pkg],
          preferredSoftwareManager: SOFTWARE_MANAGERS.APT);
      if (!context.mounted) return;
      unawaited(Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RunCommandQueue(
                  title: "APT",
                  message: "Your package will be installed in a few moments...",
                  route: MainSearchLoader(),
                )),
      ));
    }

    if (actionEntry.action.startsWith("apt-uninstall:")) {
      String pkg = actionEntry.action.replaceFirst("apt-uninstall:", "");
      await Linux.removeApplications([pkg],
          softwareManager: SOFTWARE_MANAGERS.APT);
      if (!context.mounted) return;
      unawaited(Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                UninstallerQuestion(action: actionEntry.action),
          )));
    }

    if (actionEntry.action.startsWith("zypper-install:")) {
      String pkg = actionEntry.action.replaceFirst("zypper-install:", "");
      Linux.commandQueue.add(LinuxCommand(userId: 0, argv: [
        Linux.getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.ZYPPER),
        "--non-interactive",
        "install",
        pkg
      ]));
      if (!context.mounted) return;
      unawaited(Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RunCommandQueue(
                  title: "Zypper",
                  message: "Your package will be installed in a few moments...",
                  route: MainSearchLoader(),
                )),
      ));
    }

    if (actionEntry.action.startsWith("zypper-uninstall:")) {
      String pkg = actionEntry.action.replaceFirst("zypper-uninstall:", "");
      await Linux.removeApplications([pkg],
          softwareManager: SOFTWARE_MANAGERS.ZYPPER);
      if (!context.mounted) return;
      unawaited(Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                UninstallerQuestion(action: actionEntry.action),
          )));
    }

    if (actionEntry.action.startsWith("dnf-install:")) {
      String pkg = actionEntry.action.replaceFirst("dnf-install:", "");
      Linux.commandQueue.add(LinuxCommand(userId: 0, argv: [
        Linux.getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.DNF),
        "install",
        pkg,
        "-y"
      ]));
      if (!context.mounted) return;
      unawaited(Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RunCommandQueue(
                  title: "DNF",
                  message: "Your package will be installed in a few moments...",
                  route: MainSearchLoader(),
                )),
      ));
    }

    if (actionEntry.action.startsWith("dnf-uninstall:")) {
      String pkg = actionEntry.action.replaceFirst("dnf-uninstall:", "");
      await Linux.removeApplications([pkg],
          softwareManager: SOFTWARE_MANAGERS.DNF);
      if (!context.mounted) return;
      unawaited(Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                UninstallerQuestion(action: actionEntry.action),
          )));
    }

    if (actionEntry.action.startsWith("pacman-install:")) {
      String pkg = actionEntry.action.replaceFirst("pacman-install:", "");
      Linux.commandQueue.add(LinuxCommand(userId: 0, argv: [
        Linux.getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.PACMAN),
        "-S",
        "--needed",
        "--noconfirm",
        pkg
      ]));
      if (!context.mounted) return;
      unawaited(Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RunCommandQueue(
                  title: "Pacman",
                  message: AppLocalizations.of(context)!.packageWillBeInstalled,
                  route: const MainSearchLoader(),
                )),
      ));
    }

    if (actionEntry.action.startsWith("pacman-uninstall:")) {
      String pkg = actionEntry.action.replaceFirst("pacman-uninstall:", "");
      Linux.commandQueue.add(LinuxCommand(userId: 0, argv: [
        Linux.getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.PACMAN),
        "-Rs",
        "--noconfirm",
        pkg
      ]));
      if (!context.mounted) return;
      unawaited(Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                UninstallerQuestion(action: actionEntry.action),
          )));
    }

    if (actionEntry.action.startsWith("flatpak-install:")) {
      String pkg = actionEntry.action.replaceFirst("flatpak-install:", "");
      Linux.commandQueue.add(LinuxCommand(userId: 0, argv: [
        Linux.getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.FLATPAK),
        "install",
        pkg,
        "-y",
        "--noninteractive"
      ]));
      if (!context.mounted) return;
      unawaited(Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RunCommandQueue(
                  title: "Flatpak",
                  message: AppLocalizations.of(context)!.packageWillBeInstalled,
                  route: const MainSearchLoader(),
                )),
      ));
    }

    if (actionEntry.action.startsWith("flatpak-uninstall:")) {
      String pkg = actionEntry.action.replaceFirst("flatpak-uninstall:", "");
      await Linux.removeApplications([pkg],
          softwareManager: SOFTWARE_MANAGERS.FLATPAK);
      if (!context.mounted) return;
      unawaited(Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RunCommandQueue(
                  title: actionEntry.name,
                  message: AppLocalizations.of(context)!
                      .uninstallingXDescription(pkg),
                  route: const MainSearchLoader(),
                )),
      ));
    }

    if (actionEntry.action.startsWith("snap-install:")) {
      String pkg = actionEntry.action.replaceFirst("snap-install:", "");
      Linux.commandQueue.add(LinuxCommand(
        userId: 0,
        argv: [
          Linux.getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.SNAP),
          "install",
          pkg
        ],
        environment: {"DEBIAN_FRONTEND": "noninteractive"},
      ));
      if (!context.mounted) return;
      unawaited(Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RunCommandQueue(
                  title: "Snap",
                  message: AppLocalizations.of(context)!.packageWillBeInstalled,
                  route: const MainSearchLoader(),
                )),
      ));
    }

    if (actionEntry.action.startsWith("snap-uninstall:")) {
      String pkg = actionEntry.action.replaceFirst("snap-uninstall:", "");
      await Linux.removeApplications([pkg],
          softwareManager: SOFTWARE_MANAGERS.SNAP);
      if (!context.mounted) return;
      unawaited(Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RunCommandQueue(
                  title: actionEntry.name,
                  message: AppLocalizations.of(context)!
                      .uninstallingXDescription(pkg),
                  route: const MainSearchLoader(),
                )),
      ));
    }

    if (actionEntry.action.startsWith("openapp:")) {
      if (Linux.currentenvironment.desktop == DESKTOPS.KDE) {
        unawaited(Linux.runCommandWithCustomArguments("kioclient",
            ["exec", actionEntry.action.replaceFirst("openapp:", "")]));
      } else {
        String filepath = actionEntry.action.replaceFirst("openapp:", "");
        String file = filepath.split("/").last;
        unawaited(
            Linux.runCommandWithCustomArguments("/usr/bin/gtk-launch", [file]));
      }

      callback();
    }

    if (actionEntry.action.startsWith("just_callback")) {
      callback();
    }

    if (actionEntry.action.startsWith("fix_package_manager")) {
      if (!context.mounted) return;
      Linux.fixPackageManager(context);
    }

    if (actionEntry.action.startsWith("bash:")) {
      String command = actionEntry.action.replaceFirst("bash:", "");
      Linux.openCommandInTerminal(command);
      callback();
    }

    if (actionEntry.action.startsWith("setup_snap")) {
      if (!context.mounted) return;
      Linux.setupSnapAndSnapStore(context);
    }

    if (actionEntry.action.startsWith("make_administrator")) {
      if (!context.mounted) return;
      Linux.makeCurrentUserToAdministrator(context);
    }

    if (actionEntry.action.startsWith("open_software_center")) {
      if (!context.mounted) return;
      unawaited(Linux.openSoftwareCenter(context));
      callback();
    }
  }
}
