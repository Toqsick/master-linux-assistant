import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linux_assistant/content/top_level_domains.dart';
import 'package:linux_assistant/enums/softwareManagers.dart';
import 'package:linux_assistant/layouts/feature_overview/feature_overview.dart';
import 'package:linux_assistant/layouts/greeter/introduction.dart';
import 'package:linux_assistant/layouts/main_screen/action_entry_card.dart';
import 'package:linux_assistant/services/action_entry_list_service.dart';
import 'package:linux_assistant/widgets/disk_space.dart';
import 'package:linux_assistant/layouts/feedback/feedback_form.dart';
import 'package:linux_assistant/layouts/settings/settings_start.dart';
import 'package:linux_assistant/services/main_search_loader.dart';
import 'package:linux_assistant/widgets/memory_status.dart';
import 'package:linux_assistant/layouts/mint_y.dart';
import 'package:linux_assistant/layouts/main_screen/recommendation_card.dart';
import 'package:linux_assistant/main.dart';
import 'package:linux_assistant/models/action_entry.dart';
import 'package:linux_assistant/services/action_handler.dart';
import 'package:linux_assistant/services/config_handler.dart';
import 'package:linux_assistant/services/linux.dart';
import 'package:window_manager/window_manager.dart';
import 'package:linux_assistant/l10n/app_localizations.dart';

class MainSearch extends StatefulWidget {
  final bool colorfulBackground;

  /// True when the search is a section of the hub rather than the whole window.
  final bool embedded;

  MainSearch({super.key, this.embedded = false})
      : colorfulBackground = _resolveColorfulBackground(embedded);

  /// The gradient is a full-window launcher backdrop. Inside the hub it covers
  /// the content area only and fights with the surrounding chrome, so the
  /// section stays on the theme's own surface.
  static bool _resolveColorfulBackground(bool embedded) {
    if (embedded) {
      return false;
    }
    return ConfigHandler().getValueUnsafe("colorfulBackground", true);
  }

  /// Set by the hub while it is on screen.
  ///
  /// The search was built as a launcher overlay: finishing an action minimizes
  /// the window, and on Wayland quits the app a few seconds later, because
  /// `wmctrl -a` cannot raise it again there. Inside a hub that is the wrong
  /// behaviour — there is a window to go back to — so the hub installs a
  /// callback that returns to the dashboard instead.
  static VoidCallback? onDismiss;

  @override
  State<MainSearch> createState() => _MainSearchState();

  /// Makes sure the desktop has the "bring me up" shortcut.
  ///
  /// The name is a leftover: the search screen used to unregister the global
  /// hotkeys here, because the old hotkey library kept them in one
  /// process-wide registry and the app-side grab had to be gone while the
  /// search was on screen. That registry is gone — the shortcut belongs to the
  /// desktop and is registered once — so all that is left is making sure the
  /// desktop still has it.
  static void unregisterHotkeysForKeyboardUse() {
    MyApp.initHotkeyToShowUp();
  }
}

class _MainSearchState extends State<MainSearch> {
  String _lastKeyword = "";

  List<ActionEntry> _foundEntries = [];

  var selectedIndex = 0;
  var selectedIndexInView = 0;

  /// Only describes the technical possible amount of visible entries depending
  /// at the screen size
  late int visibleEntries;

  final searchBarController = TextEditingController();
  final scrollController = ScrollController();

  bool listFolders = true;
  bool listPackageManagerActions = true;

  Timer? searchOnStoppedTyping;
  Timer? suggestionTimer;

  ActionEntry? suggestion;

  @override
  void initState() {
    super.initState();
    // Started here rather than in `build()`, and cancelled in `dispose()`.
    // Both timers used to outlive the widget: inside the hub the search
    // section is kept alive in an IndexedStack, and every navigation back to
    // the search screen created another instance with another orphaned timer.
    suggestionTimer = Timer.periodic(
      const Duration(seconds: 5),
      ((timer) => _handleSuggestions()),
    );
  }

  @override
  void dispose() {
    suggestionTimer?.cancel();
    searchOnStoppedTyping?.cancel();
    searchBarController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var backgroundColor = Theme.of(context).cardColor;

    // Complete height of a search entry is 64 + 8 (padding)
    visibleEntries =
        ((MediaQuery.of(context).size.height - 40 - 70) / 72).round();
    return Scaffold(
      body: Container(
        decoration: widget.colorfulBackground ? MintY.colorfulBackground : null,
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _foundEntries.isEmpty
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 16),
                                const DiskSpace(),
                                SizedBox(width: 16),
                                SystemStatus(),
                              ],
                            )
                          : Container(),
                      _foundEntries.isEmpty
                          ? const SizedBox(height: 16)
                          : Container(),
                      ExcludeSemantics(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width > 750
                                  ? 600
                                  : MediaQuery.of(context).size.width - 50,
                              child: SearchFieldShortcuts(
                                onSelectNext: _selectNext,
                                onSelectPrevious: _selectPrevious,
                                onClear: _clearSearchField,
                                onDebugShortcut: _debugShortcut,
                                child: TextField(
                                  decoration: InputDecoration(
                                    fillColor: Theme.of(context).canvasColor,
                                    filled: true,
                                    // border: const OutlineInputBorder(
                                    //     borderSide: BorderSide(color: Colors.white)),
                                    contentPadding: _foundEntries.isEmpty
                                        ? null
                                        : const EdgeInsets.only(
                                            bottom: -20.0,
                                            left: 12,
                                            right: 3,
                                          ),
                                    hintText: suggestion != null
                                        ? suggestion!.name
                                        : AppLocalizations.of(
                                            context,
                                          )!
                                            .enterASearchTerm,
                                    prefixIcon: _foundEntries.isEmpty
                                        ? const Icon(
                                            Icons.search,
                                            color: Colors.grey,
                                          )
                                        : null,
                                    suffix: _foundEntries.isEmpty
                                        ? null
                                        : IconButton(
                                            iconSize: 14,
                                            splashRadius: 14,
                                            icon: const Icon(Icons.clear),
                                            onPressed: () =>
                                                clear(minimze: false),
                                            padding: EdgeInsets.zero,
                                            tooltip: AppLocalizations.of(
                                              context,
                                            )!
                                                .clear,
                                          ),
                                  ),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  cursorColor: MintY.currentColor,
                                  controller: searchBarController,
                                  autofocus: true,
                                  onChanged: (value) => _runFilter(value),
                                  onSubmitted: (value) {
                                    if (_foundEntries.isNotEmpty) {
                                      ActionHandler.handleActionEntry(
                                        _foundEntries[selectedIndex],
                                        clear,
                                        context,
                                      );
                                    } else if (suggestion != null) {
                                      ActionHandler.handleActionEntry(
                                        suggestion!,
                                        clear,
                                        context,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                            _foundEntries.isEmpty
                                ? Container()
                                : const SizedBox(width: 10),
                            _foundEntries.isEmpty
                                ? Container()
                                : MintYButton(
                                    textColor: listFolders
                                        ? backgroundColor
                                        : MintY.currentColor,
                                    backgroundColor: listFolders
                                        ? MintY.currentColor
                                        : backgroundColor,
                                    icon: Icons.folder,
                                    width: 40,
                                    tooltip: listFolders
                                        ? AppLocalizations.of(
                                            context,
                                          )!
                                            .hideFolders
                                        : AppLocalizations.of(
                                            context,
                                          )!
                                            .showFolders,
                                    onPressed: () {
                                      setState(() {
                                        listFolders = !listFolders;
                                        _runFilter(_lastKeyword);
                                      });
                                    },
                                  ),
                            _foundEntries.isEmpty
                                ? Container()
                                : const SizedBox(width: 10),
                            _foundEntries.isEmpty
                                ? Container()
                                : MintYButton(
                                    textColor: listPackageManagerActions
                                        ? backgroundColor
                                        : MintY.currentColor,
                                    backgroundColor: listPackageManagerActions
                                        ? MintY.currentColor
                                        : backgroundColor,
                                    icon: Icons.archive,
                                    width: 40,
                                    tooltip: listPackageManagerActions
                                        ? AppLocalizations.of(
                                            context,
                                          )!
                                            .hidePackageManagerActions
                                        : AppLocalizations.of(
                                            context,
                                          )!
                                            .showPackageManagerActions,
                                    onPressed: () {
                                      setState(() {
                                        listPackageManagerActions =
                                            !listPackageManagerActions;
                                        _runFilter(_lastKeyword);
                                      });
                                    },
                                  ),
                            _foundEntries.isEmpty
                                ? Container()
                                : const SizedBox(width: 10),
                            _foundEntries.isEmpty
                                ? Container()
                                : IconButton(
                                    iconSize: 24,
                                    splashRadius: 24,
                                    icon: Icon(
                                      Icons.feedback,
                                      color: widget.colorfulBackground
                                          ? Colors.white
                                          : Theme.of(
                                              context,
                                            ).textTheme.displayLarge!.color,
                                    ),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (context) => FeedbackDialog(
                                        calledFromHome: false,
                                        foundEntries: _foundEntries,
                                        searchText: _lastKeyword,
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                    tooltip: AppLocalizations.of(context)!
                                        .sendFeedback,
                                  ),
                          ],
                        ),
                      ),
                      _foundEntries.isEmpty
                          ? const SizedBox(height: 50)
                          : const SizedBox(height: 10),
                      _foundEntries.isEmpty
                          ? Container()
                          : Expanded(
                              child: ListView(
                                controller: scrollController,
                                children: List.generate(
                                  _foundEntries.length,
                                  (index) => ActionEntryCard(
                                    actionEntry: _foundEntries[index],
                                    callback: clear,
                                    selected: selectedIndex == index,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),

            /// Bottom Bar
            _foundEntries.isEmpty
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Left Bottom
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [Container()],
                      ),
                      // Recommendation Card
                      Expanded(child: Container()),
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: RecommendationCard(),
                      ),
                      // Right Bottom
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            // Reload Button at start page
                            ReloadSearchButton(widget: widget),

                            // Help Button at start page
                            HelpButton(widget: widget),

                            IconButton(
                              onPressed: () => {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const FeatureOverview(),
                                  ),
                                ),
                              },
                              icon: Icon(
                                Icons.apps,
                                color: widget.colorfulBackground
                                    ? Colors.white
                                    : Theme.of(
                                        context,
                                      ).textTheme.displayLarge!.color,
                              ),
                              tooltip:
                                  AppLocalizations.of(context)!.featureOverview,
                            ),

                            // Settings Button:
                            IconButton(
                              iconSize: 24,
                              splashRadius: 24,
                              icon: Icon(
                                Icons.settings,
                                color: widget.colorfulBackground
                                    ? Colors.white
                                    : Theme.of(
                                        context,
                                      ).textTheme.displayLarge!.color,
                              ),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (context) => const SettingsStart(),
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: AppLocalizations.of(context)!.settings,
                            ),
                            // Feedback Button at start page
                            FeedbackButton(
                              widget: widget,
                              foundEntries: _foundEntries,
                              lastKeyword: _lastKeyword,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Container(),
          ],
        ),
      ),
    );
  }

  void clear({minimze = true}) {
    if (minimze) {
      final VoidCallback? returnToHub = MainSearch.onDismiss;
      if (returnToHub != null) {
        // Running inside the hub: keep the window open and hand control back.
        returnToHub();
      } else {
        // Just minimize, on both session types. This used to quit the whole
        // app five seconds later on Wayland, because `wmctrl -a` cannot raise
        // a window there and the next press of the shortcut would otherwise
        // have opened a second one. SingleInstance now hands the shortcut to
        // the window that is already running, so there is nothing to quit for
        // — and the user keeps a warm process instead of paying the startup
        // cost on every use.
        unawaited(windowManager.minimize());
      }
    }
    _lastKeyword = "";
    searchBarController.clear();
    selectedIndex = 0;
    selectedIndexInView = 0;
    _runFilter("");
  }

  bool isRegex(String pattern) {
    try {
      RegExp(pattern);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// The keyword could be here also a string with spaces between.
  void _runFilter(String keyword) async {
    if (keyword.length < 3) {
      // If the keyword is too short, we don't want to run the filter
      // and just clear the results.
      _foundEntries = [];
      setState(() {});
      return;
    }

    // Heavy search
    const duration = Duration(milliseconds: 800);
    searchOnStoppedTyping?.cancel();
    searchOnStoppedTyping = Timer(duration, () => _runHeavyFilter(keyword));

    RegExp? regExp;
    if (isRegex(keyword)) {
      regExp = RegExp(keyword, caseSensitive: false);
    } else {
      // Replace all *. with that e.g. *.filetype is recognized as a file ending
      keyword = keyword.replaceAll("*.", ".");
    }

    _lastKeyword = keyword;
    keyword = keyword.toLowerCase();
    List<String> keys = keyword.split(" ");
    List<ActionEntry> results = [];
    if (keyword.isEmpty) {
      results = [];
    } else {
      var entries = await ActionEntryListService.getEntries();
      // The entry list is loaded asynchronously; the search field may be gone
      // by the time it arrives, and everything below needs a live context.
      if (!mounted) return;
      results = entries.where((actionEntry) {
        // If entry is openfolder: and show_folders is false, skip it
        if (actionEntry.action.startsWith("openfolder:") && !listFolders) {
          return false;
        }

        // If entry is package manager action and show_package_manager_actions is false, skip it
        if (listPackageManagerActions == false &&
            (actionEntry.action.contains("-install:") ||
                actionEntry.action.contains("-uninstall:"))) {
          return false;
        }

        // If regualar expression is used and matches return true
        if (regExp != null &&
            (regExp.hasMatch(actionEntry.name) ||
                regExp.hasMatch(actionEntry.description))) {
          return true;
        }
        // Otherwise check if all keys are contained in name or description
        for (String key in keys) {
          if (actionEntry.name.toLowerCase().contains(key) ||
              actionEntry.description.toLowerCase().contains(key) ||
              actionEntry.keywords.contains(key)) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    bool uriRecognized = false;

    if (Uri.parse(keyword).isAbsolute || keyword.contains("www.")) {
      uriRecognized = true;
    } else if (keyword.contains(".") && !keyword.endsWith(".")) {
      String keysplit = keyword.split(".").last.toUpperCase();
      for (String topLevelDomain in topLevelDomains) {
        if (topLevelDomain == keysplit) {
          uriRecognized = true;
          break;
        }
      }
    }

    if (uriRecognized) {
      ActionEntry actionEntry = ActionEntry(
        name: "${AppLocalizations.of(context)!.openX} $keyword",
        description: "Open with default webbrowser",
        action: "openwebsite:$keyword",
      );
      actionEntry.priority = 10;
      results.add(actionEntry);
    }

    if (Linux.isStringBashCommand(keyword)) {
      ActionEntry actionEntry = ActionEntry(
        name: keyword,
        description: AppLocalizations.of(context)!.executeInTerminal,
        action: "bash:$keyword",
        iconWidget: Icon(Icons.code, color: MintY.currentColor),
      );
      actionEntry.priority = -45;
      results.add(actionEntry);
    }

    if (keyword != "") {
      results.add(
        ActionEntry(
          name: "${AppLocalizations.of(context)!.searchInWebFor} $keyword",
          description: AppLocalizations.of(context)!.lookForOnlineResults,
          action: "websearch:$keyword",
        ),
      );
      results.last.priority = -50;
    }

    if (selectedIndex >= results.length) {
      selectedIndex = results.length - 1;
    } else if (results.isNotEmpty && selectedIndex == -1) {
      selectedIndex = 0;
      selectedIndexInView = 0;
    }

    // Sort:
    _foundEntries = results;
    _sortFoundEntries();
    _removeDuplicatedEntries();

    if (!mounted) {
      return;
    }
    setState(() {});
  }

  /// This runs fast but only removes direct neighbours.
  void _removeDuplicatedEntries() {
    for (int i = 0; i < _foundEntries.length - 1; i++) {
      if (_foundEntries[i].action.trim() ==
          _foundEntries[i + 1].action.trim()) {
        _foundEntries.removeAt(i);
      }
    }
  }

  /// This filter is only runs, if the user has stopped typing.
  void _runHeavyFilter(String keyword) async {
    if (keyword.trim() == "" || _lastKeyword == "") {
      return;
    }

    List<ActionEntry> heavyEntries = [];

    if (listPackageManagerActions) {
      // Search through apt
      if (Linux.currentenvironment.installedSoftwareManagers.contains(
        SOFTWARE_MANAGERS.APT,
      )) {
        List<ActionEntry> pckgs =
            await Linux.getInstallableAptPackagesForKeyword(context, keyword);
        heavyEntries.addAll(pckgs);
      }
      // Search through zypper
      else if (Linux.currentenvironment.installedSoftwareManagers.contains(
        SOFTWARE_MANAGERS.ZYPPER,
      )) {
        List<ActionEntry> pckgs =
            await Linux.getInstallableZypperPackagesForKeyword(keyword);
        heavyEntries.addAll(pckgs);
      }
      // Search through dnf
      else if (Linux.currentenvironment.installedSoftwareManagers.contains(
        SOFTWARE_MANAGERS.DNF,
      )) {
        List<ActionEntry> pckgs =
            await Linux.getInstallableDNFPackagesForKeyword(keyword);
        heavyEntries.addAll(pckgs);
      }

      if (Linux.currentenvironment.installedSoftwareManagers.contains(
        SOFTWARE_MANAGERS.SNAP,
      )) {
        List<ActionEntry> snaps =
            await Linux.getInstallableSnapPackagesForKeyword(keyword);
        heavyEntries.addAll(snaps);
      }

      if (Linux.currentenvironment.installedSoftwareManagers.contains(
        SOFTWARE_MANAGERS.FLATPAK,
      )) {
        List<ActionEntry> flatpaks =
            await Linux.getInstallableFlatpakPackagesForKeyword(keyword);
        heavyEntries.addAll(flatpaks);
      }

      if (Linux.currentenvironment.installedSoftwareManagers.contains(
        SOFTWARE_MANAGERS.PACMAN,
      )) {
        List<ActionEntry> pacmanEntries =
            await Linux.getInstallablePacmanPakagesForKeyword(keyword);
        heavyEntries.addAll(pacmanEntries);
      }
    }

    // If in the meantime the user cleared the search bar, we don't want to
    // show the results.
    if (keyword.trim() == "" || _lastKeyword == "") {
      return;
    }

    // The package manager queries above can take seconds on a cold cache, which
    // is more than enough time for the user to dismiss this screen.
    if (!mounted) {
      return;
    }

    setState(() {
      _foundEntries.addAll(heavyEntries);
      _sortFoundEntries();
    });
  }

  void _sortFoundEntries() {
    List<String> keys = _lastKeyword.toLowerCase().split(" ");

    for (ActionEntry result in _foundEntries) {
      result.tmpPriority = 0;
      for (String key in keys) {
        if (key.trim() == "") {
          continue;
        }
        if (result.name.toLowerCase().contains(key)) {
          result.tmpPriority += 10;
          if (result.name.toLowerCase().startsWith(key)) {
            result.tmpPriority += 20;
          }
        }
        if (result.description.toLowerCase().contains(_lastKeyword)) {
          result.tmpPriority += 5;
        }
      }
      if (_lastKeyword == result.name) {
        result.tmpPriority += 20;
      }
    }
    if (ConfigHandler().getValueUnsafe("self_learning_search", true)) {
      for (var element in _foundEntries) {
        String datesString = ConfigHandler().getValueUnsafe(
          "opened.${element.action}",
          "",
        );

        /// length of an date entry is 11: "1970-01-01;".length = 11
        int openTimes = (datesString.length / 11.0).round();
        element.tmpPriority += openTimes * 2;
      }
    }

    _foundEntries.sort((a, b) => (a.name).compareTo(b.name));

    _foundEntries.sort(
      (a, b) =>
          (b.priority + b.tmpPriority).compareTo(a.priority + a.tmpPriority),
    );
  }

  /// Moves the selection one entry down in the result list.
  ///
  /// The same logic the global hotkey handler had, now reached through the
  /// field's own shortcut instead of a window-wide key grab.
  void _selectNext() {
    if (!mounted || selectedIndex + 1 >= _foundEntries.length) {
      return;
    }
    setState(() {
      selectedIndex += 1;
      selectedIndexInView += 1;
      if (selectedIndexInView >= visibleEntries) {
        // The list is only there when there is something to select, but the
        // controller is not attached in the frame between the entries
        // appearing and the list being built.
        if (scrollController.hasClients) {
          scrollController.jumpTo(scrollController.offset + 72);
        }
        selectedIndexInView -= 1;
      }
    });
  }

  /// Moves the selection one entry up in the result list.
  void _selectPrevious() {
    if (!mounted || selectedIndex - 1 < 0) {
      return;
    }
    setState(() {
      selectedIndex -= 1;
      selectedIndexInView -= 1;
      if (selectedIndexInView < 0) {
        if (scrollController.hasClients) {
          scrollController.jumpTo(scrollController.offset - 72);
        }
        selectedIndexInView += 1;
      }
    });
  }

  /// Empties the search field.
  ///
  /// Escape keeps the window open — the user clears the search, they do not
  /// leave the app.
  void _clearSearchField() {
    clear(minimze: false);
  }

  /// The debug hook behind Ctrl+D.
  ///
  /// It does nothing on purpose: it is the place where the next debugging
  /// call goes, without the search screen having to be changed for it.
  void _debugShortcut() {
    // insert here function calls to debug
    // Linux.getInstalledFlatpaks();
    // Linux.getInstalledSnaps();
    // Linux.getInstalledAPTPackages();
  }

  void _handleSuggestions() async {
    var entries = await ActionEntryListService.getEntries();
    // If the main search window is present and the user has not typed anything
    if (_foundEntries.isEmpty && entries.isNotEmpty) {
      var proposals =
          entries.where((e) => !e.excludeFromSearchProposal).toList();
      if (proposals.isNotEmpty) {
        int random = Random().nextInt(proposals.length);
        if (mounted) {
          setState(() {
            suggestion = proposals[random];
          });
        }
      }
    }
  }
}

/// The key bindings of the search field.
///
/// The app used to register these through a global hotkey library, which
/// hooked the keys into the window itself: they fired even when the search
/// field did not have the focus, and they needed the native libkeybinder
/// library to be present. They are plain Flutter shortcuts now, and they sit
/// directly on the field — so they only fire while the field is focused, and
/// the arrow keys move the selection in the result list instead of the text
/// cursor.
///
/// The ordering matters: the framework maps the arrow keys to the text cursor
/// in `DefaultTextEditingShortcuts`, which sits at the top of the app. A
/// `Shortcuts` widget below it is asked first, so ours wins.
class SearchFieldShortcuts extends StatelessWidget {
  const SearchFieldShortcuts({
    super.key,
    required this.onSelectNext,
    required this.onSelectPrevious,
    required this.onClear,
    this.onDebugShortcut,
    required this.child,
  });

  /// Arrow down: the next entry in the result list.
  final VoidCallback onSelectNext;

  /// Arrow up: the previous entry in the result list.
  final VoidCallback onSelectPrevious;

  /// Escape: empty the search field.
  final VoidCallback onClear;

  /// Ctrl+D: the debug hook. It does nothing on purpose.
  final VoidCallback? onDebugShortcut;

  /// The search field itself.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        _SelectNextIntent: CallbackAction<_SelectNextIntent>(
          onInvoke: (_) {
            onSelectNext();
            return null;
          },
        ),
        _SelectPreviousIntent: CallbackAction<_SelectPreviousIntent>(
          onInvoke: (_) {
            onSelectPrevious();
            return null;
          },
        ),
        _ClearSearchIntent: CallbackAction<_ClearSearchIntent>(
          onInvoke: (_) {
            onClear();
            return null;
          },
        ),
        _DebugIntent: CallbackAction<_DebugIntent>(
          onInvoke: (_) {
            onDebugShortcut?.call();
            return null;
          },
        ),
      },
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.arrowDown):
              const _SelectNextIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowUp):
              const _SelectPreviousIntent(),
          const SingleActivator(LogicalKeyboardKey.escape):
              const _ClearSearchIntent(),
          const SingleActivator(LogicalKeyboardKey.keyD, control: true):
              const _DebugIntent(),
        },
        child: child,
      ),
    );
  }
}

/// Intents of the search field's own shortcuts.
///
/// Own types on purpose: the framework's text editing intents map the arrow
/// keys to the cursor movement, and a shortcut of ours has to win over them.
/// That only works if it does not reuse their intents.
class _SelectNextIntent extends Intent {
  const _SelectNextIntent();
}

/// Arrow up in the result list.
class _SelectPreviousIntent extends Intent {
  const _SelectPreviousIntent();
}

/// Escape: empty the search field.
class _ClearSearchIntent extends Intent {
  const _ClearSearchIntent();
}

/// Ctrl+D: the debug hook.
class _DebugIntent extends Intent {
  const _DebugIntent();
}

class FeedbackButton extends StatelessWidget {
  const FeedbackButton({
    super.key,
    required this.widget,
    required List<ActionEntry> foundEntries,
    required String lastKeyword,
  })  : _foundEntries = foundEntries,
        _lastKeyword = lastKeyword;

  final MainSearch widget;
  final List<ActionEntry> _foundEntries;
  final String _lastKeyword;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 24,
      splashRadius: 24,
      icon: Icon(
        Icons.feedback,
        color: widget.colorfulBackground
            ? Colors.white
            : Theme.of(context).textTheme.displayLarge!.color,
      ),
      onPressed: () => showDialog(
        context: context,
        builder: (context) => FeedbackDialog(
          calledFromHome: true,
          foundEntries: _foundEntries,
          searchText: _lastKeyword,
        ),
      ),
      padding: EdgeInsets.zero,
      tooltip: AppLocalizations.of(context)!.sendFeedback,
    );
  }
}

class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.widget});

  final MainSearch widget;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 24,
      splashRadius: 24,
      icon: Icon(
        Icons.help,
        color: widget.colorfulBackground
            ? Colors.white
            : Theme.of(context).textTheme.displayLarge!.color,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const GreeterIntroduction(forceOpen: true),
          ),
        );
      },
      padding: EdgeInsets.zero,
      tooltip: AppLocalizations.of(context)!.introduction,
    );
  }
}

class ReloadSearchButton extends StatelessWidget {
  const ReloadSearchButton({super.key, required this.widget});

  final MainSearch widget;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 24,
      splashRadius: 24,
      icon: Icon(
        Icons.autorenew,
        color: widget.colorfulBackground
            ? Colors.white
            : Theme.of(context).textTheme.displayLarge!.color,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MainSearchLoader()),
        );
      },
      padding: EdgeInsets.zero,
      tooltip: AppLocalizations.of(context)!.reload,
    );
  }
}
