# Master Linux Assistant (MLA)

A linux application which is a daily linux helper with powerful integrated search, routines checks and admninistrative tasks. The Project is built with flutter and python.

The product name is **Master Linux Assistant (MLA)**; the package and binary name stays `linux-assistant` — this is a maintained fork of [Jean28518/linux-assistant](https://github.com/Jean28518/linux-assistant).

## Install

With a `.deb` at hand — from a release, from CI or from `build-deb.sh`:

```bash
bash install.sh                    # picks up the .deb next to the script
bash install.sh path/to/pkg.deb    # or a specific one
bash install.sh --purge            # additionally: fresh settings, no leftover shortcuts
```

The script looks for an older installation first — a `.deb`, a Flatpak, a
binary someone copied onto the `PATH`, orphaned `.desktop` files — and clears
out what `apt` cannot replace on its own. Run it as your normal user; it calls
`sudo` where it needs to, so that settings and keyboard shortcuts end up in
your account rather than root's. See [Uninstall](#uninstall) for doing it by
hand.

## Keyboard shortcut

Linux Assistant registers a global hotkey that brings the launcher to the
foreground. The default is `Super+Q`, except on **KDE**, **Pop!_OS**, **Ubuntu**
and **Zorin OS**, where the desktop convention is `Alt+Q` and the app follows
it. `lib/services/linux.dart` (`getHotkeyModifier()`) is the source of truth.

Two registration paths exist and the app picks one at startup based on the
session type:

- **X11 sessions** — the app grabs the key itself via libkeybinder. The grab
  uses the modifier above, so what the greeter tells the user matches what is
  actually grabbed.
- **Wayland sessions** — there is no global X11 grab, so the libkeybinder call
  is skipped (it used to log `Binding '<Meta>q' failed!` on every start) and
  the desktop's own gsettings shortcut is registered instead, through
  `additional/python/setup_keybinding.py`. The entry is written once and
  reused — the script looks for an entry whose `command` is `linux-assistant`
  before adding a new one, so repeated starts no longer pile up duplicates.

See [Uninstall](#uninstall) for how to remove the shortcut, which lives in the
desktop's settings rather than in the package.

## Requirements

To build:

```bash
sudo apt install libkeybinder-3.0-0 libkeybinder-3.0-dev
```

To run an installed package, only the runtime libraries are needed — the `.deb`
declares them, so `apt` pulls them in for you. The declared runtime set is
`libgtk-3-0, libkeybinder-3.0-0, python3, python3-gi,
gir1.2-gtk-3.0, python3-apt, mesa-utils, pkexec | policykit-1` (see
`deb/DEBIAN/control`).

If you build with `flutter build linux` and run the bundle directly (Option 1
under [Build](#build)), `apt` does not install those packages for you. The
Python helpers need GObject introspection, so install them by hand first:

```bash
sudo apt install libgtk-3-0 libkeybinder-3.0-0 python3 python3-gi \
     gir1.2-gtk-3.0 python3-apt mesa-utils policykit-1
```

## Build

```bash
# Install keybinder, see requirements
sudo rm /etc/apt/preferences.d/nosnap.pref # (For Linux Mint)
sudo apt install snapd git
sudo snap install flutter --classic
flutter doctor # If command not found: Reboot and try again
```

The project requires **Dart ≥ 3.4** and **Flutter ≥ 3.27** (see `pubspec.yaml`
`environment:`). The Flutter snap's stable channel tracks recent releases; if
`flutter build linux` fails with errors that point nowhere near the cause (the
trigger is `Color.withValues(alpha:)` in the Hermes widgets), check
`flutter --version` and switch to a newer channel if needed.

```bash
git clone https://github.com/Toqsick/master-linux-assistant.git
cd master-linux-assistant

# Option 1: Build with flutter manually
flutter build linux
chmod +x additional/python/run_script.py
cp -r additional build/linux/x64/release/bundle/
cd build/linux/x64/release/bundle/
./linux-assistant

# Option 2: Build .deb and install .deb package:
bash ./build-deb.sh
sudo apt install ./linux-assistant_*_amd64.deb
# build-deb.sh produces linux-assistant_<version>_<arch>.deb and also
# copies it to the legacy name linux-assistant.deb, which the CI artifact
# upload expects (the in-app updater picks its asset by content_type,
# not by filename).
# The build no longer mutates the tracked deb/DEBIAN/control in place —
# Version and Installed-Size are stamped into a staging dir under build/.

# Option 3: Build .rpm package (unmaintained in this fork — the spec last
# matched 0.6.2; see packaging/unmaintained/README.md):
bash packaging/unmaintained/build-rpm.sh

# Option 4: Build Arch package (unmaintained in this fork — the PKGBUILD is
# parked under packaging/unmaintained/ at pkgver=0.5.3, while build-arch-pkg.sh
# expects it next to itself; see packaging/unmaintained/README.md)
# You can only do this on an arch based distro
bash ./build-arch-pkg.sh
# To Install:
sudo pacman -U linux-assistant-*.pkg.tar.zst
```

Prefer `apt install ./…deb` over `dpkg -i`: `apt` resolves the declared
dependencies, whereas `dpkg` leaves the package half configured if one is
missing.

## Uninstall

```bash
sudo apt remove linux-assistant
```

Two things no package manager knows about and that therefore survive:

```bash
# Settings, search history and caches
rm -rf ~/.config/linux-assistant ~/.cache/linux-assistant
```

…and the keyboard shortcut, which is written into the desktop environment's own
configuration. On GNOME based desktops (Ubuntu, Zorin OS, Fedora) it is a custom
shortcut running `linux-assistant`; remove it under
*Settings ▸ Keyboard ▸ Custom Shortcuts*. On KDE the entry lives in
`~/.config/khotkeysrc`, on XFCE in the xfconf command bindings.

If the app was installed as a Flatpak instead, it is removed separately:

```bash
flatpak uninstall io.github.jean28518.Linux-Assistant
```

## Run as flatpak

Unmaintained in this fork — the manifest is parked under
`packaging/unmaintained/flatpak/` and targets the Freedesktop 23.08 runtime,
which is end of life (see `packaging/unmaintained/README.md`).

Repo: <https://github.com/Jean28518/flathub/tree/com.github.jean28518.Linux-Assistant>

- Uncomment the archive from the web and use e.g. this local one:

```yaml
      - type: archive
        path: /path/to/linux-assistant-bundle.zip
```

```bash
flatpak install runtime/org.freedesktop.Sdk/x86_64/23.08

rm -r .flatpak-builder/ # Only if you built something before.
flatpak-builder build-dir packaging/unmaintained/flatpak/io.github.jean28518.Linux-Assistant.yml  --user --force-clean --install 
flatpak run io.github.jean28518.Linux-Assistant
```

## Features

`features.csv` im Repo-Root (distro/desktop support matrix)

## Current Languages

- English
- German
- Italian
- Finnish

## Mission

`MANIFEST.md` im Repo-Root

## Development

```bash
# Install flutter

flutter run
```
