import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg_provider/flutter_svg_provider.dart';
import 'package:linux_assistant/layouts/mint_y.dart';
import 'package:linux_assistant/services/linux.dart';
import 'package:linux_assistant/services/logger.dart';

class IconLoader {
  // handle IconLoader as a singleton
  static final IconLoader _instance = IconLoader._privateConstructor();
  factory IconLoader() {
    return _instance;
  }
  IconLoader._privateConstructor();

  Map<String, Widget> cache = {};

  /// If you pass an appCode, it will just return the appCode back
  static getFileEndingFromPossiblePath(String path) {
    if (path.contains("/")) {
      path = path.split("/").last;
    }
    if (path.contains(".")) {
      return path.split(".").last;
    }
    // If the path has no file ending, return the path which is then possible an appCode
    return path;
  }

  /// If you need a icon for a file just insert the file path as appCode
  /// Also handles the special keyword "folder" for folders
  Future<Widget> getIconForAppOrFile(String appCode,
      {double iconSize = 48}) async {
    /// If the appCode is a path, use the last part of the path as appCode
    String filePath = "";
    if (appCode.contains("/")) {
      filePath = appCode;
      appCode = appCode.split(".").last;
    }

    String cacheKeyword = "$appCode-$iconSize";
    if (cache.containsKey(cacheKeyword)) {
      return cache[cacheKeyword]!;
    }
    String iconPath = "not found";

    // The path goes into the argv as data: no quoting around it, and no
    // shell in between. The two belong together — the quotes existed only
    // to survive the shell, and the Python helper had to strip them again.
    //
    // The shell was never a split risk (Dart quotes every argv element, so
    // a path with a space stays one argument); it was an unnecessary
    // intermediary, and `runInShell: false` is the pattern the rest of this
    // file uses. What the quotes did cost: the helper had to rewrite the
    // value it was given, which breaks a path that legitimately ends in a
    // quote character. The helper now passes the value through unchanged,
    // so both sides agree on the format.

    /// Load icon for folder
    if (appCode == "folder") {
      iconPath = await Linux.runCommandWithCustomArguments(
          "/usr/bin/python3",
          [
            "${Linux.pythonScriptsFolder}/get_icon_path_for_file.py",
            "--file=/tmp/",
          ],
          runInShell: false);

      /// Load icon for app
    } else if (appCode != "" && filePath == "") {
      iconPath = await Linux.runCommandWithCustomArguments(
          "/usr/bin/python3",
          [
            "${Linux.pythonScriptsFolder}/get_icon_path_for_application.py",
            "--icon=$appCode",
            "--path-to-alternative-logos=${Linux.additionalFolder}logos/"
          ],
          runInShell: false);

      /// Load icon for file type
    } else if (filePath != "") {
      iconPath = await Linux.runCommandWithCustomArguments(
          "/usr/bin/python3",
          [
            "${Linux.pythonScriptsFolder}/get_icon_path_for_file.py",
            "--file=$filePath",
          ],
          runInShell: false);
    }

    iconPath = iconPath.trim();

    // Load default icon
    if (iconPath.contains("not found")) {
      if (cache.containsKey("!default!-$iconSize")) {
        cache[cacheKeyword] = cache['!default!-$iconSize']!;
      } else {
        Icon icon = Icon(
          Icons.settings,
          size: iconSize,
          color: MintY.currentColor,
        );

        cache['!default!-$iconSize'] = icon;
        cache[cacheKeyword] = icon;
      }
      return cache[cacheKeyword]!;
    }
    File file = File(iconPath);
    if (iconPath.contains(".svg")) {
      Image image = Image(
          width: iconSize,
          height: iconSize,
          image: Svg(iconPath),
          errorBuilder: (context, error, stackTrace) {
            logError("Failed to load $iconPath", error);
            return Icon(
              Icons.settings,
              size: iconSize,
              color: MintY.currentColor,
            );
          });
      cache[cacheKeyword] = image;
      return image;
    } else {
      Image image = Image.file(
        file,
        height: iconSize,
        width: iconSize,
      );
      cache[cacheKeyword] = image;
      return image;
    }
  }

  /// You could also pass a file path to this function
  bool isIconLoaded(appCode, {double iconSize = 48}) {
    appCode = getFileEndingFromPossiblePath(appCode);
    String cacheKey = "$appCode-$iconSize";
    return (cache.containsKey(cacheKey));
  }

  /// You could also pass a file path to this function
  Widget getIconFromCache(appCode, {double iconSize = 48}) {
    appCode = getFileEndingFromPossiblePath(appCode);
    String cacheKey = "$appCode-$iconSize";
    return cache[cacheKey]!;
  }
}
