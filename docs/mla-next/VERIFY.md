# MLA-Next: Verifikation und Handoff

Stand dieses Branchs: keine hier dokumentierten GTK-Laufzeit-, Zorin-, IPC- oder Performance-Tests ausgeführt. Der Scaffold-Commit ist **kein** Release-Gate.

## Gate 0: Scaffold

- [ ] `python3 -m py_compile prototype/gtk/mla_app.py` grün, Ausgabe und Python-Version erfassen.
- [ ] Auf Zorin OS 18.1 als normaler Nutzer starten; GTK4/libadwaita-Version, Wayland/X11 festhalten.
- [ ] Dashboard, Monitor, Backup und Security anwählen; Titel, rechte Details und unbekannten Backup-Status prüfen.
- [ ] Fenster verkleinern/vergrößern; Tastatur/Fokus, Hell/Dunkel, 100/125/150%-Skalierung prüfen.
- [ ] App ohne Root, ohne Systemschreibfunktion, ohne Secrets in Screenshots/Logs.

## Gate 1: Kern/Registry

- [ ] Issue #59: `dart test` und `dart compile exe`; Probe ohne DISPLAY/WAYLAND_DISPLAY; Binärgröße/Startzeit messen.
- [ ] Issue #60: IDs eindeutig, fehlende/zyklische Abhängigkeiten abgewiesen, Start/Stop/Lazy-Loading getestet; Flutter-Navigation unverändert.
- [ ] Bestehende Repo-Gates nach Scope tatsächlich ausführen: `tool/check-versions.sh`, `dart format`, `flutter analyze`, `flutter test`, Python-Tests.

## Gate 2: IPC und Backup

- [ ] Frame-/UTF-8-/JSON-/Schema-/Timeout-/Reconnect-/Backpressure-Tests; falsche Peer-UID und Event-Lücke.
- [ ] Issue #63: User-/System-Units, Timer, Journal-Fehler und Unknown/Stale mit Fixtures; keine Repo-/Passwortzugriffe.
- [ ] `systemctl --user start` nur nach Bestätigung und serverseitiger Allowlist; Abbruch, Race und Doppel-Request prüfen.
- [ ] Kein grünes Backup allein wegen eines erfolgreichen Unit-Starts; Restore separat beurteilen.

## Agenten-Handoff

Je Aufgabe: Basis-SHA, Pfade, Scope, Failing-Test/Fixture, Umsetzung, Ergebnis von Reviewer 1 (Funktion/UX) und Reviewer 2 (Sicherheit), **wirklich ausgeführte** Gates mit Ausgaben, rote/übersprungene Gates, manuelle Zorin-Prüfung, Rückfallplan. Kein Merge/Release/Policy-Update ohne gesonderte Freigabe.
