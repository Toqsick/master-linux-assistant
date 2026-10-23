# SDD-Plan: V0.8.2 „XDG-Browser-Fix" — Abnahme und Abschluss

- **Datum:** 2026-10-23 · **Quellen:** Issue #33, #34, #47, #52 (WP-B1), `AGENTS.md`, `MANIFEST.md`, `meilensteine-v0.8.1-v0.8.5.md` (Meilenstein 2), `security-fixplan-42-50.md` (WP-B1, Verdict-Landkarte), `issues-v0.8.1-v0.8.5.md` (Issue 3/4/5), `lib/services/app_launcher.dart`, `lib/layouts/hub/hub_shell.dart`, `test/app_launcher_test.dart`
- **Branch:** `chore/v0.8.2-xdg-abschluss` · **Basis-SHA:** `add73e3` (main)
- **Freigabe:** Auftrag „arbeite an V0.8.2 – XDG-Browser-Fix weiter und schließe ab" (2026-10-23). Der Code-Teil ist seit `add73e3` (PR #118) gemerged; offen sind Abnahme-Nachweis, Tracking-Doku und das Schliessen der Issues. Merge der Doku-Änderung nach Repo-Konvention weiterhin bei Basti.
- **Nicht-Ziel:** neue Features. Der Plan dokumentiert, verifiziert und schliesst — er implementiert keinen Browser-Code.

## Global Constraints (für jeden Task verbindlich)

1. **Gates je Task frisch ausführen und im Report belegen** — mit *echten* Exitcodes. Fallstrick: `cmd | tail` liefert den Exitcode von `tail`; der Exitcode ist vor dem Piping zu sichern.
2. **Kein Shell-String, kein Root-Exec, keine Secrets in Logs oder Commits.** Die polkit-Trinität (`org.linux-assistant.operations.policy` ↔ `lib/services/linux.dart` `_privilegedEntryPoints` ↔ `build-deb.sh`-chmod) wird nicht berührt.
3. **Beleg- statt Blind-Pflicht:** jede Abnahme-Aussage mit `file:line` oder Gate-Ausgabe unterlegen.
4. Repo-Konventionen: Conventional Commits, deutschsprachige Bodies, Issue-Referenz im Body, `dart format` vor jedem Commit.
5. **Kein Merge ohne Freigabe.** Push und PR-Eröffnung sind Auftrag; der Merge in `main` bleibt bei Basti.
6. Nichts committen, was nicht zum Scope gehört: `.plugin-cache/`, `build/`, `/tmp`-Artefakte, `.deb`-Dateien (laut `AGENTS.md` gitignored).

## Ausgangslage — Abnahme gegen `main` (Basis `add73e3`)

Der XDG-Browser-Fix ist implementiert und in `main` gemerged (PR #118, Squash → `add73e3` „V0.8.x-Hardening: XDG-Browser-Kette (#33/#34, #47)"). Die vier Issues sind trotzdem offen, und die Tracking-Dokumente sind nicht nachgezogen. Die verbleibende Arbeit ist damit **Nachweis + Doku + Issue-Abschluss**, nicht Implementierung.

| Kriterium | Quelle | Beleg in `main` | Status |
|---|---|---|---|
| `import 'dart:io';` ergänzt | #33 | `test/app_launcher_test.dart:1` | erfüllt |
| Gruppe `defaultBrowserDesktopId` (4 Tests) | #33 | `test/app_launcher_test.dart:81` | erfüllt |
| Gruppe `desktopEntryExistsIn` (2 Tests) | #33 | `test/app_launcher_test.dart:113` | erfüllt |
| Gruppe `launchBrowser` (8 Tests, Spec) | #33 | `test/app_launcher_test.dart:139` — 9 Tests (Superset: + Debug-Override, + WP-B1-Pfad, + URL am Listen-Fallback) | erfüllt |
| Gruppen `detectBrowser` / `launchApp` wörtlich | #33 | `test/app_launcher_test.dart:55, :270` | erfüllt |
| `BrowserLaunchResult`-Enum | #34 | `lib/services/app_launcher.dart:6-16` | erfüllt |
| 5 injizierbare Zugriffe | #34 | `app_launcher.dart:46, :49, :53, :57, :61` | erfüllt |
| Reihenfolge preferred → XDG → `kKnownBrowsers` | #34 | `app_launcher.dart:174-207` | erfüllt |
| Doc-Kommentar exakt 5 Zeilen | #34 | `lib/layouts/hub/hub_shell.dart:143-147` | erfüllt |
| Fallback-Info-Snackbar | #34 | `hub_shell.dart:154-158` | erfüllt |
| Doku `Admin-Hub.md` | #34 | `docs/wiki/Admin-Hub.md:23-28` | erfüllt |
| Doku `hub-shell.md` | #34 | `docs/handoff/panels/hub-shell.md:55` | erfüllt |
| Doku `feature-spec-admin-hub.md` | #34 | `docs/design/feature-spec-admin-hub.md:44-46` | erfüllt |
| Doku `admin-hub-followups.md` | #34 | `docs/design/admin-hub-followups.md:23` | erfüllt (Checkliste manuell — **bleibt offen**) |
| trim + Allowlist + `/` ablehnen | #47 / #52 | `app_launcher.dart:133-138` (`sanitizePreferredBrowser`) | erfüllt |
| 4 Config-Pfad-Tests | #52 | `test/app_launcher_test.dart:251-268` | erfüllt |

**Erschwerend: `_validDesktopId` (app_launcher.dart:216-220) prüft die Desktop-ID zusätzlich gegen `/`, `..` und ein Namens-Regex — Härtung über die Issue-Spezifikation hinaus.**

## Design-Entscheidungen

1. **Kein Nachimplementieren.** Die Abnahme prüft den Ist-Stand gegen die Issue-Kriterien und schliesst nur ab, was belegbar erfüllt ist. Kein Refactoring von `app_launcher.dart` — die Datei ist frisch gemerged, das erhöht nur das Diff-Risiko ohne Nutzen.
2. **Checkboxen nur bei objektiv erfüllten Kriterien.** `admin-hub-followups.md:23` ist eine *manuelle* GUI-Checkliste (Sidebar, Browser-Klick, Quick Notes, Dateimanager, Systemmonitor). Ohne Bastis Rechner wird sie **nicht** abgehakt — sie ist der sichtbare Rest des Meilensteins.
3. **Issue-Schließung mit Evidenz, nicht mit Behauptung.** Jedes geschlossene Issue bekommt einen Kommentar mit `file:line`-Belegen und den Gate-Ausgaben. #34 wird geschlossen, weil alle drei Gates in seinem Body erfüllt sind; der manuelle Meilenstein-Abnahmeschritt (Brave Origin auf Zorin 18.1) wird im Meilenstein-Doc **sichtbar offen** gehalten und in PR + Issue-Kommentar ausdrücklich genannt.
4. **Der veraltete Branch `hardening/0.8.x-browser-xdg` wird nicht fortgeführt.** Er steht auf einem Merge-Stand vom 2026-09-23 (118 Dateien / 13.828 Zeilen hinter `main`) und ist durch den Squash-Merge in `add73e3` überholt. Er wird nur noch zur Löschung vorgemerkt — er ist superseded, kein Arbeitsstand.
5. **Commit-Aufteilung nach Doc-Art:** ein Commit für die Tracking-Doku, einer für den Nachweis. Getrennt, damit der Nachweis später nicht die Doku-Historie verdeckt.

## Tasks

- **Task 0 — Prep:** Branch `chore/v0.8.2-xdg-abschluss` von `main` (`add73e3`), Git-Identität `ElGregor <Bastick123@gmail.com>` (aus der Historie übernommen), Plan-Datei. Commit `docs(mla): SDD-Plan V0.8.2 XDG-Browser-Fix — Abnahme und Abschluss`.
- **Task 1 — Tracking-Doku:** `issues-v0.8.1-v0.8.5.md` (Issue 3/4-Checkboxen), `meilensteine-v0.8.1-v0.8.5.md` (Meilenstein 2: Codeseitig erfüllt + manueller Rest offen), `security-fixplan-42-50.md` (globale CI-Gates, WP-B1 als erledigt). Commit `docs(mla): V0.8.2 XDG-Browser-Fix — Tracking-Doku nachziehen`.
- **Task 2 — Nachweis-Doc:** `docs/handoff/v0.8.2-xdg-browser-abschluss.md` (neu, deutsch, `file:line`-evidenced nach `docs/handoff/`-Konvention): Kriterien-Tabelle, Gate-Protokoll, manueller Rest, Löschhinweis für den superseded Branch. Commit `docs(mla): Abnahme-Nachweis V0.8.2 XDG-Browser-Fix`.
- **Task 3 — Gates:** alle globalen Gates frisch mit echten Exitcodes: `tool/check-versions.sh`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, Python-Unit-Tests (`additional/python`, `prototype/gtk/tests`), `packages/la_core`-Gates. Optional, falls Build-Deps installierbar: `bash build-deb.sh` + `dpkg-deb -f linux-assistant.deb Depends` (Issue #35 Verify-Gate). Ergebnis in Task 2 nachtragen, falls nachträglich erzeugt.
- **Task 4 — Push + PR:** Branch über die Contents-API-Bridge publizieren, PR gegen `main` eröffnen. Body: Summary, Abnahme-Tabelle, Gate-Protokoll, manueller Rest, Merge-Hinweis.
- **Task 5 — Issues schließen:** #33, #34, #47, #52 mit Evidenz-Kommentar schließen; #35 nur, wenn das Build-Gate real grün läuft. Offen bleiben: #43, #48, #53–#56 (andere Work-Packages, nicht Teil dieses Plans).

## Boundary / bewusst draußen

- **Manueller Abnahmeschritt (Basti):** Browser-Werkzeug öffnet Brave Origin (Zorin 18.1) ohne Snackbar, plus die übrigen Checks in `docs/design/admin-hub-followups.md`. Ohne Desktop-Umgebung in dieser Sandbox nicht prüfbar.
- **Keine Implementierungsänderung** an `lib/services/app_launcher.dart`, `lib/layouts/hub/hub_shell.dart` oder `test/app_launcher_test.dart` — reine Abnahme.
- **Keine Version-Erhöhung, kein Tag, kein Release.** `version` bleibt `0.8.0`; Release-Entscheidung liegt bei Basti (`docs/wiki/Release-Process.md`).
- **Kein Merge in `main`** ohne Freigabe.
- **Kein Löschen von Branches** — die App hat kein Branch-Delete-Tool; `hardening/0.8.x-browser-xdg` wird zur manuellen Löschung gemeldet.

## Risiken

| Risiko | Gegenmaßage |
|---|---|
| Checkboxen werden getickt, ohne dass das Gate lief | Gate-Exitcodes im Nachweis-Doc festhalten, Ticks erst nach grünem Lauf |
| `flutter test` schlägt nach Doku-Änderung fehl | Doku-Änderungen liegen außerhalb `lib/`/`test/` — Format-Gate prüft nur `lib test` |
| Squash-Merge-Vorlage verhindert Commit-Nachweis | im Nachweis beide SHAs nennen: Original-Branch-Commit (`388811d`) und Squash in `main` (`add73e3`) |
| Manuelle Checks verschwinden unbemerkt | Meilenstein-Doc führt den manuellen Rest als offenen Punkt mit Zeilenangabe |
