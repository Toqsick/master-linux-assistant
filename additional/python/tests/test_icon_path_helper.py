"""WP-B2 (#45): the icon helper must hand the path through unchanged.

The icon loader used to pass the path to the Python helper as
`--file='<path>'` — quotes embedded in the value — and the helper stripped
them again with `removeprefix("'")` / `removesuffix("'")`. The two sides only
agreed because the one caller happened to add exactly the quotes the one
helper removed.

The fix makes the contract explicit: the caller owns the encoding, the
helper passes the value through. That is what these tests pin.

Why it matters, concretely: the helper used to *rewrite* the value it was
given. A caller that passes the plain path — which is what the icon loader
does now — would have had a path ending in a quote character truncated by
the old shim. The pair therefore has to change together, and the tests below
hold both halves to that.

The GTK stack is mocked: the helper only needs `gi` to exist, and the
assertion is about which path reaches `Gio.File.new_for_path`.
"""

import contextlib
import importlib.util
import io
import os
import sys
import unittest
from unittest import mock

SCRIPTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HELPER = os.path.join(SCRIPTS, "get_icon_path_for_file.py")
sys.path.insert(0, SCRIPTS)


def load_helper(argv):
    """Loads the helper with a mocked GTK stack, returns the mocked Gio."""
    fake_gi = mock.MagicMock()
    fake_repository = mock.MagicMock()
    fake_gi.repository = fake_repository
    sys.modules["gi"] = fake_gi
    sys.modules["gi.repository"] = fake_repository

    old_argv = sys.argv
    sys.argv = argv
    try:
        spec = importlib.util.spec_from_file_location(
            "get_icon_path_for_file_under_test", HELPER)
        module = importlib.util.module_from_spec(spec)
        # The helper prints the resolved icon path; that is not what this test
        # is about, and the mock's repr would drown the test output.
        with contextlib.redirect_stdout(io.StringIO()):
            spec.loader.exec_module(module)
    finally:
        sys.argv = old_argv
        sys.modules.pop("gi", None)
        sys.modules.pop("gi.repository", None)
    return fake_repository.Gio


class IconPathHelper(unittest.TestCase):
    def path_reaching_gio(self, file_value):
        """Runs the helper with `--file=<file_value>`, returns that path."""
        gio = load_helper(["get_icon_path_for_file.py", "--file=" + file_value])
        gio.File.new_for_path.assert_called_once()
        return gio.File.new_for_path.call_args[0][0]

    def test_plain_path_arrives_unchanged(self):
        path = "/home/user/Documents/report.txt"
        self.assertEqual(self.path_reaching_gio(path), path)

    def test_path_with_spaces_arrives_unchanged(self):
        path = "/home/user/My Documents/annual report.txt"
        self.assertEqual(self.path_reaching_gio(path), path)

    def test_path_ending_in_a_quote_is_not_truncated(self):
        # The old shim ran removesuffix("'") over the value, so a value that
        # ends in a quote character lost it. The caller no longer adds
        # quotes, which is exactly the case the old shim would have broken.
        path = "/home/user/odd name'"
        self.assertEqual(self.path_reaching_gio(path), path)

    def test_surrounding_quotes_are_kept(self):
        # The helper must not strip quotes: the value is data. Whether it
        # carries quotes is the caller's decision — the icon loader passes
        # the plain path, and adds no quotes of its own.
        value = "'/tmp/foo'"
        self.assertEqual(self.path_reaching_gio(value), value)


if __name__ == "__main__":
    unittest.main()
