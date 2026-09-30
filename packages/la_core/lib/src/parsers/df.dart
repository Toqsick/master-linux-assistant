/// One row of `df -h` output.
class DeviceInfo {
  final String filesystem;
  final bool isRemovable;
  final String mountPoint;
  final String size;
  final String sizeFree;
  final String sizeUsed;
  final int usedPercent;

  const DeviceInfo(
    this.filesystem,
    this.size,
    this.sizeUsed,
    this.sizeFree,
    this.usedPercent,
    this.mountPoint,
    this.isRemovable,
  );
}

const List<String> _ignoreDevices = [
  "dev",
  "run",
  "df:",
  "udev",
  "tmpfs",
  "/dev/loop",
  "revokefs-fuse",
  "cgroup",
  "efivarfs",
];

const List<String> _removableDevices = ["/media/", "/mnt/"];

/// Pure parser for `df -h` output, split out so it can be tested without
/// shelling out.
///
/// The mount point is everything after the fifth field, not a sixth
/// whitespace token: mount points like "/media/user/USB Stick" would
/// otherwise shift every column and blow up the Use% parse.
List<DeviceInfo> parseDfOutput(String cmdResult) {
  final linePattern = RegExp(
    r'^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)%\s+(.+)$',
  );

  final devices = <DeviceInfo>[];
  final devicesRead = <String>[];
  for (final raw in cmdResult.split("\n").skip(1)) {
    final line = raw.trim();
    if (_ignoreDevices.any((y) => line.startsWith(y))) continue;
    if (line.length <= 10) continue;

    final match = linePattern.firstMatch(line);
    if (match == null) continue;
    final source = match.group(1)!;
    final size = match.group(2)!;
    if (devicesRead.contains(source) || size.endsWith("M")) continue;

    devices.add(
      DeviceInfo(
        source,
        size,
        match.group(3)!,
        match.group(4)!,
        int.parse(match.group(5)!),
        match.group(6)!,
        _removableDevices.any((x) => match.group(6)!.contains(x)),
      ),
    );
    devicesRead.add(source);
  }

  return devices;
}
