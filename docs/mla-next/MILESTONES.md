# MLA-Next — Milestones

> Spiegel der GitHub-Milestones (Stand 2026-09-30). Track: getrenntes GTK4-Experiment; die Roadmap V0.8.x–V1.0 bleibt gültig. Quelle der Wahrheit ist GitHub; diese Datei ist ein 1:1-kopierbarer Stand.

## MLA-Next 0.0.1 – GTK-Fixture-Shell

Isolierte GTK4-Shell (Python/PyGObject, libadwaita) mit Fixture-Dashboard, Backup und Security: nur Demo-Daten, keine schreibende Funktion, kein Root. Teil des getrennten MLA-Next-Experiments (`docs/mla-next/`, Draft-PR #89); die Roadmap V0.8.x–V1.0 bleibt gültig, es gibt keinen Flutter-Ersatzbeschluss.

Erfolgskriterium: Gate 0 aus `docs/mla-next/VERIFY.md` — `py_compile` grün, Start als normaler Nutzer auf Zorin OS 18.1 in Wayland und X11, manuelle Prüfung (Dashboard/Monitor/Backup/Security, Resize, Tastatur/Fokus, Hell/Dunkel, 100/125/150 %). Stand 2026-09-30: automatisierte Teile belegt, manuelle Liste offen.

## MLA-Next 0.0.2 – Dart-Kern & Registry

#59 Headless-Probe (`packages/la_core`, `la_probe`) und #60 Registry-Vertrag (ID-/Zyklenprüfung, Single-Flight-Aktivierung, Rückwärts-Stopp). Reiner Dart-Kern ohne Flutter-/GTK-Typen; die Roadmap-Issues #59/#60 bleiben im Milestone V0.9, hier steht der Rest (A3).

Erfolgskriterium: Gate 1 — `dart test` und `dart compile exe` grün, Probe läuft ohne DISPLAY/WAYLAND_DISPLAY, bestehende Flutter-Tests unverändert grün. Stand 2026-09-30: Spike und Registry-Kern im Branch belegt (`docs/mla-next/BASELINE.md` §7).

## MLA-Next 0.0.3 – Fixtures & Baseline

Gemeinsame Fixtures, Fehler-/Stale-Modelle und die Vergleichsbasis: CPU-, RAM- und Startzeit-Baseline gegen den Flutter-Release-Build auf demselben Zorin-Rechner.

Erfolgskriterium: Messprotokoll mit Kommando, Sitzungstyp (Wayland/X11) und Rohwerten; die Zustände unknown/stale/failed/running/ok sind per Fixture getestet; das Protokoll nennt, was nicht verglichen wurde.

## MLA-Next 0.1.x – Lesender Monitor

Lesender Monitor mit Drill-down und Ringpuffer, Pausieren im Hintergrund, Langlauf und Accessibility. Diagramme zeigen Einheit, Messzeit und Quelle; nichts Schreibendes.

Erfolgskriterium: Werte gegen `/proc` plausibilisiert; keine Polls in unsichtbaren Ansichten; Langlauf ohne Speicherzuwachs; Bedienung vollständig per Tastatur.

## MLA-Next 0.2.x – Notes, Dateien & Palette

Notes, Dateiansicht, sicherer Dokument-Reviewer, Suchpalette sowie kontextuelle Browser-/Terminal-Aktionen. Keine stillen Fremdclients; Dateizugriffe halten dokumentierte Sicherheitsgrenzen.

Erfolgskriterium: Tests für Pfadtricks (`..`, Symlinks, sehr große und binäre Dateien) grün; jede Aktion mit Seiteneffekt braucht eine Bestätigung; Reviewer 2 hat die Dateigrenzen geprüft.

## MLA-Next 0.3.x – Lagebild, Dienste & Backup

Security-/Operations-Lagebild, Dienste/Timer und #63 Backup auf einem unprivilegierten Dart-Host mit IPC (JSON-RPC 2.0 über privaten Unix-Socket). Agenten-Gateway nur für Diagnose und einzeln genehmigte Aktionen mit Audit. Zuordnung der Pakete zu dieser Version ist ein Vorschlag (AGENT_PLAN nennt die Version für IPC nicht).

Erfolgskriterium: Gate 2 — IPC-Tests (Frame, UTF-8, JSON, Schema, Timeout, Reconnect, Backpressure, falsche Peer-UID, Event-Lücke); #63 mit Unit-/Timer-/Journal-Fixtures; `systemctl --user start` nur nach Bestätigung und Allowlist; kein grünes Backup allein wegen eines erfolgreichen Unit-Starts.

## MLA-Next 0.4.x – Evaluation & Entscheidung

Computer-Use-Evaluation, Wayland-Freigaben, Stop-Schalter, Sicherheits-/Performance-Regressionsmatrix, Packaging-/Upgrade-Probe und die dokumentierte Flutter-vs-GTK-Entscheidung samt Rückfallplan. 0.5 ist offen und wird erst anhand der 0.4.x-Evidenz definiert.

Erfolgskriterium: Regressionsmatrix ausgeführt und belegt; Packaging-/Upgrade-Probe belegt; Entscheidung und Rückfallplan dokumentiert. Merge, Release und Policy-Updates nur nach gesonderter Freigabe von Basti.

