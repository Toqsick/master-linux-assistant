import 'package:la_core/la_core.dart' as core;
import 'package:linux_assistant/services/linux.dart';

export 'package:la_core/la_core.dart' show DeviceInfo;

abstract class LinuxFilesystem {
  static Future<List<core.DeviceInfo>> disks() async {
    var cmdResult = await Linux.runCommandWithCustomArguments(
        "/usr/bin/df", ["-h"],
        getErrorMessages: false);

    return parseDfOutput(cmdResult);
  }

  /// Delegates to the pure parser in `la_core` (#93), which is the one place
  /// the format is understood now.
  ///
  /// The mount point is everything after the fifth field, not a sixth
  /// whitespace token: mount points like "/media/user/USB Stick" would
  /// otherwise shift every column and blow up the Use% parse.
  static List<core.DeviceInfo> parseDfOutput(String cmdResult) =>
      core.parseDfOutput(cmdResult);
}
