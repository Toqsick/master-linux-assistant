"""Tests for the file helpers.

WP-P1 (#43): `copy_file` backs the Timeshift setup, which copies the default
config to its live location. The copy must not route through `os.system` with
interpolated paths — and `shutil.copy2` additionally keeps the metadata the
old `cp` invocation promised, which matters for a config file an admin may
have just edited.
"""

import os
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import jfiles  # noqa: E402


class CopyFile(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.source = os.path.join(self._tmp.name, "default.json")
        self.destination = os.path.join(self._tmp.name, "timeshift.json")
        with open(self.source, "w") as handle:
            handle.write('{"schedule": "daily"}\n')
        # A whole-second stamp: also exact on filesystems with coarse
        # timestamp granularity.
        os.utime(self.source, (1234567, 1234567))

    def tearDown(self):
        self._tmp.cleanup()

    def test_copies_content_and_mtime_without_a_shell(self):
        with mock.patch.object(
            jfiles.os, "system", side_effect=AssertionError("os.system must not be used")
        ):
            jfiles.copy_file(self.source, self.destination)
        with open(self.destination) as handle:
            self.assertEqual(handle.read(), '{"schedule": "daily"}\n')
        self.assertEqual(
            os.stat(self.destination).st_mtime, os.stat(self.source).st_mtime
        )
