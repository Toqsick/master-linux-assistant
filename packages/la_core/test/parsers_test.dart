import 'dart:io';

import 'package:la_core/la_core.dart';
import 'package:test/test.dart';

/// Unit tests for the parsers that moved into this package (#93).
///
/// The multi-line samples come from the shared fixture directory; see
/// `test/fixtures/README.md` in the repository root.
void main() {
  group("df parser", () {
    test("keeps real filesystems and drops pseudo ones", () {
      final output = File(
        '../../test/fixtures/zorin_df.txt',
      ).readAsStringSync();

      final disks = parseDfOutput(output);

      expect(disks, hasLength(2));
      expect(disks.any((d) => d.mountPoint == "/run"), isFalse);
      expect(disks.any((d) => d.mountPoint == "/dev/shm"), isFalse);
      expect(
        disks.any((d) => d.mountPoint == "/sys/firmware/efi/efivars"),
        isFalse,
      );

      final root = disks.firstWhere((d) => d.mountPoint == "/");
      expect(root.filesystem, "/dev/nvme0n1p3");
      expect(root.usedPercent, 89);
      expect(root.sizeFree, "66G");
      expect(root.isRemovable, isFalse);

      final data = disks.firstWhere((d) => d.mountPoint == "/mnt/DATA");
      expect(data.filesystem, "/dev/nvme0n1p2");
      expect(data.usedPercent, 83);
      expect(data.isRemovable, isTrue);
    });

    test("skips megabyte-sized partitions and duplicate devices", () {
      final output = File(
        '../../test/fixtures/df_duplicate_device.txt',
      ).readAsStringSync();

      final disks = parseDfOutput(output);

      expect(disks.length, 1);
      expect(disks.single.mountPoint, "/");
    });

    test("keeps mount points that contain spaces", () {
      // The naive whitespace split shifted every column by one and blew up
      // the Use% parse on sticks labeled "USB Stick".
      final output = File(
        '../../test/fixtures/df_mountpoint_spaces.txt',
      ).readAsStringSync();

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
      final output = File(
        '../../test/fixtures/zorin_ps.txt',
      ).readAsStringSync();

      final processes = parsePsOutput(output, 3);

      expect(processes.length, 3);
      expect(processes.first.metricValue, "54.1");
      expect(processes.first.processName, "zcode");
      expect(processes[1].processName, "zcode");
      expect(processes[2].processName, "gnome-shell");
    });

    test("honours the requested count", () {
      final output = File(
        '../../test/fixtures/zorin_ps.txt',
      ).readAsStringSync();
      expect(parsePsOutput(output, 2).length, 2);
    });

    test("skips lines that carry no command instead of throwing", () {
      // ps emits bare metric lines for some kernel threads.
      final output = File(
        '../../test/fixtures/ps_kernel_thread_line.txt',
      ).readAsStringSync();

      final processes = parsePsOutput(output, 3);
      expect(processes.map((p) => p.processName), ["a", "c"]);
    });

    test("fills the requested count when a bare line comes first", () {
      // A kernel-thread bare line among the first `count` data lines must
      // not shrink the result below the requested count.
      const output =
          "%CPU COMMAND\n"
          " 42.0 /usr/bin/a\n"
          " 0.0\n"
          " 3.2 /usr/bin/c\n"
          " 5.0 /usr/bin/d\n";

      final processes = parsePsOutput(output, 3);

      expect(processes.map((p) => p.processName), ["a", "c", "d"]);
    });

    test("count 0 or negative yields every entry, not an empty list", () {
      // Pinned edge, documented in the parser's doc comment but previously
      // untested and without production callers: the early-exit compare
      // `processes.length == count` never fires for count <= 0, so the
      // parser degenerates to "all entries". If that is ever deemed a bug
      // and changed to "empty", this pin makes the change visible instead
      // of silent.
      const output =
          "%CPU COMMAND\n"
          " 42.0 /usr/bin/a\n"
          " 3.2 /usr/bin/c\n"
          " 5.0 /usr/bin/d\n";

      expect(parsePsOutput(output, 0).map((p) => p.processName), [
        "a",
        "c",
        "d",
      ]);
      expect(parsePsOutput(output, -1).map((p) => p.processName), [
        "a",
        "c",
        "d",
      ]);
    });
  });

  group("uptime parser", () {
    test("reads hours and minutes from the clock format", () {
      final output = File(
        '../../test/fixtures/zorin_uptime.txt',
      ).readAsStringSync();
      final uptime = parseUptime(output);
      expect(uptime.unit, "h");
      expect(uptime.value, 1);
    });

    test("reports minutes when the hour component is zero", () {
      final output = File(
        '../../test/fixtures/uptime_minutes.txt',
      ).readAsStringSync();
      final uptime = parseUptime(output);
      expect(uptime.unit, "m");
      expect(uptime.value, 27);
    });

    test("reads the 'min' wording", () {
      final output = File(
        '../../test/fixtures/uptime_min_wording.txt',
      ).readAsStringSync();
      final uptime = parseUptime(output);
      expect(uptime.unit, "m");
      expect(uptime.value, 42);
    });

    test("reads the 'days' wording", () {
      final output = File(
        '../../test/fixtures/uptime_days.txt',
      ).readAsStringSync();
      final uptime = parseUptime(output);
      expect(uptime.unit, "d");
      expect(uptime.value, 12);
    });
  });

  group("free parser", () {
    test("reads memory and swap totals", () {
      final output = File(
        '../../test/fixtures/zorin_free.txt',
      ).readAsStringSync();

      final memory = MemoryInfo.parseFreeOutput(output)!;

      // Captured with `free -m`: the fixture's figures are mebibytes.
      expect(memory.totalMb, 15690);
      expect(memory.usedMb, 8578);
      expect(memory.swapTotalMb, 16036);
      expect(memory.swapUsedMb, 5437);
      expect(memory.hasSwap, isTrue);
      expect(memory.usedRatio, closeTo(8578 / 15690, 0.0001));
    });

    test("handles a machine without swap", () {
      final output = File(
        '../../test/fixtures/free_no_swap.txt',
      ).readAsStringSync();

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
      final output = File(
        '../../test/fixtures/zorin_loadavg.txt',
      ).readAsStringSync();
      expect(parseLoadAvg(output), 3.46);
    });

    test("tolerates trailing whitespace", () {
      expect(parseLoadAvg("  1.25 0.90 0.75 2/300 111  "), 1.25);
    });
  });
}
