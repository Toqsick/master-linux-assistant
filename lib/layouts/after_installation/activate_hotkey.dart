import 'package:flutter/material.dart';
import 'package:linux_assistant/layouts/greeter/start_after_installation.dart';
import 'package:linux_assistant/layouts/mint_y.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/services/config_handler.dart';
import 'package:linux_assistant/services/linux.dart';

class ActivateHotkeyQuestion extends StatelessWidget {
  final Widget route;
  const ActivateHotkeyQuestion(
      {super.key, this.route = const StartAfterInstallationRoutineQuestion()});

  @override
  Widget build(BuildContext context) {
    return MintYPage(
      title: AppLocalizations.of(context)!.activateHotkey,
      contentElements: [
        Text(
          AppLocalizations.of(context)!.openLinuxAssistantFaster,
          style: Theme.of(context).textTheme.displayLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(
          height: 16,
        ),
        Text(
          AppLocalizations.of(context)!
              .openLinuxAssistantFasterDescription(Linux.getHotkeyModifier()),
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
      bottom: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MintYButtonNavigate(
            route: route,
            text: Text(
              AppLocalizations.of(context)!.skip,
              style: MintY.heading4,
            ),
          ),
          const SizedBox(
            width: 16,
          ),
          MintYButtonNext(
            route: route,
            // Awaited, and the result is shown. The button used to fire the
            // registration and navigate away in the same frame, so a failure
            // was invisible — and a second press queued a second run.
            onPressedFuture: () async {
              // The desktop's own shortcut is registered in both sessions.
              // It used to be skipped on X11, because the app grabbed the key
              // itself there (libkeybinder) and the desktop shortcut on top of
              // that fired twice per press — raise plus a second process. The
              // app-side grab is gone, so the desktop shortcut is the only
              // mechanism left, and it has to be there under X11 as well.
              final bool ok =
                  await Linux.activateSystemHotkeyForLinuxAssistant();
              // Only remember it when it worked. main.dart skips the
              // registration on later starts based on this flag, so writing
              // it unconditionally would make a failed setup permanent.
              await ConfigHandler().setValue("keybinding_registered", ok);
            },
          ),
        ],
      ),
    );
  }
}
