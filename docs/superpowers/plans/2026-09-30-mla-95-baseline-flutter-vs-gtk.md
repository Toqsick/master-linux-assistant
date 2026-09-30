# SDD-Plan: #95 — Baseline-Messung Flutter-Release vs. GTK (reduzierter Schnitt)

- **Datum:** 2026-09-30 · **Issue:** #95 ([Next 0.0.3], milestone `MLA-Next 0.0.3 – Fixtures & Baseline`)
- **Branch:** `feature/mla-95-baseline` · **Basis-SHA:** `31277a2` (main, nach Merge PR #108)
- **Freigabe:** Plan am 2026-09-30 via ExitPlanMode genehmigt (vorher User-Freigabe für Merge PR #108 + Close #94 erteilt und ausgeführt). Scope-Entscheidung des User 2026-09-30: **«Reduziert messen»** — 4 Startzustands-Zellen statt voller Last-Matrix.
- **Quellen:** `docs/mla-next/ISSUES.md` #95-Sektion, `docs/mla-next/AGENT_PLAN.md` (0.0.3), `docs/mla-next/BASELINE.md` §1/§6 Punkt 5/§7

## Global Constraints (für jeden Task verbindlich)

1. **Ausschließlich unprivilegierte Kommandos.** Die polkit-Trinität (`_privilegedEntryPoints`, Policy `exec.path`, `chmod +x` in build-deb.sh) bleibt unberührt. Kein `sudo`, kein pkexec.
2. **Keine App-/Test-Codeänderungen** — #95 ist eine Mess-/Dokumentationsaufgabe. Geändert werden dürfen nur `docs/mla-next/BASELINE.md`, `docs/mla-next/VERIFY.md`, `docs/mla-next/ISSUES.md` und diese Plan-Datei (Errata). Mess-Helfer (Skripte, Rohwerte) liegen unter `/tmp` bzw. `.superpowers/sdd/` und werden **nicht** committet.
3. **Gates frisch ausführen und belegen** (nur Task 3/4 ändern Repo-Dateien; Task 1/2 belegen Build- und Messläufe):
   - Flutter-Root: `dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test`
   - la_core: `cd packages/la_core && dart pub get && dart format --output=none --set-exit-if-changed lib test && dart analyze && dart test` (`pub get` vor `dart format` — sonst falsche Language-Version)
   - Python: `cd additional/python && python3 -m unittest discover -s tests -t .` → `OK`
   - `bash tool/check-versions.sh`
4. Conventional-Commits mit `(#95)`-Suffix, deutschsprachige Bodies wie im Repo üblich. `git status` vor jedem Commit prüfen (`.superpowers/`, `build/`, `/tmp` nie committen).
5. **Kein Push, kein Merge, kein Release** ohne gesonderte Freigabe. gh immer `-R Toqsick/master-linux-assistant`.
6. **Kein TDD-RED möglich** (kein Code) — Handoff-Box «Failing-Test/Fixture»: *keiner; Messaufgabe, Beleg sind die Rohwerte 1:1 und die Gates*.

## Design-Entscheidungen (vom Controller gesetzt, nicht zur Diskussion im Implementer)

### Messzellen (4) und Szenario-Definitionen

| Zelle | Artefakt | Start-Kommando | Startzustand |
|---|---|---|---|
| Flutter × Wayland | `build/linux/x64/release/bundle/linux_assistant` | Binär direkt | Dashboard mit aktivem 3-s-Stat-Poll (`hub_shell.dart`: initialSection-Default, `setSectionActive(usesStats)` in initState) — **echte Systemdaten** |
| Flutter × X11 | dito | `GDK_BACKEND=x11 <Binär>` | dito (über XWayland `:1`) |
| GTK × Wayland | `prototype/gtk/mla_app.py` | `python3 prototype/gtk/mla_app.py` | statisches Demo-Dashboard (kein Refresh-Timer; grep-Beleg: kein `timeout_add`/`GLib.timeout`/`Thread` in mla_app.py) |
| GTK × X11 | dito | `GDK_BACKEND=x11 python3 prototype/gtk/mla_app.py` | dito |

- **5 Läufe je Zelle, Median + Rohwerte.** Pro Lauf: Startzeit messen, 10 s Settle, dann 20-s-Fenster mit 1-Hz-Samples (RAM) und CPU-Delta (Fensteranfang/-ende). Zwischen Läufen: SIGTERM an den App-Prozess, auf Exit warten, 2 s Cooldown, Restprozess-Check (`pgrep`).
- **Gemessen wird der App-Prozess selbst** (`linux_assistant` bzw. `python3`), nie ein Wrapper. `$!` nach direktem Launch ist die App-PID (Gate-0-Lektion: keine Shell-Wrapper dazwischen).
- **Harte Vorbedingung je Lauf:** kein App-Restprozess (`pgrep -af linux_assistant`, `pgrep -af mla_app.py` leer — Self-Match der prüfenden Shell ausschließen) und unter X11 kein Fenster mit dem Suchnamen (`xdotool search --name` leer). Die installierte v0.8.0-App hat denselben Titel «Linux Assistant» und Single-Instance-Verhalten — läuft sie, würde ein zweiter Launch nur fokussieren und sofort exiten. Messung nur ab Ruhezustand.

### Messgrößen (exakte Kommandos)

- **Startzeit X11 — Fenster sichtbar:**
  ```bash
  s=$(date +%s%N); <Start-Kommando> & app_pid=$!
  while ! xdotool search --name "Linux Assistant" >/dev/null 2>&1; do sleep 0.01; done
  e=$(date +%s%N); echo $(( (e-s)/1000000 )) ms   # GTK-Zelle: Suchname "Prototyp"
  ```
- **Startzeit Wayland — erster Wayland-Protokollverkehr (Proxy, Vor-First-Frame):**
  ```bash
  : > /tmp/mla95-wl.log
  s=$(date +%s%N); WAYLAND_DEBUG=1 <Start-Kommando> 2>>/tmp/mla95-wl.log & app_pid=$!
  while [ ! -s /tmp/mla95-wl.log ]; do sleep 0.005; done
  e=$(date +%s%N); echo $(( (e-s)/1000000 )) ms
  ```
  `WAYLAND_DEBUG=1` lässt libwayland-client jeden Protokollverkehr auf stderr drucken; erste Zeile ≈ Verbindungs-/Registry-Phase. Perturbation (ein fprintf) dokumentieren; **nur für die Startzeit-Läufe setzen, nicht für RAM/CPU-Läufe.**
- **RAM:** je Sample `grep -E 'VmRSS|VmHWM' /proc/$app_pid/status` und `grep VmPss /proc/$app_pid/smaps_rollup`; Median der 20 Samples je Lauf.
- **CPU:** `awk '{print $14+$15}' /proc/$app_pid/stat` bei Fensterbeginn und -ende (utime+stime in Ticks; comm ohne Leerzeichen bei beiden Apps — `linux_assistan`/`python3` — Feldposition sicher); Differenz × 10 ms / 20 s → % eines Kerns.
- **Umgebung je Zelle protokollieren:** `XDG_SESSION_TYPE`, `DISPLAY`, `WAYLAND_DISPLAY`, `date -Is`, `cat /proc/loadavg` vor/nach der Zelle (Ruhe-Bedingung).
- **Bundle-Größe (nur Angabe, kein Ranking):** `du -sb build/linux/x64/release/bundle` und `stat -c '%s' build/linux/x64/release/bundle/linux_assistant`.

### «Nicht verglichen»-Box (Kriterium 4 — geplanter Wortlaut für BASELINE §8)

1. **GTK-Fixture-Last:** kein Datenadapter/Refresh-Timer in `mla_app.py` (grep-Beleg) — hängt am #92-Rest; die GTK-Zellen messen den Fixture-**Startzustand**.
2. **Flutter-Last-Zustände** (z. B. Systemmonitor-1-s-Sampler): nur per UI-Interaktion erreichbar, unter Wayland nicht fernsteuerbar; bewusst keine xdotool-Koordinatenklicks in die Baseline (Validitätsrisiko). User-Entscheidung 2026-09-30 «Reduziert messen».
3. **Wayland-Startzeit = erster Protokollverkehr ≠ First-Frame** (X11 misst Fenster-Erscheinen) → Startzeiten backend-übergreifend nicht direkt vergleichbar.
4. **Datenquellen nicht identisch:** Flutter pollt echte Systemdaten (df/ps/uptime/free/loadavg, 3 s), GTK zeigt statische Demo-Fixtures.
5. **Kein Binärgrößen-Ranking:** Flutter-Bundle vs. Python-Skript haben unterschiedliche Natur (Skript braucht Python+GI-Runtime) — nur Angabe; `la_probe` (§7: 6 547 240 Bytes, 3 ms) bleibt separater Referenzpunkt.
6. **Kein Debug-Build, keine Langlauf-/Memory-Growth-Aussage** (Langlauf ist 0.1.x-Aufgabe).

### Task-sequenz

- **Task 0 — Controller-Prep** (direkt, kein Implementer): Branch, diese Plan-Datei, Ledger-Sektion. Commit `docs(mla): SDD-Plan #95 Baseline-Messung (#95)`.
- **Task 1 — Flutter-Release-Build + Flutter-Zellen:** `flutter pub get && flutter build linux --release`; Zellen Flutter×Wayland und Flutter×X11 nach Protokoll messen (je 5 Läufe: Startzeit, RAM-Median, CPU-%, Umgebung); Rohwerte 1:1 nach `.superpowers/sdd/task-1-report.md`. Kein Commit (nur /tmp + .superpowers).
- **Task 2 — GTK-Zellen:** Wayland + X11 messen, gleiches Protokoll; Rohwerte nach `.superpowers/sdd/task-2-report.md`. Kein Commit.
- **Task 3 — Dokumentation:** `BASELINE.md` §8 «Flutter-Release vs. GTK-Shell» (Kommando, Rechner, Sitzungstyp, Datum, Rohwerte, Median-Tabelle, «Nicht verglichen»-Box wortgleich zu oben); `VERIFY.md` Gate-1-Zeile + Handoff-Abschnitt #95; `ISSUES.md` #95-Spiegel-Abnahme abhaken (soweit erfüllt). Commit.
- **Task 4 — Abschluss:** Final-Whole-Branch-Review (Reviewer A: Protokolltreue/Rohwert-Plausibilität; Reviewer B: Beweisqualität/Grenzen-Ehrlichkeit — beide als Parallel-Dispatch), alle Gates frisch, dann finishing-a-development-branch → PR-Frage an den User.

### Boundary / bewusst draußen

- Manuelle Gate-0-Checks (BASELINE §3) bleiben Bastis eigene, unberührt.
- #92-Abnahme bleibt offen (formale Blockade von #95); im #95-Handoff benannt, nicht «weggebügelt».
- Die Flutter-vs-GTK-**Entscheidung** selbst ist 0.4.x-Aufgabe; #95 liefert nur die Vergleichsbasis für #105.
