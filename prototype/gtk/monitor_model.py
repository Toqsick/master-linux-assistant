"""Reine /proc-Parser, Wertespec, Ringpuffer, Serienbildung und Sampler für
den GTK-Systemmonitor (Issue #96).

Spec: `docs/mla-next/MONITOR.md` §1–§3; die maschinenlesbare Fassung der
Tabelle liegt hier als `VALUE_SPECS`. Die Parser und `build_series` sind
gi-frei und machen kein I/O — sie arbeiten auf übergebenen Textinhalten
bzw. Einträgen; fehlende Pflichtfelder werfen `ValueError` mit klarer
Botschaft. Datei-I/O gibt es ausschließlich in `ProcReader`/`Sampler`
(nur lesend, ohne Subprozess); das Lücken-Handling (stale statt 0)
übernimmt der Sampler. Kein Import aus dem GTK-Stack — die CI läuft headless.
"""
import math
import os
import time
from collections.abc import Callable, Iterable, Sequence
from dataclasses import dataclass
from typing import NamedTuple


class CpuTimes(NamedTuple):
    """Aggregierte CPU-Zähler (Jiffies) aus der `cpu `-Zeile von /proc/stat."""

    total: int
    idle: int
    iowait: int


class MemInfo(NamedTuple):
    """MemTotal/MemAvailable aus /proc/meminfo, in KiB."""

    total_kib: int
    available_kib: int


@dataclass(frozen=True)
class ValueSpec:
    """Ein Monitorwert: Quelle, Formel, Anzeige und Prüftoleranz (D1)."""

    id: str
    label: str
    unit: str
    source: str
    fixture: str
    formula: str
    decimals: int
    tolerance: float


# cpu_percent entsteht als Delta zweier Proben (proc_stat_a.txt → b);
# `fixture` nennt die jüngere Probe des Paares.
VALUE_SPECS = (
    ValueSpec(
        id='cpu_percent',
        label='CPU',
        unit='%',
        source='/proc/stat',
        fixture='proc_stat_b.txt',
        formula='100 × Δbusy/Δtotal, busy = total − idle − iowait, '
                'Delta zweier aufeinanderfolgender Proben',
        decimals=1,
        tolerance=0.5,
    ),
    ValueSpec(
        id='ram_percent',
        label='RAM',
        unit='%',
        source='/proc/meminfo',
        fixture='proc_meminfo.txt',
        formula='100 × (MemTotal − MemAvailable)/MemTotal',
        decimals=1,
        tolerance=0.2,
    ),
    ValueSpec(
        id='psi_cpu_avg10',
        label='PSI CPU',
        unit='%',
        source='/proc/pressure/cpu',
        fixture='proc_pressure_cpu.txt',
        formula='some avg10 unverändert übernommen',
        decimals=2,
        tolerance=0.01,
    ),
    ValueSpec(
        id='psi_memory_avg10',
        label='PSI Speicher',
        unit='%',
        source='/proc/pressure/memory',
        fixture='proc_pressure_memory.txt',
        formula='some avg10 unverändert übernommen',
        decimals=2,
        tolerance=0.01,
    ),
    ValueSpec(
        id='psi_io_avg10',
        label='PSI I/O',
        unit='%',
        source='/proc/pressure/io',
        fixture='proc_pressure_io.txt',
        formula='some avg10 unverändert übernommen',
        decimals=2,
        tolerance=0.01,
    ),
)


def parse_cpu_times(text: str) -> CpuTimes:
    """Aggregierte `cpu `-Zeile aus /proc/stat: total, idle, iowait.

    `total` ist die Summe der Felder 1–8 (user, nice, system, idle, iowait,
    irq, softirq, steal). guest/guest_nice (Felder 9/10) zählen NICHT
    zusätzlich — sie stecken laut `man proc` bereits in user/nice. `idle`
    ist Feld 4, `iowait` Feld 5 (fehlend = 0). Weniger als vier Felder sind
    kein gültiger Snapshot → ValueError.
    """
    for line in text.splitlines():
        if line.startswith('cpu '):
            fields = [int(part) for part in line.split()[1:]]
            if len(fields) < 4:
                raise ValueError(
                    'cpu -Zeile braucht mindestens 4 Felder, hat %d'
                    % len(fields))
            return CpuTimes(
                total=sum(fields[:8]),
                idle=fields[3],
                iowait=fields[4] if len(fields) > 4 else 0,
            )
    raise ValueError('keine aggregierte cpu -Zeile gefunden')


def cpu_percent(prev: CpuTimes | None, cur: CpuTimes) -> float | None:
    """Busy-Anteil zwischen zwei Proben in Prozent.

    `busy = total − idle − iowait`, `100 × Δbusy/Δtotal`. `None` ohne
    Vorgängerprobe (erste Probe) oder bei `Δtotal <= 0` — der Aufrufer
    behandelt das als Lücke (stale), nie als 0.
    """
    if prev is None:
        return None
    delta_total = cur.total - prev.total
    if delta_total <= 0:
        return None
    delta_busy = ((cur.total - cur.idle - cur.iowait)
                  - (prev.total - prev.idle - prev.iowait))
    return 100.0 * delta_busy / delta_total


def parse_meminfo(text: str) -> MemInfo:
    """`MemTotal`/`MemAvailable` aus /proc/meminfo in KiB; beide Pflicht."""
    values = {}
    for line in text.splitlines():
        key, _separator, rest = line.partition(':')
        if key in ('MemTotal', 'MemAvailable'):
            parts = rest.split()
            if not parts:
                raise ValueError('%s ohne Wert in /proc/meminfo' % key)
            values[key] = int(parts[0])
    missing = [key for key in ('MemTotal', 'MemAvailable')
               if key not in values]
    if missing:
        raise ValueError('meminfo ohne %s' % ', '.join(missing))
    return MemInfo(total_kib=values['MemTotal'],
                   available_kib=values['MemAvailable'])


def meminfo_percent(info: MemInfo) -> float | None:
    """Belegter RAM-Anteil in Prozent; `None` bei `total <= 0`."""
    if info.total_kib <= 0:
        return None
    return 100.0 * (info.total_kib - info.available_kib) / info.total_kib


def parse_pressure_avg10(text: str) -> float:
    """`some avg10` aus /proc/pressure/*; some-Zeile und avg10= sind Pflicht."""
    for line in text.splitlines():
        if line.startswith('some '):
            for token in line.split()[1:]:
                if token.startswith('avg10='):
                    return float(token.split('=', 1)[1])
            raise ValueError('some-Zeile ohne avg10=')
    raise ValueError('keine some-Zeile gefunden')


class Sample(NamedTuple):
    """Zeitgestempelter Eintrag des Ringpuffers: Zeitstempel + beliebiger Payload."""

    ts: float
    payload: object


class RingBuffer:
    """Ringpuffer fester Kapazität für zeitgestempelte Einträge (D3).

    Reine Datenstruktur ohne Wertelogik, Parsing oder I/O. `append` nimmt nur
    streng größere Zeitstempel als der letzte Eintrag an (strikte
    Zeitmonotonie); abgelehnte Appends mutieren nichts und zählen in
    `rejected`. Bei Überlauf fällt der älteste Eintrag heraus, die Reihenfolge
    bleibt älteste→neueste und `len(ring) <= capacity` gilt immer.
    """

    def __init__(self, capacity: int):
        if capacity < 1:
            raise ValueError(
                'capacity muss mindestens 1 sein, ist %r' % capacity)
        self._capacity = capacity
        self._entries: list[Sample] = []
        self.rejected = 0

    def __len__(self) -> int:
        return len(self._entries)

    @property
    def entries(self) -> tuple[Sample, ...]:
        """Momentaufnahme älteste→neueste; nie die interne Liste."""
        return tuple(self._entries)

    def append(self, ts: float, payload: object) -> bool:
        """Eintrag anhängen, wenn `ts` streng größer als der letzte ist.

        `NaN`-Zeitstempel werden abgelehnt (sobald verglichen wird, ist `not
        ts > letzter ts` für NaN wahr); `+inf`/`-inf` nehmen als geordnete
        Werte (größter/kleinster Zeitstempel) am normalen Vergleich teil:
        `+inf` wird angenommen, solange der letzte Eintrag kleiner ist;
        `-inf` wird bei bestehendem Puffer abgelehnt (nur als erster Append
        akzeptiert).
        """
        if self._entries and not ts > self._entries[-1].ts:
            # 'not >' weist NaN ab (NaN > x ist False); ±inf laufen durch den
            # normalen Vergleich: +inf wird angenommen, -inf nur als Erstappend.
            self.rejected += 1
            return False
        self._entries.append(Sample(ts=ts, payload=payload))
        if len(self._entries) > self._capacity:
            del self._entries[0]
        return True


class ValueSample(NamedTuple):
    """Ein Messwert für die Anzeige: Wanduhr (`wall`) und Wert (`value`).

    Der Ringpuffer-Zeitstempel (`Sample.ts`) ist die monotone Uhr; `wall`
    trägt die Wanduhr nur für die „Messzeit"-Anzeige und wird nie für
    Slot-Zuordnung oder Monotonie verwendet (D5).
    """

    wall: float
    value: float


def build_series(entries: Iterable[Sample], *, interval: float,
                 capacity: int, now: float) -> tuple:
    """Feste Raster-Serie der Länge `capacity` aus Ringpuffer-Einträgen (D4).

    Slot eines Eintrags ist `floor(ts/interval)`; das Raster endet bei
    `floor(now/interval)` und beginnt `capacity - 1` Slots davor — bei
    `now` exakt auf einer Slot-Grenze zählt dieser Slot als letzter.
    Enthält ein Slot mehrere Einträge, gewinnt der jüngste (größter `ts`);
    leere Slots werden `None` (stale, strikt unterscheidbar von `0.0`).
    Einträge außerhalb des Rasters — älter als das Fenster oder in der
    Zukunft — fallen weg. Rückgabe: Tupel der `payload.value`-Werte
    älteste→neueste (links→rechts im Raster).
    """
    last_slot = math.floor(now / interval)
    first_slot = last_slot - (capacity - 1)
    values = [None] * capacity
    newest_ts = [None] * capacity
    for entry in entries:
        slot = math.floor(entry.ts / interval)
        if not first_slot <= slot <= last_slot:
            continue
        index = slot - first_slot
        if newest_ts[index] is None or entry.ts > newest_ts[index]:
            values[index] = entry.payload.value
            newest_ts[index] = entry.ts
    return tuple(values)


def stale_count(series: Iterable[float | None]) -> int:
    """Anzahl der `None`-Slots (stale-Lücken) einer Serie."""
    return sum(1 for slot in series if slot is None)


class ProcReader:
    """Minimaler Lese-Zugriff auf Dateien unter `/proc` (D5).

    Nur `open` + `read`, ausschließlich lesend: keine Subprozesse, kein
    Shell-Aufruf. `root` ist injizierbar (Tests lesen aus einem
    tmp-Verzeichnis); `read` bekommt Pfade relativ zu `root`, abgeleitet
    aus dem `source`-Feld der `VALUE_SPECS` (z. B. `'stat'`,
    `'pressure/cpu'`).
    """

    def __init__(self, root: str = '/proc'):
        self._root = root

    def read(self, relpath: str) -> str:
        """Datei `root/relpath` vollständig als Text lesen."""
        path = os.path.join(self._root, relpath)
        with open(path, encoding='utf-8') as handle:
            return handle.read()


class Sampler:
    """Zeitgeberfreier /proc-Sampler für die fünf Werte (D5).

    `read(relpath)` und `clock()` sind injiziert; `clock()` liefert
    `(mono, wall)` — Ringpuffer-Zeitstempel ist die monotone Uhr,
    `ValueSample.wall` die Wanduhr für die Anzeige. `tick()` liest jeden
    Wert einzeln: Lesefehler und Parser-Fehler werden je Wert zur Lücke in
    `gaps`, nie zu einem Ersatzwert. Bewusst ohne `start`/`stop` — den
    Zeitgeber besitzt die UI (GLib-Main-Loop, Andockpunkt #97); die ganze
    Kette läuft single-threaded, darum braucht der Puffer keinen Lock.
    """

    def __init__(self, read: Callable[[str], str],
                 clock: Callable[[], tuple[float, float]],
                 interval: float = 3.0, capacity: int = 60):
        self._read = read
        self._clock = clock
        self._interval = interval
        self._capacity = capacity
        self._rings = {spec.id: RingBuffer(capacity) for spec in VALUE_SPECS}
        self._previous_cpu: CpuTimes | None = None
        self._last_mono: float | None = None
        #: Grund je Wert, der im letzten Tick keine frische Probe bekam.
        self.gaps: dict[str, str] = {}

    @property
    def interval(self) -> float:
        """Messintervall in Sekunden (für den Zeitgeber der UI, #97)."""
        return self._interval

    @property
    def capacity(self) -> int:
        """Slots je Serie (Rasterbreite der Diagramme)."""
        return self._capacity

    def tick(self) -> None:
        """Alle fünf Werte einmal lesen und je Wert in den Puffer anhängen.

        Zu Tick-Beginn wird `gaps` geleert. Jeder Wert hat sein eigenes
        `try/except (OSError, ValueError)`; Fehler werden zur Lücke, die
        übrigen Werte laufen weiter. Der erste CPU-Tick hat keine
        Delta-Basis und wird bewusst zur Lücke (kein Fake-Wert); die
        Vorprobe wird trotzdem gespeichert und nach jedem Tick aktualisiert.
        """
        mono, wall = self._clock()
        self.gaps.clear()
        self._last_mono = mono
        for spec in VALUE_SPECS:
            relpath = spec.source.removeprefix('/proc/')
            try:
                value, gap = self._measure(spec, relpath)
            except (OSError, ValueError) as exc:
                self.gaps[spec.id] = '%s: %s' % (type(exc).__name__, relpath)
                continue
            if gap is not None:
                self.gaps[spec.id] = gap
                continue
            sample = ValueSample(wall=wall, value=value)
            if not self._rings[spec.id].append(mono, sample):
                self.gaps[spec.id] = 'Zeit nicht monoton'

    def _measure(self, spec: ValueSpec,
                 relpath: str) -> tuple[float | None, str | None]:
        """Einen Wert lesen und berechnen: `(value, None)` oder `(None, Grund)`.

        Bewusste Nicht-Werte (fehlende CPU-Delta-Basis, ungültiges Delta,
        meminfo ohne belegbaren Wert) bekommen einen Lücken-Grund; Lesen
        und Parsen werfen `OSError`/`ValueError` wie Reader und Parser.
        """
        text = self._read(relpath)
        if spec.id == 'cpu_percent':
            current = parse_cpu_times(text)
            previous = self._previous_cpu
            self._previous_cpu = current
            value = cpu_percent(previous, current)
            if value is None:
                if previous is None:
                    return None, 'Delta-Basis fehlt (erster Tick)'
                return None, 'Delta ungueltig'
            return value, None
        if spec.id == 'ram_percent':
            value = meminfo_percent(parse_meminfo(text))
        else:
            value = parse_pressure_avg10(text)
        if value is None:
            return None, 'Wert ungueltig: %s' % relpath
        return value, None

    def samples(self, value_id: str) -> tuple[ValueSample, ...]:
        """Alle gesammelten Werte älteste→neueste (fürs Drill-down)."""
        entries = self._rings[value_id].entries
        return tuple(entry.payload for entry in entries)

    def latest(self, value_id: str) -> ValueSample | None:
        """Jüngster Wert oder `None`, solange keiner gesammelt wurde."""
        entries = self._rings[value_id].entries
        return entries[-1].payload if entries else None

    def series(self, value_id: str, now: float | None = None) -> tuple:
        """Serie dieses Werts über das feste Raster (`now=None` → letzter Tick).

        Vor dem ersten Tick ist die Serie vollständig `None` der Länge
        `capacity` (kein Fehler).
        """
        if now is None:
            now = 0.0 if self._last_mono is None else self._last_mono
        return build_series(
            self._rings[value_id].entries,
            interval=self._interval, capacity=self._capacity, now=now)

    def stale_count(self, value_id: str, now: float | None = None) -> int:
        """Anzahl stale-Slots dieses Werts (Modul-Funktion auf `series`)."""
        return stale_count(self.series(value_id, now))


# --- Anzeige-Formatierer (Task 4, MONITOR.md §4) ---------------------------
# Rein und gi-frei; die Zeitfelder nutzen die Wanduhr `ValueSample.wall`
# (bzw. `newest_wall`) ausschließlich zur Anzeige, nie für Slot-Logik (D5).
# Kein `None` wird je zu `0` — Lücken heißen exakt `stale` (D4).

def format_value(spec: ValueSpec, value: float | None) -> str:
    """Anzeigewert aus `spec.decimals` + `spec.unit`, Punkt als Trenner.

    `None` (Lücke) wird exakt `stale` — nie `0.0` oder `0`.
    """
    if value is None:
        return 'stale'
    return f'{value:.{spec.decimals}f} {spec.unit}'


def format_caption(spec: ValueSpec, newest_wall: float | None,
                   stale: int) -> str:
    """Bildunterschrift `Quelle: … · Einheit: … · Messzeit: HH:MM:SS`.

    Zeit aus `newest_wall` per `time.localtime`; ohne Messwert steht `–`
    (Halbgeviertstrich) im Zeitfeld. Das Suffix ` · stale: N` erscheint nur
    bei `stale > 0`.
    """
    if newest_wall is None:
        when = '–'
    else:
        when = time.strftime('%H:%M:%S', time.localtime(newest_wall))
    caption = f'Quelle: {spec.source} · Einheit: {spec.unit} · Messzeit: {when}'
    if stale > 0:
        caption += f' · stale: {stale}'
    return caption


def format_drilldown(spec: ValueSpec, samples: Sequence[ValueSample],
                     stale: int) -> str:
    """Drill-down-Text: Kopfzeilen plus höchstens die letzten 10 Samples.

    Reihenfolge: `Label: Wert`, `Quelle:`, `Formel:`, `Toleranz: ±N pp`,
    `stale: N`, danach die Samples älteste→neueste als
    `HH:MM:SS  Wert` (zwei Leerzeichen; Zeit aus `sample.wall`). Ohne
    Samples bleiben die Sample-Zeilen weg.
    """
    newest = format_value(spec, samples[-1].value) if samples else 'stale'
    lines = [
        f'{spec.label}: {newest}',
        f'Quelle: {spec.source}',
        f'Formel: {spec.formula}',
        f'Toleranz: ±{spec.tolerance} pp',
        f'stale: {stale}',
    ]
    for sample in samples[-10:]:
        stamp = time.strftime('%H:%M:%S', time.localtime(sample.wall))
        lines.append(f'{stamp}  {format_value(spec, sample.value)}')
    return '\n'.join(lines)
