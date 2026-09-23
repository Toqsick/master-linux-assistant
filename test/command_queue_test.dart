// The queue is the app's root path: whatever ends up in it is executed with
// full privileges. These tests cover the serialization the Python runner reads
// (additional/python/tests/test_command_queue.py covers the other side).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linux_assistant/models/linux_command.dart';
import 'package:linux_assistant/services/linux.dart';

/// A snapshot directory name of this shape is enough to own the machine when
/// the queue is a shell command line. Timeshift snapshot names come off a
/// mounted disk, so they are not the app's to trust.
const String hostile = 'foo"; touch /tmp/pwned; #';

Map<String, dynamic> decodeSingle(String serialized) {
  final List<String> lines = const LineSplitter().convert(serialized);
  expect(lines, hasLength(1));
  return jsonDecode(lines.single) as Map<String, dynamic>;
}

void main() {
  group("serialization", () {
    test("one JSON object per command", () {
      final String serialized = Linux.serializeCommandQueue([
        LinuxCommand(userId: 0, argv: const ["/usr/bin/apt", "update"]),
        LinuxCommand(userId: 1000, argv: const ["/usr/bin/flatpak", "update"]),
      ]);

      final List<String> lines = const LineSplitter().convert(serialized);
      expect(lines, hasLength(2));
      expect(jsonDecode(lines.first)["uid"], 0);
      expect(jsonDecode(lines.last)["uid"], 1000);
    });

    test("an argument keeps its exact value, whatever is in it", () {
      final Map<String, dynamic> command = decodeSingle(
        Linux.serializeCommandQueue([
          LinuxCommand(
            userId: 0,
            argv: ["timeshift", "--delete", "--snapshot", hostile],
          ),
        ]),
      );

      expect(command["argv"], ["timeshift", "--delete", "--snapshot", hostile]);
      expect(command["shell"], isFalse);
    });

    test("values containing quotes, semicolons and equals signs survive", () {
      // The previous format was `"uid";"cmd";"KEY='value'";`, split on `";"`
      // and on `=`. Each of these broke it.
      for (final String nasty in [
        'has"quote',
        "has;semicolon",
        "has=equals",
        "has'single'quote",
        "has\ttab and spaces",
        "hät ümläute",
      ]) {
        final Map<String, dynamic> command = decodeSingle(
          Linux.serializeCommandQueue([
            LinuxCommand(
              userId: 0,
              argv: ["/bin/echo", nasty],
              environment: {"MARKER": nasty},
            ),
          ]),
        );

        expect(command["argv"], ["/bin/echo", nasty], reason: nasty);
        expect(command["env"], {"MARKER": nasty}, reason: nasty);
      }
    });

    test("a newline in an argument cannot forge a second command", () {
      final String serialized = Linux.serializeCommandQueue([
        LinuxCommand(
          userId: 1000,
          argv: ['{"uid": 0, "argv": ["/bin/sh"]}\n', "second"],
        ),
      ]);

      expect(const LineSplitter().convert(serialized), hasLength(1),
          reason: "JSON escapes the newline, so it stays inside the argument");
      expect(decodeSingle(serialized)["uid"], 1000);
    });

    test("the shell flag is carried explicitly", () {
      final Map<String, dynamic> command = decodeSingle(
        Linux.serializeCommandQueue([
          LinuxCommand(
            userId: 0,
            useShell: true,
            argv: const ['printf "%s" "\$1"', "value"],
          ),
        ]),
      );

      expect(command["shell"], isTrue);
      expect(command["argv"], ['printf "%s" "\$1"', "value"]);
    });

    test("an empty environment is an empty object, not null", () {
      expect(
        decodeSingle(Linux.serializeCommandQueue([
          LinuxCommand(userId: 0, argv: const ["/bin/true"])
        ]))["env"],
        isEmpty,
      );
    });
  });

  group("display", () {
    test("plain arguments are shown unquoted", () {
      expect(
        LinuxCommand(userId: 0, argv: const ["/usr/bin/apt", "install", "vlc"])
            .displayCommand,
        "/usr/bin/apt install vlc",
      );
    });

    test("an argument that needs quoting gets it", () {
      expect(
        LinuxCommand(userId: 0, argv: ["timeshift", "--snapshot", hostile])
            .displayCommand,
        contains("'foo\"; touch /tmp/pwned; #'"),
      );
    });

    test("a single quote inside an argument is escaped", () {
      expect(
        LinuxCommand(userId: 0, argv: const ["echo", "it's"]).displayCommand,
        r"echo 'it'\''s'",
      );
    });

    test("a shell command says so", () {
      expect(
        LinuxCommand(userId: 0, useShell: true, argv: const ["a | b", "arg"])
            .displayCommand,
        startsWith("bash -c "),
      );
    });

    test("the environment is shown in front of the command", () {
      expect(
        LinuxCommand(
          userId: 0,
          argv: const ["/usr/bin/apt", "upgrade"],
          environment: {"DEBIAN_FRONTEND": "noninteractive"},
        ).displayCommand,
        "env DEBIAN_FRONTEND=noninteractive /usr/bin/apt upgrade",
      );
    });

    test("a hostile environment value is quoted like an argument", () {
      final String shown = LinuxCommand(
        userId: 0,
        argv: const ["/bin/true"],
        environment: {"MARKER": hostile},
      ).displayCommand;

      expect(shown, startsWith("env "));
      expect(shown, contains("'MARKER="),
          reason: "the KEY=VALUE token needed quoting");
    });

    test("a shell command with an environment shows both", () {
      final String shown = LinuxCommand(
        userId: 0,
        useShell: true,
        argv: const ["a | b"],
        environment: {"PATH": "/usr/bin"},
      ).displayCommand;

      expect(shown, "env PATH=/usr/bin bash -c 'a | b'");
    });
  });

  test("a command without an executable is rejected", () {
    expect(() => LinuxCommand(userId: 0, argv: const []), throwsA(anything));
  });

  // argv keeps a value out of the shell, but a sed script is a second parser.
  group("sed escaping", () {
    test("a slash in a replacement cannot end the expression", () {
      expect(Linux.sedEscapeReplacement("/boot/grub"), r"\/boot\/grub");
    });

    test("an ampersand does not become the whole match", () {
      expect(Linux.sedEscapeReplacement("a&b"), r"a\&b");
    });

    test("a backslash is escaped before anything else", () {
      expect(Linux.sedEscapeReplacement(r"a\b"), r"a\\b");
    });

    test("pattern metacharacters lose their meaning", () {
      expect(Linux.sedEscapePattern("GRUB.TIMEOUT"), r"GRUB\.TIMEOUT");
      expect(Linux.sedEscapePattern("a/b"), r"a\/b");
      expect(Linux.sedEscapePattern("a[b]"), r"a\[b\]");
    });

    test("an ordinary key is left alone", () {
      expect(Linux.sedEscapePattern("GRUB_TIMEOUT"), "GRUB_TIMEOUT");
      expect(Linux.sedEscapeReplacement("hidden"), "hidden");
    });
  });
}
