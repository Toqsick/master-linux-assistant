"""Tests for the download/unzip helpers.

WP-P2 (#48): `download_file` and `unzip_file` have no callers in this repo,
but the root scripts import jessentials, so the helpers must stay safe to
call. Both used to interpolate URLs and paths into command strings that
`run_command` hands to shlex: a path with spaces became several arguments
(whitespace split), and a leading-dash URL became wget options (CWE-88).
Passed as argv lists, the values stay values.
"""

import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import jessentials  # noqa: E402


class RunCommand(unittest.TestCase):
    def test_accepts_an_argv_list_directly(self):
        completed = jessentials.run_command(
            [sys.executable, "-c", "print('ok')"], print_output=False
        )
        self.assertEqual(completed, 0)


class DownloadFile(unittest.TestCase):
    def test_url_and_folder_stay_single_arguments(self):
        with mock.patch.object(jessentials, "run_command") as run:
            jessentials.download_file(
                "https://example.org/my file.tar.gz", "/opt/my apps"
            )
        argv = run.call_args[0][0]
        self.assertIsInstance(argv, list)
        self.assertIn("https://example.org/my file.tar.gz", argv)
        self.assertIn("/opt/my apps", argv)

    def test_leading_dash_url_lands_after_the_option_fence(self):
        with mock.patch.object(jessentials, "run_command") as run:
            jessentials.download_file("-O/tmp/pwned", "/tmp")
        argv = run.call_args[0][0]
        self.assertIn("--", argv)
        self.assertLess(argv.index("--"), argv.index("-O/tmp/pwned"))


class UnzipFile(unittest.TestCase):
    def test_path_with_spaces_stays_one_argument(self):
        with mock.patch.object(jessentials, "run_command") as run:
            returned = jessentials.unzip_file("/opt/my apps/archive v2.zip")
        mkdir_argv = run.call_args_list[0][0][0]
        unzip_argv = run.call_args_list[1][0][0]
        self.assertEqual(mkdir_argv, ["mkdir", "/opt/my apps/archive v2"])
        self.assertEqual(
            unzip_argv,
            ["unzip", "-o", "/opt/my apps/archive v2.zip", "-d", "/opt/my apps/archive v2"],
        )
        self.assertEqual(returned, "/opt/my apps/archive v2")
        # No `--` fence for unzip: after it, the `-d` target would be read
        # as a member name to extract instead of the destination.
        self.assertNotIn("--", unzip_argv)
