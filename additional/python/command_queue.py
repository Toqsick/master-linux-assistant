"""Parsing and execution of the Linux Assistant command queue.

Kept apart from `run_multiple_commands.py` so it can be tested without root:
that script is the privileged entry point and does nothing but read the file,
check the hash and call in here.
"""

import os
import subprocess
import sys


class QueueFormatError(ValueError):
    """A line in the queue file is not a command this runner will execute."""


def parse_command(raw, line_number):
    """Validate one already-decoded queue entry.

    Returns `(uid, argv, env, use_shell)`. Raises [QueueFormatError] rather
    than guessing: this runs as root, so a queue entry that is not exactly what
    is expected must stop the run, not be repaired into something plausible.
    """
    if not isinstance(raw, dict):
        raise QueueFormatError(f"Line {line_number} is not a command object.")

    argv = raw.get("argv")
    if not isinstance(argv, list) or not argv:
        raise QueueFormatError(f"Line {line_number} has no argv.")
    if not all(isinstance(a, str) for a in argv):
        raise QueueFormatError(f"Line {line_number} has a non-string in argv.")

    uid = raw.get("uid", 0)
    if isinstance(uid, bool) or not isinstance(uid, int) or uid < 0:
        raise QueueFormatError(f"Line {line_number} has a bad uid: {uid!r}")

    env = raw.get("env") or {}
    if not isinstance(env, dict) or not all(
        isinstance(k, str) and isinstance(v, str) for k, v in env.items()
    ):
        raise QueueFormatError(f"Line {line_number} has a malformed env.")

    use_shell = raw.get("shell", False)
    if not isinstance(use_shell, bool):
        raise QueueFormatError(f"Line {line_number} has a non-boolean shell flag.")

    if not use_shell and not os.path.isabs(argv[0]):
        raise QueueFormatError(
            f"Line {line_number} has a non-absolute executable: {argv[0]!r}. "
            "The runner resolves it through PATH as root — queue an absolute path."
        )

    if use_shell and len(argv) < 1:
        raise QueueFormatError(f"Line {line_number} asks for a shell without a script.")

    return uid, argv, env, use_shell


def build_argv(argv, use_shell):
    """The argument vector actually handed to the kernel.

    Without `use_shell` this is the vector itself — no shell, so nothing in it
    can be interpreted as syntax. With it, argv[0] is the script and the rest
    become positional parameters, so values still never reach the parser.
    """
    if not use_shell:
        return list(argv)
    return ["/bin/bash", "-c", argv[0], "linux-assistant"] + list(argv[1:])


#: Variables the dynamic linker or an invoked shell would honour when the
#: command runs as root — the one case where uid == euid, so `ld.so` still
#: acts on LD_PRELOAD and friends (WP-S2 in security-fixplan-42-50.md).
_ROOT_ENV_DENY_PREFIXES = ("LD_",)
_ROOT_ENV_DENY_KEYS = frozenset({"BASH_ENV", "ENV", "IFS"})


def build_environment(env, uid=None):
    """Command environment merged over the inherited one.

    The previous runner replaced the environment with just what the app passed,
    so a command that needed PATH had to carry its own copy of it.

    For uid 0 the merged result drops the linker and shell injection
    variables — whether they arrived through the inherited environment or
    through the queue entry itself. When the command's uid differs from the
    runner's euid, `ld.so` ignores LD_* on its own, so nothing is stripped.
    """
    environment = dict(os.environ)
    environment.update(env)
    if uid == 0:
        for key in [
            key
            for key in environment
            if key.startswith(_ROOT_ENV_DENY_PREFIXES)
            or key in _ROOT_ENV_DENY_KEYS
        ]:
            del environment[key]
    return environment


def run_command(uid, argv, env, use_shell, stream=None):
    """Execute one queue entry and return its exit code."""
    stream = stream if stream is not None else sys.stdout

    process = subprocess.Popen(
        build_argv(argv, use_shell),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=build_environment(env, uid),
        user=uid,
    )
    with process.stdout:
        for raw in process.stdout:
            stream.write(raw.decode("utf-8", errors="replace"))
            stream.flush()
    return process.wait()
