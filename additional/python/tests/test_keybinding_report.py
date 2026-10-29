"""Tests for the keybinding report and the cleanup of orphaned entries.

The report is the diagnosis row of the app, the cleanup repairs a session
that collected several `custom*` entries of ours. The rules work on plain
data and are tested here without a desktop session; the script itself is
only exercised for its command line contract, which needs neither a
desktop nor PyGObject.
"""

import json
import os
import subprocess
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import keybinding_files  # noqa: E402


PYTHON_HELPER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(PYTHON_HELPER_DIR, "setup_keybinding.py")

GNOME_PATH = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
CINNAMON_PATH = "/org/cinnamon/desktop/keybindings/custom-keybindings"


def entry(path, command, binding):
    """One shortcut entry of the desktop's own list."""
    return keybinding_files.KeybindingEntry(
        path=path, command=command, binding=binding)


def run_script(*arguments, environment=None):
    """Runs the script with a controlled environment.

    The environment is built from scratch, so the desktop of the machine
    that runs the tests cannot leak into the result.
    """
    env = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "HOME": os.environ.get("HOME", "/tmp"),
    }
    if environment:
        env.update(environment)
    return subprocess.run(
        [sys.executable, SCRIPT, *arguments],
        capture_output=True, text=True, env=env, check=False, timeout=60,
    )


class NextCustomName(unittest.TestCase):
    def test_the_gap_in_the_numbering_is_filled(self):
        self.assertEqual(
            keybinding_files.next_custom_name(["custom0", "custom2"]),
            "custom1",
        )

    def test_a_dense_list_grows_by_one(self):
        self.assertEqual(
            keybinding_files.next_custom_name(["custom0", "custom1"]),
            "custom2",
        )

    def test_an_empty_list_starts_at_zero(self):
        self.assertEqual(keybinding_files.next_custom_name([]), "custom0")

    def test_the_gnome_paths_are_read_as_well(self):
        self.assertEqual(
            keybinding_files.next_custom_name([
                f"{GNOME_PATH}/custom0/",
                f"{GNOME_PATH}/custom2/",
            ]),
            "custom1",
        )

    def test_the_dummy_entry_of_cinnamon_is_ignored(self):
        self.assertEqual(
            keybinding_files.next_custom_name(["__dummy__", "custom0"]),
            "custom1",
        )


class OrphanDetection(unittest.TestCase):
    OURS_VALID = entry(f"{GNOME_PATH}/custom0/", "linux-assistant", "<Super>q")
    OURS_STALE = entry(f"{GNOME_PATH}/custom3/", "linux-assistant", "<Alt>q")
    FOREIGN = entry(f"{GNOME_PATH}/custom1/", "firefox", "<Ctrl>f")

    def test_the_entry_with_the_wrong_combination_is_an_orphan(self):
        orphans = keybinding_files.find_orphans(
            [self.OURS_VALID, self.OURS_STALE], "<Super>q")

        self.assertEqual([orphan.path for orphan in orphans],
                         [f"{GNOME_PATH}/custom3/"])

    def test_a_foreign_entry_is_never_an_orphan(self):
        orphans = keybinding_files.find_orphans(
            [self.OURS_VALID, self.FOREIGN], "<Super>q")

        self.assertEqual(orphans, [])

    def test_a_duplicate_of_the_valid_entry_is_an_orphan(self):
        duplicate = entry(f"{GNOME_PATH}/custom4/", "linux-assistant", "<Super>q")

        orphans = keybinding_files.find_orphans(
            [self.OURS_VALID, duplicate], "<Super>q")

        self.assertEqual([orphan.path for orphan in orphans],
                         [f"{GNOME_PATH}/custom4/"])

    def test_our_entries_without_the_wanted_combination_are_orphans(self):
        orphans = keybinding_files.find_orphans([self.OURS_STALE], "<Super>q")

        self.assertEqual([orphan.path for orphan in orphans],
                         [f"{GNOME_PATH}/custom3/"])

    def test_without_a_known_combination_nothing_is_an_orphan(self):
        orphans = keybinding_files.find_orphans(
            [self.OURS_VALID, self.OURS_STALE], "")

        self.assertEqual(orphans, [])

    def test_the_entries_of_ours_are_the_only_ones_considered(self):
        entries = [self.OURS_VALID, self.OURS_STALE, self.FOREIGN]

        self.assertEqual(
            [item.path for item in keybinding_files.our_entries(entries)],
            [f"{GNOME_PATH}/custom0/", f"{GNOME_PATH}/custom3/"],
        )


class OrphanRemoval(unittest.TestCase):
    OURS_VALID = entry(f"{GNOME_PATH}/custom0/", "linux-assistant", "<Super>q")
    OURS_STALE = entry(f"{GNOME_PATH}/custom3/", "linux-assistant", "<Alt>q")
    FOREIGN = entry(f"{GNOME_PATH}/custom1/", "firefox", "<Ctrl>f")

    def test_the_orphan_is_gone_and_the_rest_stays(self):
        entries = [self.OURS_VALID, self.FOREIGN, self.OURS_STALE]

        remaining, removed = keybinding_files.remove_orphans(entries, "<Super>q")

        self.assertEqual([item.path for item in remaining],
                         [f"{GNOME_PATH}/custom0/", f"{GNOME_PATH}/custom1/"])
        self.assertEqual([item.path for item in removed],
                         [f"{GNOME_PATH}/custom3/"])

    def test_a_foreign_entry_is_never_removed(self):
        entries = [self.FOREIGN]

        remaining, removed = keybinding_files.remove_orphans(entries, "<Super>q")

        self.assertEqual(remaining, entries)
        self.assertEqual(removed, [])


class Report(unittest.TestCase):
    OURS_VALID = entry(f"{GNOME_PATH}/custom0/", "linux-assistant", "<Super>q")
    OURS_STALE = entry(f"{GNOME_PATH}/custom3/", "linux-assistant", "<Alt>q")
    FOREIGN = entry(f"{GNOME_PATH}/custom1/", "firefox", "<Ctrl>f")

    def test_the_report_is_valid_json_with_the_expected_fields(self):
        payload = keybinding_files.build_report(
            "gnome", "wayland", [self.OURS_VALID], "<Super>q")

        self.assertEqual(
            sorted(payload.keys()),
            ["binding", "desktop", "orphans", "registered", "session"],
        )
        parsed = json.loads(keybinding_files.report_json(payload))
        self.assertEqual(parsed["desktop"], "gnome")
        self.assertEqual(parsed["session"], "wayland")
        self.assertEqual(parsed["binding"], "<Super>q")

    def test_nothing_registered_gives_an_empty_report(self):
        payload = keybinding_files.build_report(
            "gnome", "wayland", [], "<Super>q")

        self.assertFalse(payload["registered"])
        self.assertEqual(payload["orphans"], [])

    def test_the_orphans_are_listed_with_path_and_combination(self):
        payload = keybinding_files.build_report(
            "gnome", "x11", [self.OURS_VALID, self.OURS_STALE], "<Super>q")

        self.assertTrue(payload["registered"])
        self.assertEqual(
            payload["orphans"],
            [{"path": f"{GNOME_PATH}/custom3/", "binding": "<Alt>q"}],
        )

    def test_a_foreign_entry_does_not_show_up_in_the_report(self):
        payload = keybinding_files.build_report(
            "gnome", "x11", [self.OURS_VALID, self.FOREIGN], "<Super>q")

        self.assertEqual(payload["orphans"], [])

    def test_an_unknown_desktop_is_reported_as_unknown(self):
        payload = keybinding_files.build_report(
            "unknown", "unknown", [], "<Super>q")

        self.assertEqual(payload["desktop"], "unknown")
        self.assertFalse(payload["registered"])

    def test_the_report_is_one_line(self):
        line = keybinding_files.report_json(
            keybinding_files.build_report("gnome", "wayland", [], "<Super>q"))

        self.assertNotIn("\n", line)
        self.assertEqual(json.loads(line)["desktop"], "gnome")


class CleanupResult(unittest.TestCase):
    def test_the_removed_entries_are_listed(self):
        removed = entry(f"{GNOME_PATH}/custom3/", "linux-assistant", "<Alt>q")

        payload = keybinding_files.build_cleanup_result(
            "gnome", "wayland", "<Super>q", [], [removed])

        self.assertEqual(
            payload["removed"],
            [{"path": f"{GNOME_PATH}/custom3/", "binding": "<Alt>q"}],
        )
        self.assertFalse(payload["registered"])

    def test_the_state_after_the_cleanup_is_reported(self):
        valid = entry(f"{GNOME_PATH}/custom0/", "linux-assistant", "<Super>q")

        payload = keybinding_files.build_cleanup_result(
            "gnome", "wayland", "<Super>q", [valid], [])

        self.assertTrue(payload["registered"])
        self.assertEqual(payload["removed"], [])


class DesktopDetection(unittest.TestCase):
    def test_gnome_is_recognized(self):
        self.assertEqual(
            keybinding_files.detect_desktop({"XDG_CURRENT_DESKTOP": "GNOME"}),
            "gnome",
        )

    def test_cinnamon_wins_over_gnome(self):
        self.assertEqual(
            keybinding_files.detect_desktop(
                {"XDG_CURRENT_DESKTOP": "X-Cinnamon:GNOME"}),
            "cinnamon",
        )

    def test_a_colon_separated_list_is_read(self):
        self.assertEqual(
            keybinding_files.detect_desktop({"XDG_CURRENT_DESKTOP": "zorin:GNOME"}),
            "gnome",
        )

    def test_xfce_is_recognized(self):
        self.assertEqual(
            keybinding_files.detect_desktop({"XDG_CURRENT_DESKTOP": "XFCE"}),
            "xfce",
        )

    def test_kde_is_recognized(self):
        self.assertEqual(
            keybinding_files.detect_desktop({"XDG_CURRENT_DESKTOP": "KDE"}),
            "kde",
        )

    def test_an_unknown_desktop_says_so(self):
        self.assertEqual(
            keybinding_files.detect_desktop({"XDG_CURRENT_DESKTOP": "Sway"}),
            "unknown",
        )

    def test_a_missing_variable_says_unknown(self):
        self.assertEqual(keybinding_files.detect_desktop({}), "unknown")


class SessionDetection(unittest.TestCase):
    def test_wayland_is_recognized(self):
        self.assertEqual(
            keybinding_files.detect_session_type(
                {"XDG_SESSION_TYPE": "wayland", "DISPLAY": ":0"}),
            "wayland",
        )

    def test_x11_is_recognized(self):
        self.assertEqual(
            keybinding_files.detect_session_type({"XDG_SESSION_TYPE": "x11"}),
            "x11",
        )

    def test_the_display_variable_is_the_fallback(self):
        self.assertEqual(
            keybinding_files.detect_session_type({"WAYLAND_DISPLAY": "wayland-0"}),
            "wayland",
        )
        self.assertEqual(
            keybinding_files.detect_session_type({"DISPLAY": ":0"}),
            "x11",
        )

    def test_without_a_session_it_is_unknown(self):
        self.assertEqual(keybinding_files.detect_session_type({}), "unknown")


class XfceBinding(unittest.TestCase):
    def test_the_combination_is_taken_from_the_path(self):
        self.assertEqual(
            keybinding_files.xfce_binding_of_path("/commands/custom/<Super>q"),
            "<Super>q",
        )

    def test_a_path_without_the_prefix_is_kept_as_it_is(self):
        self.assertEqual(
            keybinding_files.xfce_binding_of_path("/commands/custom"),
            "/commands/custom",
        )


class CommandLine(unittest.TestCase):
    """The contract of the script on the command line."""

    def test_the_report_prints_one_json_line(self):
        result = run_script("--report", environment={"XDG_CURRENT_DESKTOP": ""})

        self.assertEqual(result.returncode, 0, result.stderr)
        lines = [line for line in result.stdout.splitlines() if line.strip()]
        self.assertEqual(len(lines), 1, result.stdout)
        payload = json.loads(lines[0])
        self.assertEqual(payload["desktop"], "unknown")
        self.assertFalse(payload["registered"])
        self.assertEqual(payload["orphans"], [])

    def test_the_session_type_is_reported(self):
        result = run_script(
            "--report", environment={"XDG_SESSION_TYPE": "wayland"})

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["session"], "wayland")

    def test_the_modifier_is_taken_over(self):
        result = run_script("--report", "--alt")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["binding"], "<Alt>q")

    def test_the_cleanup_reports_what_it_did(self):
        result = run_script("--cleanup", environment={"XDG_CURRENT_DESKTOP": ""})

        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["removed"], [])
        self.assertFalse(payload["registered"])

    def test_both_modes_at_once_fail_without_output(self):
        result = run_script("--report", "--cleanup")

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "")
        self.assertIn("--cleanup", result.stderr)

    def test_the_report_does_not_write_a_broken_line(self):
        result = run_script("--report", "--alt", environment={
            "XDG_CURRENT_DESKTOP": "GNOME",
        })

        if result.returncode == 0:
            # PyGObject is installed here: the desktop is read for real.
            json.loads(result.stdout)
        else:
            # Without PyGObject the run fails, and stdout stays empty.
            self.assertEqual(result.stdout.strip(), "")
            self.assertTrue(result.stderr.strip())


if __name__ == "__main__":
    unittest.main()
