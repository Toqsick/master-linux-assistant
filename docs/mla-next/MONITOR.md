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
- Überlauf: Bei voller Kapazität fällt der älteste Eintrag heraus; die
  Reihenfolge bleibt älteste→neueste, `len(ring) <= capacity` gilt immer.
- `entries` liefert eine Tupel-Momentaufnahme älteste→neueste — nie die
  interne Liste; `__len__` und `rejected` (Start 0) sind lesbar.

> Der Serien-/Lücken-Teil (`build_series`, `stale_count`, Slots als `None`)
> folgt in Task 3.

## 3. Sampler & Leseregeln

> Platzhalter — folgt in Task 3.

## 4. Darstellung & Drill-down

> Platzhalter — folgt in Task 4.

## 5. Vergleichsbasis Flutter

> Platzhalter — folgt in Task 5.

## 6. Tests & Fixtures

> Platzhalter — folgt in Task 4.

## 7. Grenzen / #97

> Platzhalter — folgt in Task 5.
