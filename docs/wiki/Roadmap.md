# Roadmap

Stand: 2026-09-18. Tracking-Dokumente leben unter `docs/design/` (Issues
sind im Repo deaktiviert).

## Aktuell: v0.8.0 veröffentlicht, v0.8.1–v0.8.5 in Planung

`v0.8.0` ist getaggt („alles nutzbar“). Die weitere Planung liegt in
`meilensteine-v0.8.1-v0.8.5.md`, `issues-v0.8.1-v0.8.5.md` und
`release-plaene-v0.8.1-v0.8.5.md` (Repo-Root).

## Kandidaten (Stand nach v0.8.0)

| Thema | Quelle | Aufwand |
|---|---|---|
| Golden-Baselines (Setup + neue Screens) | followups §3 | ½–1 Tag |
| PR B abschließen: Dashboard-Widgets auf `MintYColors` (der `single_bar_chart.dart`-Mutations-Hack wurde im 0.8.0-Hardening **ersetzt**) | Tracker #10, Audit §2.1 | 1–2 Tage |
| ~~`main.dart`-Fallback `Colors.blue` → Mint; `#7F7FFF` zuordnen~~ — erledigt | Audit F1/F2 | 15 min |
| ~~Analyzer-Backlog abbauen (189 Findings), dann `flutter analyze` in CI~~ — erledigt: 0 Findings, analyze-Gate scharf | Commit `1e90957` | laufend |

## Danach: PR C/D (Design-Audit-Fixliste)

Priorisiert nach `design-audit-inconsistencies.md` §3:

- `secondaryHeaderColor` → `chartTrack` (cleaner-Screens)
- `Colors.grey` Info-Box (security_check) → `surfaceRaised`
- `Colors.black54` (power_mode) → `inactive`-Token
- `Colors.red`-Reste → `statusDanger`
- Terminal-Farben + Courier (run_command_queue) → Tokens
- Settings-State-String → echte Routen (PR C, größer)
- Fokus-Ringe / A11y-Zustände (Komponenten-Härtung, Phase 3)
- Widgetbook für Kern-Komponenten (Phase 3, Schritt 5)

## Werkzeug-v2 (nicht terminiert, Spec-Kandidaten)

| Tool | v2-Ideen |
|---|---|
| Quick Notes | Markdown-Preview, Sync-Provider (`NotesService` ist Interface) |
| Dateimanager | Copy/Move/Rename, rekursive Größen on-demand, Drag&Drop, Tabs |
| Systemmonitor | AMD/Intel-GPU, Per-Interface-Sparklines, Prozess-Details |
| Browser | Eigener Fenster-Host statt externem Launch (Playbook §4) |

## Backlog (Hermes-Layer)

Kriterien aus `docs/design/hermes-backlog.md` beachten (die Datei liegt auf
dem Branch `origin/backlog/hermes-layer`, nicht im Main): Weiterentwicklung
der Hermes-Widgets (Audits, Varianten, Doku im Komponenten-Katalog) erst
nach Reaktivierung.

## Prinzip

Reihenfolge bleibt: **Verifizieren → Härten → Erweitern.** Erst grüne
Suite + verifizierte v0.8.0, dann Token-Migration, dann neue Features.
