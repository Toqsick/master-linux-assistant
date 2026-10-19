# AGENTS.md — `linux-assistant`

Last verified: 2026-09-30.

Deeper instructions override `~/AGENTS.md` for this subtree.

**Purpose and stack:** Flutter/Dart Linux desktop app (C++/GTK runner,
localized en/de/it/fi) with privileged Python helpers and Debian packaging.
Read `MANIFEST.md` (philosophy; reference system: Zorin OS 18.1) and
`features.csv` (distro/desktop support matrix; distro columns frozen at
upstream state) before changing distro-conditional behavior. Requires
Dart ≥3.4 / Flutter ≥3.27.

**Key files:** `version` (single source of truth), `pubspec.yaml`,
`analysis_options.yaml`, `l10n.yaml`, `lib/`, `linux/CMakeLists.txt`,
`additional/python/`, `deb/DEBIAN/control`, `tool/check-versions.sh`,
`.github/workflows/build.yml`.

```bash
cd ~/10-Projekte/10-active/linux-assistant
flutter pub get
dart format --output=none --set-exit-if-changed lib test  # CI gate
flutter analyze        # CI gate: zero findings expected
flutter test           # 18 files, 208 cases — real coverage
(cd additional/python && python3 -m unittest discover -s tests -t .)  # 53 tests
(cd packages/la_core && dart pub get && dart format --output=none --set-exit-if-changed . && dart analyze && dart test)  # la_core gates, own CI steps
bash build-deb.sh      # the only maintained packaging path
```

**Packaging reality:** only the Debian path (`build-deb.sh` + `deb/`) is
maintained. RPM/Arch/Flatpak live in `packaging/unmaintained/` (parked
2026-09-06, not exercised by CI). Root `build-bundle.sh` and
`build-arch-pkg.sh` are broken as-is — they reference a root `flatpak/`
directory and a root `PKGBUILD` that no longer exist.

**Architecture:** `lib/layouts/` UI panels (hub shell, settings, tools,
updater, …), `lib/services/` app logic — `linux.dart` is the core
system-interaction service including pkexec entry points —
`lib/widgets/hermes/` design-system widgets, `lib/linux/` native system
access, `additional/python/` the privileged root runner and per-distro
security checkers. Read `docs/handoff/` (German, `file:line`-evidenced)
before touching design tokens, Hermes widgets, or the hub shell.

**Security invariant:** all privileged work flows through the command queue
(`additional/python/run_multiple_commands.py`: JSON-Lines, no shell,
hash-checked). `org.linux-assistant.operations.policy` defines exactly two
polkit actions with hardcoded exec paths; `lib/services/linux.dart` keeps a
matching `_privilegedEntryPoints` list and `build-deb.sh` chmods those two
scripts. Rename or move any of them only together, in all three places.

**Conventions:** CI runs version check → format gate → analyze → Dart tests
→ Python tests → la_core gates (`packages/la_core`, plain `dart`) → build-deb
on pinned `ubuntu-24.04` (glibc compat for Zorin
18 / Mint 22). `unawaited_futures` is enforced — wrap fire-and-forget
futures in `unawaited(...)`; log through `lib/services/logger.dart`, never
`print`. L10n arb files live in `lib/l10n`; Finnish is
`linuxassistant_fi.arb`, not `app_fi.arb`.

**Release:** follow `docs/wiki/Release-Process.md` — bump `version`, commit,
tag `vX.Y.Z`, `bash build-deb.sh` (the alias artifact `linux-assistant.deb`
is what the CI artifact upload expects; the in-app updater selects its
asset by `content_type`, not by filename).
`tool/check-versions.sh` fails if `version` and `pubspec.yaml` diverge or if
the tracked `deb/DEBIAN/control` carries Version/Installed-Size fields
(those are stamped at build time). Root `.deb` files are gitignored local
outputs, not committed assets.