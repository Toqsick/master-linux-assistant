# Getting Started

## Voraussetzungen

Zum Bauen:

```bash
sudo apt install libkeybinder-3.0-0 libkeybinder-3.0-dev
```

Zum Ausführen eines installierten Pakets reichen die Laufzeit-Bibliotheken –
das `.deb` deklariert sie (`libgtk-3-0`, `libkeybinder-3.0-0`, `python3`,
`python3-gi`, `gir1.2-gtk-3.0`, `python3-apt`, `mesa-utils`,
`pkexec | policykit-1`, `xdg-utils`, `libgtk-3-bin`, `libglib2.0-bin`),
`apt` zieht sie automatisch.

Flutter: `>=3.27.0` (pubspec.yaml). Der Grund: `Color.withValues(alpha:)`
wird in den Design-Tokens genutzt.

## Bauen & Starten

```bash
flutter pub get
flutter gen-l10n          # generiert lib/l10n/app_localizations.dart
flutter run -d linux      # Entwicklung

flutter build linux       # Release-Bundle
```

Das Bundle liegt unter `build/linux/x64/release/bundle/`. Für einen echten
Lauf aus dem Bundle:

```bash
chmod +x additional/python/run_script.py
cp -r additional build/linux/x64/release/bundle/
cd build/linux/x64/release/bundle/
./linux-assistant
```

## Installation als Paket

```bash
# Debian/Ubuntu/Zorin/Mint:
bash ./build-deb.sh
sudo apt install ./linux-assistant_*_amd64.deb

# Fedora/openSUSE (im Fork unmaintained — die Spec entspricht zuletzt 0.6.2;
# siehe packaging/unmaintained/README.md):
bash packaging/unmaintained/build-rpm.sh

# Arch (im Fork unmaintained — das PKGBUILD liegt unter
# packaging/unmaintained/ bei pkgver=0.5.3, während build-arch-pkg.sh es
# neben sich erwartet; nur auf Arch-basierten Systemen):
bash ./build-arch-pkg.sh
sudo pacman -U linux-assistant-*.pkg.tar.zst
```

> `apt install ./…deb` statt `dpkg -i` verwenden: `apt` löst die deklarierten
> Abhängigkeiten auf, `dpkg` hinterlässt ein halb konfiguriertes Paket.

## Hotkey

Der globale Hotkey öffnet das Suchfeld direkt: standardmäßig **Super+Q**, auf
**KDE**, **Pop!_OS**, **Ubuntu** und **Zorin OS** hingegen **Alt+Q** (Quelle:
`lib/services/linux.dart`, `getHotkeyModifier()`). Unter X11 grabbt die App
den Hotkey selbst über libkeybinder; unter Wayland wird er in die
Desktop-Konfiguration geschrieben (`additional/python/setup_keybinding.py`,
unterstützt Cinnamon, GNOME, XFCE, KDE).

## Deinstallation

```bash
sudo apt remove linux-assistant
# Einstellungen & Caches (überlebt kein Paketmanager):
rm -rf ~/.config/linux-assistant ~/.cache/linux-assistant
```

Der Hotkey bleibt ebenfalls bestehen: GNOME/Zorin → *Einstellungen ▸
Tastatur ▸ Eigene Tastenkürzel*, KDE → `~/.config/khotkeysrc`, XFCE →
xfconf-Kommando-Bindings. Flatpak separat:
`flatpak uninstall io.github.jean28518.Linux-Assistant`.

## Erste Schritte in der App

1. Beim Start lädt der `MainSearchLoader` den Aktionskatalog und öffnet den
   **Hub** (Dashboard)
2. Links in der Sidebar: Sektionen (Dashboard, Suche, Speicher,
   Linux-Gesundheit, Sicherheit) und darunter die **Werkzeuge** (siehe
   [[Admin-Hub]])
3. Oben rechts: Suche, Reload, Theme-Umschalter (hell/dunkel/System)

Weiter: [[Architecture]] für den Aufbau, [[Contributing]] für den Workflow.
