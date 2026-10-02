# MLA-Next Systemmonitor — Werte, Quellen, Semantik (Issue #96, A5)

> Stand: 2026-10-02 · Branch `feature/mla-96-monitor` · Plan:
> `docs/superpowers/plans/2026-10-02-mla-96-monitor.md`
>
> Spec-Artefakt des lesenden GTK-Systemmonitors (#96). Die maschinenlesbare
> Fassung der Wertespec liegt in `prototype/gtk/monitor_model.py`
> (`VALUE_SPECS`); diese Datei dokumentiert sie und die Regeln dahinter.
> §1 ist mit Task 1 vollständig; §2–§7 formulieren die Folgetasks aus,
> Task 5 prüft final kreuz.
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

- `capacity < 1` → `ValueError`.
- `append(ts, payload) -> bool` akzeptiert nur **streng größere** Zeitstempel
  als der letzte Eintrag (strikte Zeitmonotonie). `ts <= letzter ts` wird
  abgelehnt: Rückgabe `False`, Zähler `rejected` erhöht, **keine Mutation**.
  Der erste Append ist immer akzeptiert.
- `NaN`-Zeitstempel werden ebenfalls abgelehnt (der Guard `not ts > letzter
  ts` ist für NaN stets wahr); `+inf`/`-inf` sind dagegen **geordnete Werte**
  (größter/kleinster Zeitstempel) und passieren den Guard regulär.
- Überlauf: Bei voller Kapazität fällt der älteste Eintrag heraus; die
  Reihenfolge bleibt älteste→neueste, `len(ring) <= capacity` gilt immer.
- `entries` liefert eine Tupel-Momentaufnahme älteste→neueste — nie die
  interne Liste; `__len__` und `rejected` (Start 0) sind lesbar.

### Serien-Regeln (bindend, umgesetzt in Task 3)

`build_series(entries, *, interval, capacity, now)` bildet das feste Raster
über den Puffereinträgen, `stale_count(series)` zählt die Lücken; der Sampler
nutzt als Payload `ValueSample(wall, value)` (Wanduhr + Wert, §3).

- Das Raster hat **exakt `capacity`** Slots. Der Slot eines Eintrags ist
  `floor(ts/interval)`; das Raster endet bei `floor(now/interval)` und beginnt
  `capacity − 1` Slots davor. `now` exakt auf einer Slot-Grenze zählt diesen
  Slot als letzten; Einträge in der Zukunft fallen weg.
- Enthält ein Slot mehrere Einträge, gewinnt der **jüngste** (größter `ts`) —
  unabhängig von der Eingabereihenfolge.
- Leere Slots sind `None` (stale) und damit strikt unterscheidbar von `0.0`:
  eine Lücke wird nie als 0 dargestellt oder interpretiert (D4). Einträge
  älter als das Fenster fallen weg.
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
- **Zugänge für die UI:** `series(value_id, now=None)`, `samples(value_id)`
  (älteste→neueste, fürs Drill-down), `latest(value_id)` und
  `stale_count(value_id, now=None)`; `interval`/`capacity` sind lesbar.
- **Start/stop-frei:** Den 3-s-Zeitgeber besitzt die UI im GLib-Main-Loop —
  Andockpunkt für #97. Sampler, Ringpuffer und Serien laufen
  **single-threaded** im Main-Loop; `RingBuffer.append` braucht deshalb keinen
  Lock (der kurze Zwischenzustand `len == capacity + 1` innerhalb eines
  Appends ist unkritisch).

## 4. Darstellung & Drill-down

> Platzhalter — folgt in Task 4.

## 5. Vergleichsbasis Flutter

> Platzhalter — folgt in Task 5.

## 6. Tests & Fixtures

> Platzhalter — folgt in Task 4.

## 7. Grenzen / #97

> Platzhalter — folgt in Task 5.
