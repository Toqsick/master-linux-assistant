# MLA-Next — Issues

> Spiegel der GitHub-Issues mit Label `track:mla-next` (Stand 2026-09-30). Zuordnung Schlüssel → Issue-Nummer steht in der Tabelle.

| Schlüssel | Issue | Milestone |
|---|---|---|
| A0 | #90 | MLA-Next 0.0.1 – GTK-Fixture-Shell |
| A1 | #91 | MLA-Next 0.0.1 – GTK-Fixture-Shell |
| A2 | #92 | MLA-Next 0.0.1 – GTK-Fixture-Shell |
| A3 | #93 | MLA-Next 0.0.2 – Dart-Kern & Registry |
| FX | #94 | MLA-Next 0.0.3 – Fixtures & Baseline |
| BL | #95 | MLA-Next 0.0.3 – Fixtures & Baseline |
| A5 | #96 | MLA-Next 0.1.x – Lesender Monitor |
| A5B | #97 | MLA-Next 0.1.x – Lesender Monitor |
| A7 | #98 | MLA-Next 0.2.x – Notes, Dateien & Palette |
| A7B | #99 | MLA-Next 0.2.x – Notes, Dateien & Palette |
| A4 | #100 | MLA-Next 0.3.x – Lagebild, Dienste & Backup |
| A6 | #101 | MLA-Next 0.3.x – Lagebild, Dienste & Backup |
| LG | #102 | MLA-Next 0.3.x – Lagebild, Dienste & Backup |
| A8 | #103 | MLA-Next 0.3.x – Lagebild, Dienste & Backup |
| E1 | #104 | MLA-Next 0.4.x – Evaluation & Entscheidung |
| E2 | #105 | MLA-Next 0.4.x – Evaluation & Entscheidung |
| E3 | #106 | MLA-Next 0.4.x – Evaluation & Entscheidung |

---

## #90 — [Next 0.0.1] A0 Baseline & Evidence-Map

**Milestone:** MLA-Next 0.0.1 – GTK-Fixture-Shell · **Labels:** `track:mla-next`, `size:S`

### Body

```markdown
## Scope
Ausgangslage für alle MLA-Next-Pakete festhalten: aktueller SHA, Issues/PRs, Flutter-Gates, Zorin-Matrix und eine Evidence-Map (Aussage → Kommando + Kernausgabe). Ergebnis: `docs/mla-next/BASELINE.md` auf `feature/mla-gtk-scaffold` (Draft-PR #89). Vor jeder neuen Aufgabe wird der SHA neu geprüft.

## Abnahme
- [x] Zorin-Matrix erfasst (Zorin OS 18.1, Wayland, GTK 4.14.5, libadwaita 1.5.0, Dart 3.13.4, Flutter 3.47.5) — `BASELINE.md` §1
- [x] Repo-Gates frisch ausgeführt: `check-versions.sh`, `dart format` (118 Dateien, 0 geändert), `flutter analyze` (0 Findings), `flutter test` (+184), Python-Tests (49, OK) — §4; am 2026-09-30 erneut Exit 0 (`VERIFY.md` Gate 1)
- [x] Evidence-Map: jede Aussage mit Kommando und Kernausgabe — §5
- [ ] Wayland-Screenshot nachholen (nur manuell; `gnome-screenshot` fehlt, D-Bus-API verweigert) — §6 Punkt 2
- [ ] `-dev`-Pakete für künftige C-Builds klären (`gtk4.pc`/`libadwaita-1.pc` fehlen) — §6 Punkt 3
- [ ] §6 Punkt 4 (`analysis_options.yaml`-Exclude) abgleichen: Commit `1367d3c` übernimmt die Excludes bereits, der Text in `BASELINE.md` führt den Punkt noch als offen

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: —
Blockiert: alle weiteren MLA-Next-Pakete (Vergleichsgrundlage).

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (A0), `docs/mla-next/BASELINE.md`._
```

---

## #91 — [Next 0.0.1] A1 Tokens & UI-Design

**Milestone:** MLA-Next 0.0.1 – GTK-Fixture-Shell · **Labels:** `track:mla-next`, `size:M`, `gate:manual`

### Body

```markdown
## Scope
Semantische Tokens für die GTK4/libadwaita-Oberfläche (Golden/Cream/Navy, hell und dunkel), Accessibility, Fokus und Screenshot-Regeln. Fensteraufbau laut Plan: `AdwApplicationWindow` → `AdwNavigationSplitView` (Sidebar + `AdwToolbarView` mit HeaderBar), Hauptbereich `GtkStack` plus kontextuelle rechte Leiste. Keine Polls in unsichtbaren Ansichten; Diagramme zeigen Einheit, Messzeit und Quelle.

Offen (im Task-Spec zu klären): ob Token-Namen an `HermesTokens` der Flutter-App angelehnt werden (Vergleichbarkeit) oder GTK-eigen bleiben.

**Grenzen (gelten für jedes MLA-Next-Paket):** GTK-UI, Flutter-UI und Dart-Host laufen nie als Root; keine generische Root-IPC, keine Shell-Strings, keine Secrets in Logs, Screenshots oder Commits; die vorhandene polkit-Grenze bleibt unberührt.

## Abnahme
- [ ] Token-Liste (Farben hell/dunkel, Abstände, Typografie) liegt unter `docs/mla-next/`; die Shell nutzt keine harten Farbwerte außerhalb der Token-Definition
- [ ] Kontrast je Token-Paar geprüft; Zielwert legt der Task-Spec fest
- [ ] Tastatur: vollständige Fokusreihenfolge, sichtbarer Fokusring in allen Bereichen
- [ ] Screenshots hell/dunkel bei 100/125/150 % (ohne Secrets; nur als Artefakt, nicht im Repo)
- [ ] Wayland **und** X11

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #90 (Baseline)
Blockiert: #92, #96

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (A1, Architektur)._
```

---

## #92 — [Next 0.0.1] A2 GTK-Fixture-Shell mit Test-Fakes & Lifecycle

**Milestone:** MLA-Next 0.0.1 – GTK-Fixture-Shell · **Labels:** `track:mla-next`, `size:M`, `gate:verify`, `gate:manual`

### Body

```markdown
## Scope
`prototype/gtk/mla_app.py` als lauffähige Fixture-Shell: Dashboard, Monitor, Backup und Security mit Demo-Daten; Test-Fakes statt Systemzugriff; sauberer Lifecycle (Start, Beenden, Ressourcen). Umsetzung des Gate 0 aus `docs/mla-next/VERIFY.md`. Der Scaffold-Commit ist **kein** Release-Gate.

**Grenzen (gelten für jedes MLA-Next-Paket):** GTK-UI, Flutter-UI und Dart-Host laufen nie als Root; keine generische Root-IPC, keine Shell-Strings, keine Secrets in Logs, Screenshots oder Commits; die vorhandene polkit-Grenze bleibt unberührt.

## Abnahme
- [x] `python3 -m py_compile prototype/gtk/mla_app.py` grün — 2026-09-29, `BASELINE.md` §2
- [x] Start als normaler Nutzer auf Zorin OS 18.1 (GTK 4.14.5, libadwaita 1.5.0) unter Wayland und X11, je ≥ 3 s am Leben, stderr leer — automatisiert, §2; Wayland-Lebensbeleg nur indirekt (§2/§6 Punkt 1)
- [x] Ohne Root, ohne Systemschreibfunktion, ohne Secrets in Screenshots/Logs (Fixture-Only)
- [ ] Dashboard, Monitor, Backup, Security anwählen; Titel, rechte Details und unbekannten Backup-Status prüfen (manuell, `BASELINE.md` §3)
- [ ] Fenster verkleinern/vergrößern; Tastatur/Fokus; Hell/Dunkel; 100/125/150 % (manuell, §3)
- [ ] Test-Fakes: die Shell läuft gegen Fixtures ohne echte Systemaufrufe; Lifecycle (Start/Beenden) getestet — Testform legt der Task-Spec fest

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #90, #91 (Tokens)
Blockiert: Milestone 0.0.2 und folgende (die Shell ist der UI-Adapter)

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (A2, 0.0.1), `docs/mla-next/VERIFY.md` (Gate 0)._
```

---

## #93 — [Next 0.0.2] A3 la_core-Rest: Parser, DI, Event-Vertrag, Flutter-Adapter

**Milestone:** MLA-Next 0.0.2 – Dart-Kern & Registry · **Labels:** `track:mla-next`, `size:L`, `gate:test`

### Body

```markdown
## Scope
Fortsetzung von #59 (Headless-Probe) und #60 (Registry), deren Kern im Branch `feature/mla-gtk-scaffold` umgesetzt und belegt ist (Gate 1). Rest für den reinen Dart-Kern `packages/la_core` ohne Flutter-/GTK-Typen:
- Parser/Probe-Modelle für `free`, `df`, `uptime`, `ps` (Quellen: `lib/services/system_stats_service.dart`, `lib/linux/linux_filesystem.dart`, `lib/linux/linux_system.dart`, `lib/linux/linux_process.dart`)
- Dependency Injection und Event-Vertrag
- Flutter-Adapter (path-Dependency) für die bestehende App
- Deskriptor: id, titleKey, viewId, kind, capabilities, requires, probeIds, actionIds, subscribedTopics; View-Factories gehören in die UI-Adapter

Nicht: `linux.dart` komplett zerlegen; dynamische Fremdcode-Plugins.

## Abnahme
- [x] Parser mit Fixtures aus echten, geschwärzten Zorin-Ausgaben; `dart test` grün; die bestehenden Flutter-Parser-Tests (`test/system_parsers_test.dart`) laufen unverändert — Schnitt 1 (`080becf`): `test/system_parsers_test.dart` byte-identisch (sha `d78d0141…`).
- [x] DI und Event-Vertrag: Tests für Registrierung, Auflösung und Fehlerfälle — Schnitt 2 (2026-09-30): `command_runner`/`cpu_info`/`event_bus`/`probe_registry`-Tests, la_core 30 → 52.
- [x] Flutter-Adapter bindet `la_core` ein; Root-`flutter test` bleibt grün (Stand 2026-09-29: +184) — 2026-09-30: `+200: All tests passed!` (la_core als path-Dependency, keine App-Test-Änderung).
- [x] `dart compile exe` und Lauf ohne DISPLAY/WAYLAND_DISPLAY bleiben grün (Gate 1) — 2026-09-30: `Generated: /tmp/la_probe`; `la_probe 0.0.1-spike.1 (dart 3.13.4 … linux_x64)` headless.
- [x] `git diff --stat <Basis>..HEAD -- lib/ additional/ deb/ linux/` zeigt nur die beabsichtigten Adapter-Änderungen; der Spike selbst hatte hier einen leeren Diff — die Abweichung wird im Handoff begründet — 2026-09-30 gegen `6c5c625`: nur `lib/helpers/command_helper.dart`, `lib/linux/linux_system.dart`, `lib/services/linux.dart`.

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [x] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest — Basis `6c5c625`; Abschnitt „Handoff #93 Schnitt 2" in `docs/mla-next/VERIFY.md`.
- [x] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft — adversarialer Workflow `mla-93-rest-verify` (3 Sonnet-Linsen + Synthese): **PASS** ohne Blocker.
- [x] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt — Gate-Tabelle im Handoff-Abschnitt; nicht ausgeführt: Prozess-Spawn-Beweis, CI, manuelle Zorin-Checks (benannt).
- [x] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe — eingehalten: Schnitt 2 nur committet/gepusht, PR offen; Merge/Close von #93 wartet auf Freigabe.

## Abhängigkeiten
Blockiert durch: #59 und #60 (Kern; Roadmap-Issues in V0.9)
Blockiert: #96, #100, #94

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (A3), `docs/mla-next/VERIFY.md` (Gate 1)._
```

---

## #94 — [Next 0.0.3] Gemeinsame Fixtures + Fehler-/Stale-Modelle

**Milestone:** MLA-Next 0.0.3 – Fixtures & Baseline · **Labels:** `track:mla-next`, `size:M`, `gate:test`

### Body

```markdown
## Scope
Eine Fixture-Bibliothek, die Flutter- und GTK-Track gemeinsam nutzen (echte, geschwärzte Zorin-Ausgaben; Ablageort legt der Spec fest — `test/fixtures/` existiert noch nicht). Dazu Fehler- und Stale-Modelle: `unknown`, `stale`, `failed`, `running`, `ok` sind getrennte Zustände; `stale` ist UI-/Transportstatus und wird nie stillschweigend zu `ok` (`IPC_CONTRACT.md`).

## Abnahme
- [ ] Fixtures liegen an einem Ort; beide Tracks lesen sie, kein Duplikat
- [ ] Schwärzung dokumentiert; Leak-Check (keine Hosts, IPs, Ports, `/home`-Pfade) auf allen Fixtures leer
- [ ] Tests für jeden Zustand, den Übergang ok → stale und den Fehlerpfad
- [ ] Abgrenzung zu QA3 (#87, V1.0): dieser Task liefert die Basis, QA3 konsolidiert den Bestand

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #93
Blockiert: #95, #96, #101

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (0.0.3), `docs/mla-next/IPC_CONTRACT.md`._
```

---

## #95 — [Next 0.0.3] Baseline-Messung Flutter-Release vs. GTK

**Milestone:** MLA-Next 0.0.3 – Fixtures & Baseline · **Labels:** `track:mla-next`, `size:S`, `gate:verify`

### Body

```markdown
## Scope
CPU-, RAM- und Startzeit-Baseline des Flutter-Release-Builds gegen die GTK-Shell auf demselben Zorin-Rechner. Vorhanden: `la_probe` (Binär 6 547 240 Bytes, Median-Startzeit 3 ms, `BASELINE.md` §7) und die Zorin-Matrix (§1). Neu: Leerlauf und Fixture-Last für beide Varianten.

## Abnahme
- [ ] Messprotokoll in `docs/mla-next/BASELINE.md`: Kommando, Rechner, Sitzungstyp, Datum, Rohwerte
- [ ] Wiederholungen mit Median wie beim `la_probe`-Spike (5 Läufe je Variante)
- [ ] Wayland und X11 getrennt ausgewiesen
- [ ] Das Ergebnis nennt ausdrücklich, was nicht verglichen wurde

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #94, #92
Blockiert: #105 (Vergleichsbasis der Regressionsmatrix)

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (0.0.3), `docs/mla-next/BASELINE.md` §6 Punkt 5._
```

---

## #96 — [Next 0.1.x] A5 Lesender Monitor: /proc-Quellen, Ringpuffer, Drill-down

**Milestone:** MLA-Next 0.1.x – Lesender Monitor · **Labels:** `track:mla-next`, `size:L`, `gate:test`

### Body

```markdown
## Scope
Schreibfreier Monitor in der GTK-Shell: Werte aus `/proc` (CPU, RAM, PSI u. a.; Umfang legt der Spec fest), Ringpuffer fester Größe, Drill-down, Diagramme mit Einheit, Messzeit und Quelle. Vergleichsbasis in der Flutter-App: `lib/services/system_stats_service.dart` (`historyLength = 60` bei 3 s); Roadmap-Gegenstück ist WZ1 (#85).

**Grenzen (gelten für jedes MLA-Next-Paket):** GTK-UI, Flutter-UI und Dart-Host laufen nie als Root; keine generische Root-IPC, keine Shell-Strings, keine Secrets in Logs, Screenshots oder Commits; die vorhandene polkit-Grenze bleibt unberührt.

## Abnahme
- [ ] Je Wert sind Quelle und Einheit dokumentiert; jedes Diagramm zeigt Einheit, Messzeit und Quelle
- [ ] Ringpuffer: Tests für Überlauf, Zeitmonotonie und Lücken (Lücke = `stale`, nie 0)
- [ ] Plausibilisierung gegen den `/proc`-Rohwert innerhalb einer dokumentierten Toleranz — Toleranz legt der Spec fest
- [ ] Tests laufen gegen Fixtures, ohne echtes System

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #91, #93, #94
Blockiert: #97

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (A5, 0.1.0–0.1.x)._
```

---

## #97 — [Next 0.1.x] Hintergrund-Pause, Langlauf & Accessibility

**Milestone:** MLA-Next 0.1.x – Lesender Monitor · **Labels:** `track:mla-next`, `size:M`, `gate:verify`, `gate:manual`

### Body

```markdown
## Scope
Der Monitor pausiert in unsichtbaren Ansichten und im Hintergrund, hält einen Langlauf ohne Speicherzuwachs durch und ist per Tastatur und Screenreader bedienbar.

## Abnahme
- [ ] Unsichtbare Ansicht erzeugt nachweislich keine Timer/Polls (Test oder Trace)
- [ ] Langlauf ohne Speicherzuwachs; Dauer und Messverfahren legt der Task fest
- [ ] Diagramme haben Textalternativen; Fokusreihenfolge vollständig; Kontrast geprüft
- [ ] Wayland **und** X11

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #96
Blockiert: Milestone 0.2.x

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (0.1.0–0.1.x: Pausieren im Hintergrund, Langlauf, Accessibility)._
```

---

## #98 — [Next 0.2.x] A7 Notes & Dateiansicht mit Dateisicherheitsgrenzen

**Milestone:** MLA-Next 0.2.x – Notes, Dateien & Palette · **Labels:** `track:mla-next`, `size:M`

### Body

```markdown
## Scope
Notes und Dateiansicht in der GTK-Shell mit ausdrücklichen Dateisicherheitsgrenzen: Pfade werden kanonisiert, Symlinks aus dem Wurzelverzeichnis heraus abgewiesen, Größenlimit, keine Ausführung. Geschrieben wird nur in den gewählten Notizordner. Roadmap-Gegenstück in der Flutter-App: WZ2 (#75, Übergabe an Obsidian per `obsidian://`).

**Grenzen (gelten für jedes MLA-Next-Paket):** GTK-UI, Flutter-UI und Dart-Host laufen nie als Root; keine generische Root-IPC, keine Shell-Strings, keine Secrets in Logs, Screenshots oder Commits; die vorhandene polkit-Grenze bleibt unberührt.

## Abnahme
- [ ] Tests für `..`, Symlink aus dem Wurzelverzeichnis heraus, sehr große Datei und Binärdatei
- [ ] Notizordner wählbar; Schreiben nur dort
- [ ] Kein Öffnen oder Ausführen von Dateien ohne Bestätigung
- [ ] Reviewer 2 hat die Dateigrenzen geprüft

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #97 (Milestone-Reihenfolge)
Blockiert: #99

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (A7, 0.2.0–0.2.x)._
```

---

## #99 — [Next 0.2.x] Sicherer Dokument-Reviewer, Suchpalette & Browser-/Terminal-Aktionen

**Milestone:** MLA-Next 0.2.x – Notes, Dateien & Palette · **Labels:** `track:mla-next`, `size:L`

### Body

```markdown
## Scope
- **Sicherer Dokument-Reviewer:** zeigt Dokumente an, ohne Skripte, Makros oder Netzzugriffe aus dem Dokument auszuführen. Format-Umfang offen (Spec).
- **Suchpalette:** Aktionen und Treffer per Tastatur; Roadmap-Gegenstück ist TE2 (#73).
- **Kontextuelle Aktionen:** Browser und Terminal über argv, nie über Shell-Strings; der Browser folgt der XDG-Kette aus V0.8.2 (#33/#34); keine stillen Fremdclients.

**Grenzen (gelten für jedes MLA-Next-Paket):** GTK-UI, Flutter-UI und Dart-Host laufen nie als Root; keine generische Root-IPC, keine Shell-Strings, keine Secrets in Logs, Screenshots oder Commits; die vorhandene polkit-Grenze bleibt unberührt.

## Abnahme
- [ ] Reviewer öffnet manipulierte Testdokumente ohne Ausführung oder Netzverkehr (Negativfälle als Fixture)
- [ ] Palette: Auswahl per Tastatur; Aktionen mit Seiteneffekt verlangen eine Bestätigung
- [ ] Browser-/Terminal-Aktionen: argv ohne Shell; Test mit Sonderzeichen im Argument
- [ ] Reviewer 2 hat argv-Pfade und Dokumentbehandlung geprüft

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #98
Blockiert: Milestone 0.3.x

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (0.2.0–0.2.x)._
```

---

## #100 — [Next 0.3.x] A4 IPC: JSON-RPC-Schema, Peer-UID, Framing, Backpressure

**Milestone:** MLA-Next 0.3.x – Lagebild, Dienste & Backup · **Labels:** `track:mla-next`, `size:L`, `gate:test`

### Body

```markdown
## Scope
Umsetzung des Entwurfs `docs/mla-next/IPC_CONTRACT.md` (noch nicht implementiert): JSON-RPC 2.0 über UTF-8-JSONL auf einem privaten Unix-Socket im `XDG_RUNTIME_DIR`; ein Dart-Host bindet, GTK und ein optionaler Flutter-Adapter sind Clients. `mla.hello` mit Protokollversion und Capabilities zuerst, danach `backup.list`, `backup.watch`, später `backup.startUserUnit`. Schema und positive/negative Contract-Fixtures sind Teil dieses Pakets. Erst nach einem isolierten Spike.

Same-UID ist keine Sandbox. Nicht: generische Root-IPC, Shell-Execute- oder Root-Methodennamen im Wire, Tokens/Passwörter/rohe Journalausgaben.

## Abnahme (Gate 2, erster Punkt)
- [ ] Frame über 65 536 Bytes wird **vor** dem Parsen abgewiesen; ungültiges UTF-8, ungültiges JSON, Schemaverletzung, Batch-Request (v1) jeweils mit definiertem Fehler
- [ ] Socket-Verzeichnis 0700, Socket 0600; Eigentümer und Peer-UID geprüft; falsche Peer-UID wird abgewiesen
- [ ] Timeout, Reconnect und Backpressure (begrenzte Schreibqueue, geordnete Writes)
- [ ] Event-Sequenz-/Revisionslücke und Disconnect lösen einen vollständigen Snapshot-Neuabruf aus
- [ ] Schutz gegen doppelte Start-Requests
- [ ] Fehlerdaten nur `code`, `messageKey`, `retryable`; keine Secrets

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #93, #99 (Milestone-Reihenfolge; Zuordnung zu 0.3.x ist ein Vorschlag)
Blockiert: #101, #103, #102

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/IPC_CONTRACT.md`, `docs/mla-next/VERIFY.md` (Gate 2)._
```

---

## #101 — [Next 0.3.x] A6 Backup nach #63: Fixtures, Zustände, Start nach Bestätigung

**Milestone:** MLA-Next 0.3.x – Lagebild, Dienste & Backup · **Labels:** `track:mla-next`, `size:M`, `gate:test`

### Body

```markdown
## Scope
Backup-Cockpit auf dem Dart-Host nach den Vorgaben von #63 (LB2): User- und System-Units, letzter Lauf, Result/Journal-Evidenz, nächster Timer, Heartbeat. Zustände `unknown`, `stale`, `failed`, `running`, `ok` sind unterscheidbar. `systemctl --user start` nur für eine erneut validierte User-Unit nach Bestätigung; System-Units bleiben lesend. Prozentwerte nur bei echter Datenquelle. Der rsync-Ordnerkopier-Prototyp ist ausdrücklich **nicht** Teil dieses Pakets.

## Abnahme (Gate 2)
- [ ] Fixtures für User-/System-Units, Timer, Journal-Fehler sowie unknown/stale; keine Zugriffe auf Repos oder Passwörter
- [ ] `systemctl --user start` nur nach Bestätigung und serverseitiger Allowlist; Abbruch, Race und Doppel-Request getestet
- [ ] Ein erfolgreicher Unit-Start macht das Backup nicht grün; ein erfolgreicher Unit-Exit ist kein Restore-Nachweis (Restore wird separat beurteilt)
- [ ] Keine Backups über Repo-Tokens oder Restic-Passwörter

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #100, #94
Tracking-Bezug: #63 (Roadmap, Flutter-Seite)

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (A6, 0.3.x), `docs/mla-next/VERIFY.md` (Gate 2)._
```

---

## #102 — [Next 0.3.x] Security-/Operations-Lagebild + Dienste/Timer (GTK)

**Milestone:** MLA-Next 0.3.x – Lagebild, Dienste & Backup · **Labels:** `track:mla-next`, `size:L`

### Body

```markdown
## Scope
Lesendes Lagebild für Sicherheit und Betrieb sowie Dienste/Timer in der GTK-Shell. Roadmap-Gegenstücke in der Flutter-App: LB1 (#62), DI1 (#67), SI1 (#80). Detailumfang offen — der Plan nennt nur „Security-/Operations-Lagebild, Dienste/Timer"; ein kurzer Spec vor Start legt Ampeln, Quellen und Grenzen fest.

**Grenzen (gelten für jedes MLA-Next-Paket):** GTK-UI, Flutter-UI und Dart-Host laufen nie als Root; keine generische Root-IPC, keine Shell-Strings, keine Secrets in Logs, Screenshots oder Commits; die vorhandene polkit-Grenze bleibt unberührt.

## Abnahme
- [ ] Ampeln als Registry-Probes im Kern (`la_core`), je mit Ein-Satz-Erklärung
- [ ] Dienste und Timer beider Scopes; Start/Stop nur für `--user`-Units nach Bestätigung
- [ ] Fixtures aus echten, geschwärzten Zorin-Ausgaben
- [ ] Privilegiertes nur über die vorhandene polkit-Grenze: keine dritte Action, kein neuer Root-Pfad

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #100, #101
Blockiert: Milestone 0.4.x

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (0.3.0–0.3.x)._
```

---

## #103 — [Next 0.3.x] A8 Agenten-Gateway: Diagnose + einzeln genehmigte Aktionen

**Milestone:** MLA-Next 0.3.x – Lagebild, Dienste & Backup · **Labels:** `track:mla-next`, `size:L`, `gate:test`, `gate:manual`

### Body

```markdown
## Scope
Agenten-Gateway nur für Diagnose und für einzeln genehmigte Aktionen, mit Audit. Ohne Freigabe läuft nichts. Schreibende Aktionen brauchen eine serverseitige Allowlist und eine bestätigte Nutzerauswahl. Roadmap-Gegenstücke: SI2 Aktions-Journal (#81) für das Audit, DI3 (#69) für die Cockpit-Regel „fremde Backends nur read-only und Starten".

**Grenzen (gelten für jedes MLA-Next-Paket):** GTK-UI, Flutter-UI und Dart-Host laufen nie als Root; keine generische Root-IPC, keine Shell-Strings, keine Secrets in Logs, Screenshots oder Commits; die vorhandene polkit-Grenze bleibt unberührt.

## Abnahme
- [ ] Diagnose lesend ohne Genehmigung; jede Aktion einzeln genehmigt, gegen die serverseitige Allowlist geprüft
- [ ] Audit-Eintrag je Aktion (argv, Env-Schlüssel ohne Werte, Exit-Code, Dauer)
- [ ] Keine Agenten-Ausführung ohne Nutzerfreigabe; keine Secrets in Logs; ein Stop-Schalter beendet laufende Agenten-Aktionen
- [ ] Nie-Liste beachtet (kein Klartext-Fallback für Secrets, kein Pass-/OTP-Zugriff)
- [ ] Reviewer 2 (Privilegien/Secrets/IPC) hat den Pfad geprüft; manuelle Abnahme durch Basti

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #100
Blockiert: #104

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (A8, 0.3.0–0.3.x)._
```

---

## #104 — [Next 0.4.x] Computer-Use-Evaluation, Wayland-Freigaben & Stop-Schalter

**Milestone:** MLA-Next 0.4.x – Evaluation & Entscheidung · **Labels:** `track:mla-next`, `size:M`, `gate:manual`

### Body

```markdown
## Scope
Bewerten, ob und wie Computer-Use-Werkzeuge gegen die GTK-Shell arbeiten dürfen: Wayland-Freigaben (Portale/Berechtigungen), ein Stop-Schalter, der jede laufende Automatisierung sofort beendet, und ein Audit der Zugriffe. Ergebnis ist eine dokumentierte Evaluation, kein Produktversprechen.

**Grenzen (gelten für jedes MLA-Next-Paket):** GTK-UI, Flutter-UI und Dart-Host laufen nie als Root; keine generische Root-IPC, keine Shell-Strings, keine Secrets in Logs, Screenshots oder Commits; die vorhandene polkit-Grenze bleibt unberührt.

## Abnahme
- [ ] Evaluation dokumentiert: getestete Werkzeuge, Freigabeweg unter Wayland, Grenzen
- [ ] Stop-Schalter wirkt nachweislich sofort (Messwert oder Trace)
- [ ] Keine Aufnahme sensibler Bildschirminhalte in Logs oder Commits
- [ ] Manuelle Abnahme durch Basti

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #103
Blockiert: #106

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (0.4.0–0.4.x)._
```

---

## #105 — [Next 0.4.x] Regressionsmatrix (Sicherheit/Performance) + Packaging-/Upgrade-Probe

**Milestone:** MLA-Next 0.4.x – Evaluation & Entscheidung · **Labels:** `track:mla-next`, `size:L`, `gate:verify`

### Body

```markdown
## Scope
Regressionsmatrix für Sicherheit und Performance gegen die Baseline aus 0.0.3 sowie eine Packaging-/Upgrade-Probe. Paket-, Binär-, Policy- und Datenpfadnamen bleiben vorerst `linux-assistant` (AGENT_PLAN). Die Probe prüft, ob eine GTK-Variante neben oder anstelle der Flutter-App installierbar und upgradefähig wäre; Ergebnis ist ein Beleg, keine Paketierung.

## Abnahme
- [ ] Matrix ausgeführt und belegt (Sicherheit: Privilegiengrenzen, IPC-Tests aus Gate 2; Performance: Werte gegen die Baseline aus #95)
- [ ] Packaging-/Upgrade-Probe belegt: Installation, Upgrade, Rückbau ohne Reste; Policy-Datei und Exec-Pfade unverändert
- [ ] Rote oder übersprungene Zeilen der Matrix benannt

## Handoff (Pflicht je Aufgabe, aus `docs/mla-next/VERIFY.md`)
- [ ] Basis-SHA, Pfade, Scope und Failing-Test/Fixture stehen vor der Umsetzung fest
- [ ] Reviewer 1 (Funktion/UX/Races) und Reviewer 2 (Privilegien/Secrets/argv/IPC) haben geprüft
- [ ] Wirklich ausgeführte Gates mit Ausgabe; rote oder übersprungene Gates benannt; Rückfallplan genannt
- [ ] Kein Merge, Release oder Policy-Update ohne gesonderte Freigabe

## Abhängigkeiten
Blockiert durch: #95, #102
Blockiert: #106

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (0.4.0–0.4.x, Nicht-Ziele)._
```

---

## #106 — [Next 0.4.x] Doku Flutter-vs-GTK-Entscheidung samt Rückfallplan

**Milestone:** MLA-Next 0.4.x – Evaluation & Entscheidung · **Labels:** `track:mla-next`, `size:S`, `gate:manual`

### Body

```markdown
## Scope
Die Entscheidung Flutter vs. GTK wird anhand der Evidenz aus 0.0.3–0.4.x dokumentiert, samt Rückfallplan. Die Entscheidung trifft Basti; dieses Issue liefert die Entscheidungsgrundlage. Außerdem: 0.5 anhand der 0.4.x-Evidenz definieren (bisher offen) und die Merge-Frage zu Draft-PR #89 beantworten (nicht mergen vor bestandenem Gate 0).

## Abnahme
- [ ] Entscheidungsdokument: Kriterien, Messwerte aus #95 und #105, Risiken, Rückfallplan
- [ ] 0.5 definiert oder ausdrücklich geparkt
- [ ] Merge-Entscheidung zu PR #89 dokumentiert
- [ ] Freigabe durch Basti (kein Merge, Release oder Policy-Update ohne sie)

## Abhängigkeiten
Blockiert durch: #104, #105

_Track: MLA-Next — getrenntes Experiment, kein Flutter-Ersatzbeschluss; die Roadmap V0.8.x–V1.0 bleibt gültig._
_Quelle: `docs/mla-next/AGENT_PLAN.md` (0.4.0–0.4.x, 0.5 offen)._
```

