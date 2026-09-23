import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:linux_assistant/enums/distros.dart';
import 'package:linux_assistant/enums/softwareManagers.dart';
import 'package:linux_assistant/main.dart';
import 'package:linux_assistant/models/linux_command.dart';
import 'package:linux_assistant/services/config_handler.dart';
import 'package:linux_assistant/services/linux.dart';
import 'package:linux_assistant/services/logger.dart';

class LinuxAssistantUpdater {
  /// The GitHub repository the update check looks at.
  ///
  /// This fork's builds carry a higher version number than upstream's, so
  /// pointing the updater at upstream would eventually replace a hardened
  /// build with an unhardened one the moment upstream passes it. Change this
  /// back to "Jean28518/linux-assistant" only together with the version
  /// scheme.
  static const String releaseRepository = "Toqsick/master-linux-assistant";

  static Map? newestVersionInformation;

  /// Only searches, if the last successful search is 7 days old, otherwise returns false;
  static bool isNewerVersionAvailable() {
    // Lookup done by WeeklyTasks

    // If we are running as flatpak we don't need to check for updates manually.
    if (Linux.currentenvironment.runningInFlatpak) {
      return false;
    }

    // Return false if we are running on Arch Linux and the user has it not running in flatpak.
    // We are missing an update mechanism for Arch Linux at the current time.
    if (!Linux.currentenvironment.runningInFlatpak &&
        [DISTROS.ARCH, DISTROS.MANJARO, DISTROS.ENDEAVOUR]
            .contains(Linux.currentenvironment.distribution)) {
      return false;
    }

    String newestVersion = ConfigHandler().getValueUnsafe(
        "newest-linux-assistant-version", currentLinuxAssistantVersion);

    // If reading the version file failed, just return false. Else the version
    // check will crash.
    return currentLinuxAssistantVersion.isEmpty
        ? false
        : isVersionGreaterThanCurrent(newestVersion);
  }

  /// example for [version] would be: "3.4.19"
  ///
  /// Tolerates shapes other than exactly `x.y.z`. This used to assert on the
  /// component count and `int.parse` each part, so a release tagged `0.8` or
  /// `v0.8.0-rc1` threw instead of simply reporting "no update".
  static bool isVersionGreaterThanCurrent(String version) {
    final List<int> current = _parseVersion(currentLinuxAssistantVersion);
    final List<int> other = _parseVersion(version);

    if (current.isEmpty || other.isEmpty) {
      return false;
    }

    final int length =
        current.length > other.length ? current.length : other.length;
    for (int i = 0; i < length; i++) {
      final int a = i < other.length ? other[i] : 0;
      final int b = i < current.length ? current[i] : 0;
      if (a != b) {
        return a > b;
      }
    }
    // If they are equal return false.
    return false;
  }

  /// Turns "v1.2.3", "1.2" or "1.2.3-rc1" into its numeric components.
  /// Returns an empty list when nothing numeric can be read at all.
  static List<int> _parseVersion(String version) {
    final List<int> parts = [];
    for (final String raw in version.trim().replaceFirst("v", "").split(".")) {
      final match = RegExp(r"^\d+").firstMatch(raw.trim());
      if (match == null) {
        break;
      }
      parts.add(int.parse(match.group(0)!));
    }
    return parts;
  }

  /// Where the downloaded package is staged.
  ///
  /// Not /tmp. The package was downloaded there and then installed as root
  /// from that path, and /tmp is world-writable: any local account could
  /// replace the file between the two queue entries and have it installed with
  /// full privileges. This directory belongs to the user running the app.
  static Directory get downloadDirectory =>
      Directory("${Linux.getHomeDirectory()}.cache/linux-assistant/updates");

  /// Downloads the release asset and verifies it, then queues the install.
  ///
  /// Returns an error message, or null on success. The download used to be a
  /// queued `wget` followed by a queued `apt install`, with nothing in between
  /// checking that the file was the one GitHub advertised — and the runner
  /// carries on after a failed command, so a failed download would have been
  /// followed by an install attempt anyway.
  static Future<String?> prepareUpdate() async {
    final Map? release = newestVersionInformation;
    if (release == null || release["assets"] is! List) {
      return "No release information available.";
    }

    final Map? asset = _assetForThisSystem(release["assets"] as List);
    if (asset == null) {
      return "This release carries no package for this system.";
    }

    final String downloadUrl = (asset["browser_download_url"] ?? "") as String;
    if (downloadUrl.isEmpty) {
      return "The release asset has no download URL.";
    }

    // GitHub publishes the asset digest as "sha256:<hex>". Without it there is
    // nothing to verify against, and installing an unverified package as root
    // is the thing this method exists to avoid.
    final String digest = (asset["digest"] ?? "") as String;
    if (!digest.startsWith("sha256:")) {
      return "The release asset carries no SHA-256 digest; refusing to install it.";
    }
    final String expected = digest.substring("sha256:".length).toLowerCase();

    final File target =
        File("${downloadDirectory.path}/${downloadUrl.split("/").last}");

    try {
      await downloadDirectory.create(recursive: true);
      final http.Response response = await http
          .get(Uri.parse(downloadUrl))
          .timeout(const Duration(minutes: 10));
      if (response.statusCode != 200) {
        return "Download failed with HTTP ${response.statusCode}.";
      }

      final String actual = sha256.convert(response.bodyBytes).toString();
      if (actual != expected) {
        return "The downloaded package does not match its published checksum.";
      }

      await target.writeAsBytes(response.bodyBytes, flush: true);
    } catch (e) {
      logError("Downloading the update failed", e);
      return "Downloading the update failed: $e";
    }

    _queueInstall(target.path);
    return null;
  }

  static Map? _assetForThisSystem(List assets) {
    for (final asset in assets) {
      if (asset is! Map) {
        continue;
      }
      if (asset["content_type"] == "application/vnd.debian.binary-package" &&
          Linux.usesCurrentEnvironmentDebPackages()) {
        return asset;
      }
      if (asset["content_type"] == "application/x-rpm" &&
          Linux.usesCurrentEnvironmentRPMPackages()) {
        return asset;
      }
    }
    return null;
  }

  static void _queueInstall(String path) {
    if (path.endsWith(".deb")) {
      Linux.commandQueue.add(LinuxCommand(
          userId: 0, argv: ["/usr/bin/apt", "install", path, "-y"]));
      return;
    }

    if (Linux.currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.ZYPPER)) {
      Linux.commandQueue.add(LinuxCommand(userId: 0, argv: [
        Linux.getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.ZYPPER),
        "--non-interactive",
        "install",
        path
      ]));
    }
    if (Linux.currentenvironment.installedSoftwareManagers
        .contains(SOFTWARE_MANAGERS.DNF)) {
      Linux.commandQueue.add(LinuxCommand(userId: 0, argv: [
        Linux.getExecutablePathOfSoftwareManager(SOFTWARE_MANAGERS.DNF),
        "install",
        path,
        "-y"
      ]));
    }
  }
}
