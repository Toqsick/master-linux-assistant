"""Registration and diagnosis of the "bring me up" shortcut.

Without an argument the script registers the shortcut with the desktop and
ends — that is what the app calls on its first start. `--report` prints the
current state as a single JSON line (the diagnosis row of the app),
`--cleanup` takes the orphaned `custom*` entries of ours away.

Both modes read the shortcut list of the desktop, so they run in the session
of the user and need no root. The pure parts of the diagnosis live in
`keybinding_files.py` and are tested without a desktop.
"""

import os
import subprocess
import sys

try:
    from gi.repository import Gio
except ImportError:
    # PyGObject is missing where the GNOME stack is not installed. The report
    # still works there as long as the desktop is unknown; everything that
    # reads the settings of a desktop fails with a readable message.
    Gio = None

import jessentials
import jfiles
import jfolders

import keybinding_files

# Cinnamon ----------------------------------------------------------------------------------
CUSTOM_KEYS_PARENT_SCHEMA_CINNAMON = "org.cinnamon.desktop.keybindings"
CUSTOM_KEYS_BASENAME_CINNAMON = "/org/cinnamon/desktop/keybindings/custom-keybindings"
CUSTOM_KEYS_SCHEMA_CINNAMON = "org.cinnamon.desktop.keybindings.custom-keybinding"
DUMMY_CUSTOM_ENTRY_CINNAMON = "__dummy__"

KEY_MODIFIER = "<Super>"

def add_linux_assistant_keybinding_cinnamon():
    parent = Gio.Settings.new(CUSTOM_KEYS_PARENT_SCHEMA_CINNAMON)

    # Generate new name
    array = parent.get_strv("custom-list")

    existing = find_own_keybinding(
        CUSTOM_KEYS_SCHEMA_CINNAMON,
        [f"{CUSTOM_KEYS_BASENAME_CINNAMON}/{name}/"
         for name in array if name != DUMMY_CUSTOM_ENTRY_CINNAMON])
    if existing is not None:
        entry = Gio.Settings.new_with_path(CUSTOM_KEYS_SCHEMA_CINNAMON, existing)
        entry.set_strv("binding", [f"{KEY_MODIFIER}q"])
        entry.sync()
        entry.apply()
        return

    # The free name is searched in one place for both desktop handlers.
    custom_name = keybinding_files.next_custom_name(
        [name for name in array if name != DUMMY_CUSTOM_ENTRY_CINNAMON])
    array.append(custom_name)
    parent.set_strv("custom-list", array)

    # Insert new keybinding entry
    custom_path = f"{CUSTOM_KEYS_BASENAME_CINNAMON}/{custom_name}/"
    new_schema = Gio.Settings.new_with_path(CUSTOM_KEYS_SCHEMA_CINNAMON, custom_path)
    new_schema.set_string("name", "linux-assistant")
    new_schema.set_string("command", "linux-assistant")
    new_schema.set_strv("binding", [f"{KEY_MODIFIER}q"])
    new_schema.sync()
    new_schema.apply()

    # Touch the custom-list key, this will trigger a rebuild in cinnamon
    parent = Gio.Settings.new(CUSTOM_KEYS_PARENT_SCHEMA_CINNAMON)
    custom_list = parent.get_strv("custom-list")
    custom_list.reverse()
    parent.set_strv("custom-list", custom_list)

# Gnome ----------------------------------------------------------------------------------
CUSTOM_KEYS_PARENT_SCHEMA_GNOME = "org.gnome.settings-daemon.plugins.media-keys"
CUSTOM_KEYS_BASENAME_GNOME = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
CUSTOM_KEYS_SCHEMA_GNOME = "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"

def find_own_keybinding(schema, paths):
    """Returns the path of a shortcut this app already registered, or None.

    Every run used to append a fresh entry unconditionally, so each setup left
    another duplicate behind on the same key — and uninstalling the package
    never took any of them away, because they live in the desktop's settings
    rather than in the package.
    """
    for path in paths:
        try:
            entry = Gio.Settings.new_with_path(schema, path)
            if entry.get_string("command") == "linux-assistant":
                return path
        except Exception:
            # A stale path left in the list by some other tool is not worth
            # failing the whole setup for.
            continue
    return None


def add_linux_assistant_keybinding_gnome():
    parent = Gio.Settings.new(CUSTOM_KEYS_PARENT_SCHEMA_GNOME)

    # Generate new name
    array = parent.get_strv("custom-keybindings")

    existing = find_own_keybinding(CUSTOM_KEYS_SCHEMA_GNOME, array)
    if existing is not None:
        entry = Gio.Settings.new_with_path(CUSTOM_KEYS_SCHEMA_GNOME, existing)
        entry.set_string("binding", f"{KEY_MODIFIER}q")
        entry.sync()
        entry.apply()
        return

    # The free name is searched in one place for both desktop handlers.
    custom_name = keybinding_files.next_custom_name(array)
    array.append(f"{CUSTOM_KEYS_BASENAME_GNOME}/{custom_name}/")
    parent.set_strv("custom-keybindings", array)

    # Insert new keybinding entry
    custom_path = f"{CUSTOM_KEYS_BASENAME_GNOME}/{custom_name}/"
    new_schema = Gio.Settings.new_with_path(CUSTOM_KEYS_SCHEMA_GNOME, custom_path)
    new_schema.set_string("name", "linux-assistant")
    new_schema.set_string("command", "linux-assistant")
    new_schema.set_string("binding", f"{KEY_MODIFIER}q")
    new_schema.sync()
    new_schema.apply()

    # Touch the custom-list key, this will trigger a rebuild in gnome
    parent = Gio.Settings.new(CUSTOM_KEYS_PARENT_SCHEMA_GNOME)
    custom_list = parent.get_strv("custom-keybindings")
    custom_list.reverse()
    parent.set_strv("custom-keybindings", custom_list)

# Xfce ----------------------------------------------------------------------------------

def add_linux_assistant_keybinding_xfce():
    os.environ["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=/run/user/" + str(os.getuid()) + "/bus"

    # The key combination is part of the property path, so a run with a
    # different modifier used to add a second binding instead of moving the
    # first. Ours are found by value and removed before the new one is set.
    listing = subprocess.run(
        ["xfconf-query", "-c", "xfce4-keyboard-shortcuts", "-lv"],
        capture_output=True, text=True, check=False,
    ).stdout
    wanted = f"/commands/custom/{KEY_MODIFIER}q"
    for path in keybinding_files.xfce_properties_of_ours(listing):
        if path == wanted:
            continue
        subprocess.run(
            ["xfconf-query", "-c", "xfce4-keyboard-shortcuts", "-p", path, "-r"],
            check=False,
        )

    result = subprocess.run(
        ["xfconf-query", "-c", "xfce4-keyboard-shortcuts",
         "-p", wanted, "-n", "-t", "string", "-s", "linux-assistant"],
        check=False,
    )
    if result.returncode != 0:
        # Same contract as the unknown-desktop case: exiting 0 here would
        # make the app mark the hotkey as done and never retry.
        jessentials.fail("xfconf-query could not create the shortcut.", 1)

# KDE ----------------------------------------------------------------------------------
# Keymodifier is always <Alt> here.

def add_linux_assistant_keybinding_kde():
    # KDE's own shortcut editor writes Alt+Q; the app tells the user the same
    # (see Linux.getHotkeyModifier, which returns <Alt> for every KDE session).
    key = "Alt+Q"

    khotkeysrc = jfolders.replace_tilde_to_home("~/.config/khotkeysrc")
    jfiles.write_lines_to_file(
        khotkeysrc,
        keybinding_files.kde_khotkeysrc(
            jfiles.get_all_lines_from_file(khotkeysrc), key),
    )

    kglobalshortcutsrc = jfolders.replace_tilde_to_home(
        "~/.config/kglobalshortcutsrc")
    jfiles.write_lines_to_file(
        kglobalshortcutsrc,
        keybinding_files.kde_kglobalshortcutsrc(
            jfiles.get_all_lines_from_file(kglobalshortcutsrc), key),
    )


# Diagnosis --------------------------------------------------------------------------------

# KDE writes its shortcut as `Alt+Q`, the gsettings based desktops as
# `<Super>q` resp. `<Alt>q`.
KDE_KEY = "Alt+Q"


def require_gio():
    """Fails with a readable message when PyGObject is not installed."""
    if Gio is None:
        jessentials.fail(
            "PyGObject (python3-gi) is not installed, the shortcut list of "
            "the desktop cannot be read.", 1)


def expected_binding(desktop):
    """The key combination the desktop is supposed to use."""
    if desktop == keybinding_files.DESKTOP_KDE:
        return KDE_KEY
    return f"{KEY_MODIFIER}q"


def read_gsettings_entry(schema, path, binding_is_list):
    """One custom keybinding entry, or None when it cannot be read.

    A stale path in the list of the desktop is not worth failing the whole
    report for, so it is skipped.
    """
    try:
        child = Gio.Settings.new_with_path(schema, path)
        if binding_is_list:
            # Cinnamon keeps the combination as a list of accelerators, GNOME
            # as a single string.
            binding = "".join(child.get_strv("binding"))
        else:
            binding = child.get_string("binding")
        return keybinding_files.KeybindingEntry(
            path=path,
            command=child.get_string("command"),
            binding=binding,
        )
    except Exception:
        return None


def gsettings_entries_gnome():
    """The custom keybindings of GNOME."""
    require_gio()
    parent = Gio.Settings.new(CUSTOM_KEYS_PARENT_SCHEMA_GNOME)
    entries = []
    for path in parent.get_strv("custom-keybindings"):
        entry = read_gsettings_entry(CUSTOM_KEYS_SCHEMA_GNOME, path, False)
        if entry is not None:
            entries.append(entry)
    return entries


def gsettings_entries_cinnamon():
    """The custom keybindings of Cinnamon."""
    require_gio()
    parent = Gio.Settings.new(CUSTOM_KEYS_PARENT_SCHEMA_CINNAMON)
    entries = []
    for name in parent.get_strv("custom-list"):
        if name == DUMMY_CUSTOM_ENTRY_CINNAMON:
            continue
        path = f"{CUSTOM_KEYS_BASENAME_CINNAMON}/{name}/"
        entry = read_gsettings_entry(CUSTOM_KEYS_SCHEMA_CINNAMON, path, True)
        if entry is not None:
            entries.append(entry)
    return entries


def xfce_entries():
    """Our shortcuts in the shortcut store of XFCE."""
    listing = subprocess.run(
        ["xfconf-query", "-c", "xfce4-keyboard-shortcuts", "-lv"],
        capture_output=True, text=True, check=False,
    ).stdout
    entries = []
    for path in keybinding_files.xfce_properties_of_ours(listing):
        entries.append(keybinding_files.KeybindingEntry(
            path=path,
            command=keybinding_files.COMMAND,
            binding=keybinding_files.xfce_binding_of_path(path),
        ))
    return entries


def kde_entries():
    """Our shortcut in the shortcut file of KDE."""
    khotkeysrc = jfolders.replace_tilde_to_home("~/.config/khotkeysrc")
    if not jfiles.does_file_exist(khotkeysrc):
        return []
    lines = jfiles.get_all_lines_from_file(khotkeysrc)
    number = keybinding_files.find_kde_data_number(lines)
    if number is None:
        return []
    binding = keybinding_files.find_kde_trigger_key(lines, number)
    if binding is None:
        return []
    return [keybinding_files.KeybindingEntry(
        path=f"khotkeysrc:Data_{number}",
        command=keybinding_files.COMMAND,
        binding=binding,
    )]


def read_entries(desktop):
    """The shortcut entries of the desktop we are on.

    An unknown desktop has no list to read — the report then says
    `registered: false` instead of guessing.
    """
    if desktop == keybinding_files.DESKTOP_GNOME:
        return gsettings_entries_gnome()
    if desktop == keybinding_files.DESKTOP_CINNAMON:
        return gsettings_entries_cinnamon()
    if desktop == keybinding_files.DESKTOP_XFCE:
        return xfce_entries()
    if desktop == keybinding_files.DESKTOP_KDE:
        return kde_entries()
    return []


def reset_gsettings_entry(schema, path):
    """Clears the values of an entry that was taken away.

    The entry is out of the list of the desktop already, so the leftovers
    are invisible — but they would still be found by a scan of the settings
    database. A failure here must not abort the cleanup.
    """
    try:
        child = Gio.Settings.new_with_path(schema, path)
        for key in ("name", "command", "binding"):
            try:
                child.reset(key)
            except Exception:
                continue
        child.sync()
    except Exception:
        return


def remove_gnome_orphans(orphans):
    """Removes the given entries from the custom keybindings of GNOME."""
    require_gio()
    paths = {orphan.path for orphan in orphans}
    parent = Gio.Settings.new(CUSTOM_KEYS_PARENT_SCHEMA_GNOME)
    current = parent.get_strv("custom-keybindings")
    kept = [path for path in current if path not in paths]
    if len(kept) == len(current):
        return []
    parent.set_strv("custom-keybindings", kept)
    for path in paths:
        reset_gsettings_entry(CUSTOM_KEYS_SCHEMA_GNOME, path)
    return [orphan for orphan in orphans if orphan.path in paths]


def remove_cinnamon_orphans(orphans):
    """Removes the given entries from the custom keybindings of Cinnamon."""
    require_gio()
    paths = {orphan.path for orphan in orphans}
    parent = Gio.Settings.new(CUSTOM_KEYS_PARENT_SCHEMA_CINNAMON)
    current = parent.get_strv("custom-list")
    kept = [
        name for name in current
        if name == DUMMY_CUSTOM_ENTRY_CINNAMON
        or f"{CUSTOM_KEYS_BASENAME_CINNAMON}/{name}/" not in paths
    ]
    if len(kept) == len(current):
        return []
    parent.set_strv("custom-list", kept)
    for path in paths:
        reset_gsettings_entry(CUSTOM_KEYS_SCHEMA_CINNAMON, path)
    return [orphan for orphan in orphans if orphan.path in paths]


def remove_xfce_orphans(orphans):
    """Removes the given properties from the shortcut store of XFCE."""
    removed = []
    for orphan in orphans:
        result = subprocess.run(
            ["xfconf-query", "-c", "xfce4-keyboard-shortcuts",
             "-p", orphan.path, "-r"],
            check=False,
        )
        if result.returncode == 0:
            removed.append(orphan)
    return removed


def remove_orphans(desktop, orphans):
    """Removes the given orphan entries and returns the ones that are gone.

    Only entries of ours are ever handed in here — the check is the second
    line of defence against taking a shortcut of another application away.
    """
    ours = [
        orphan for orphan in orphans
        if orphan.command == keybinding_files.COMMAND
    ]
    if not ours:
        return []
    if desktop == keybinding_files.DESKTOP_GNOME:
        return remove_gnome_orphans(ours)
    if desktop == keybinding_files.DESKTOP_CINNAMON:
        return remove_cinnamon_orphans(ours)
    if desktop == keybinding_files.DESKTOP_XFCE:
        return remove_xfce_orphans(ours)
    # KDE keeps its shortcuts in ~/.config/khotkeysrc; there are no custom*
    # entries there to take away.
    return []


def write_json_line(payload):
    """Writes the payload as a single JSON line on stdout.

    The line is built completely before anything is written, so a broken
    payload never reaches stdout half finished.
    """
    line = keybinding_files.report_json(payload)
    sys.stdout.write(line + "\n")
    sys.stdout.flush()


def run_report():
    """Prints the state of the shortcut as one JSON line on stdout."""
    try:
        desktop = keybinding_files.detect_desktop(os.environ)
        session = keybinding_files.detect_session_type(os.environ)
        binding = expected_binding(desktop)
        entries = read_entries(desktop)
        payload = keybinding_files.build_report(
            desktop, session, entries, binding)
        write_json_line(payload)
    except Exception as error:
        # A broken report is worse than no report: the error goes to stderr,
        # the exit code says it failed and stdout stays empty.
        jessentials.fail(
            f"The state of the keyboard shortcut could not be read: {error}", 1)


def run_cleanup():
    """Removes the orphaned entries of ours and reports what it did."""
    try:
        desktop = keybinding_files.detect_desktop(os.environ)
        session = keybinding_files.detect_session_type(os.environ)
        binding = expected_binding(desktop)
        entries = read_entries(desktop)
        _, orphans = keybinding_files.remove_orphans(entries, binding)
        removed = remove_orphans(desktop, orphans)
        removed_paths = {entry.path for entry in removed}
        remaining = [
            entry for entry in entries if entry.path not in removed_paths]
        payload = keybinding_files.build_cleanup_result(
            desktop, session, binding, remaining, removed)
        write_json_line(payload)

        if orphans and not removed:
            jessentials.printerr(
                "The orphaned shortcut entries were not removed — this "
                "desktop keeps them somewhere else.")
        elif removed and not keybinding_files.is_registered(remaining, binding):
            jessentials.printerr(
                "No valid shortcut entry is left — run setup_keybinding.py "
                "without --cleanup to register it again.")
    except Exception as error:
        jessentials.fail(
            f"The orphaned shortcut entries could not be removed: {error}", 1)


def main():
    global KEY_MODIFIER
    if jessentials.is_argument_option_given("alt", "a"):
        KEY_MODIFIER = "<Alt>"
    else:
        pass

    if (jessentials.is_argument_option_given("report")
            and jessentials.is_argument_option_given("cleanup")):
        jessentials.fail("--report and --cleanup cannot be used together.", 1)

    # The diagnosis modes do not register anything: they read the state of
    # the shortcut and clean it up.
    if jessentials.is_argument_option_given("report"):
        run_report()
        return
    if jessentials.is_argument_option_given("cleanup"):
        run_cleanup()
        return

    # Read once and defensively: the variable is absent in a TTY and under
    # pkexec, where `.lower()` on None raised AttributeError.
    desktop = keybinding_files.detect_desktop(os.environ)

    # elif, not four separate ifs: XDG_CURRENT_DESKTOP is a colon separated
    # list ("zorin:GNOME", "X-Cinnamon:GNOME"), so more than one token can
    # match and the binding would be registered twice.
    if desktop == keybinding_files.DESKTOP_CINNAMON:
        add_linux_assistant_keybinding_cinnamon()
    elif desktop == keybinding_files.DESKTOP_GNOME:
        add_linux_assistant_keybinding_gnome()
    elif desktop == keybinding_files.DESKTOP_XFCE:
        add_linux_assistant_keybinding_xfce()
    elif desktop == keybinding_files.DESKTOP_KDE:
        add_linux_assistant_keybinding_kde()
    else:
        # Exit non-zero: the Dart side marks the hotkey done on success and
        # never retries. A silent "nothing registered" left the shortcut
        # dead forever on sessions of unlisted desktops.
        jessentials.fail(
            f"No supported desktop found in XDG_CURRENT_DESKTOP='{os.getenv('XDG_CURRENT_DESKTOP') or ''}', "
            "no keyboard shortcut was registered.", 1)

if __name__ == "__main__":
    main()