import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linux_assistant/linux/linux_filesystem.dart';
import 'package:linux_assistant/linux/linux_process.dart';
import 'package:linux_assistant/linux/linux_system.dart';
import 'package:linux_assistant/services/system_stats_service.dart';

void main() {
  group("df parser", () {
    test("keeps real filesystems and drops pseudo ones", () {
      final output = File('test/fixtures/zorin_df.txt').readAsStringSync();

      final disks = LinuxFilesystem.parseDfOutput(output);

      expect(disks, hasLength(2));
      expect(disks.any((d) => d.mountPoint == "/run"), isFalse);
      expect(disks.any((d) => d.mountPoint == "/dev/shm"), isFalse);
      expect(disks.any((d) => d.mountPoint == "/sys/firmware/efi/efivars"),
          isFalse);

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
      final output =
          File('test/fixtures/df_duplicate_device.txt').readAsStringSync();

      final disks = LinuxFilesystem.parseDfOutput(output);

      expect(disks.length, 1);
      expect(disks.single.mountPoint, "/");
    });

    test("keeps mount points that contain spaces", () {
      // The naive whitespace split shifted every column by one and blew up
      // the Use% parse on sticks labeled "USB Stick".
      final output =
          File('test/fixtures/df_mountpoint_spaces.txt').readAsStringSync();

      final disks = LinuxFilesystem.parseDfOutput(output);

      expect(disks.length, 1);
      expect(disks.single.mountPoint, "/media/user/USB Stick");
      expect(disks.single.usedPercent, 21);
      expect(disks.single.isRemovable, isTrue);
    });

    test("returns an empty list for empty output", () {
      expect(LinuxFilesystem.parseDfOutput(""), isEmpty);
    });
  });

  group("ps parser", () {
    test("reads the metric and strips the command path", () {
      final output = File('test/fixtures/zorin_ps.txt').readAsStringSync();

      final processes = LinuxProcess.parsePsOutput(output, 3);

      expect(processes.length, 3);
      expect(processes.first.metricValue, "54.1");
      expect(processes.first.processName, "zcode");
      expect(processes[1].processName, "zcode");
      expect(processes[2].processName, "gnome-shell");
    });

    test("honours the requested count", () {
      final output = File('test/fixtures/zorin_ps.txt').readAsStringSync();
      expect(LinuxProcess.parsePsOutput(output, 2).length, 2);
    });

    test("skips lines that carry no command instead of throwing", () {
      // ps emits bare metric lines for some kernel threads.
      final output =
          File('test/fixtures/ps_kernel_thread_line.txt').readAsStringSync();

      final processes = LinuxProcess.parsePsOutput(output, 3);
      expect(processes.map((p) => p.processName), ["a", "c"]);
    });
  });

  group("uptime parser", () {
    test("reads hours and minutes from the clock format", () {
      final output = File('test/fixtures/zorin_uptime.txt').readAsStringSync();
      final uptime = LinuxSystem.parseUptime(output);
      expect(uptime.unit, "h");
      expect(uptime.value, 1);
    });

    test("reports minutes when the hour component is zero", () {
      final output =
          File('test/fixtures/uptime_minutes.txt').readAsStringSync();
      final uptime = LinuxSystem.parseUptime(output);
      expect(uptime.unit, "m");
      expect(uptime.value, 27);
    });

    test("reads the 'min' wording", () {
      final output =
          File('test/fixtures/uptime_min_wording.txt').readAsStringSync();
      final uptime = LinuxSystem.parseUptime(output);
      expect(uptime.unit, "m");
      expect(uptime.value, 42);
    });

    test("reads the 'days' wording", () {
      final output = File('test/fixtures/uptime_days.txt').readAsStringSync();
      final uptime = LinuxSystem.parseUptime(output);
      expect(uptime.unit, "d");
      expect(uptime.value, 12);
    });
  });

  group("free parser", () {
    test("reads memory and swap totals", () {
      final output = File('test/fixtures/zorin_free.txt').readAsStringSync();

      final memory = MemoryInfo.parseFreeOutput(output)!;

      expect(memory.totalMb, 16066996);
      expect(memory.usedMb, 10558324);
      expect(memory.swapTotalMb, 16421880);
      expect(memory.swapUsedMb, 7950396);
      expect(memory.hasSwap, isTrue);
      expect(memory.usedRatio, closeTo(10558324 / 16066996, 0.0001));
    });

    test("handles a machine without swap", () {
      final output = File('test/fixtures/free_no_swap.txt').readAsStringSync();

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

  group("stats service", () {
    test("reference counting starts and stops the poller", () {
      final service = SystemStatsService();
      addTearDown(service.resetForTesting);
      service.resetForTesting();

      expect(service.isRunning, isFalse);

      service.acquire();
      expect(service.subscriberCount, 1);
      expect(service.isRunning, isTrue);

      service.acquire();
      expect(service.subscriberCount, 2);

      service.release();
      // Still one listener left, so polling must continue.
      expect(service.isRunning, isTrue);

      service.release();
      expect(service.subscriberCount, 0);
      expect(service.isRunning, isFalse);
    });

    test("releasing below zero is a no-op", () {
      final service = SystemStatsService();
      addTearDown(service.resetForTesting);
      service.resetForTesting();

      service.release();
      expect(service.subscriberCount, 0);
      expect(service.isRunning, isFalse);
    });

    test("a section without stats stops the poll despite live subscribers", () {
      final service = SystemStatsService();
      addTearDown(service.resetForTesting);
      service.resetForTesting();

      service.acquire();
      expect(service.isRunning, isTrue);

      // The hub never disposes a visited section, so the subscriber stays.
      service.setSectionActive(false);
      expect(service.subscriberCount, 1);
      expect(service.isRunning, isFalse);

      service.setSectionActive(true);
      expect(service.isRunning, isTrue);
    });

    test("a minimized window stops the poll", () {
      final service = SystemStatsService();
      addTearDown(service.resetForTesting);
      service.resetForTesting();

      service.acquire();
      service.setWindowVisible(false);
      expect(service.isRunning, isFalse);

      service.setWindowVisible(true);
      expect(service.isRunning, isTrue);
    });

    test("both conditions have to be met before polling resumes", () {
      final service = SystemStatsService();
      addTearDown(service.resetForTesting);
      service.resetForTesting();

      service.acquire();
      service.setWindowVisible(false);
      service.setSectionActive(false);

      service.setWindowVisible(true);
      expect(service.isRunning, isFalse, reason: "section is still inactive");

      service.setSectionActive(true);
      expect(service.isRunning, isTrue);
    });

    test("flags alone do not poll without a subscriber", () {
      final service = SystemStatsService();
      addTearDown(service.resetForTesting);
      service.resetForTesting();

      service.setSectionActive(true);
      service.setWindowVisible(true);
      expect(service.isRunning, isFalse);
    });
  });

  group("loadavg parser", () {
    test("takes the one-minute figure", () {
      final output = File('test/fixtures/zorin_loadavg.txt').readAsStringSync();
      expect(LinuxSystem.parseLoadAvg(output), 3.46);
    });

    test("tolerates trailing whitespace", () {
      expect(LinuxSystem.parseLoadAvg("  1.25 0.90 0.75 2/300 111  "), 1.25);
    });
  });
}
