# MLA Next: GTK4-Prototyp und Coding-Agenten-Masterplan

Stand 2026-09-25. Isolierter Prototyp-Track für Master Linux Assistant auf Zorin OS 18.1 GNOME. Ausgangspunkt main 92bef600; vor jeder Aufgabe neu prüfen. Kein Release, kein Flutter-Ersatzbeschluss. Paket/Binär/Policy/Datenpfade bleiben vorerst linux-assistant. Bestehende v0.8.x–v1.0-Roadmap bleibt gültig; MLA-Next 0.0.1–0.4.x ist ein getrenntes Experiment. 0.5 bleibt offen.

## Grenzen

- GTK-UI, Flutter-UI und Dart-Host nie als Root. Keine generische Root-IPC, Shell-Strings, Agenten-Ausführung oder Secrets in Logs/Screenshots/Commits. Vorhandene polkit-Grenze nicht umgehen.
- Dieser Commit enthält ausschließlich neue Dateien unter prototype/gtk und docs/mla-next. Demo-Daten, keine Systemänderung, keine Behauptung ausgeführter Tests. Keine Integration mit install.sh, deb oder main.
- Issue #59 ist der Headless-Spike für packages/la_core; #60 betrifft die Registry; #63 das Backup-Cockpit aus Units, Timern und Journal. Agenten müssen aktuelle Issue-Bodies lesen, bevor sie implementieren. Der rsync-Ordnerkopier-Prototyp ist ausdrücklich nicht Teil von #63.

## Architektur

GTK4/libadwaita ist ein unprivilegierter UI-Adapter; bestehendes Flutter bleibt Vergleichsbasis. Reiner Dart-Kern packages/la_core enthält Probe-/Parsermodelle, Registry, DI und Event-Vertrag ohne Flutter-/GTK-Typen. Deskriptor: id, titleKey, viewId, kind, capabilities, requires, probeIds, actionIds und subscribedTopics. View-Factories gehören in UI-Adapter. Registry prüft doppelte IDs/Zyklen, aktiviert Abhängigkeiten Single-Flight und stoppt rückwärts. Kein dynamisches Fremdcode-Plugin.

Fenster: AdwApplicationWindow → AdwNavigationSplitView → Sidebar und AdwToolbarView mit HeaderBar; Hauptbereich GtkStack und kontextuelle rechte Leiste. Golden/Cream/Navy über semantische Tokens; keine Polls in unsichtbaren Ansichten. Diagramme zeigen Einheiten, Messzeit und Quelle.

IPC erst nach isoliertem Spike: JSON-RPC 2.0 über privaten Unix-Socket im XDG_RUNTIME_DIR, hello/Capabilities, 64-KiB-Framelimit vor Parsing, Peer-UID, begrenzte Queues, Timeout, Reconnect, Snapshot nach Event-Lücke; Same-UID ist keine Sandbox. Schreibende Aktionen benötigen serverseitige Allowlist und bestätigte Nutzerauswahl. Keine Backups über Repo-Tokens oder Restic-Passwörter.

Backup nach #63: User-/System-Units, letzter Lauf, Result/Journal-Evidenz, nächster Timer, Heartbeat. Zustände unknown/stale/failed/running/ok unterscheiden. `systemctl --user start` nur für erneut validierte User-Unit nach Bestätigung. System-Unit bleibt lesend. Erfolgreicher Unit-Exit ist kein Restore-Nachweis; Prozent nur bei echter Datenquelle.

## Versionen und Gates

- 0.0.1: isolierte GTK-Shell mit Fixture-Dashboard, Backup und Security; Syntaxcheck, Wayland/X11, Hell/Dunkel, Resize, Tastatur; keine schreibende Funktion.
- 0.0.2: #59 Dart-Headless-Probe und #60 Registry-Vertrag; `dart test`, `dart compile exe`, Lauf ohne DISPLAY/WAYLAND_DISPLAY und bestehende Flutter-Tests.
- 0.0.3: gemeinsame Fixtures, Fehler-/Stale-Modelle, CPU-/RAM-/Startzeit-Baseline gegen Flutter-Release-Build auf demselben Zorin-Rechner.
- 0.1.0–0.1.x: lesender Monitor, Drill-down, Ringpuffer, Pausieren im Hintergrund, Langlauf und Accessibility; Werte gegen /proc plausibilisieren.
- 0.2.0–0.2.x: Notes, Dateiansicht, sicherer Dokument-Reviewer, Suchpalette, kontextuelle Browser-/Terminal-Aktionen; keine stillen Fremdclients.
- 0.3.0–0.3.x: Security-/Operations-Lagebild, Dienste/Timer und #63 Backup; Agent-Gateway nur für Diagnose und einzeln genehmigte Aktionen mit Audit.
- 0.4.0–0.4.x: Computer-Use-Evaluation, Wayland-Freigaben, Stop-Schalter, Sicherheits-/Performance-Regressionsmatrix, Packaging-/Upgrade-Probe und dokumentierte Flutter-vs-GTK-Entscheidung samt Rückfallplan.
- 0.5: offen; erst anhand 0.4.x-Evidenz definieren.

## Agenten-Arbeitspakete

A0 Baseline: aktuellen SHA, Issues/PRs, Flutter-Gates, Zorin-Matrix und Evidence-Map erfassen. A1 Tokens/UI-Design: Semantik, Accessibility, Fokus, Screenshots. A2 GTK-Fixture-Shell mit Test-Fakes und sauberem Lifecycle. A3 la_core: Parser/Probe, DI, Registry, Flutter-Adapter. A4 IPC: Schema, Peer- und Framing-Tests, kein Root-Execute. A5 Monitoring/Diagramme mit Zeit-/Einheiten-Validierung. A6 Backup gemäß #63 mit Unit-/Timer-/Journal-Fixtures. A7 optionale Tools mit Dateisicherheitsgrenzen. A8 Agenten-Gateway mit Audit und Nutzerfreigaben. A9 Benchmarks, Sicherheitsreview, Zorin-E2E, Merge-Entscheidung.

Je Task: Scope/Dateien/Fixture/Failing-Test zuerst, minimaler Implementierungsschritt, Reviewer 1 für Funktion/UX/Races, Reviewer 2 für Privilegien/Secrets/argv/IPC. Handoff enthält Commit-SHA, tatsächlich ausgeführte Gates, rote/übersprungene Gates und Rückfallplan. Keine Behauptung 'fertig' ohne Test. Bei wiederholten Fehlschlägen Root Cause statt blindem Patchen.

## Start und Nicht-Ziele

`python3 -m py_compile prototype/gtk/mla_app.py`; danach auf Zorin mit PyGObject, GTK4 und libadwaita `python3 prototype/gtk/mla_app.py`. Diese Befehle sind Vorschläge, nicht hier ausgeführt. Keine Änderungen an bestehenden Flutter-, Python-, Policy-, Packaging- oder Release-Dateien. Kein Push auf Upstream; kein Merge in main ohne separate Freigabe.
