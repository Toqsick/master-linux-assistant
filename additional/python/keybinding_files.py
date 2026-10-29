"""Pure helpers for the keyboard shortcut handling.

Two groups of things live here:

* the text transformations for the KDE and XFCE shortcut files. Both handlers
  appended unconditionally. `khotkeysrc` grew another `[Data_N]` block on
  every run, `kglobalshortcutsrc` another line carrying the *same* hardcoded
  UUID, and XFCE's property path contains the modifier
  (`/commands/custom/<Super>q`), so switching from Super to Alt left the old
  binding in place next to the new one. The GNOME and Cinnamon handlers
  already looked for an entry they own before adding one; these bring the
  other two to the same behaviour.

* the entry helpers for the diagnosis of the shortcut state: the next free
  `customN` name, the search for our own entries, the detection of the
  orphaned ones and the report that goes with it.

Everything in the second group works on plain data — lists of entries and
strings — and needs neither a desktop session nor PyGObject. That is why it
is here and not in `setup_keybinding.py`, which can only be exercised on a
running desktop.

Kept as line-in, line-out functions so they can be tested without a desktop
session.
"""

import json
import re
from dataclasses import dataclass

COMMAND = "linux-assistant"

# Stable, and ours. It used to be hardcoded in the block that was appended
# every run, so repeated setups produced several shortcuts claiming the same
# identity.
KDE_UUID = "{c3daee14-f3bd-49db-bb5f-0a31a4b7fa73}"


def _section_of(lines, index):
    """Name of the [Section] the given line belongs to."""
    for i in range(index, -1, -1):
        stripped = lines[i].strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            return stripped[1:-1]
    return ""


def find_kde_data_number(lines):
    """The N of an existing `[Data_N…]` block that runs our command."""
    for i, line in enumerate(lines):
        if line.strip() != f"CommandURL={COMMAND}":
            continue
        section = _section_of(lines, i)
        match = re.match(r"Data_(\d+)Actions\d+$", section)
        if match:
            return int(match.group(1))
    return None


def find_kde_trigger_key(lines, number):
    """The key combination of an existing `[Data_N…]` block, or None.

    The number comes from `find_kde_data_number`; the key itself lives in
    the `Data_NTriggers0` section of that block.
    """
    section = f"Data_{number}Triggers0"
    for i, line in enumerate(lines):
        if line.startswith("Key=") and _section_of(lines, i) == section:
            return line[len("Key="):].strip()
    return None


def kde_khotkeysrc(lines, key):
    """Returns khotkeysrc lines with exactly one shortcut of ours, bound to [key]."""
    lines = list(lines)

    existing = find_kde_data_number(lines)
    if existing is not None:
        # Only the trigger can change; rewrite it in place.
        trigger_section = f"Data_{existing}Triggers0"
        for i, line in enumerate(lines):
            if line.startswith("Key=") and _section_of(lines, i) == trigger_section:
                lines[i] = f"Key={key}"
        return lines

    number = _next_kde_data_number(lines)
    block = f"""[Data_{number}]
Comment=Open {COMMAND}
Enabled=true
Name={COMMAND}
Type=SIMPLE_ACTION_DATA

[Data_{number}Actions]
ActionsCount=1

[Data_{number}Actions0]
CommandURL={COMMAND}
Type=COMMAND_URL

[Data_{number}Conditions]
Comment=
ConditionsCount=0

[Data_{number}Triggers]
Comment=Simple_action
TriggersCount=1

[Data_{number}Triggers0]
Key={key}
Type=SHORTCUT
Uuid={KDE_UUID}
"""

    out = []
    inserted = False
    for line in lines:
        if not inserted and line.strip() == "[General]":
            out.extend(block.split("\n"))
            inserted = True
        out.append(line)
    if not inserted:
        # No [General] section: append rather than drop the shortcut, which is
        # what the old loop did when the file was not shaped as expected.
        if out and out[-1].strip():
            out.append("")
        out.extend(block.split("\n"))
    return out


def _next_kde_data_number(lines):
    """Bumps DataCount and returns the number to use."""
    for i, line in enumerate(lines):
        if line.strip() == "[Data]":
            for j in range(i + 1, len(lines)):
                if lines[j].startswith("DataCount="):
                    count = int(lines[j][len("DataCount="):].strip() or 0)
                    lines[j] = f"DataCount={count + 1}"
                    return count + 1
                if lines[j].strip().startswith("["):
                    break
    # No [Data] section yet: this is the first shortcut in the file.
    return 1


def kde_kglobalshortcutsrc(lines, key):
    """Returns lines with exactly one `[khotkeys]` entry for our UUID."""
    lines = list(lines)
    entry = f"{KDE_UUID}={key},none,{COMMAND}"

    for i, line in enumerate(lines):
        if line.startswith(f"{KDE_UUID}=") and _section_of(lines, i) == "khotkeys":
            lines[i] = entry
            return lines

    for i, line in enumerate(lines):
        if line.strip() == "[khotkeys]":
            lines.insert(i + 1, entry)
            return lines

    if lines and lines[-1].strip():
        lines.append("")
    lines.extend(["[khotkeys]", entry])
    return lines


def xfce_properties_of_ours(listing):
    """Property paths in `xfconf-query -c … -lv` output that run our command.

    The path carries the key combination, so the only way to change the
    modifier without leaving the old binding behind is to find ours by value.
    """
    paths = []
    for raw in listing.split("\n"):
        line = raw.strip()
        if not line.startswith("/commands/custom/"):
            continue
        parts = line.split()
        if len(parts) >= 2 and parts[-1] == COMMAND:
            paths.append(parts[0])
    return paths


def xfce_binding_of_path(path):
    """The key combination out of an XFCE property path.

    `/commands/custom/<Super>q` holds `<Super>q`; the property path is the
    only place XFCE keeps the combination.
    """
    prefix = "/commands/custom/"
    if path.startswith(prefix):
        return path[len(prefix):]
    return path


# ------------------------------------------------------------------------------
# Shortcut entries and the diagnosis of their state
# ------------------------------------------------------------------------------
#
# GNOME and Cinnamon keep their own shortcuts in a `customN` list of the
# desktop's settings. Every run of the setup used to look for a free name on
# its own, and an entry of ours that carried an outdated key combination was
# never taken away — so a session could end up with several `custom*` entries
# of ours, of which only one actually works.

DESKTOP_CINNAMON = "cinnamon"
DESKTOP_GNOME = "gnome"
DESKTOP_XFCE = "xfce"
DESKTOP_KDE = "kde"
UNKNOWN = "unknown"

SESSION_WAYLAND = "wayland"
SESSION_X11 = "x11"

# The number of a `customN` entry, e.g. `custom12`. The name of the list in
# GNOME ("custom-keybindings") carries no number, so it does not match.
CUSTOM_NAME_PATTERN = re.compile(r"custom(\d+)")


@dataclass(frozen=True)
class KeybindingEntry:
    """One shortcut entry of the desktop's own keybinding list.

    `path` is where the entry lives (a gsettings path, an xfconf property),
    `command` is what it runs and `binding` is the key combination it uses.
    """

    path: str
    command: str
    binding: str


def next_custom_name(names):
    """The next free `customN` name for a list of existing names.

    GNOME and Cinnamon both number their custom entries `custom0`, `custom1`, …
    and the number is part of the path, so the search looks at the last
    `customN` of every name. The lowest free number wins, which keeps the
    numbering dense instead of growing on every run.

    The search for the free name was duplicated in both desktop handlers; it
    is here once, so both use the same rule.
    """
    used = set()
    for name in names:
        matches = CUSTOM_NAME_PATTERN.findall(name)
        if matches:
            used.add(int(matches[-1]))
    number = 0
    while number in used:
        number += 1
    return f"custom{number}"


def our_entries(entries):
    """The entries that run our own command.

    Everything the cleanup does starts from this list, so a shortcut of
    another application can never be touched: it is not in here.
    """
    return [entry for entry in entries if entry.command == COMMAND]


def find_orphans(entries, wanted_binding):
    """Our own entries that are not the currently valid shortcut.

    The valid one is the first of our entries that carries the wanted key
    combination; every other entry of ours is an orphan — an older one with
    a different modifier, or a duplicate of the valid one.

    Without a known valid combination nothing can be judged an orphan, so
    nothing is returned in that case.
    """
    ours = our_entries(entries)
    if not wanted_binding:
        return []

    valid = None
    for entry in ours:
        if entry.binding == wanted_binding:
            valid = entry
            break

    if valid is None:
        # None of our entries carries the wanted combination — they are all
        # leftovers of an earlier modifier and do not deliver the shortcut.
        return list(ours)

    return [entry for entry in ours if entry is not valid]


def remove_orphans(entries, wanted_binding):
    """The entries without the orphans, and the orphans themselves.

    The second list is always a part of `our_entries`, so removing one can
    never hit a shortcut of another application.
    """
    orphans = find_orphans(entries, wanted_binding)
    orphan_paths = {orphan.path for orphan in orphans}
    remaining = [entry for entry in entries if entry.path not in orphan_paths]
    return remaining, orphans


def is_registered(entries, wanted_binding):
    """True iff one of our own entries carries the wanted combination."""
    if not wanted_binding:
        return False
    return any(entry.binding == wanted_binding for entry in our_entries(entries))


def build_report(desktop, session, entries, wanted_binding):
    """The diagnosis of the shortcut state as a plain dict.

    `registered` says whether our shortcut is in place, `orphans` lists our
    own entries that are not that one. The desktop and the session are taken
    as they are, so this can be built without a running session.
    """
    return {
        "desktop": desktop,
        "session": session,
        "binding": wanted_binding,
        "registered": is_registered(entries, wanted_binding),
        "orphans": [
            {"path": orphan.path, "binding": orphan.binding}
            for orphan in find_orphans(entries, wanted_binding)
        ],
    }


def build_cleanup_result(desktop, session, wanted_binding, entries_after, removed):
    """What the cleanup did — the shape of the report, plus the removals."""
    return {
        "desktop": desktop,
        "session": session,
        "binding": wanted_binding,
        "registered": is_registered(entries_after, wanted_binding),
        "removed": [
            {"path": entry.path, "binding": entry.binding} for entry in removed
        ],
    }


def report_json(payload):
    """The payload as a single JSON line.

    The whole line is built before anything is written, so a broken payload
    can never end up half printed on stdout.
    """
    return json.dumps(payload, ensure_ascii=False)


def detect_desktop(environment):
    """The desktop we are on, read from XDG_CURRENT_DESKTOP.

    The variable holds a colon separated list ("zorin:GNOME"), so all of it
    is looked at. The order of the checks is the order the setup uses:
    "X-Cinnamon:GNOME" mentions GNOME as well and must not be taken for it.
    """
    current = (environment.get("XDG_CURRENT_DESKTOP") or "").lower()
    for desktop in (DESKTOP_CINNAMON, DESKTOP_GNOME, DESKTOP_XFCE, DESKTOP_KDE):
        if desktop in current:
            return desktop
    return UNKNOWN


def detect_session_type(environment):
    """The session type we are in: wayland, x11 or unknown.

    XDG_SESSION_TYPE is the reliable source; the display variables are the
    fallback for the case that it is missing.
    """
    session_type = (environment.get("XDG_SESSION_TYPE") or "").strip().lower()
    if session_type in (SESSION_WAYLAND, SESSION_X11):
        return session_type
    if environment.get("WAYLAND_DISPLAY"):
        return SESSION_WAYLAND
    if environment.get("DISPLAY"):
        return SESSION_X11
    return UNKNOWN
