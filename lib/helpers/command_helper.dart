import 'dart:io';

import 'package:la_core/la_core.dart' as core;

// `export` does not import into the declaring library (Falle 2): callers still
// get `CommandResult`/`CommandRunner` from *this* file, so both are imported
// above for use here and re-exported below for them.
export 'package:la_core/la_core.dart' show CommandResult, CommandRunner;

/// The process-backed [core.CommandRunner] — the app's one place that starts a
/// process.
///
/// The Flatpak indirection, the pkexec prefix, the environment handling and
/// the exit code all live in a single implementation instead of two that had
/// drifted apart.
///
/// `runningInFlatpak` is an instance field now: [CommandHelper.processRunner]
/// is the instance `Linux.init()` flips.
class ProcessCommandRunner implements core.CommandRunner {
  /// Set by `Linux.init()` when the app itself runs inside a Flatpak sandbox.
  ///
  /// Commands then have to be handed to the host through `flatpak-spawn`.
  bool runningInFlatpak = false;

  @override
  Future<core.CommandResult> run(
    String command,
    List<String> arguments, {
    Map<String, String>? environment,
    bool asRoot = false,
    bool hostOnFlatpak = true,
    bool runInShell = false,
  }) async {
    // A copy. Both this method and its counterpart in Linux used to insert
    // their prefixes into the list the caller passed in, so calling either one
    // twice with the same list produced "pkexec pkexec …".
    final List<String> argv = [command, ...arguments];

    if (asRoot) {
      argv.insert(0, "pkexec");
    }
    if (runningInFlatpak) {
      // Without --host the command stays inside the sandbox, which is what a
      // few callers want.
      argv.insertAll(
          0, hostOnFlatpak ? ["flatpak-spawn", "--host"] : ["flatpak-spawn"]);
    }

    try {
      final ProcessResult result = await Process.run(
        argv.first,
        argv.sublist(1),
        environment: environment,
        runInShell: runInShell,
      );
      return core.CommandResult(
        result.exitCode == 0,
        result.stdout.toString(),
        result.stderr.toString(),
        result.exitCode,
      );
    } on ProcessException catch (e) {
      // A missing executable is a normal answer here — "is zypper installed"
      // is asked by trying to run it — so it is reported, not thrown.
      return core.CommandResult(false, "", e.message, -1);
    }
  }
}

/// The app-side facade over a [core.CommandRunner].
///
/// [Linux.runCommandWithCustomArguments] delegates here, and the static call
/// surface ([run], [runWithArguments], [succeeds]) is kept so the many call
/// sites stay untouched. Every call is delegated to [runner] instead of being
/// executed here, so a test can swap in a fake.
abstract class CommandHelper {
  /// The process-backed implementation the app uses by default.
  static final ProcessCommandRunner processRunner = ProcessCommandRunner();

  /// The injection seam. Defaults to [processRunner]; tests replace it.
  static core.CommandRunner runner = processRunner;

  static Future<core.CommandResult> run(String cmd,
      {Map<String, String>? env,
      bool asRoot = false,
      bool hostOnFlatpak = true,
      bool runInShell = false}) async {
    // Delegated through the instance on purpose: an unqualified call to
    // `runWithArguments` in here would bind to this class's own static method
    // and recurse (Falle 1).
    return await runner.run(cmd, const [],
        environment: env,
        asRoot: asRoot,
        hostOnFlatpak: hostOnFlatpak,
        runInShell: runInShell);
  }

  static Future<core.CommandResult> runWithArguments(
      String cmd, List<String> args,
      {Map<String, String>? env,
      bool asRoot = false,
      bool hostOnFlatpak = true,
      bool runInShell = false}) async {
    return await runner.run(cmd, args,
        environment: env,
        asRoot: asRoot,
        hostOnFlatpak: hostOnFlatpak,
        runInShell: runInShell);
  }

  /// Convenience for the many checks that only ask "did this succeed".
  ///
  /// Runs with `LC_ALL=C` so the caller can rely on the exit code without
  /// worrying about the user's locale.
  static Future<bool> succeeds(String cmd, List<String> args,
      {Map<String, String>? env}) async {
    final core.CommandResult result = await runner.run(
      cmd,
      args,
      environment: {"LC_ALL": "C", ...?env},
    );
    return result.success;
  }
}
