# MLA-Next Systemmonitor — Werte, Quellen, Semantik (Issue #96, A5)

> Stand: 2026-10-17 (Task 5, nach Final-Review) · Branch `feature/mla-96-monitor` (T5 via Session-Worktree) · Plan:
> `docs/superpowers/plans/2026-10-02-mla-96-monitor.md`
>
> Spec-Artefakt des lesenden GTK-Systemmonitors (#96). Die maschinenlesbare
> Fassung der Wertespec liegt in `prototype/gtk/monitor_model.py`
> (`VALUE_SPECS`); diese Datei dokumentiert sie und die Regeln dahinter.
> §1–§7 sind vollständig. §1–§4 und §6 hat das Final-Whole-Branch-Review
> (`de0026d..7f01b7b`) gegen Code und Tests kreuzgeprüft, §2–§4 nach den
> Errata E2/E3 die Scoped-Re-Reviews; §5, §7 und die §6-Nachträge entstanden
> im Handoff-Commit (Controller plus Claim-Check).
>
> Der Monitor ist rein lesend: kein Root, keine IPC, keine Admin-Aktionen;
> gelesen werden ausschließlich Dateien unter `/proc`.

## 1. Werte & Quellen (Wertespec D1)

Fünf Werte, genau diese; Erweiterungen sind spätere Slices. Die Parser
liefern Rohwerte (0–100 %), die Anzeige-Rundung übernimmt der Formatierer
(Task 4).

| Wert (id) | Label | Quelle | Formel | Einheit | Anzeige | Toleranz |
|---|---|---|---|---|---|---|
| `cpu_percent` | CPU | `/proc/stat`, Zeile `cpu ` | `100 × Δbusy/Δtotal`, `busy = total − idle − iowait`, Delta zweier aufeinanderfolgender Proben | % | 1 Dezimale | ±0,5 pp |
| `ram_percent` | RAM | `/proc/meminfo` | `100 × (MemTotal − MemAvailable)/MemTotal` | % | 1 Dezimale | ±0,2 pp |
| `psi_cpu_avg10` | PSI CPU | `/proc/pressure/cpu` | `some avg10` unverändert übernommen | % | 2 Dezimalen | ±0,01 pp |
| `psi_memory_avg10` | PSI Speicher | `/proc/pressure/memory` | `some avg10` unverändert übernommen | % | 2 Dezimalen | ±0,01 pp |
| `psi_io_avg10` | PSI I/O | `/proc/pressure/io` | `some avg10` unverändert übernommen | % | 2 Dezimalen | ±0,01 pp |

### Parser-Regeln (bindend, umgesetzt in Task 1)

- `parse_cpu_times`: aggregierte `cpu `-Zeile; `total` = Summe der Felder 1–8
  (user, nice, system, idle, iowait, irq, softirq, steal). Die Felder 9/10
  (guest, guest_nice) zählen **nicht zusätzlich** — sie stecken laut
  `man proc` bereits in user/nice. `idle` = Feld 4, `iowait` = Feld 5
  (fehlend = 0). Weniger als 4 Felder → `ValueError`.
- `cpu_percent`: `None` bei fehlender Vorgängerprobe oder `Δtotal <= 0` —
  die erste CPU-Probe ist damit bewusst eine Lücke (Task 3), kein Fake-Wert.
- `parse_meminfo`: `MemTotal` und `MemAvailable` sind Pflicht → sonst
  `ValueError`.
- `meminfo_percent`: `None` bei `total <= 0`.
- `parse_pressure_avg10`: `some`-Zeile und `avg10=` sind Pflicht → sonst
  `ValueError`.
- Die Parser **werfen** bei fehlenden Pflichtfeldern `ValueError` mit klarer
  Botschaft; Lücken-Handling (stale statt 0) macht ausschließlich der Sampler
  (Task 3). Kein `try/except`-Schlucken in den Parsern.

### Fixture-Anker (synthetische Snapshots, `test/fixtures/proc_*.txt`)

- `proc_stat_a.txt` → `proc_stat_b.txt`: Δtotal 996, Δbusy 376 →
  `100 × 376/996 = 37,7510… %` (Anzeige in Task 4: `37.8 %`).
- `proc_meminfo.txt`: `100 × 7066996/16066996 = 43,98455… %`
  (Anzeige: `44.0 %`).
- `proc_pressure_cpu.txt` / `proc_pressure_memory.txt` /
  `proc_pressure_io.txt`: `some avg10` 0.52 / 1.25 / 2.50.
- Die Tests (`prototype/gtk/tests/test_monitor_model.py`) rechnen die
  Erwartungswerte **unabhängig inline** aus den Fixture-Strings nach;
  zusätzlich gilt für alle fünf Werte `0 ≤ wert ≤ 100`.

### Toleranzbegründung

Die Toleranzen sind an der Anzeige ausgerichtet, nicht an der
Parser-Präzision: Anzeige-Rundung (halbe letzte Stelle) mit Reserve —
±0,05 bei 1 Dezimale, ±0,005 bei 2 Dezimalen. Bei der CPU kommt die
Jiffy-Granularität der Zähler hinzu (beide Proben zählen in
1/100-s-Schritten; der Auflösungsfehler wirkt als Rundung des Verhältnisses),
daher ±0,5 pp.

## 2. Ringpuffer & Serien

### Puffer-Regeln (bindend, umgesetzt in Task 2)

`RingBuffer(capacity)` hält zeitgestempelte Einträge `Sample(ts, payload)`;
der Payload ist beliebig — der Sampler nutzt in Task 3 `ValueSample(wall,
value)`. Der Puffer ist eine reine Datenstruktur: keine Wertelogik, kein
Parsing, kein I/O.

- `capacity` ist eine Slot-Anzahl: alles außer `int` ≥ 1 → `ValueError`
  (auch `bool`, ganzzahlige Floats wie `3.0`, `nan`, `inf`; PR-Review #119,
  Plan-Erratum E4).
- `append(ts, payload) -> bool` akzeptiert nur **streng größere** Zeitstempel
  als der letzte Eintrag (strikte Zeitmonotonie). `ts <= letzter ts` wird
  abgelehnt: Rückgabe `False`, Zähler `rejected` erhöht, **keine Mutation**.
  Der erste Append ist akzeptiert, außer bei `NaN`.
- `NaN`-Zeitstempel werden immer abgelehnt, auch als erster Append — ein NaN
  im Puffer ließe jeden späteren Vergleich `ts > nan` scheitern und
  blockierte den Wert dauerhaft (PR-Review #119). Der Sampler macht daraus
  die Lücke `Zeit nicht monoton` (§3). `+inf`/`-inf` nehmen als geordnete
  Werte (größter/kleinster Zeitstempel) am normalen Vergleich teil: `+inf`
  wird angenommen, solange der letzte Eintrag kleiner ist; `-inf` wird bei
  bestehendem Puffer abgelehnt (nur als erster Append akzeptiert).
- Überlauf: Bei voller Kapazität fällt der älteste Eintrag heraus; die
  Reihenfolge bleibt älteste→neueste, `len(ring) <= capacity` gilt immer.
- `entries` liefert eine Tupel-Momentaufnahme älteste→neueste — nie die
  interne Liste; `__len__` und `rejected` (Start 0) sind lesbar.

### Serien-Regeln (bindend, umgesetzt in Task 3)

`build_series(entries, *, interval, capacity, now)` bildet das feste Raster
über den Puffereinträgen, `stale_count(series)` zählt die Lücken; der Sampler
nutzt als Payload `ValueSample(wall, value)` (Wanduhr + Wert, §3).

- Das Raster hat **exakt `capacity`** Slots und ist ein **Kettenraster**
  (Plan-Erratum E3, das E2 verfeinert): Einträge mit endlichem `ts <= now`
  werden nach `ts` absteigend durchlaufen. Der jüngste liegt
  `k0 = floor((now − ts)/interval + 0,5)` Slots vor dem letzten Slot (Index
  `capacity − 1 − k0`); jeder ältere liegt `step = floor(Δ/interval + 0,5)`
  Slots vor dem zuletzt berücksichtigten, nächstjüngeren Eintrag (Δ = dessen
  `ts` minus eigenes `ts`; Index = dessen Index − `step`). `step == 0` heißt
  derselbe Slot: der jüngere Wert bleibt stehen. Ein Index unter 0 beendet
  die Kette — alle älteren Einträge fallen ebenfalls weg, ebenso Einträge in
  der Zukunft (`ts > now`).
- **Wann eine Lücke entsteht:** nur bei echtem Abstand ab 1,5 Intervallen
  zwischen zwei aufeinanderfolgenden Einträgen (`step >= 2` lässt `step − 1`
  Slots leer). Jitter unter `interval/2` und die Phasendrift des Zeitgebers
  (§4 taktet mit genau der Slotbreite; jeder Main-Loop-Stall verschiebt die
  Phase von `timeout_add_seconds` dauerhaft) verschieben keinen Eintrag: ein
  absolutes `floor(ts/interval)`-Raster oder ein nur am letzten Tick
  verankertes Raster ließe dagegen schon wenige Dutzend Millisekunden
  Verspätung bzw. eine aufsummierte Drift von 1,5 s eine falsche
  `stale`-Lücke erzeugen. Grenzfall: viele Abstände knapp unter 1,5
  Intervallen (je ein Slot) können das Fenster zeitlich stauchen — das
  Raster zählt Ticks, nicht Wanduhr.
- **Nicht-endliche Zahlen:** Einträge mit nicht-endlichem `ts` (`±inf`, `NaN`)
  werden übersprungen, ein nicht-endliches `now` ergibt das leere Raster
  (`(None,) * capacity`); `build_series` wirft dafür nie. Der
  `RingBuffer`-Vertrag (`±inf`, s. o.) bleibt unverändert.
- Enthält ein Slot mehrere Einträge, gewinnt der **jüngste** (größter `ts`) —
  unabhängig von der Eingabereihenfolge.
- Leere Slots sind `None` (stale) und damit strikt unterscheidbar von `0.0`:
  eine Lücke wird nie als 0 dargestellt oder interpretiert (D4).
- Rückgabe ist ein Tupel der `payload.value`-Werte älteste→neueste
  (links→rechts im Raster); vor dem ersten Tick ist die Serie vollständig
  `None` der Länge `capacity` (kein Fehler).
- `stale_count(series)` ist die Anzahl der `None`-Slots.

## 3. Sampler & Leseregeln

### Sampler-Regeln (bindend, umgesetzt in Task 3)

`Sampler(read, clock, interval=3.0, capacity=60)` misst die fünf Werte aus
`VALUE_SPECS` bei jedem `tick()` — bewusst **start/stop-frei**:

- **Injektion:** `read(relpath)` und `clock()` kommen als Konstruktor-
  Parameter. Produktionsuhr: `(time.monotonic(), time.time())`. Der Lese-Pfad
  je Wert ist `spec.source` ohne Präfix `/proc/` (z. B. `'stat'`,
  `'pressure/cpu'`) — `VALUE_SPECS` bleibt die einzige Pfad-Quelle.
- **Lesen:** `ProcReader(root='/proc')` liest ausschließlich per `open` +
  `read` (kein Subprozess, kein Shell); der Produktions-Sampler wird mit
  `ProcReader().read` verdrahtet.
- **Zeitbasen:** `clock()` liefert `(mono, wall)`. Ringpuffer-Zeitstempel ist
  die **monotone** Uhr (immun gegen Wanduhr-Sprünge/NTP); `ValueSample.wall`
  trägt die Wanduhr nur für die Anzeige („Messzeit"). `series`/`stale_count`
  nehmen `now` monoton entgegen; `now=None` bedeutet „letzter Tick" (vor dem
  ersten Tick: komplett `None`).
- **Per-Wert-Lücken:** Jeder Wert hat sein eigenes `try/except (OSError,
  ValueError)`; ein Fehler wird zur Lücke, kein Crash, die übrigen Werte
  laufen weiter. Ein Wert mit frischem Sample steht **nicht** in `gaps`.
- **Erster CPU-Tick:** ohne Vorprobe fehlt die Delta-Basis → bewusst Lücke
  („Delta-Basis fehlt (erster Tick)"), nie ein Fake-Wert. Die Probe wird
  trotzdem gespeichert und nach jedem Tick aktualisiert.
- **Fehlende Dateien:** fehlende `pressure`-Dateien (alte Kernel) nehmen
  denselben Lücken-Pfad; kaputtes/trunkiertes `meminfo` wirft `ValueError`.
- **`gaps`:** Dict `value_id → Kurztext`, auf den **letzten Tick** beschränkt
  (zu Tick-Beginn geleert). Format `Typ: relpath`, z. B. `OSError:
  pressure/io` oder `ValueError: meminfo`; dazu die Sonderfälle „Delta-Basis
  fehlt (erster Tick)", „Delta ungueltig", „Wert ungueltig: relpath" und
  „Zeit nicht monoton" (abgelehnter Append). Keine Inhalte, keine Secrets.
- **Nicht-endliche Messwerte:** `parse_pressure_avg10` wirft bei `nan`/`inf`
  als `avg10` einen `ValueError` — der Sampler macht daraus eine Lücke
  (`ValueError: pressure/…`) statt eines `nan %`-Samples.
- **Zugänge für die UI:** `series(value_id, now=None)`, `samples(value_id)`
  (älteste→neueste, fürs Drill-down), `latest(value_id)` und
  `stale_count(value_id, now=None)`; `interval`/`capacity` sind lesbar.
- **Start/stop-frei:** Den 3-s-Zeitgeber besitzt die UI im GLib-Main-Loop —
  Andockpunkt für #97. Sampler, Ringpuffer und Serien laufen
  **single-threaded** im Main-Loop; `RingBuffer.append` braucht deshalb keinen
  Lock (der kurze Zwischenzustand `len == capacity + 1` innerhalb eines
  Appends ist unkritisch).

## 4. Darstellung & Drill-down

### Aufbau je Wert (umgesetzt in Task 4)

Je `VALUE_SPECS`-Eintrag eine Zeile aus Caption-Label und
`Gtk.DrawingArea` (Mindesthöhe 72 px, `hexpand`/`vexpand`); Zeilenabstand
space3, Label↔Diagramm space1 (TOKENS.md §2). Ein `Gtk.GestureClick` je
Zeile (Signal `released`, `value_id` als Signal-User-Data) öffnet das
Drill-down (nur Primärklick, `Gdk.BUTTON_PRIMARY`); die ganze Zeile ist
Klickfläche.

### Caption (exakt, `format_caption`)

`Quelle: <spec.source> · Einheit: <spec.unit> · Messzeit: HH:MM:SS`

- Zeit aus `latest(value_id).wall` (Wanduhr, ausschließlich Anzeige — §3)
  über `time.localtime`; ohne Messwert steht `–` (Halbgeviertstrich) im
  Zeitfeld.
- Das Suffix ` · stale: N` erscheint nur bei `N > 0`
  (N = `stale_count(value_id)`).

### Anzeigewert (exakt, `format_value`)

`spec.decimals` Dezimalen mit Punkt als Trenner plus Einheit (`37.8 %`,
`0.52 %`); `None` wird exakt `stale` — nie `0.0 %` oder `0 %` (D4).

### Drill-down (exakt, `format_drilldown`)

Kopfzeilen `Label: Wert`, `Quelle:`, `Formel:`, `Toleranz: ±{spec.tolerance} pp`,
`stale: N`, danach höchstens die letzten 10 Samples älteste→neueste als
`HH:MM:SS␣␣Wert` (zwei Leerzeichen; Zeit aus `sample.wall`). Ohne Samples
bleiben die Sample-Zeilen weg (der Kopf sagt dann `Label: stale`). Der
Text steht in der rechten Detail-Leiste und trägt dort die farbfreie
Klasse `.mla-drilldown` (Monospace, TOKENS.md §8); der Chip zeigt dabei
`messend` (Tone `running`).

### Diagramme (Cairo, `MonitorView._draw_chart`)

- Grundlinie in `border-subtle`, Datenpolyline in `accent` — beide zur
  Laufzeit über `StyleContext.lookup_color()` geholt (Fallback: aktuelle
  Textfarbe); kein Farbwert im Quelltext (TOKENS.md §8).
- Feste Y-Skala 0–100 %: Grundlinie = 0 %, Oberkante = 100 %; Werte
  werden fürs Zeichnen auf [0, 100] geklemmt.
- X-Raster = `sampler.series(value_id)`: Slot `i` liegt bei
  `(i + 0,5) × Breite/Kapazität` (älteste links); `None`-Slots brechen
  die Linie — es wird nie durch eine Lücke (oder gar 0) gezogen; eine
  leere Serie zeigt nur die Grundlinie.
- Ein Einzelwert ohne Nicht-`None`-Nachbarn links und rechts (z. B. der erste
  Sample nach dem Start oder ein Wert zwischen zwei Lücken) hätte als Linie
  keine Länge und wird deshalb als gefüllter Punkt (Radius 1,5 px) in der
  Linienfarbe `accent` gezeichnet.

### Zeitgeber & Refresh (D6, Single-Source)

- Der einzige Mess-Zeitgeber lebt in der Shell:
  `GLib.timeout_add_seconds(int(sampler.interval), self._tick)`; `_tick`
  ruft `sampler.tick()` + `MonitorView.refresh()` und gibt
  `GLib.SOURCE_CONTINUE`. Doppelstart-Guard über `_tick_source_id`
  (armt nur, solange keine Source-ID steht).
- `MonitorView` besitzt bewusst keinen eigenen Timer; `refresh()` zieht
  Captions (auf den letzten Tick) und stößt `queue_draw` für alle
  Flächen an.
- `App.do_shutdown` bestellt die Source über `GLib.source_remove` ab
  (`Window.stop_ticking`, idempotent).
- MODULES-Untertitel des Monitor-Eintrags exakt `60 × 3 s · /proc`.

## 5. Vergleichsbasis Flutter

Gegenstück in der Flutter-App ist `SystemStatsService`
(`lib/services/system_stats_service.dart`); die Werte unten sind dort
zeilengenau belegt (Zeilenangaben ohne Dateinamen =
`system_stats_service.dart`). Daneben hat die Flutter-App den
Systemmonitor `SystemMonitorService` (`lib/services/system_monitor_service.dart`,
Admin-Hub E3): CPU aus `/proc/stat` (Δbusy/Δtotal, `total` inkl.
guest-Felder), RAM aus `/proc/meminfo` mit derselben Formel, 60 × 1 s,
Pause über `TickerMode`, Lücken werden dort 0. Er ist inhaltlich näher,
aber nicht die Vergleichsbasis aus ISSUES #96. Gleich ist nur das Raster — Quellen und
Lückensemantik unterscheiden sich bewusst.

| Aspekt | Flutter (`SystemStatsService`) | GTK-Monitor (#96) |
|---|---|---|
| Raster | `historyLength = 60`, `defaultInterval = 3 s` (`:85-86`) | `60 × 3 s` (`Sampler`-Default, MODULES-Untertitel) — identisch |
| CPU | 1-Minuten-`loadavg` aus `/proc/loadavg` geteilt durch die Thread-Zahl (`lib/linux/linux_system.dart:55-60`) — eine Last-Kennzahl, keine Auslastung | `100 × Δbusy/Δtotal` aus `/proc/stat` (§1) — Auslastung in % zwischen zwei Ticks; **nicht** direkt mit dem Flutter-Wert vergleichbar |
| RAM | Subprozess `free -m` je Tick (`:187-188`), `usedRatio` | `/proc/meminfo`: `100 × (MemTotal − MemAvailable)/MemTotal`, kein Subprozess |
| PSI | kein Gegenstück | `some avg10` für CPU, Speicher, I/O (§1) |
| Lücken | Ist `free` nicht parsebar, wiederholt die Historie den letzten Wert (`memory ?? previous.memory`) bzw. schreibt **0**, solange noch nie ein Wert vorlag (`:210-213`); bei einer Exception bleibt die alte Historie unverändert stehen (`:216-231`) — in der Historie ist eine Lücke nie als Lücke sichtbar (nur der Exception-Pfad setzt `error`, den das Dashboard als Warnkarte zeigt) | Lücke = `None` → `stale`, nie 0 (§2/§3); Linie bricht (§4) |
| Zeitstempel | ein `updatedAt` je Snapshot (Wanduhr) | Monotonie-Uhr für Puffer/Raster, Wanduhr nur für die Anzeige (§3) |
| Pausieren | pollt nur bei `acquire` + aktiver Sektion + sichtbarem Fenster (`:66-77`, `_sync` `:151-159`) | **noch keine Pause** — der Tick läuft, solange die App lebt → #97 (§7) |
| Prozesse je Tick | mehrere Subprozesse (`free`, `df`, `ps` …) über `Future.wait` (`:183-195`; der Doc-Kommentar `:73-77` spricht von acht) | 0 Subprozesse; nur Lesen von 5 festen `/proc`-Dateien |

Folgerung für spätere Vergleiche (#95-Baseline, #97): CPU-Kurven beider
Apps nebeneinander zu legen, ist nur nach Umrechnung sinnvoll (gegen `SystemStatsService`; gegen
`SystemMonitorService` sind CPU und RAM direkt vergleichbar, bis auf
Raster 1 s statt 3 s, guest-Felder und Lückensemantik); die
RAM-Kurven sind bis auf die Lückensemantik vergleichbar.

## 6. Tests & Fixtures

### Modell-Suite `prototype/gtk/tests/test_monitor_model.py`

- Tasks 1–3 (Parser, Ringpuffer, Serien, Sampler) sind dort vollständig
  gepinnt; Fixture-Anker siehe §1.
- Task 4 ergänzt `FormatterTests` (8 Tests, heute 10) mit exakten Strings; TZ
  wird in setUp/tearDown auf `UTC` erzwungen (`TZ` + `time.tzset()`), damit
  die `HH:MM:SS`-Felder deterministisch sind; Fix-Runde 1 (`18a63df`) ergänzt einen Test auf
  die Nicht-UTC-Zone `XXX-02` und pinnt so die Lokalzeit-Anzeige
  (`Messzeit: 02:16:40`), ein weiterer die festen zwei Dezimalen
  (`2.50 %`):
  - `format_value`: `37.751` → `37.8 %`, `43.98455…` → `44.0 %`,
    `0.52` → `0.52 %`; `None` → exakt `stale` (mit
    `assertNotEqual`-Pins gegen `0.0 %`/`0 %`).
  - `format_caption`: exakt
    `Quelle: /proc/stat · Einheit: % · Messzeit: 00:16:40`; mit Lücken
    `… · stale: 57`, ohne Messwert `… · Messzeit: – · stale: 60`.
  - `format_drilldown`: exakter Mehrzeiler aus Kopf und letzten 10
    Samples; ohne Samples exakt 5 Zeilen (`CPU: stale` als erste); bei
    12 Samples nur die letzten 10 (`00:16:46 …` bis `00:17:13 …`).

- Der in T5 übernommene Pin-Commit `7f01b7b` (Fremd-Diff, Mutationsbelege
  in T5) pinnt den ±inf-Monotonievertrag (§2),
  den stat-Lesefehler ohne gespeicherte Delta-Basis, den
  truncated-stat-`ValueError` und den Durchgriff von `interval`/`capacity`
  ins Serienraster — je mit Mutationsbeleg.
- Die Final-Review-Fixes (`18a63df`, `e7e8145`) pinnen Jitter und
  Zeitgeber-Phasendrift (Kettenraster, §2; je ein `build_series`- und ein
  Sampler-Test), eine echte Lücke ab 1,5 Intervallen, die Fenstergrenze,
  Einträge in der Zukunft (`ts > now`), nicht-endliche `ts`/`now`/`avg10` und den meminfo-Leerwert.

### Token-Suite `prototype/gtk/tests/test_tokens.py`

- Das Hardcode-Gate prüft seit #96 alle drei Shell-Dateien
  (`SCANNED_PY`: `mla_app.py`, `monitor_ui.py`, `monitor_model.py`);
  der Known-Bad-Nachweis (`#B8860B`, `rgba(`) bleibt als RED-Beleg
  bestehen. Die Erweiterung lief zunächst rot (`monitor_ui.py` fehlte
  noch, `FileNotFoundError`), danach grün.
- Konsistenz-/Kontrast-Tests (§1, §5) bleiben unverändert.

### Ausführung (Gates)

- GTK: `python3 -m unittest discover -s prototype/gtk/tests` (aus dem
  Repo-Root) — 96 Tests (84 Modell + 10 Token + 2 Shell-Layout; davon 4
  Modell-Tests aus dem PR-Review #119: NaN als Erst-Zeitstempel, ungültige
  Kapazitäten). Die Layout-Klasse in `test_shell_layout.py` braucht GTK
  4/libadwaita und ein Display und wird ohne beides — so in CI —
  übersprungen.
- Bestehende Python-Suite: `cd additional/python && python3 -m unittest
  discover -s tests -t .` — 53 Tests, unabhängig vom GTK-Track.
- Start-Gates (BASELINE §2): Start unter Wayland und X11 je
  `timeout 6` → Exit 124 (App läuft, kein stderr); Screenshot nur als
  /tmp-Artefakt, nie im Repo (TOKENS.md §7).

## 7. Grenzen / #97

Bewusst **nicht** in #96 (Scope-Grenze laut Plan „Nicht-Ziele"):

- **Hintergrund-Pause, Langlauf, Accessibility** → #97. Der
  `GLib`-Tick läuft auch bei unsichtbarer Monitor-Ansicht oder
  minimiertem Fenster weiter; Diagramme haben noch keine
  Textalternativen; Fokusreihenfolge und Kontrast der Chart-Flächen sind
  ungeprüft. #97 braucht hierfür einen Test oder Trace „unsichtbar ⇒ kein
  Tick" (Abnahme 1 dort).
- **Gequetschte rechte Detail-Leiste** (vorbestehend seit dem Scaffold
  `6c5c625`, nicht #96-verursacht) — **triagiert und behoben** auf
  `fix/mla-details-pane-width`. Root Cause: `Gtk.Paned` liegt im
  Inhaltsbereich der NavigationSplitView (1200 px Fenster − 280 px
  Nav-Sidebar = 920 px), `PANE_POSITION` 850 zählt ab dessen linker Kante;
  mit dem GTK4-Default `shrink-end-child=TRUE` ignoriert der Trenner die
  280-px-Mindestbreite. GTK alloziert die Leiste trotzdem mit 280 px, aber
  ab Fenster-x 1131 — 211 px liegen jenseits des rechten Rands und werden
  abgeschnitten (sichtbar 69 px unter X11; unter Wayland skaliert der
  Paned 850 nach dem Compositor-Resize auf 954 px proportional auf 661 →
  54 px). Fix: `shrink-end-child=False` in `build_detail_pane`; der
  Trenner wird jetzt auf `Paned-Breite − 1 − 280` geklemmt (bei 1200 px:
  639, Leiste 280 px bis exakt zur Fensterkante). Regression:
  `test_shell_layout.py` (RED 69/54/51/100 px sichtbar → GREEN).
- **Start-Gate-Teardown-Flake**: in T4 einmal 116 B
  `GLib-GIO-CRITICAL … check_unclosed` beim SIGTERM-Teardown unter
  Wayland (1 von 4 Läufen), Exit stets 124; im T5-Frischlauf 0 von 6 (3 Wayland + 3 X11).
  In den Final-Fix-Runden etwa 1 von 5 Läufen (115 B), auch auf dem
  unveränderten Vor-Fix-Stand `4e61a80` (1 von 8); Gate-Frischlauf nach den Fixes 0 von 6.
  Gilt als umgebungsbedingt und vorbestehend; Root Cause in #97
  (Langlauf/Shutdown-Pfad).
- **Methodik-Hinweise für UI-Belege** (aus T4): vor `xdotool`-Klicks das
  mutter-Guard-Fenster unmappen; teil-offscreen Fenster stoppen den
  Ticker-Repaint; PNG-`md5` taugt nicht als Pixelvergleich (tIME-Chunk) —
  `compare -metric AE` verwenden.
- **Geparkter Test-Pin**: Der `%r`-Wortlaut der Kapazitätsmeldung
  (`RingBuffer`) ist nicht wortgleich gepinnt (T2-N2), nur der
  `ValueError`-Typ.
- **Getrennte Ketten je Wert** (Final-Review N3, geparkt): Jeder Wert bildet
  sein Kettenraster (§2) für sich. Fällt bei einem Wert ein Tick durch einen
  Lesefehler aus, während benachbarte Abstände durch Zeitgeber-Stalls
  gedehnt sind, kann dieser Wert eine Lücke zu viel zeigen und seine ältere
  Historie um einen Slot gegen die anderen Diagramme versetzen — stets in
  die vorsichtige Richtung (mehr `stale`, nie verdeckt). Kandidat für #97:
  eine gemeinsame Tick-Kette im Sampler, in die jeder Wert seine Lücke
  einträgt.
- **Suspend/Uhrensprung:** Puffer und Raster laufen auf `time.monotonic()`
  (= `CLOCK_MONOTONIC`, ohne Suspend-Zeit, §3). Nach einem Suspend schließt
  das Raster die Werte vor dem Suspend ohne Lücke an die frischen an — der
  Messausfall ist im Diagramm **nicht** als `stale` sichtbar, nur am Sprung
  der Wanduhr in Caption-`Messzeit` und Drill-down-Zeilen. Langlauf und
  Suspend-Verhalten (z. B. `CLOCK_BOOTTIME`) prüft #97.
- **Weitere Werte** (Temperaturen, Netz, Datenträger) sind spätere
  Slices; §1 legt genau fünf Werte fest.
- **Keine IPC, kein Root, keine Schreibzugriffe** — der Monitor bleibt bis
  A4 (#100) ein reiner Datei-Leser in der unprivilegierten Shell.
