import 'package:la_core/la_core.dart';
import 'package:test/test.dart';

/// Unit tests for the parsers that moved into this package (#93).
///
/// The fixtures are inlined on purpose: a shared fixture directory is #94 and
/// is blocked by this move, and the strings are already in the repository in
/// `test/system_parsers_test.dart`.
void main() {
  group("df parser", () {
    test("keeps real filesystems and drops pseudo ones", () {
      const output = '''
Filesystem      Size  Used Avail Use% Mounted on
udev            7,8G     0  7,8G   0% /dev
tmpfs           1,6G  2,1M  1,6G   1% /run
/dev/nvme0n1p2  468G  212G  233G  48% /
/dev/nvme0n1p1  511M  6,1M  505M   2% /boot/efi
/dev/sdb1        59G   12G   47G  21% /media/user/USB
''';

      final disks = parseDfOutput(output);

      expect(
        disks.map((d) => d.mountPoint),
        containsAll(<String>["/", "/media/user/USB"]),
      );
      expect(disks.any((d) => d.mountPoint == "/dev"), isFalse);
      expect(disks.any((d) => d.mountPoint == "/run"), isFalse);

      final root = disks.firstWhere((d) => d.mountPoint == "/");
      expect(root.filesystem, "/dev/nvme0n1p2");
      expect(root.usedPercent, 48);
      expect(root.sizeFree, "233G");
      expect(root.isRemovable, isFalse);

      final usb = disks.firstWhere((d) => d.mountPoint == "/media/user/USB");
      expect(usb.isRemovable, isTrue);
    });

    test("skips megabyte-sized partitions and duplicate devices", () {
      const output = '''
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       511M  6,1M  505M   2% /boot/efi
/dev/sda2       468G  212G  233G  48% /
/dev/sda2       468G  212G  233G  48% /home
''';

      final disks = parseDfOutput(output);

      expect(disks.length, 1);
      expect(disks.single.mountPoint, "/");
    });

    test("keeps mount points that contain spaces", () {
      // The naive whitespace split shifted every column by one and blew up
      // the Use% parse on sticks labeled "USB Stick".
      const output = '''
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb1        59G   12G   47G  21% /media/user/USB Stick
''';

      final disks = parseDfOutput(output);

      expect(disks.length, 1);
      expect(disks.single.mountPoint, "/media/user/USB Stick");
      expect(disks.single.usedPercent, 21);
      expect(disks.single.isRemovable, isTrue);
    });

    test("returns an empty list for empty output", () {
      expect(parseDfOutput(""), isEmpty);
    });
  });

  group("ps parser", () {
    test("reads the metric and strips the command path", () {
      const output = '''
%CPU COMMAND
 42.0 /usr/lib/firefox/firefox
 11.5 /usr/bin/gnome-shell
  3.2 /usr/bin/Xorg
''';

      final processes = parsePsOutput(output, 3);

      expect(processes.length, 3);
      expect(processes.first.metricValue, "42.0");
      expect(processes.first.processName, "firefox");
      expect(processes[1].processName, "gnome-shell");
    });

    test("honours the requested count", () {
      const output = '''
%CPU COMMAND
 42.0 /usr/bin/a
 11.5 /usr/bin/b
  3.2 /usr/bin/c
''';
      expect(parsePsOutput(output, 2).length, 2);
    });

    test("skips lines that carry no command instead of throwing", () {
      // ps emits bare metric lines for some kernel threads.
      const output = '''
%CPU COMMAND
 42.0 /usr/bin/a
 0.0
 3.2 /usr/bin/c
''';

      final processes = parsePsOutput(output, 3);
      expect(processes.map((p) => p.processName), ["a", "c"]);
    });
  });

  group("uptime parser", () {
    test("reads hours and minutes from the clock format", () {
      final uptime = parseUptime(
        " 14:23:01 up  3:45,  1 user,  load average: 0,52, 0,58, 0,59",
      );
      expect(uptime.unit, "h");
      expect(uptime.value, 3);
    });

    test("reports minutes when the hour component is zero", () {
      final uptime = parseUptime(
        " 09:12:44 up  0:27,  1 user,  load average: 0,10, 0,20, 0,30",
      );
      expect(uptime.unit, "m");
      expect(uptime.value, 27);
    });

    test("reads the 'min' wording", () {
      final uptime = parseUptime(
        " 09:12:44 up 42 min,  1 user,  load average: 0,10, 0,20, 0,30",
      );
      expect(uptime.unit, "m");
      expect(uptime.value, 42);
    });

    test("reads the 'days' wording", () {
      final uptime = parseUptime(
        " 09:12:44 up 12 days,  3:21,  2 users,  load average: 0,10",
      );
      expect(uptime.unit, "d");
      expect(uptime.value, 12);
    });
  });

  group("free parser", () {
    test("reads memory and swap totals", () {
      const output = '''
             total        used        free      shared  buff/cache   available
Mem:           15889        6421        1204         512        8263        8901
Swap:           2047         128        1919
''';

      final memory = MemoryInfo.parseFreeOutput(output)!;

      expect(memory.totalMb, 15889);
      expect(memory.usedMb, 6421);
      expect(memory.swapTotalMb, 2047);
      expect(memory.swapUsedMb, 128);
      expect(memory.hasSwap, isTrue);
      expect(memory.usedRatio, closeTo(6421 / 15889, 0.0001));
    });

    test("handles a machine without swap", () {
      const output = '''
             total        used        free      shared  buff/cache   available
Mem:            7861        2100        3000         200        2761        5400
Swap:              0           0           0
''';

      final memory = MemoryInfo.parseFreeOutput(output)!;
      expect(memory.hasSwap, isFalse);
      expect(memory.swapUsedRatio, 0);
    });

    test("returns null rather than throwing on unusable output", () {
      expect(MemoryInfo.parseFreeOutput(""), isNull);
      expect(MemoryInfo.parseFreeOutput("some error\n"), isNull);
      expect(MemoryInfo.parseFreeOutput("header\nMem: not a number\n"), isNull);
    });
  });

  group("loadavg parser", () {
    test("takes the one-minute figure", () {
      expect(parseLoadAvg("0.52 0.58 0.59 1/1234 5678\n"), 0.52);
    });

    test("tolerates trailing whitespace", () {
      expect(parseLoadAvg("  1.25 0.90 0.75 2/300 111  "), 1.25);
    });
  });
}
