# Contributing

## Workflow

1. **Spec zuerst** bei größeren Features (Vorbild:
   `docs/design/feature-spec-admin-hub.md`): Verhalten, Implementierung,
   Design-Tokens, Scope-Grenzen („bewusst NICHT“), Aufwand/Reihenfolge.
2. **Kleine PRs pro Feature** (E1–E4 waren je ein PR). Jeder PR:
   Branch von aktuellem `main`, aussagekräftiger Titel
   (`feat(scope): …`, `fix(test): …`, `docs: …`), Beschreibung mit
   Verifikations-Schritten.
3. **Merge-Commits** (kein Squash) – die Historie bleibt nachvollziehbar.
4. **Branches nach Merge löschen** (Einzeiler in
   `docs/design/admin-hub-followups.md` §4).

> Hinweis: Issues und GitHub-Milestones sind in diesem Repo deaktiviert.
> Tracking passiert als versionierte Doku unter `docs/design/`
> (z. B. `admin-hub-followups.md`, `milestone-v0.7.2.md`).

## Code-Konventionen

- **Tokens statt Hardcodes:** `HermesTokens.of(context)` / `context.mintY`
  (nach PR B). Keine neuen `Colors.*`/Hex-Werte in Screens. Bestehende
  Verstöße: `docs/design/design-audit-inconsistencies.md`.
- **Screens swappen, nicht pushen:** Neue Hub-Bereiche registrieren sich in
  der Modul-Registry ([[Architecture]]). Kein `Navigator.push` für
  Hub-interne Navigation.
- **Ressourcen-Disziplin:** Kein `Timer` in `build()`; Futures einmal in
  `initState` starten; `mounted` nach jedem `await`; Controller/Timer in
  `dispose()` aufräumen. Diese Klasse von Bugs hat `d221d0e` aufgeräumt –
  nicht wieder einführen.
- **Polling braucht Gating:** Siehe `SystemStatsService`
  (Subscriber + Section + Fenster). Screen-eigenes Sampling: `Ticker`
  statt `Timer` (TickerMode-Synergien).
- **Shell-outs sparsam:** `/proc` & Co. direkt lesen (File-Read statt
  `cat`-Fork). Forks auf dem Hot Path dokumentieren (vgl. Systemmonitor:
  `ps` + `df` pro Tick, `nvidia-smi` nur alle 5 s).
- **Destructive Aktionen:** Confirm-Dialog mit dem konkreten Objekt
  (Name/voller Pfad), rote Aktion, Guard-Tests im Service.
- **Services testbar:** Injizierbarer Konstruktor; Parser rein & statisch
  mit String-Fixtures.
- **Defensive Defaults:** Unbekannte Config-Werte fallen auf Defaults
  zurück statt zu werfen.

## Tests

Neue Services/Screens kommen mit Tests ([[Testing]]). Erwartungswerte für
Rechenlogik per Rechnung verifizieren, nicht schätzen.

## L10n

Neue UI-Strings → Keys in `lib/l10n/app_en.arb` + `app_de.arb`, dann
`flutter gen-l10n`. Aktuell gibt es einen `_tr()`-Übergangs-Helper in der
Werkzeuge-Sektion (Ablösung: `admin-hub-followups.md` §2) – bitte keine
neuen `_tr()`-Stellen mehr hinzufügen.

## Python-Helfer

`additional/python/get_environment.py` wird **zeilenindiziert** gelesen:
neue Ausgaben nur hinten anhängen, nie dazwischen einfügen.

## Review-Checkliste für PRs

- [ ] `flutter test` lokal grün
- [ ] Keine neuen Hardcode-Farben
- [ ] Destructive Aktionen mit Confirm + Tests
- [ ] Polling/Timer: Gating bzw. dispose vorhanden
- [ ] Docs aktualisiert (Spec/Wiki/Followups), wenn Verhalten sich ändert
