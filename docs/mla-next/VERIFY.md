# MLA-Next: Verifikation und Handoff

Aktualisierung 2026-09-30: Die GTK-Scaffold-Laufzeit ist auf Zorin verifiziert (Wayland- und X11-Start — Gate 0, BASELINE §2; manuelle Checks offen), la_core-Spike und Registry sind getestet inkl. Performance-Messwerten (Gate 1, BASELINE §7). Weiterhin nicht ausgeführt: IPC-/Gate-2-Tests, Flutter-vs-GTK-Vergleichsmessung (Roadmap 0.0.3), manuelle Gate-0-Checks (BASELINE §3). Der Scaffold-Commit ist **kein** Release-Gate.

## Gate 0: Scaffold

- [x] `python3 -m py_compile prototype/gtk/mla_app.py` grün, Ausgabe und Python-Version erfassen. — 2026-09-29: automatisiert verifiziert, siehe docs/mla-next/BASELINE.md; manuelle Checks offen
- [x] Auf Zorin OS 18.1 als normaler Nutzer starten; GTK4/libadwaita-Version, Wayland/X11 festhalten. — 2026-09-29: automatisiert verifiziert, siehe docs/mla-next/BASELINE.md; manuelle Checks offen
- [ ] Dashboard, Monitor, Backup und Security anwählen; Titel, rechte Details und unbekannten Backup-Status prüfen.
- [ ] Fenster verkleinern/vergrößern; Tastatur/Fokus, Hell/Dunkel, 100/125/150%-Skalierung prüfen.
- [x] App ohne Root, ohne Systemschreibfunktion, ohne Secrets in Screenshots/Logs. — 2026-09-29: unprivilegierter Start als normaler Nutzer, Fixture-Only (Demo-Daten, keine Systemaktionen), Screenshots nur /tmp — siehe docs/mla-next/BASELINE.md

## Gate 1: Kern/Registry

- [x] Issue #59: `dart test` und `dart compile exe`; Probe ohne DISPLAY/WAYLAND_DISPLAY; Binärgröße/Startzeit messen. — 2026-09-30: `dart test` 14/14 in packages/la_core (frisch); `dart compile exe` + Headless-Lauf ohne DISPLAY/WAYLAND_DISPLAY; Binär 6 547 240 Bytes, Median-Startzeit 3 ms — siehe docs/mla-next/BASELINE.md §7
- [x] Issue #60: IDs eindeutig, fehlende/zyklische Abhängigkeiten abgewiesen, Start/Stop/Lazy-Loading getestet; Flutter-Navigation unverändert. — 2026-09-30: `dart test` 14/14 in packages/la_core (doppelte IDs, fehlende/zyklische Abhängigkeiten, Topo-Start/Rückwärts-Stop, Single-Flight); `git diff --stat 92bef60..HEAD -- lib/ additional/ deb/ linux/` leer (Exit 0); Root-`flutter test` +184 bestanden
- [x] Bestehende Repo-Gates nach Scope tatsächlich ausführen: `tool/check-versions.sh`, `dart format`, `flutter analyze`, `flutter test`, Python-Tests. — 2026-09-30 frisch ausgeführt, alle Exit 0: `version 0.8.0 is consistent`; `Formatted 118 files (0 changed)`; `No issues found!`; `00:02 +184: All tests passed!`; `Ran 49 tests` / `OK` — vgl. docs/mla-next/BASELINE.md §4

## Gate 2: IPC und Backup

- [ ] Frame-/UTF-8-/JSON-/Schema-/Timeout-/Reconnect-/Backpressure-Tests; falsche Peer-UID und Event-Lücke.
- [ ] Issue #63: User-/System-Units, Timer, Journal-Fehler und Unknown/Stale mit Fixtures; keine Repo-/Passwortzugriffe.
- [ ] `systemctl --user start` nur nach Bestätigung und serverseitiger Allowlist; Abbruch, Race und Doppel-Request prüfen.
- [ ] Kein grünes Backup allein wegen eines erfolgreichen Unit-Starts; Restore separat beurteilen.

## Agenten-Handoff

Je Aufgabe: Basis-SHA, Pfade, Scope, Failing-Test/Fixture, Umsetzung, Ergebnis von Reviewer 1 (Funktion/UX) und Reviewer 2 (Sicherheit), **wirklich ausgeführte** Gates mit Ausgaben, rote/übersprungene Gates, manuelle Zorin-Prüfung, Rückfallplan. Kein Merge/Release/Policy-Update ohne gesonderte Freigabe.
