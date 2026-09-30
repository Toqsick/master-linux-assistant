#!/bin/bash
set -euo pipefail

VERSION="$( cat version )"
ARCH="$( dpkg --print-architecture )"

# The package is assembled in build/ rather than in the tracked deb/ directory.
# Stamping Version and Installed-Size used to rewrite the checked-in
# deb/DEBIAN/control, so every build left the working tree dirty and the
# committed file carried whatever the last local build measured.
STAGE="build/deb-root"
rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN"
cp deb/DEBIAN/control "$STAGE/DEBIAN/control"

# Build Linux Assistant
# The two privileged entry points are named in the polkit policy by path, so
# pkexec has to be able to execute them directly.
chmod +x additional/python/run_multiple_commands.py
chmod +x additional/python/read_security_report.py
flutter build linux
cp -r additional build/linux/x64/release/bundle/
# The runner's unit tests are not part of the product.
rm -rf build/linux/x64/release/bundle/additional/python/tests
cp version build/linux/x64/release/bundle/

# Prepare deb files for packaging
mkdir -p "$STAGE/usr/lib/linux-assistant/"
cp -r build/linux/x64/release/bundle/* "$STAGE/usr/lib/linux-assistant/"

# Bundle the core probe binary (#93). It lives in the app's lib directory on
# purpose: it is internal, gets no chmod +x, no /usr/bin entry and no polkit
# action, and nothing outside the app calls it.
if command -v dart >/dev/null 2>&1; then
  dart compile exe packages/la_core/bin/la_probe.dart \
    -o "$STAGE/usr/lib/linux-assistant/la_probe"
  # Smoke check: the binary has to answer --version with no display attached.
  env -u DISPLAY -u WAYLAND_DISPLAY \
    "$STAGE/usr/lib/linux-assistant/la_probe" --version
else
  echo "dart not found in PATH; skipping la_probe build" >&2
fi

mkdir -p "$STAGE/usr/share/icons/hicolor/scalable/apps/"
cp linux-assistant.svg "$STAGE/usr/share/icons/hicolor/scalable/apps/"
mkdir -p "$STAGE/usr/share/icons/hicolor/256x256/apps/"
cp linux-assistant.png "$STAGE/usr/share/icons/hicolor/256x256/apps/"
mkdir -p "$STAGE/usr/share/applications/"
cp linux-assistant.desktop "$STAGE/usr/share/applications/"
mkdir -p "$STAGE/usr/share/polkit-1/actions/"
cp org.linux-assistant.operations.policy "$STAGE/usr/share/polkit-1/actions/"
mkdir -p "$STAGE/usr/bin/"
cp linux-assistant.sh "$STAGE/usr/bin/linux-assistant"
chmod +x "$STAGE/usr/bin/linux-assistant"
chmod 755 "$STAGE/DEBIAN"

# Version, Installed-Size and Architecture are generated, not tracked. The
# checked-in control file used to carry Version and Installed-Size, and both
# went stale; the Architecture field stayed a hardcoded amd64 even when
# dpkg named the artifact arm64.
SIZE=$(du -s "$STAGE" | cut -f1)
sed -i "/^Description:/i Version: $VERSION\nInstalled-Size: $SIZE" \
  "$STAGE/DEBIAN/control"
sed -i "s/^Architecture: .*/Architecture: $ARCH/" "$STAGE/DEBIAN/control"

# Build deb package
dpkg-deb --build -Zxz --root-owner-group "$STAGE"
mv "$STAGE.deb" "linux-assistant_${VERSION}_${ARCH}.deb"

# The CI artifact step and the in-app updater both expect this name.
cp "linux-assistant_${VERSION}_${ARCH}.deb" linux-assistant.deb

echo "Built linux-assistant_${VERSION}_${ARCH}.deb"
