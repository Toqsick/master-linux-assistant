"""Tests for the root command runner.

The point of these is one property: a value that reaches the queue from
outside the app — a Timeshift snapshot name read off a mounted disk, a
mountpoint, a package name from a search result — must never be able to become
a command. Before argv, all of them were spliced into a string that the root
helper handed to `bash -c`.
"""

import io
import json
import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import command_queue  # noqa: E402


HOSTILE = 'foo"; touch {}; #'


class BuildArgv(unittest.TestCase):
    def test_without_a_shell_the_vector_is_passed_through(self):
        argv = ["/usr/bin/timeshift", "--delete", "--snapshot", HOSTILE]
        self.assertEqual(command_queue.build_argv(argv, False), argv)

    def test_with_a_shell_values_become_positional_parameters(self):
        built = command_queue.build_argv(
            ['printf "%s" "$1" >> "$2"', "KEY=value", "/etc/default/grub"], True
        )
        self.assertEqual(
            built,
            [
                "/bin/bash",
                "-c",
                'printf "%s" "$1" >> "$2"',
                "linux-assistant",
                "KEY=value",
                "/etc/default/grub",
            ],
        )

    def test_the_script_is_never_built_from_the_values(self):
        built = command_queue.build_argv(["echo \"$1\"", HOSTILE], True)
        self.assertNotIn(HOSTILE, built[2], "the value leaked into the script")
        self.assertIn(HOSTILE, built[4:])


class BuildEnvironment(unittest.TestCase):
    """The env the runner hands to a command (WP-S2: strip linker env for root).

    The runner executes as root via pkexec, so a command running as uid 0 is
    the case where `ld.so` still honours LD_PRELOAD and friends (uid == euid):
    a hostile environment must not survive into the child.
    """

    def setUp(self):
        # build_environment() merges over the real os.environ — inject a
        # hostile inherited value so the filter is exercised on both halves
        # of the merge, not just the queue-supplied one.
        os.environ["LD_LIBRARY_PATH"] = "/tmp/injected.so"
        self.addCleanup(os.environ.pop, "LD_LIBRARY_PATH", None)

    def test_root_commands_drop_linker_and_shell_env_keys(self):
        env = command_queue.build_environment(
            {
                "LD_PRELOAD": "/tmp/evil.so",
                "BASH_ENV": "/tmp/evil.bash",
                "ENV": "/tmp/evil.sh",
                "IFS": "x",
            },
            uid=0,
        )
        for key in ("LD_PRELOAD", "LD_LIBRARY_PATH", "BASH_ENV", "ENV", "IFS"):
            self.assertNotIn(key, env, key)

    def test_root_commands_keep_ordinary_variables(self):
        env = command_queue.build_environment(
            {"DEBIAN_FRONTEND": "noninteractive", "LC_ALL": "C"}, uid=0
        )
        self.assertEqual(env["DEBIAN_FRONTEND"], "noninteractive")
        self.assertEqual(env["LC_ALL"], "C")
        self.assertIn("PATH", env, "PATH was not inherited")
        self.assertIn("HOME", env, "HOME was not inherited")

    def test_non_root_commands_inherit_everything(self):
        # ld.so ignores LD_* when the command's uid differs from the runner's
        # euid, so the filter deliberately only applies to uid 0.
        env = command_queue.build_environment(
            {"LD_PRELOAD": "/tmp/evil.so"}, uid=1000
        )
        self.assertEqual(env["LD_PRELOAD"], "/tmp/evil.so")
        self.assertEqual(env["LD_LIBRARY_PATH"], "/tmp/injected.so")

    def test_without_a_uid_the_merge_stays_unfiltered(self):
        env = command_queue.build_environment({"LA_TEST_MARKER": "set"})
        self.assertEqual(env["LA_TEST_MARKER"], "set")
        self.assertEqual(env["LD_LIBRARY_PATH"], "/tmp/injected.so")


class ParseCommand(unittest.TestCase):
    def valid(self, **overrides):
        entry = {"uid": 0, "argv": ["/bin/true"], "env": {}, "shell": False}
        entry.update(overrides)
        return entry

    def test_a_well_formed_entry_round_trips(self):
        uid, argv, env, shell = command_queue.parse_command(
            self.valid(uid=1000, env={"PATH": "/usr/bin"}), 1
        )
        self.assertEqual((uid, argv, env, shell), (1000, ["/bin/true"], {"PATH": "/usr/bin"}, False))

    def test_env_and_shell_default(self):
        uid, argv, env, shell = command_queue.parse_command({"argv": ["/bin/true"]}, 1)
        self.assertEqual((uid, env, shell), (0, {}, False))

    def test_rejects_a_missing_or_empty_argv(self):
        for bad in [{}, self.valid(argv=[]), self.valid(argv="apt install vlc")]:
            with self.assertRaises(command_queue.QueueFormatError):
                command_queue.parse_command(bad, 1)

    def test_rejects_a_non_string_in_argv(self):
        with self.assertRaises(command_queue.QueueFormatError):
            command_queue.parse_command(self.valid(argv=["/bin/true", 7]), 1)

    def test_rejects_a_bad_uid(self):
        for bad in ["0", -1, True, None]:
            with self.assertRaises(command_queue.QueueFormatError):
                command_queue.parse_command(self.valid(uid=bad), 1)

    def test_rejects_a_malformed_env(self):
        for bad in ["PATH=/usr/bin", {"PATH": 1}, {1: "x"}]:
            with self.assertRaises(command_queue.QueueFormatError):
                command_queue.parse_command(self.valid(env=bad), 1)

    def test_rejects_a_non_boolean_shell_flag(self):
        with self.assertRaises(command_queue.QueueFormatError):
            command_queue.parse_command(self.valid(shell="true"), 1)

    def test_rejects_a_bare_executable_name(self):
        # The runner resolves argv[0] through PATH as root before dropping
        # privileges — a bare name is a PATH hijack, not a convenience.
        with self.assertRaises(command_queue.QueueFormatError):
            command_queue.parse_command(self.valid(argv=["rm", "/etc/fstab"]), 1)

    def test_rejects_a_relative_executable_path(self):
        with self.assertRaises(command_queue.QueueFormatError):
            command_queue.parse_command(self.valid(argv=["bin/rm", "x"]), 1)

    def test_shell_entries_are_exempt_their_argv0_is_a_script(self):
        uid, argv, env, shell = command_queue.parse_command(
            self.valid(argv=["echo $1", "value"], shell=True), 1
        )
        self.assertEqual((uid, shell), (0, True))


class Execution(unittest.TestCase):
    """Actually runs commands, as the current user."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="la-queue-test")
        self.uid = os.getuid()

    def run_entry(self, entry):
        uid, argv, env, shell = command_queue.parse_command(entry, 1)
        out = io.StringIO()
        code = command_queue.run_command(uid, argv, env, shell, stream=out)
        return code, out.getvalue()

    def test_a_hostile_argument_stays_an_argument(self):
        marker = os.path.join(self.tmp, "pwned")
        code, output = self.run_entry(
            {
                "uid": self.uid,
                "argv": ["/bin/echo", HOSTILE.format(marker)],
            }
        )

        self.assertEqual(code, 0)
        self.assertFalse(
            os.path.exists(marker),
            "the argument was interpreted as a command — this is the bug argv removes",
        )
        self.assertIn(HOSTILE.format(marker), output)

    def test_a_hostile_argument_in_a_shell_command_stays_data(self):
        marker = os.path.join(self.tmp, "pwned-shell")
        code, output = self.run_entry(
            {
                "uid": self.uid,
                "argv": ['printf "%s" "$1"', HOSTILE.format(marker)],
                "shell": True,
            }
        )

        self.assertEqual(code, 0)
        self.assertFalse(os.path.exists(marker))
        self.assertIn(HOSTILE.format(marker), output)

    def test_a_failing_command_reports_its_exit_code(self):
        code, _ = self.run_entry({"uid": self.uid, "argv": ["/bin/false"]})
        self.assertNotEqual(code, 0)

    def test_stderr_is_captured_too(self):
        code, output = self.run_entry(
            {
                "uid": self.uid,
                "argv": ["/bin/sh", "-c", "echo boom >&2; exit 3"],
            }
        )
        self.assertEqual(code, 3)
        self.assertIn("boom", output)

    def test_the_environment_is_inherited_and_then_overridden(self):
        _, output = self.run_entry(
            {
                "uid": self.uid,
                "argv": ["/bin/sh", "-c", "echo $PATH; echo $LA_TEST_MARKER"],
                "env": {"LA_TEST_MARKER": "set-by-the-queue"},
            }
        )
        self.assertIn("/", output, "PATH was not inherited")
        self.assertIn("set-by-the-queue", output)


class EndToEnd(unittest.TestCase):
    """Drives run_multiple_commands.py the way the app does, minus the root check."""

    def test_the_queue_file_the_app_writes_is_accepted(self):
        here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        with tempfile.TemporaryDirectory(prefix="la-queue-e2e") as tmp:
            marker = os.path.join(tmp, "pwned")
            queue = os.path.join(tmp, "queue")
            lines = [
                json.dumps(
                    {
                        "uid": os.getuid(),
                        "argv": ["/bin/echo", HOSTILE.format(marker)],
                        "env": {},
                        "shell": False,
                    }
                )
            ]
            content = "\n".join(lines)
            with open(queue, "w", encoding="utf-8") as handle:
                handle.write(content)

            import hashlib

            digest = hashlib.md5(content.encode("utf-8")).hexdigest()
            # ensure_root_privileges() is the one thing a test cannot satisfy,
            # so the script is exercised through its module instead.
            result = subprocess.run(
                [
                    sys.executable,
                    "-c",
                    "import sys, json, hashlib, command_queue;"
                    "content=open(sys.argv[1]).read();"
                    "assert hashlib.md5(content.encode()).hexdigest()==sys.argv[2];"
                    "e=json.loads(content.strip());"
                    "u,a,v,s=command_queue.parse_command(e,1);"
                    "sys.exit(command_queue.run_command(u,a,v,s))",
                    queue,
                    digest,
                ],
                cwd=here,
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(os.path.exists(marker))


if __name__ == "__main__":
    unittest.main()
