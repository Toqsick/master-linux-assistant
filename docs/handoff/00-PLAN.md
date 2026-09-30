# Plan: Linux-Assistant V0.7.1 → V0.8.0 — Handoff, UI/UX-Analyse, Admin-Hub-Roadmap, Release

**Datum:** 2026-09-10 · **Freigegeben von:** Basti (Toqsick) · **Ausführung:** ZCode/GLM, superpowers-SDD
**Repo:** `$HOME/10-Projekte/10-active/linux-assistant` (Flutter/Linux, Fork `Toqsick/linux-assistant`, 44 ahead / 0 behind Upstream; Upstream dormat bei 0.6.2)

## Ausgangslage (5-Agenten-Recon, 2026-09-10)

- Branch `hardening/0.8.0` = 3 unpushed Commits (Phase 0+1 der Härtung) + 13 modified/5 untracked (Phase-2-Arbeit).
- Installiert & lief während der Planung: **v0.7.1** (Build 30.07.) — Baseline für Screenshots.
- Kein `git fetch` seit 30.07. — origin/main hat neuere Commits (docs/wiki, 23.08.).
- **Sudo-Bug root-caused:** alte `check_security.py` crascht per `IndexError` beim Parsen der
  deb822-`.sources`-Datei (`/etc/apt/sources.list.d/graphics-drivers-ubuntu-ppa-noble.sources`,
  Inline-`Signed-By:`-Block). Passwort-Auth succeeds (journal belegt), Script stirbt ~1s danach,
  UI zeigt falsch „Du benötigst Root-Rechte". Fix: `apt_sources.py` (deb822-Parser) liegt uncommittet im Tree.
- GitHub-Fork hat bereits: `docs/design/` (12 Dateien), `docs/wiki/` (9 Seiten), PR #24
  (Implementierungsplan Admin-Hub v0.8.5), Issues #25–#30, CI-Artefakte (deb/rpm).
- Design-System im Code: `HermesTokens` (Gold-Akzent `#B8860B`/`#FFD700`, Cream-Light/Navy-Dark,
  Elevation = 1px-Border + Tint statt Schatten) + Legacy `MintY`-Widgets, `HubShell` mit 5 Sektionen
  (dashboard, search, storage, health, security), Launcher `MainSearch` (600px, Alt+Q-Hotkey).

## Entscheidungen (Basti, 2026-09-10)

| Frage | Entscheidung |
|---|---|
| Handoff-Ort | **Beides:** Quelle im Repo `docs/handoff/`, Kurzfassung in `20-Workspace/20-research/results/` |
| Scope | **Alles in einem Zug** — Handoff + Analyse + Roadmap + V0.8.0 bis Release |
| Git-Ausgleich | **Fetch + Rebase + Dirt committen** |
| Release-Form | **Tag v0.8.0 + GitHub-Release + Push** |

## Phasen

### PHASE 0 — Git-Hygiene & Basis
1. Dieser Plan → `docs/handoff/00-PLAN.md`. ✅
2. `git fetch origin`, Bestandsaufnahme `origin/main..hardening/0.8.0` und umgekehrt.
3. `git rebase origin/main` auf `hardening/0.8.0`; Konflikte: Code-Vorrang, docs → origin-Vorrang; README.md (lokal uncommittet) behalten.
4. Phase-2-Dirt in logischen Commits: (a) `apt_sources.py`+Tests+`check_security.py`, (b) `keybinding_files.py`+`setup_keybinding.py`+Tests, (c) `install.sh`/`linux-assistant.sh`/`deb/DEBIAN/control`, (d) übrige Dart-Änderungen (`main_search.dart`, `main.dart`, `linux.dart`, `single_instance.dart`, `activate_hotkey.dart`, `setup_automatic_updates_debian.py`), (e) README.
5. Local Gates wie CI: `tool/check-versions.sh`, `dart format`, `flutter analyze`, `flutter test`, Python-unittests.
**Acceptance:** `git status` clean, Gates grün, Version konsistent 0.8.0.

### PHASE A — V0.7.1-Baseline-Screenshots (VOR jedem Reinstall)
1. Fenster-Erkundung: `xwininfo -root -tree` / `xlsclients` (Xwayland :1).
2. Pfad X11 (bevorzugt): `import -window <id>`/`scrot -u` + `xdotool`-Navigation. Pfad Wayland (Fallback): GNOME-Shell D-Bus Screenshot API.
3. Shot-Liste je Light+Dark: 5 Hub-Sektionen, Settings-Dialog, Launcher, Security-Fehlerzustand (Bug-Evidence), 2–3 Werkzeuge, Distro-Akzent-Subset (Ubuntu/Zorin/Mint).
4. Ablage `screenshots/v0.7.1/<section>_<theme>_NN.png`, Budget <25 MB.
**Acceptance:** ≥20 scharfe PNGs, beide Themes, Bug-Zustand dokumentiert.

### PHASE B — Design-System-Extraktion
`design/colors.md` (Tokens + Distro-Paletten + Hardcode-Sünden), `design/typography.md`,
`design/shapes-spacing.md`, `components/component-catalog.md`, `panels/hub-shell.md`,
`README.md` als Index der bestehenden `docs/design/`+`docs/wiki/` (indexieren, nicht duplizieren).
**Acceptance:** Jede Regel mit file:line + Screenshot-Beleg.

### PHASE C — UI/UX-Analyse
`analysis/findings.md` — Schwere (Critical/Important/Minor/Nice), Evidence (Shot + Code-Zeile),
Empfehlung, Zielversion. Ehrliches Urteil „Admin-Linux-Hub-Readiness".
**Acceptance:** Beide Themes abgedeckt; Security-Fehlertext-Lüge als Critical.

### PHASE D — Roadmap
`roadmap.md` — konsolidiert aus PR #24, Issues #25–#30, `.claude/plans/den-linux-assistant-weiter-swift-adleman.md`:
- **V0.8.0 „Alles nutzbar":** Security-Fix, Error-UX (Script-Fehler ≠ Rechte-Problem), Phase-3-Reste (tote Settings, Hub-Default-Nav, fi-Locale), Release.
- **V0.8.X „Zorin optimal":** Zorin-Erkennung/Akzent, Timeshift-auf-Zorin, deb822-Vollabdeckung, Updater-Stand, Tool-/Plugin-Registry (#27/#28/#29) als V0.9-Basis.
- **V0.9 „Wiring":** Tokentelemetrie, Docker Watcher, System Monitor, Backup-System (Restic), Hermes Gateway Manager, Kanban Watcher — als Hub-Modul-Slots über die Registry.
**Acceptance:** Jede V0.9-Idee mit Hub-Anker + Priorität; PR #24-Inhalte gehen auf/ersetzt.

### PHASE E — V0.8.0-Umsetzung (SDD)
1. Error-UX Security: `lib/layouts/security_check/overview.dart` — rc 126/127/polkit-abort → Rechte-Seite; sonst Script-Fehler-Dialog mit stderr. + Test.
2. Phase-3-Reste (nutzbar-blockierend): tote Settings, Hub-Default-Nav `hub`, `supportedLocales` + fi.
3. Gates grün. 4. `bash build-deb.sh`. 5. `bash install.sh --purge` (**Passwort tippt ausschließlich Basti**).
6. Verifikation mit Evidenz (journal/pkexec, Erfolgsmarker). 7. `screenshots/v0.8.0/` Before/After.
**Acceptance:** Installiert 0.8.0, Security-Check fehlerfrei, Gates grün.

### PHASE F — Release + Sync
1. Merge → main, push. 2. Tag `v0.8.0` + `gh release create` mit deb-Asset. 3. PR #24 schließen (ersetzt durch roadmap.md, mit Verweis), #10 offen lassen. 4. Kurzfassung nach `20-Workspace/20-research/results/linux-assistant-handoff-2026-09-10.md` (keine Bild-Duplikate). 5. `du -sh docs/handoff` ≤100 MB.

## Globale Constraints

- **Niemals Passwörter/Secrets tippen, loggen, committen**; sudo-Auth immer Basti.
- Screenshots nur App-Fenster bzw. fokussierte App; Recent-Files/Command-History nicht ins Bild; `~/.cache/linux_assistant_commands` nicht committen.
- Upstream nur lesen, nie pushen; kein Upstream-PR.
- Phase A vor E.5 (Baseline sichern).
- Conventional Commits; SDD: frischer Implementer je Task, Two-Reviewer-Gate, Ledger `.superpowers/sdd/progress.md`, finale Whole-Branch-Review; nach 3 fehlgeschlagenen Fixes → systematic-debugging.
- Ehrlich melden: rote Gates, übersprungene Schritte, gekippte Annahmen.
