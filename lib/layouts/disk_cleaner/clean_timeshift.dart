import 'dart:async';
import 'package:flutter/material.dart';
import 'package:linux_assistant/layouts/mint_y.dart';
import 'package:linux_assistant/layouts/run_command_queue.dart';
import 'package:linux_assistant/models/linux_command.dart';
import 'package:linux_assistant/services/linux.dart';
import 'package:linux_assistant/widgets/system_icon.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';

class TimeshiftCleanWidget extends StatelessWidget {
  final Widget routeAfterRemoval;
  final String mountpoint;
  const TimeshiftCleanWidget(
      {super.key, required this.routeAfterRemoval, this.mountpoint = "/"});

  @override
  Widget build(BuildContext context) {
    Future<List<String>> timeshiftSnapshotsFuture = _getTimeshiftSnapshots();
    return FutureBuilder(
        future: timeshiftSnapshotsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            List<String> timeshiftSnapshots = snapshot.data!;
            if (timeshiftSnapshots.isEmpty) {
              return Text("No timeshift snapshots found");
            }
            return MintYGrid(
              padding: 10,
              ratio: 2,
              widgetSize: 450,
              children: [
                for (var timeshiftSnapshot in timeshiftSnapshots)
                  MintYCardWithIconAndAction(
                    icon: SystemIcon(iconString: "timeshift"),
                    title: timeshiftSnapshot,
                    text: "(Timeshift)",
                    buttonText: AppLocalizations.of(context)!.remove,
                    onPressed: () async {
                      // Deleting a snapshot is not a disk-cleanup detail: it
                      // can be the last rollback point on the machine, and the
                      // button used to act on the first click.
                      final bool confirmed =
                          await _confirmDeletion(context, timeshiftSnapshot);
                      if (!confirmed || !context.mounted) {
                        return;
                      }

                      Linux.commandQueue.add(LinuxCommand(userId: 0, argv: [
                        "/usr/bin/timeshift",
                        "--delete",
                        "--snapshot",
                        timeshiftSnapshot
                      ]));
                      unawaited(Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => RunCommandQueue(
                                title: AppLocalizations.of(context)!
                                    .cleaningDiskspace,
                                route: routeAfterRemoval,
                              ))));
                    },
                  ),
              ],
            );
          }
          return MintYProgressIndicatorCircle();
        });
  }

  Future<bool> _confirmDeletion(BuildContext context, String snapshot) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteSnapshotQuestion(snapshot)),
        content: Text(l10n.deleteSnapshotWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  Future<List<String>> _getTimeshiftSnapshots() async {
    List<String> timeshiftSnapshots = [];
    // String timeshiftOutput =
    //     await Linux.runCommandWithCustomArguments("timeshift", ["--list"]);
    // List<String> timeshiftOutputLines = timeshiftOutput.split("\n");
    // print("timeshiftOutputLines: $timeshiftOutputLines");
    // for (var line in timeshiftOutputLines) {
    //   if (line.contains(">")) {
    //     timeshiftSnapshots.add(line.split(">").last.trim().split(" ").first);
    //   }
    // }
    String timeshiftOutput = await Linux.runCommandWithCustomArguments(
        "ls", ["$mountpoint/timeshift/snapshots/"]);
    List<String> timeshiftOutputLines = timeshiftOutput.split("\n");
    for (var line in timeshiftOutputLines) {
      if (line.contains("20")) {
        timeshiftSnapshots.add(line.trim());
      }
    }
    return timeshiftSnapshots;
  }
}
