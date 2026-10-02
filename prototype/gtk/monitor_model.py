"""Reine /proc-Parser und Wertespec für den GTK-Systemmonitor (Issue #96).

Spec: `docs/mla-next/MONITOR.md` §1 (Werte & Quellen); die maschinenlesbare
Fassung der Tabelle liegt hier als `VALUE_SPECS`. Das Modul ist gi-frei und
macht kein I/O — es parst übergebene Textinhalte. Fehlende Pflichtfelder
werfen `ValueError` mit klarer Botschaft; das Lücken-Handling (stale statt 0)
übernimmt ausschließlich der Sampler aus Task 3. Kein Import aus dem
GTK-Stack — die CI läuft headless.
"""
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
