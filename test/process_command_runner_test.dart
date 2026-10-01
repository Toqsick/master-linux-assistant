import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linux_assistant/helpers/command_helper.dart';

/// Real process-spawn proof for [ProcessCommandRunner].
///
/// The runner resolves its prefixes (`pkexec`, `flatpak-spawn`) as *bare
/// names* over PATH, so the tests inject fake executables through the
/// `environment` argument: a temp directory with two POSIX shell scripts that
/// dump their argv, one argument per line. The inner "command" (e.g.
/// `/usr/bin/example-cmd`) is never executed — it is only an argument of the
/// fake. Everything runs unprivileged; no real pkexec or flatpak-spawn is
/// ever started.
///
/// No fake async around these `Process.run` calls — real dart:io streams
/// stall under fake async, so these tests await the futures directly.
void main() {
  late Directory tempDir;
  late String fakeBinDir;

  const String fakeScriptTemplate = r'''
#!/bin/sh
# Fake pkexec / flatpak-spawn: dumps its argv, one argument per line, into
# $MLA95_ARGV_DUMP. The "command" this fake receives is data, not code.
for arg in "$@"; do
  printf '%s\n' "$arg"
done > "$MLA95_ARGV_DUMP"

# Second mode for the exit-code/stdout/stderr mapping test.
if [ "$MLA95_FAKE_MODE" = "fail" ]; then
  echo "out-line"
  echo "err-line" >&2
  exit 3
fi

echo "READY_MARKER"
exit 0
''';

  String argvDumpPath(String fakeName) => "${tempDir.path}/argv-$fakeName.txt";

  void writeFake(String path, String readyMarker) {
    final File file = File(path);
    file.writeAsStringSync(
        fakeScriptTemplate.replaceFirst("READY_MARKER", readyMarker));
    // dart:io has no chmod, so go through the real tool. The stat check turns
    // a silently failed chmod into an immediate diagnosis instead of a
    // confusing "permission denied" inside the runner.
    final ProcessResult chmod = Process.runSync("chmod", ["755", path]);
    const int executableBits = 73; // 0o111 — Dart has no octal literals.
    final int mode = file.statSync().mode;
    if (chmod.exitCode != 0 || (mode & executableBits) != executableBits) {
      throw StateError("making $path executable failed (chmod exit "
          "${chmod.exitCode}, mode $mode)");
    }
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("mla_proc_runner_");
    fakeBinDir = "${tempDir.path}/bin";
    Directory(fakeBinDir).createSync();
    writeFake("$fakeBinDir/pkexec", "fake-pkexec-ran");
    writeFake("$fakeBinDir/flatpak-spawn", "fake-flatpak-spawn-ran");
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group("ProcessCommandRunner", () {
    test("asRoot prefixes pkexec and resolves it over the injected PATH",
        () async {
      final ProcessCommandRunner runner = ProcessCommandRunner();

      final CommandResult result = await runner.run(
        "/usr/bin/example-cmd",
        ["--flag", "value"],
        asRoot: true,
        environment: {
          "PATH": fakeBinDir,
          "MLA95_ARGV_DUMP": argvDumpPath("pkexec"),
        },
      );

      expect(result.success, isTrue);
      expect(result.output, contains("fake-pkexec-ran"));
      expect(File(argvDumpPath("pkexec")).readAsLinesSync(),
          ["/usr/bin/example-cmd", "--flag", "value"]);
    });

    test("flatpak sandbox routes through flatpak-spawn --host", () async {
      final ProcessCommandRunner runner = ProcessCommandRunner();
      runner.runningInFlatpak = true;

      final CommandResult result = await runner.run(
        "/usr/bin/example-cmd",
        ["--flag", "value"],
        hostOnFlatpak: true,
        environment: {
          "PATH": fakeBinDir,
          "MLA95_ARGV_DUMP": argvDumpPath("flatpak-spawn"),
        },
      );

      expect(result.success, isTrue);
      expect(result.output, contains("fake-flatpak-spawn-ran"));
      expect(File(argvDumpPath("flatpak-spawn")).readAsLinesSync(),
          ["--host", "/usr/bin/example-cmd", "--flag", "value"]);
    });

    test("flatpak without hostOnFlatpak drops the --host flag", () async {
      final ProcessCommandRunner runner = ProcessCommandRunner();
      runner.runningInFlatpak = true;

      final CommandResult result = await runner.run(
        "/usr/bin/example-cmd",
        ["--flag", "value"],
        hostOnFlatpak: false,
        environment: {
          "PATH": fakeBinDir,
          "MLA95_ARGV_DUMP": argvDumpPath("flatpak-spawn"),
        },
      );

      expect(result.success, isTrue);
      expect(File(argvDumpPath("flatpak-spawn")).readAsLinesSync(),
          ["/usr/bin/example-cmd", "--flag", "value"]);
    });

    test("combination builds flatpak-spawn --host pkexec <cmd> <args>",
        () async {
      final ProcessCommandRunner runner = ProcessCommandRunner();
      runner.runningInFlatpak = true;

      final CommandResult result = await runner.run(
        "/usr/bin/example-cmd",
        ["--flag", "value"],
        asRoot: true,
        hostOnFlatpak: true,
        environment: {
          "PATH": fakeBinDir,
          "MLA95_ARGV_DUMP": argvDumpPath("flatpak-spawn"),
        },
      );

      expect(result.success, isTrue);
      // Only the argv construction is under test here — the fake pkexec must
      // not have run on top of the fake flatpak-spawn.
      expect(File(argvDumpPath("flatpak-spawn")).readAsLinesSync(),
          ["--host", "pkexec", "/usr/bin/example-cmd", "--flag", "value"]);
      expect(File(argvDumpPath("pkexec")).existsSync(), isFalse);
    });

    test("maps exit code, stdout and stderr of the spawned process", () async {
      final ProcessCommandRunner runner = ProcessCommandRunner();

      final CommandResult result = await runner.run(
        "/usr/bin/example-cmd",
        ["--flag", "value"],
        asRoot: true,
        environment: {
          "PATH": fakeBinDir,
          "MLA95_ARGV_DUMP": argvDumpPath("pkexec"),
          "MLA95_FAKE_MODE": "fail",
        },
      );

      expect(result.success, isFalse);
      expect(result.exitCode, 3);
      expect(result.output, contains("out-line"));
      expect(result.error, contains("err-line"));
      // The fail mode must not have changed the argv that reached the fake.
      expect(File(argvDumpPath("pkexec")).readAsLinesSync(),
          ["/usr/bin/example-cmd", "--flag", "value"]);
    });

    test("reports a missing binary as failure instead of throwing", () async {
      final Directory emptyDir = Directory("${tempDir.path}/empty");
      emptyDir.createSync();
      final ProcessCommandRunner runner = ProcessCommandRunner();

      // A bare pkexec over an empty PATH cannot start — the await returning a
      // result at all is the "no exception escapes" part of the pin.
      final CommandResult result = await runner.run(
        "/usr/bin/example-cmd",
        const [],
        asRoot: true,
        environment: {"PATH": emptyDir.path},
      );

      expect(result.success, isFalse);
      expect(result.exitCode, -1);
      // The full error contract of the ProcessException path: no stdout was
      // ever produced, and the message is the OS lookup failure (measured on
      // this toolchain: "No such file or directory"), not a generic blob.
      expect(result.output, isEmpty);
      expect(result.error, contains("No such file or directory"));
    });

    test(
        "documentation: the passed PATH decides where the naked pkexec "
        "prefix is resolved", () async {
      // Mirrors what CommandHelper.succeeds does on top of a caller env
      // ({"LC_ALL": "C", ...?env}): an environment is passed AND the runner
      // still prefixes a *bare* binary name. The PATH that resolves that
      // prefix is the one from the passed environment — a caller whose PATH
      // does not contain the prefix dirs breaks pkexec/flatpak-spawn.
      //
      // Measured Dart semantics (pinned on purpose, no production fix in this
      // package — a real gap would need its own issue): Process.run defaults
      // to includeParentEnvironment: true, so the child environment is the
      // parent's environment with the passed keys overriding. A passed
      // environment *without* a PATH key therefore still resolves the naked
      // prefix over the parent PATH — "just pass an env without PATH" is NOT
      // a guard. An explicitly passed PATH always wins.
      final Directory emptyDir = Directory("${tempDir.path}/empty");
      emptyDir.createSync();
      final ProcessCommandRunner runner = ProcessCommandRunner();

      final CommandResult result = await runner.run(
        "/usr/bin/example-cmd",
        const [],
        asRoot: true,
        environment: {"LC_ALL": "C", "PATH": emptyDir.path},
      );

      expect(result.success, isFalse);
      expect(result.exitCode, -1);
      expect(result.error, isNotEmpty);
    });

    test(
        "documentation: an environment without PATH still sees the parent "
        "PATH (includeParentEnvironment default)", () async {
      // The counterpart of the test above, measured against real behavior:
      // because Process.run merges the parent environment back in unless
      // includeParentEnvironment is set to false (the runner does not), a
      // passed {"LC_ALL": "C"} leaves the child PATH untouched and the naked
      // prefix still resolves. Real /bin/sh — unprivileged, echo only.
      final ProcessCommandRunner runner = ProcessCommandRunner();

      // Exact prefix chain instead of a bare startsWith("PATH=/"): the child
      // sees the parent's PATH verbatim (not merely "some absolute path"),
      // so echo it once and pin the full line.
      final String parentPath = Platform.environment["PATH"]!;
      final CommandResult result = await runner.run(
        "sh",
        [r"-c", r"echo PATH=$PATH"],
        environment: {"LC_ALL": "C"},
      );

      expect(result.success, isTrue);
      expect(result.output.trim(), "PATH=$parentPath");
    });
  });
}
