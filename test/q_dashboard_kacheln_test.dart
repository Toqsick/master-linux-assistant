// Q2, Q3, Q5 and Q6 of issue #58 — the four dashboard additions.
//
// The dashboard shows: whether a reboot is pending and which packages caused
// it, which systemd units failed, which browser the desktop calls the
// standard one, and what the memory pressure actually is. All four are read
// from the system, so the parsers are the part worth pinning: a wrong
// number on a dashboard is worse than no number.
//
// The parsers are pure functions, so they are tested without touching the
// file system or starting a process.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linux_assistant/linux/linux_memory.dart';
import 'package:linux_assistant/services/browser_status_service.dart';
import 'package:linux_assistant/services/failed_units_service.dart';
import 'package:linux_assistant/services/reboot_service.dart';

void main() {
  group("Q2 — the reboot marker", () {
    test("lists the packages that caused the reboot", () {
      final List<String> packages = RebootService.parsePackages(
        "linux-firmware\nlinux-image-6.1\n",
      );
      expect(packages, <String>["linux-firmware", "linux-image-6.1"]);
    });

    test("skips blank lines and comments", () {
      final List<String> packages = RebootService.parsePackages(
        "\n# a comment\nlinux-firmware\n\n   \n",
      );
      expect(packages, <String>["linux-firmware"]);
    });

    test("an empty file yields no packages", () {
      expect(RebootService.parsePackages(""), isEmpty);
    });

    test("no marker file means no reboot is pending", () async {
      final RebootStatus status = await RebootService.readStatus(
        markerPaths: <String>["/nonexistent/reboot-required"],
        packagePaths: <String>["/nonexistent/reboot-required.pkgs"],
      );
      expect(status.required, isFalse);
      expect(status.packages, isEmpty);
    });

    test("a marker without a package list is a pending reboot of unknown cause",
        () async {
      final Directory directory =
          Directory.systemTemp.createTempSync("mla-reboot-marker");
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final File marker = File("${directory.path}/reboot-required");
      marker.writeAsStringSync("");

      final RebootStatus status = await RebootService.readStatus(
        markerPaths: <String>[marker.path],
        packagePaths: <String>["${directory.path}/missing.pkgs"],
      );
      expect(status.required, isTrue);
      expect(status.packages, isEmpty);
    });

    test("a marker with a package list names the cause", () async {
      final Directory directory =
          Directory.systemTemp.createTempSync("mla-reboot-packages");
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final File marker = File("${directory.path}/reboot-required");
      marker.writeAsStringSync("");
      final File packages = File("${directory.path}/reboot-required.pkgs");
      packages.writeAsStringSync("linux-firmware\nlinux-image-6.1\n");

      final RebootStatus status = await RebootService.readStatus(
        markerPaths: <String>[marker.path],
        packagePaths: <String>[packages.path],
      );
      expect(status.required, isTrue);
      expect(status.packages, <String>["linux-firmware", "linux-image-6.1"]);
    });
  });

  group("Q3 — the failed systemd units", () {
    test("reads unit, description and scope from the systemctl JSON", () {
      final List<FailedUnit> units = FailedUnitsService.parseUnitsJson(
        '{"units":[{"unit":"restic-backup.service",'
        '"description":"Backup and restore service"}]}',
        FailedUnitScope.system,
      );
      expect(units, hasLength(1));
      expect(units.single.unit, "restic-backup.service");
      expect(units.single.description, "Backup and restore service");
      expect(units.single.scope, FailedUnitScope.system);
    });

    test("the scope comes from the manager that was asked", () {
      final List<FailedUnit> units = FailedUnitsService.parseUnitsJson(
        '{"units":[{"unit":"user@1000.service","description":""}]}',
        FailedUnitScope.user,
      );
      expect(units.single.scope, FailedUnitScope.user);
    });

    test("a unit without a description is still listed", () {
      final List<FailedUnit> units = FailedUnitsService.parseUnitsJson(
        '{"units":[{"unit":"a.service"}]}',
        FailedUnitScope.system,
      );
      expect(units, hasLength(1));
      expect(units.single.description, isEmpty);
    });

    test("an entry without a unit name is skipped", () {
      final List<FailedUnit> units = FailedUnitsService.parseUnitsJson(
        '{"units":[{"description":"no name here"}]}',
        FailedUnitScope.system,
      );
      expect(units, isEmpty);
    });

    test("broken JSON does not crash the dashboard", () {
      final List<FailedUnit> units = FailedUnitsService.parseUnitsJson(
        "{not json at all",
        FailedUnitScope.system,
      );
      expect(units, isEmpty);
    });

    test("an empty answer is an empty list", () {
      expect(
        FailedUnitsService.parseUnitsJson("", FailedUnitScope.system),
        isEmpty,
      );
      expect(
        FailedUnitsService.parseUnitsJson(
            '{"units":[]}', FailedUnitScope.system),
        isEmpty,
      );
    });
  });

  group("Q5 — the standard browser", () {
    // The format below is what `gio mime x-scheme-handler/https` really prints
    // (measured on gio 2.74). The trailing sections list applications that can
    // open the type without being the default; the dashboard wants the
    // default, so they are ignored.
    const String gioOutput = "Default application for "
        "?x-scheme-handler/https?: brave-browser.desktop\n"
        "No registered applications\n"
        "No recommended applications\n";

    test("reads the desktop entry that handles HTTPS", () {
      expect(
        BrowserStatusService.parseGioMimeHandler(gioOutput),
        "brave-browser.desktop",
      );
    });

    test("ignores the sections that only list candidates", () {
      expect(
        BrowserStatusService.parseGioMimeHandler(
          "No default applications for ?x-scheme-handler/https?\n",
        ),
        isNull,
      );
    });

    test("an output without a default line means the handler is unknown", () {
      expect(BrowserStatusService.parseGioMimeHandler(""), isNull);
      expect(
        BrowserStatusService.parseGioMimeHandler(
            "No registered applications\n"),
        isNull,
      );
    });

    test("an empty value means the handler is unknown", () {
      expect(
        BrowserStatusService.parseGioMimeHandler(
          "Default application for ?x-scheme-handler/https?: \n",
        ),
        isNull,
      );
    });
  });

  group("Q6 — the memory tile", () {
    test("reads the average over the last minute from the PSI file", () {
      final MemoryPressure? pressure = LinuxMemory.parsePressure(
        "some avg10=0.00 avg60=1.23 avg300=0.45 total=1234\n"
        "full avg10=0.00 avg60=0.10 avg300=0.02 total=567\n",
      );
      expect(pressure, isNotNull);
      expect(pressure!.someAvg60, closeTo(1.23, 0.001));
      expect(pressure.fullAvg60, closeTo(0.10, 0.001));
    });

    test("a machine under no pressure is normal", () {
      expect(
        LinuxMemory.levelFor(someAvg60: 0.5, fullAvg60: 0.0),
        MemoryPressureLevel.normal,
      );
    });

    test("sustained pressure is elevated", () {
      expect(
        LinuxMemory.levelFor(someAvg60: 6.0, fullAvg60: 0.0),
        MemoryPressureLevel.elevated,
      );
    });

    test("a machine that is out of memory is at the high level", () {
      expect(
        LinuxMemory.levelFor(someAvg60: 20.0, fullAvg60: 0.0),
        MemoryPressureLevel.high,
      );
      expect(
        LinuxMemory.levelFor(someAvg60: 0.0, fullAvg60: 6.0),
        MemoryPressureLevel.high,
      );
    });

    test("a PSI file without a usable figure yields nothing", () {
      expect(LinuxMemory.parsePressure(""), isNull);
      expect(LinuxMemory.parsePressure("some avg10=0.00 total=1\n"), isNull);
    });

    test("zram reports the size before and after compression", () {
      final (int, int)? sizes =
          LinuxMemory.parseZramMmStat("7516192768 2147483648 0 0 0 0 0");
      expect(sizes, isNotNull);
      expect(sizes!.$1, 7516192768);
      expect(sizes.$2, 2147483648);
    });

    test("a broken zram statistic yields nothing", () {
      expect(LinuxMemory.parseZramMmStat(""), isNull);
      expect(LinuxMemory.parseZramMmStat("7516192768"), isNull);
      expect(LinuxMemory.parseZramMmStat("no numbers here"), isNull);
    });

    test("the zram capacity is the size of the device", () {
      expect(LinuxMemory.parseZramDiskSize("2147483648\n"), 2147483648);
      expect(LinuxMemory.parseZramDiskSize(""), isNull);
    });
  });
}
