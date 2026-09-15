# Security-Fix-Plan: RepoLens-Issues #42–#50 — Linux Master Assistant

> Fix-Plan für die 9 security/injection-Findings des RepoLens-Audit-Runs
> `20260912T004309Z-c22e3a62` (Triage 2026-09-15:
> `~/20-Workspace/RepoLens/logs/20260912T004309Z-c22e3a62/final/TRIAGE-2026-09-15.md`).
> Aufbau folgt `release-plaene-v0.8.1-v0.8.5.md`: jedes Work-Paket erbt die globalen
> Randbedingungen — Referenzsystem Zorin OS 18.1, Branch `hardening/0.8.x-browser-xdg`,
> Security-Invarianten unangetastet (Command-Queue, zwei polkit-Actions), Commit mit
> `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Ohne Bastis OK: kein Push,
> kein PR, kein Versions-Bump, kein Release.
>
> **Reihenfolge:** `RV-1 → V0.8.1 → V0.8.2 (inkl. WP-B1/B2) → V0.8.2.5 (WP-S1/S2/S3) →
> V0.8.3 (inkl. WP-P1/P2) → V0.8.4 → V0.8.5`

## Globale CI-Gates (gelten für jedes Work-Paket)

- [ ] `bash tool/check-versions.sh`
- [ ] `dart format --output=none --set-exit-if-changed lib test`
- [ ] `flutter analyze` → 0 Findings
- [ ] `flutter test` → grün
- [ ] `(cd additional/python && python3 -m unittest discover -s tests -t .)`

## Verdict-Landkarte (aus der Triage, Kurzform)

| Issue | Verdict | Finale Severity | Fix-Paket |
|---|---|---|---|
| #49 | confirmed (Triage+Skeptiker) | **Medium — top priority** | WP-S1 (V0.8.2.5) |
| #44 | confirmed | Medium (Defense-in-Depth) | WP-S2 (V0.8.2.5) |
| #45 | contested — Mechanik-Prämisse entkräftet | Low pending RV-1 | WP-B2 (V0.8.2) |
| #50 | contested — Mechanik-Prämisse entkräftet | Low pending RV-1 | WP-S3 (V0.8.2.5) |
| #42 | **rejected** (Prämisse empirisch widerlegt) | Low (Härtung+Korrektheit) | WP-S3 (V0.8.2.5) |
| #47 | confirmed | Low | WP-B1 (V0.8.2) |
| #46 | partial (Interpolation durch Typ-Cast blockiert) | Low (Fragilität) | WP-S3 (V0.8.2.5) |
| #43 | confirmed (latent, Konstantpfade) | Low | WP-P1 (V0.8.3) |
| #48 | confirmed (Dead Code, 18 Root-Importe) | Low | WP-P2 (V0.8.3) |

Grundlage aller Entschärfungen zu #42/#45/#50: Dart `Process.run(runInShell: true)` escapet
auf POSIX jedes argv-Element per Single-Quote-Wrapping
(`sdk/lib/_internal/vm/bin/process_patch.dart`, unverändert seit >2019), nachgetestet
auf Dart 3.12.2 — Metazeichen (`;`, `$(…)`, Backticks, `*`, `'`) sind inert, Leerzeichen
bleiben in einem Argument. RV-1 prüft das über die echte gebaute App nach.

---

## RV-1 — Re-Verify über die gebaute App (Vorbereitung, vor Fix-Filing)

**Ziel:** Der endgültige Beweis für #45/#50/#42 — die Dart-VM-Empirie der Triage lief auf
`dart run` (Snap), nicht auf der gebauten App. Einmaliger, günstiger Check
(`flutter run -d linux`), **vor** WP-B2 (und vor dem Filing/Update der GitHub-Issues #45/#50).

**Proben:**
1. **#45-Kette:** Datei mit Namen `x'; echo INJECTED45 > /tmp/pwned45; #.txt` in
   `~/.local/share/recently-used.xbel` eintragen (RecentManager); App-Search öffnen, bis die
   Card rendert (200 ms-Timer). Erwartet (pro Empirie): Icon-Lookup fällt auf Default, keine
   `/tmp/pwned45`. Kontrolle: `don't.txt` → korrekter Icon-Lookup nach dem Fix.
2. **#50-Kette:** Mountpoint mit Leerzeichen + Metazeichen (`/mnt/test A b;c`) in `df -h`-Output
   simulieren, Disk-Analyzer-Klick (`openDiskSpaceAnalyzer` → linux.dart:2752/2755/2770).
   Erwartet: k4dirstat/baobab öffnet den Mountpoint korrekt (ein Argument), keine Injektion.
3. **#42-Kontrolle:** ein `openWebbrowserWithSite`-Aufruf mit Leerzeichen im Input — prüft die
   String-Form-Call-Sites, die der Default-Flip in WP-S3 verändern wird.

**Outcome-Gate:**
- Bestätigt Empirie → #45/#50 endgültig Low (Härtung), Fix-Bündel laufen wie geplant.
- Zeigt sich doch Injektion (abweichendes Flutter-Runtime-Verhalten) → #45 zurück zu
  HIGH / #50 MEDIUM, WP-B2/WP-S3 werden zur Pflicht vor V0.8.3 und der Fix-Plan wird angepasst.
- Beleg (Screenshot/Log) ins `final/`-Ordner des Run-Dirs neben den Triage-Report.

---

## Release V0.8.2.5 — „Security-Pass" (eigenes Release, TDD)

**Ziel:** Die beiden echten Security-Findings sind geschlossen und die Hygiene-Familie
(Shell-Quoting/Boundary) ist konsistent gezogen — bevor V0.8.3 das Paket einfriert.

### WP-S1 — #49: Bestätigungs-Dialog für `openfile:`-Exec (Medium, top priority)

**Befund:** RecentManager (`getRecentFiles`, linux.dart:1045-1061) und xapp-Favorites
(`getFavoriteFiles`, linux.dart:1705-1725) erzeugen `openfile:`-Entries (beide Module
default-aktiv, Quelle = GTK recent-files/xbel, von jeder App schreibbar) → Substring-Match in
der Suche → Klick → `action_handler.dart:147-160`: `isFileExecutable` prüft nur Mode-Bits →
`unawaited(Linux.runExecutableInTerminal(file))` → `gnome-terminal -- <path>` führt die Datei
aus. Die TODO-Kommentare (:160-161 „Ask the user … possible security risk") räumen die Lücke
selbst ein. (Issue-Abweichung: der Home-Scan erzeugt `openfolder:`-Einträge — kein Exec-Vektor.)

**Fix (TDD):**
1. **RED** — `test/`: Widget-Tests für den openfile-Zweig: bestätigt → `runExecutableInTerminal`
   gerufen; abgebrochen → nicht gerufen; kein Dialog bei Nicht-Executables (xdg-open-Pfad).
   Erwartet: Compile-Fehler, weil der Dialog noch fehlt.
2. **GREEN** — Bestätigungs-Dialog vor dem Exec-Aufruf nach existierendem Muster
   `lib/tools/clean_timeshift.dart:69 _confirmDeletion` (await vor dem `unawaited`,
   `context.mounted`-Check, l10n-Key für Dialogtext).
3. Optional: Executable-Badge im Suchergebnis-Card (sichtbarer Hinweis vor dem Klick).

**Gates:** CI-Gates; manuell: Suche trifft ein ausführbares Recent-File → Dialog erscheint,
Abbrechen startet nichts. Commit: „fix(search): confirm before executing files from recent/favorites".

### WP-S2 — #44: Root-Queue-Env härten + Transparenz (Medium, Defense-in-Depth)

**Befund:** `build_environment()` (command_queue.py:65-73) merged Queue-env ungefiltert über
`os.environ`; `Popen(..., user=0)` ehrt `LD_PRELOAD`/`LD_LIBRARY_PATH`/`LD_AUDIT` bei
uid==euid; PATH-Hijack über non-absolute argv[0] (empirisch bestätigt). **Kein** Befehls-Approval-
Dialog existiert (nur generischer polkit-Prompt; Kommandotabelle per Config-Flag default aus,
zeigt die Queue erst während sie läuft) — Transparenz ist also eigener Wert, kein Approval-Fix.
„Alle Builder nutzen absolute Pfade" ist falsch: rm/ln/sed/timeshift/flatpak nutzen bare
argv[0], Shell-Entries tragen den Skript-String in argv[0] — ein naiver Guard bricht diese Flows.

**Fix (dreischichtig, TDD):**
1. **RED** — `additional/python/tests/` (nach `test_command_queue.py`-Schema):
   Env-Map mit `LD_PRELOAD` wird von `build_environment()` bei uid==0 gefiltert;
   `parse_command()` lehnt non-absolute argv[0] für Nicht-Shell-Entries ab.
2. **GREEN** —
   (1) LD_*/`BASH_ENV`/`ENV`/`IFS`-Strip (oder Allowlist) in `build_environment()` für uid==0;
   (2) argv[0]-Guard nach Kanonisierung der ~8 bare-name-Sites (absolute Pfade einsetzen;
      Shell-Entries via Flag ausnehmen);
   (3) env in `displayCommand`/Kommandotabelle sichtbar machen (Transparenz).
3. Regression: bestehende Queue-Flows (Timeshift/Flatpak/Snap-Entries) laufen unverändert.

**Gates:** Python-Unittests; manuell: eine Queue-Runde (Timeshift-Apply) läuft normal.
Commit: „fix(queue): strip linker env for root commands and make queue env visible".

### WP-S3 — Hygiene-Bundle: #42 + #50 + #46 (Low, als ein thematischer Pass)

**Befund #42:** runInShell-Defaults sind true (`linux.dart:106/:128`), aber die Mechanik-Prämisse
des Issues („argv space-joined unquoted → Metazeichen werden Shell-Code") ist empirisch widerlegt
— kein Security-Bug. Real: String-Form-Call-Sites splitten Dart-seitig bei Leerzeichen
(`openWebbrowserWithSite` linux.dart:917-921, `openWebbrowserSeach` :911-914,
`cat $bookmarksLocation` :957-975) — Korrektheits-Bug; und der Kommentar :1496-1499 („argv is
space-joined unquoted") ist selbst falsch.
**Befund #50:** drei Disk-Analyzer-Launches (`linux.dart:2752/2755/2770`, zweiter Einstieg
`disk_space.dart:55`) ohne `runInShell: false`; Datenfluss df → `linux_filesystem.dart:68`
group(6) → Mountpoint. Entkräftet als Injection (Dart-Empirie), Fix bleibt Hygiene.
**Befund #46:** `folder_recursion_depth` (`linux.dart:936`) ist durch den `final int`-Cast vor
Injection blockiert (TypeError bei String-Werten → leere Ordnerliste), bleibt aber stille
Fragilität.

**Fix:**
1. `runInShell: false` an den drei Disk-Analyzer-Launches (:2752/:2755/:2770) nach dem
   etablierten Muster (:59/:62/:1478/:1501); Nebenbefund: :2752 feuert unconditionally vor dem
   Install-Check — mit reparieren.
2. Default-Flip `runInShell = false` in `runCommandWithCustomArguments` (:106) und `runProcess`
   (:128) — **vorher** alle String-Form-Call-Sites prüfen (Multi-Word-Konstanten wie
   `cinnamon-settings user` funktionieren, da `runCommand` bereits Dart-seitig splittet);
   Kommentar :1496-1499 auf die korrekte Mechanik korrigieren.
3. Depth-Klemme: `int.tryParse(getValueUnsafe(...).toString()).clamp(1, 10)` (oder gleiches
   Muster) an `linux.dart:936` + Unit-Test mit malicious Config-Wert (`"'; touch /tmp/pwned`).
4. Tests: Icon-/Analyzer-Lookups mit Apostroph-/Space-Pfaden bleiben funktional (hermetisch).

**Gates:** CI-Gates; manuell: Browser-Launch, Disk-Analyzer, Bookmark-Scan verhalten sich wie
vorher (kein Verhaltenstrend nach dem Flip). Commits: „refactor(shell): default runInShell off in
the command layer", „fix(hygiene): clamp folder_recursion_depth and pin analyzer launches".

---

## Einweben in V0.8.2 (AppLauncher-TDD-Umfeld)

### WP-B1 — #47: Boundary-Validation für `preferred_browser`

**Befund:** `_configuredBrowser()` (app_launcher.dart:122-129) liest den Config-Key ohne
Validierung; `detectBrowser()` stellt den Wert der `kKnownBrowsers`-Allowlist voran; als Gate
dient nur `_which(bin)` — GNU which akzeptiert absolute Pfade → jeder which-auflösbare Wert
wird via `Process.start(detached)` gestartet. LOW (Persistenz-Primitiv, kein Write-Pfad).

**Fix (als Teil des app_launcher.dart-Komplett-Ersatzes von V0.8.2):**
trim, Allowlist-Membership (`kKnownBrowsers`), `/` ablehnen; `null` → sauberer Fallback.
Tests: Config-Pfad-Gruppe in `test/app_launcher_test.dart` (heute keine) — validierter Wert,
nicht-allowlisteter Binary-Name, Pfad-Value, trailing-space-Value (fällt still auf Fallback).
Commit fließt in den V0.8.2-Commit „fix(launcher): …" oder eigener Commit
„fix(launcher): validate preferred_browser against the known-browsers allowlist".

### WP-B2 — #45: Icon-Loader-Quote-Shim entfernen (nur als gekoppeltes Paar)

**Befund:** Sink `icon_loader.dart:64-68` (`--file='$filePath'`, drei Aufrufe :52/:59/:64) über
runInShell:true-Default; Quote-Strip-Shim in `additional/python/get_icon_path_for_file.py`
arbeitet unter Dart-Escaping korrekt. Entkräftet als Injection (RV-1 entscheidet final) —
bleibende Härtung: handgeschriebene Quotes sind fehleranfällig (dasselbe Muster, das
`runPythonScript` :1478 schon einmal abbekommen hat).

**Fix (Paar!):** `runInShell: false` an allen drei icon_loader-Aufrufen **und gleichzeitig** den
Quote-Strip-Shim im Python-Skript entfernen (sonst bricht der Icon-Lookup: `--file='…'` bleibt
dann mit Quotes im argv und der Pfad matcht nicht). RV-1-Vorlauf (Probe 1). Commit:
„fix(icon): pass file paths as plain argv to the icon helper".

---

## Einweben in V0.8.3 (Python-Helfer, Unittest-Gate läuft ohnehin)

### WP-P1 — #43: `jfiles.copy_file()` → `shutil.copy2`

`additional/python/jfiles.py:181`: `os.system("cp '" + src + "' '" + dst + "'")` →
`shutil.copy2(source_path, destination_path)` (Pfade als Daten; Metadaten-Erhalt passt zur
Timeshift-Config). Einziger Caller `setup_automatic_snapshots.py:9` mit zwei Konstantpfaden
(latent). Regressionstest in `additional/python/tests/`. **Upstream-Hinweis** an
Jean28518/jtools-unix-python (Basti-Task, nicht Commit). Commit:
„fix(python): copy timeshift config with shutil instead of a shell command".

### WP-P2 — #48: `jessentials.download_file()/unzip_file()` auf argv-Listen

`jessentials.py:166/175-181`: URL/Pfade interpoliert in Command-Strings; `run_command()` macht
`shlex.split` + `Popen` ohne Shell → Whitespace-Split + Leading-Dash-Option-Injection (CWE-88).
Repo-weit 0 Caller (Dead Code), aber 18 Root-Skripte importieren jessentials (latent, LOW).
Fix: argv-Listen (oder Dead-Helper löschen — Entscheidung im Paket, Default: argv-Listen),
Leading-Dash-Guard/`--`-Separator für `link`, Unit-Test nach `test_command_queue.py`-Schema.
**Upstream-Hinweis** wie #43. Commit: „fix(python): invoke wget/unzip with argv lists".

---

## Abhängigkeiten & Reihenfolge (Feinbild)

```text
RV-1 ──→ WP-B2 (Severity-Entscheid)      WP-B2, WP-B1 ── parallel zum Launch-Neubau in V0.8.2
WP-S1 ── unabhängig                       WP-S2 ── unabhängig (anderer Stack: Python/Queue)
WP-S3 ── nach WP-B2 empfohlen (beide fassen runInShell-Stellen an — Merge-Konflikt vermeiden)
WP-P1/P2 ── unabhängig (V0.8.3-Umfeld)    #42-Comment/Close ── nach RV-1 + Basti-Sichtung
```

## GitHub-Issue-Filing (nach Freigabe)

Ein Issue je Paket: `[V0.8.2.5] WP-S1 …` / `[V0.8.2.5] WP-S2 …` / `[V0.8.2.5] WP-S3 …` /
`[V0.8.2] WP-B1 …` / `[V0.8.2] WP-B2 …` / `[V0.8.3] WP-P1+P2 …` / `[Vorbereitung] RV-1 …`,
je mit Verdict-Kurzfassung, Fix-Skizze, Gates; Labels `gate:test`/`gate:verify` (+ `security`,
falls angelegt). #42 erhält das Triage-Ergebnis als Kommentar (rejected, Empirie+SDK-Quelle)
und wird nach Basti-Sichtung geschlossen; #45/#50 erhalten einen Triage-Link-Kommentar
(Severity pending RV-1), bleiben offen.

## Verifikation des Gesamt-Plans

- Alle 9 Issues zugeordnet (keine Lücke): #49→WP-S1, #44→WP-S2, #42/#50/#46→WP-S3,
  #45→WP-B2, #47→WP-B1, #43→WP-P1, #48→WP-P2.
- RV-1 vor WP-B2; V0.8.2.5 zwischen V0.8.2 und V0.8.3; V0.8.4/V0.8.5 unangetastet.
- Jedes Paket: file:line + Tests + Gate + Commit-Messages; kein Push/PR/Version-Bump ohne
  Basti-OK (globale Randbedingungen).