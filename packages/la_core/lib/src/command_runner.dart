/// Outcome of a runner call. Signature is byte-identical to the copy in
/// `lib/helpers/command_helper.dart` — the app starts importing this one
/// instead, so the two must not drift.
class CommandResult {
  final String error;
  final String output;
  final bool success;

  /// The process' exit code, or -1 if it could not be started.
  final int exitCode;

  const CommandResult(
    this.success,
    this.output,
    this.error, [
    this.exitCode = 0,
  ]);
}

/// The one seam through which the core starts a process (#93).
///
/// `la_core` never touches `dart:io` itself; it asks an injected runner. The
/// app provides the Flatpak/pkexec-aware implementation, tests provide a fake.
abstract interface class CommandRunner {
  Future<CommandResult> run(
    String command,
    List<String> arguments, {
    Map<String, String>? environment,
    bool asRoot = false,
    bool hostOnFlatpak = true,
    bool runInShell = false,
  });
}

/// Signals a failed run when the caller wants an exception instead of a
/// [CommandResult] with `success == false`.
class CommandException implements Exception {
  CommandException(this.message, {this.exitCode, this.stderr});

  final String message;
  final int? exitCode;
  final String? stderr;

  @override
  String toString() => 'CommandException: $message';
}
