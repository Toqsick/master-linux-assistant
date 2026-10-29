import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:linux_assistant/enums/distros.dart';
import 'package:linux_assistant/layouts/greeter/flathub_permissions.dart';
import 'package:linux_assistant/layouts/greeter/start_screen.dart';
import 'package:linux_assistant/layouts/hermes_tokens.dart';
import 'package:linux_assistant/layouts/hub/hub_shell.dart';
import 'package:linux_assistant/layouts/mint_y.dart';
import 'package:linux_assistant/services/config_handler.dart';
import 'package:linux_assistant/services/linux.dart';
import 'package:linux_assistant/services/theme_controller.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';
import 'package:linux_assistant/services/logger.dart';
import 'package:linux_assistant/services/single_instance.dart';

String currentLinuxAssistantVersion = "";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowManager.instance.ensureInitialized();
  unawaited(WindowManager.instance.setTitle("Linux Assistant"));

  // Second press of the shortcut: hand it to the window that is already open
  // and stop here, instead of opening another one.
  final bool isTheInstance = await SingleInstance.claim(onRaise: raiseWindow);
  if (!isTheInstance) {
    exit(0);
  }

  StatelessWidget firstScreen = const StartScreen();
  bool systemIsDark = false;

  // Are we in a flatpak? Is the folder /app/bin/ present? // Do we have flatpak-spawn?
  var runningInFlatpak = Directory("/app/bin/").existsSync();
  if (runningInFlatpak) {
    firstScreen = const FlathubPermissionsPage();
    var result = Process.runSync("flatpak-spawn", ["--host", "ls", "/"]);
    if (result.stderr.toString().isEmpty) {
      firstScreen = const StartScreen();
    }
    logInfo(result.stdout.toString());
    logInfo(result.stderr.toString());
  }

  // Normal startup if everything is fine.
  if (firstScreen is StartScreen) {
    await Linux.init();

    systemIsDark = await Linux.isDarkThemeEnabled();
    await ThemeController().load(systemIsDark: systemIsDark);

    String versionFile = "${Linux.executableFolder}/version";
    if (await File(versionFile).exists()) {
      try {
        currentLinuxAssistantVersion =
            (await File(versionFile).readAsString()).trim();
      } catch (e) {
        // Do nothing.
      }
    }
  }

  runApp(MyApp(
    systemIsDark: systemIsDark,
    firstPage: firstScreen,
  ));
}

/// Brings the existing window forward and puts the caret in the search box.
///
/// Called both by the in-app hotkey on X11 and by a second process that found
/// the single-instance socket already taken.
Future<void> raiseWindow() async {
  await WindowManager.instance.restore();
  await WindowManager.instance.show();
  await WindowManager.instance.focus();
  HubShell.onSearchRequested?.call();
}

class MyApp extends StatefulWidget {
  /// What the desktop environment reports, used when the user follows the
  /// system theme.
  final bool systemIsDark;
  final Widget firstPage;

  const MyApp({
    super.key,
    this.systemIsDark = false,
    required this.firstPage,
  });

  @override
  State<MyApp> createState() => _MyAppState();

  /// Makes the "bring me up" shortcut work for the session we are in.
  ///
  /// The app does not grab the key itself any more. It used to, through
  /// libkeybinder, and that had two problems: on X11 the app's grab and the
  /// desktop's own shortcut fired together (one press raised the window and
  /// started a second process), and on Wayland the grab could not work at all
  /// — it wrote `Binding '<Meta>q' failed!` to the log on every invocation.
  ///
  /// The desktop's own shortcut is the one route now, and it exists on both
  /// session types. So there is no session distinction here any more: the
  /// same registration runs under Wayland and under X11.
  static void initHotkeyToShowUp() {
    unawaited(_ensureDesktopShortcut());
  }

  /// Registers the shortcut with the desktop itself, once.
  ///
  /// [Linux.activateSystemHotkeyForLinuxAssistant] runs `setup_keybinding.py`,
  /// which writes a gsettings entry. Doing that on every start would stack up
  /// shortcuts, so the flag records that it happened. The script skips an
  /// entry it already owns as well, which covers the case where the app dies
  /// before the flag reaches disk.
  ///
  /// This is the only registration left: it runs under Wayland and under X11
  /// alike, because the desktop's shortcut is the one that works on both.
  static Future<void> _ensureDesktopShortcut() async {
    final ConfigHandler configHandler = ConfigHandler();
    // Compared rather than used directly: the getter is untyped and the value
    // comes from a file the user can edit.
    if (configHandler.getValueUnsafe("keybinding_registered", false) == true) {
      return;
    }
    // Awaited, and only recorded when it worked. It used to fire and forget,
    // then write the flag regardless — so a desktop the script cannot handle
    // was marked as done and never retried.
    final bool ok = await Linux.activateSystemHotkeyForLinuxAssistant();
    await configHandler.setValue("keybinding_registered", ok);
  }

  /// Applies the accent colors for the current appearance.
  ///
  /// The app now ships the Hermes palette by default; the per-distribution
  /// colors below are opt-in via the `use_distro_colors` setting. An explicit
  /// `main_color` / `secondary_color` in the config still overrides both.
  static void setMainColor({required bool isDark}) {
    final tokens = isDark ? HermesTokens.dark : HermesTokens.light;

    if (!ThemeController().useDistroColors) {
      MintY.currentColor = tokens.accent;
      MintY.secondaryColor = tokens.accentHover;
      _applyConfiguredColorOverrides();
      return;
    }

    MintY.secondaryColor = const Color(0xff2ab9a4);
    switch (Linux.currentenvironment.distribution) {
      case DISTROS.DEBIAN:
        MintY.currentColor = const Color.fromARGB(255, 208, 7, 78);
        MintY.secondaryColor = const Color.fromARGB(255, 75, 5, 35);
        break;
      case DISTROS.LINUX_MINT:
      case DISTROS.LMDE:
        MintY.currentColor = const Color.fromARGB(255, 53, 168, 84);
        MintY.secondaryColor = const Color.fromARGB(255, 35, 130, 70);
        break;
      case DISTROS.MXLINUX:
        MintY.currentColor = const Color.fromARGB(255, 34, 34, 34);
        MintY.secondaryColor = const Color.fromARGB(255, 70, 80, 95);
        break;
      case DISTROS.POPOS:
        MintY.currentColor = const Color.fromARGB(255, 72, 185, 199);
        MintY.secondaryColor = const Color.fromARGB(255, 15, 80, 100);
        break;
      case DISTROS.ZORINOS:
        MintY.currentColor = const Color.fromARGB(255, 21, 166, 240);
        MintY.secondaryColor = const Color.fromARGB(255, 10, 85, 180);
        break;
      case DISTROS.KDENEON:
        MintY.currentColor = const Color.fromARGB(255, 35, 104, 150);
        MintY.secondaryColor = const Color.fromARGB(255, 24, 160, 135);
        break;
      case DISTROS.OPENSUSE:
        MintY.currentColor = const Color.fromARGB(255, 115, 186, 37);
        MintY.secondaryColor = const Color.fromARGB(255, 15, 95, 75);
        break;
      case DISTROS.UBUNTU:
        MintY.currentColor = const Color.fromARGB(255, 233, 84, 32);
        MintY.secondaryColor = const Color.fromARGB(255, 122, 42, 82);
        break;
      case DISTROS.FEDORA:
        MintY.currentColor = const Color.fromARGB(255, 81, 162, 218);
        MintY.secondaryColor = const Color.fromARGB(255, 41, 65, 114);
        break;
      case DISTROS.ARCH:
        MintY.currentColor = const Color.fromARGB(255, 15, 148, 210);
        MintY.secondaryColor = const Color.fromARGB(255, 28, 40, 51);
        break;
      case DISTROS.MANJARO:
        MintY.currentColor = const Color.fromARGB(255, 53, 191, 164);
        MintY.secondaryColor = const Color.fromARGB(255, 26, 40, 37);
        break;
      case DISTROS.ENDEAVOUR:
        MintY.currentColor = const Color.fromARGB(255, 127, 63, 191);
        MintY.secondaryColor = const Color.fromARGB(255, 127, 127, 255);
        break;
    }
    _applyConfiguredColorOverrides();
  }

  static void _applyConfiguredColorOverrides() {
    ConfigHandler configHandler = ConfigHandler();
    String colorString = configHandler.getValueUnsafe("main_color", "");
    if (colorString.isNotEmpty) {
      MintY.currentColor = HexColor(colorString);
    }
    colorString = configHandler.getValueUnsafe("secondary_color", "");
    if (colorString.isNotEmpty) {
      MintY.secondaryColor = HexColor(colorString);
    }
  }
}

class _MyAppState extends State<MyApp> {
  final ThemeController _themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    MyApp.initHotkeyToShowUp();
    _themeController.addListener(_onAppearanceChanged);
  }

  @override
  void dispose() {
    _themeController.removeListener(_onAppearanceChanged);
    super.dispose();
  }

  void _onAppearanceChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final bool isDark = _themeController.isDark(widget.systemIsDark);

    // Widgets that predate the theme extension read this static directly.
    MintY.dark = isDark;
    MyApp.setMainColor(isDark: isDark);

    final Color? accent =
        _themeController.useDistroColors ? MintY.currentColor : null;

    return MaterialApp(
      title: 'Linux Assistant',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('de', ''),
        Locale('it', ''),
        // Generated (app_localizations_fi.dart) but previously never
        // registered, so Finnish users silently got English.
        Locale('fi', ''),
      ],
      theme: MintY.theme(accent: accent),
      darkTheme: MintY.themeDark(accent: accent),
      // Resolved here rather than handed to Flutter as ThemeMode.system: the
      // desktop's setting comes from gsettings/kdeglobals via
      // Linux.isDarkThemeEnabled(), which the platform brightness does not
      // reliably mirror on Linux.
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: widget.firstPage,
    );
  }
}
