import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:linux_assistant/layouts/main_screen/main_search.dart';
import 'package:linux_assistant/layouts/mint_y.dart';
import 'package:linux_assistant/models/linux_command.dart';
import 'package:linux_assistant/services/config_handler.dart';
import 'package:linux_assistant/services/linux.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';

class RunCommandQueue extends StatefulWidget {
  final String title;
  final String message;
  final Widget route;
  final bool offerShutdownAfterwards;

  const RunCommandQueue({
    super.key,
    this.message = "",
    required this.title,
    required this.route,
    this.offerShutdownAfterwards = false,
  });

  @override
  State<RunCommandQueue> createState() => _RunCommandQueueState();
}

class _RunCommandQueueState extends State<RunCommandQueue> {
  /// Started exactly once, in [initState].
  ///
  /// This used to be `Linux.executeCommandQueue()` called from `build()`, so
  /// every rebuild — a theme toggle while an installation is running is
  /// enough — started the whole root queue again: a second polkit prompt, a
  /// second `apt install`, a second `rm -rf`. `updater/updater.dart` had the
  /// same bug and fixes it the same way.
  Future<String>? _output;

  /// The queue as it was when this page opened. [Linux.commandQueue] itself is
  /// global and is cleared by the "next" button, so the table needs its own
  /// copy to survive a rebuild.
  List<LinuxCommand> _commands = const [];

  bool _commandQueueCompleted = false;
  bool _shutdownAfterwards = false;

  @override
  void initState() {
    super.initState();
    _commands = List<LinuxCommand>.from(Linux.commandQueue);
    if (_commands.isNotEmpty) {
      _output = Linux.executeCommandQueue();
    }
  }

  /// Where "continue" leads once the queue has run.
  ///
  /// With the hub running underneath, pushing the usual fullscreen
  /// [widget.route] stranded the user: that search cannot be dismissed (its
  /// clear() hands control back to the hub below instead of popping) and its
  /// loader wipes the embedded search's in-app hotkeys via unregisterAll.
  /// Popping back to the hub is the correct "continue" there.
  void _continueAfterQueue(BuildContext context) {
    Linux.clearCommandQueue();
    if (MainSearch.onDismiss != null) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => widget.route,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_commands.isEmpty) {
      return widget.route;
    }

    // Build data for table
    List<List<String>> tableData = [
      [
        AppLocalizations.of(context)!.command,
        // AppLocalizations.of(context)!.description,
        AppLocalizations.of(context)!.root
      ]
    ];
    for (LinuxCommand command in _commands) {
      tableData.add([
        command.displayCommand,
        // command.description,
        command.userId == 0
            ? AppLocalizations.of(context)!.yes
            : AppLocalizations.of(context)!.no
      ]);
    }

    return _EnterContinuesQueue(
      onContinue: () {
        // Enter only continues when the queue is actually done. While it
        // runs, the user watches the table, not the next step.
        if (!mounted || !_commandQueueCompleted) {
          return;
        }
        _continueAfterQueue(context);
      },
      child: FutureBuilder<String>(
        future: _output,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (!_commandQueueCompleted) {
              _commandQueueCompleted = true;
              if (widget.offerShutdownAfterwards && _shutdownAfterwards) {
                Linux.shutdown();
              }
            }
            return MintYPage(
              title: widget.title,
              contentElements: [
                Text(
                  widget.message,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(
                  height: 16,
                ),
                snapshot.data!.contains(
                        "Error executing command as another user: Request dismissed")
                    ? Column(
                        children: [
                          Text(
                            AppLocalizations.of(context)!.errorThisDidntWork,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          MintYButton(
                            text: Text(
                              AppLocalizations.of(context)!.retry,
                              style: MintY.heading4White,
                            ),
                            color: MintY.currentColor,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) => RunCommandQueue(
                                          route: widget.route,
                                          title: widget.title,
                                          message: widget.message,
                                          offerShutdownAfterwards:
                                              widget.offerShutdownAfterwards,
                                        )),
                              );
                            },
                          )
                        ],
                      )
                    : Text(
                        AppLocalizations.of(context)!.complete,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
              ],
              bottom: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MintYButton(
                    text: const Text(
                      "Log",
                      style: MintY.heading4,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return Dialog(
                            backgroundColor: Colors.black,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      icon: const Icon(
                                        Icons.close,
                                        size: 36,
                                        color: Colors.white,
                                      ),
                                      iconSize: 36,
                                    )
                                  ],
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                        snapshot.data.toString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: "Courier"),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  MintYButton(
                    text: Text(
                      AppLocalizations.of(context)!.next,
                      style: MintY.heading4White,
                    ),
                    color: MintY.currentColor,
                    onPressed: () => _continueAfterQueue(context),
                  ),
                ],
              ),
            );
          } else {
            // Loading Screen
            return MintYPage(
              title: widget.title,
              contentElements: [
                Column(
                  children: [
                    Text(
                      widget.message,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    const MintYProgressIndicatorCircle(),
                    const SizedBox(
                      height: 64,
                    ),
                    CommandTable(
                      tableData: tableData,
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    widget.offerShutdownAfterwards
                        ? ShutdownCheckbox(
                            value: _shutdownAfterwards,
                            onChanged: (bool value) {
                              setState(() {
                                _shutdownAfterwards = value;
                              });
                            },
                          )
                        : Container(),
                  ],
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

/// Binds the Enter key to "continue with the next step".
///
/// The page has no text field of its own, so nothing would have the focus and
/// a key event would never arrive. The [Focus] widget takes the focus as
/// soon as the page is on screen, and the shortcut below it then hears the
/// Enter key — as long as the page is the one that is focused.
class _EnterContinuesQueue extends StatelessWidget {
  const _EnterContinuesQueue({
    required this.onContinue,
    required this.child,
  });

  /// Called when the user presses Enter.
  final VoidCallback onContinue;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        _ContinueQueueIntent: CallbackAction<_ContinueQueueIntent>(
          onInvoke: (_) {
            onContinue();
            return null;
          },
        ),
      },
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.enter):
              const _ContinueQueueIntent(),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

/// The intent behind the Enter key of the command queue.
class _ContinueQueueIntent extends Intent {
  const _ContinueQueueIntent();
}

class ShutdownCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ShutdownCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Checkbox(
          fillColor:
              WidgetStateColor.resolveWith((states) => MintY.currentColor),
          value: value,
          onChanged: (bool? newValue) => onChanged(newValue ?? false),
        ),
        Text(
          AppLocalizations.of(context)!.shutdownAfterwards,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class CommandTable extends StatefulWidget {
  final List<List<String>> tableData;
  const CommandTable({super.key, required this.tableData});

  @override
  State<CommandTable> createState() => _CommandTableState();
}

class _CommandTableState extends State<CommandTable> {
  @override
  Widget build(BuildContext context) {
    bool showTable = ConfigHandler()
        .getValueUnsafe("show_commands_in_command_overview", false);
    return Column(
      children: [
        MintYButton(
          color: MintY.currentColor,
          text: Text(
              showTable
                  ? AppLocalizations.of(context)!.hideCommands
                  : AppLocalizations.of(context)!.showCommands,
              style: MintY.heading4White),
          onPressed: () {
            ConfigHandler()
                .setValue("show_commands_in_command_overview", !showTable);
            setState(() {});
          },
        ),
        showTable
            ? const SizedBox(
                height: 16,
              )
            : Container(),
        showTable
            ? Text(
                AppLocalizations.of(context)!
                    .theFollowingCommandsWillBeExecuted,
                style: Theme.of(context).textTheme.headlineSmall)
            : Container(),
        showTable
            ? const SizedBox(
                height: 16,
              )
            : Container(),
        showTable
            ? SizedBox(
                width: min(MediaQuery.of(context).size.width - 50, 800),
                child: MintYTable(data: widget.tableData),
              )
            : Container(),
        showTable
            ? MintYButton(
                text: Text(AppLocalizations.of(context)!.copyCommands,
                    style: MintY.heading4),
                onPressed: () {
                  // Get all commands as a string
                  String commands = "";
                  // Skip first row
                  for (int i = 1; i < widget.tableData.length; i++) {
                    commands += "${widget.tableData[i][0]}\n";
                  }
                  Linux.copyToClipboard(commands);
                },
              )
            : Container(),
      ],
    );
  }
}
