"""Tests für die /proc-Parser, die Wertespec und den Ringpuffer (Issue #96).

Die erwarteten Werte rechnet jeder Test unabhängig aus den Fixture-Texten
nach (kleine Inline-Zerlegung, bewusst NICHT die Produktionsfunktionen) —
so kann ein Formelfehler in monitor_model.py nicht durch dieselbe Rechnung
im Test verdeckt werden.

Läuft mit: python3 -m unittest discover -s prototype/gtk/tests (Repo-Root).
Kein gi-Import: die CI läuft headless.
"""
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path

GTK_DIR = Path(__file__).resolve().parents[1]
FIXTURE_DIR = GTK_DIR.parent.parent / 'test' / 'fixtures'
sys.path.insert(0, str(GTK_DIR))

import monitor_model  # Modul liegt neben diesem Testverzeichnis


def fixture_text(name):
    """Fixture aus test/fixtures/ lesen; fehlende Datei ist ein Testfehler."""
    with open(FIXTURE_DIR / name, encoding='utf-8') as handle:
        return handle.read()


def inline_cpu_times(text):
    """Unabhängige Zerlegung der aggregierten cpu -Zeile: (total, idle, iowait)."""
    for line in text.splitlines():
        if line.startswith('cpu '):
            fields = [int(part) for part in line.split()[1:]]
            return (sum(fields[:8]), fields[3],
                    fields[4] if len(fields) > 4 else 0)
    raise AssertionError('keine cpu -Zeile in %r' % text)


def inline_meminfo(text):
    """Unabhängige Zerlegung von MemTotal/MemAvailable aus /proc/meminfo."""
    values = {}
    for line in text.splitlines():
        key, _separator, rest = line.partition(':')
        if key in ('MemTotal', 'MemAvailable') and rest.split():
            values[key] = int(rest.split()[0])
    return values['MemTotal'], values['MemAvailable']


def inline_pressure_some_avg10(text):
    """Unabhängige Zerlegung des some-avg10-Werts aus /proc/pressure/*."""
    for line in text.splitlines():
        if line.startswith('some '):
            for token in line.split()[1:]:
                if token.startswith('avg10='):
                    return float(token.split('=', 1)[1])
    raise AssertionError('keine some-Zeile mit avg10= in %r' % text)


class CpuParserTests(unittest.TestCase):
    def test_parse_cpu_times_reads_the_aggregated_line(self):
        text = fixture_text('proc_stat_a.txt')
        expected_total, expected_idle, expected_iowait = inline_cpu_times(text)
        # Anker: die Fixture-Arithmetik aus dem Plan (6380/5000/100).
        self.assertEqual((expected_total, expected_idle, expected_iowait),
                         (6380, 5000, 100))
        times = monitor_model.parse_cpu_times(text)
        self.assertEqual((times.total, times.idle, times.iowait),
                         (expected_total, expected_idle, expected_iowait))

    def test_guest_times_are_not_counted_twice(self):
        # guest/guest_nice (Felder 9/10) stecken laut man proc bereits in
        # user/nice und dürfen total nicht ein zweites Mal erhöhen.
        times = monitor_model.parse_cpu_times(
            'cpu 10 0 10 100 0 0 0 0 999 999\n')
        self.assertEqual(times.total, 120)
        self.assertEqual(times.idle, 100)

    def test_steal_counts_but_guest_does_not_double_count(self):
        # Felder 1–8 (user … steal) ergeben 36; die Felder 9/10
        # (guest/guest_nice = 9/10) dürfen laut man proc nicht zusätzlich
        # zählen. Damit fallen die Mutanten sum(fields[:7]) → 28 und
        # sum(fields[:10]) → 55.
        times = monitor_model.parse_cpu_times('cpu 1 2 3 4 5 6 7 8 9 10\n')
        self.assertEqual(
            times, monitor_model.CpuTimes(total=36, idle=4, iowait=5))

    def test_four_fields_are_the_minimum_and_missing_iowait_is_zero(self):
        # Feld 4 ist idle (hier 4), Feld 5 fehlt → iowait 0.
        times = monitor_model.parse_cpu_times('cpu 1 2 3 4\n')
        self.assertEqual((times.total, times.idle, times.iowait), (10, 4, 0))

    def test_too_short_cpu_line_raises(self):
        with self.assertRaises(ValueError):
            monitor_model.parse_cpu_times('cpu 1 2 3\n')

    def test_truncated_fixture_raises(self):
        with self.assertRaises(ValueError) as caught:
            monitor_model.parse_cpu_times(fixture_text('proc_stat_truncated.txt'))
        self.assertTrue(str(caught.exception))

    def test_missing_cpu_line_raises(self):
        with self.assertRaises(ValueError):
            monitor_model.parse_cpu_times('ctxt 1\n')


class CpuPercentTests(unittest.TestCase):
    def test_percent_matches_independent_fixture_delta(self):
        text_a = fixture_text('proc_stat_a.txt')
        text_b = fixture_text('proc_stat_b.txt')
        total_a, idle_a, iowait_a = inline_cpu_times(text_a)
        total_b, idle_b, iowait_b = inline_cpu_times(text_b)
        expected = 100.0 * (
            (total_b - idle_b - iowait_b) - (total_a - idle_a - iowait_a)
        ) / (total_b - total_a)
        # Anker gegen den Plan: Δbusy 376 / Δtotal 996.
        self.assertAlmostEqual(expected, 100.0 * 376 / 996, places=6)

        got = monitor_model.cpu_percent(
            monitor_model.parse_cpu_times(text_a),
            monitor_model.parse_cpu_times(text_b))
        self.assertAlmostEqual(got, expected, delta=0.5)
        self.assertGreaterEqual(got, 0.0)
        self.assertLessEqual(got, 100.0)

    def test_without_previous_sample_gives_none(self):
        cur = monitor_model.parse_cpu_times('cpu 1 2 3 4\n')
        self.assertIsNone(monitor_model.cpu_percent(None, cur))

    def test_nonpositive_delta_gives_none(self):
        sample = monitor_model.parse_cpu_times('cpu 1 2 3 4\n')
        self.assertIsNone(monitor_model.cpu_percent(sample, sample))

    def test_decreasing_counters_give_none(self):
        prev = monitor_model.parse_cpu_times('cpu 5 0 5 100 0 0 0 0\n')
        cur = monitor_model.parse_cpu_times('cpu 1 0 1 10 0 0 0 0\n')
        self.assertIsNone(monitor_model.cpu_percent(prev, cur))


class MeminfoTests(unittest.TestCase):
    def test_parse_meminfo_reads_required_fields(self):
        total, available = inline_meminfo(fixture_text('proc_meminfo.txt'))
        self.assertEqual((total, available), (16066996, 9000000))
        info = monitor_model.parse_meminfo(fixture_text('proc_meminfo.txt'))
        self.assertEqual((info.total_kib, info.available_kib),
                         (total, available))

    def test_meminfo_without_available_raises(self):
        with self.assertRaises(ValueError):
            monitor_model.parse_meminfo('MemTotal: 1024 kB\n')

    def test_percent_matches_independent_fixture_value(self):
        text = fixture_text('proc_meminfo.txt')
        total, available = inline_meminfo(text)
        expected = 100.0 * (total - available) / total
        # Anker gegen den Plan: 100 × 7066996/16066996.
        self.assertAlmostEqual(expected, 100.0 * 7066996 / 16066996, places=6)

        got = monitor_model.meminfo_percent(monitor_model.parse_meminfo(text))
        self.assertAlmostEqual(got, expected, delta=0.2)
        self.assertGreaterEqual(got, 0.0)
        self.assertLessEqual(got, 100.0)

    def test_zero_total_gives_none(self):
        self.assertIsNone(
            monitor_model.meminfo_percent(monitor_model.MemInfo(0, 0)))


class PressureTests(unittest.TestCase):
    CASES = (
        ('proc_pressure_cpu.txt', 0.52),
        ('proc_pressure_memory.txt', 1.25),
        ('proc_pressure_io.txt', 2.50),
    )

    def test_some_avg10_matches_independent_fixture_value(self):
        for name, expected in self.CASES:
            with self.subTest(fixture=name):
                text = fixture_text(name)
                self.assertAlmostEqual(inline_pressure_some_avg10(text),
                                       expected, delta=0.01)
                got = monitor_model.parse_pressure_avg10(text)
                self.assertAlmostEqual(got, expected, delta=0.01)
                self.assertGreaterEqual(got, 0.0)
                self.assertLessEqual(got, 100.0)

    def test_missing_some_line_raises(self):
        with self.assertRaises(ValueError):
            monitor_model.parse_pressure_avg10(
                'full avg10=0.00 avg60=0.00 avg300=0.00 total=0\n')

    def test_some_line_without_avg10_raises(self):
        with self.assertRaises(ValueError):
            monitor_model.parse_pressure_avg10('some avg60=0.31 total=1234567\n')


class ValueSpecTests(unittest.TestCase):
    # Bindende D1-Werte: Label, Dezimalen, Toleranz je id.
    EXPECTED = {
        'cpu_percent': ('CPU', 1, 0.5),
        'ram_percent': ('RAM', 1, 0.2),
        'psi_cpu_avg10': ('PSI CPU', 2, 0.01),
        'psi_memory_avg10': ('PSI Speicher', 2, 0.01),
        'psi_io_avg10': ('PSI I/O', 2, 0.01),
    }

    # Quelle und Formel wörtlich aus VALUE_SPECS — Spec-Drift wird rot.
    SOURCES_AND_FORMULAS = {
        'cpu_percent': (
            '/proc/stat',
            '100 × Δbusy/Δtotal, busy = total − idle − iowait, '
            'Delta zweier aufeinanderfolgender Proben',
        ),
        'ram_percent': (
            '/proc/meminfo',
            '100 × (MemTotal − MemAvailable)/MemTotal',
        ),
        'psi_cpu_avg10': (
            '/proc/pressure/cpu',
            'some avg10 unverändert übernommen',
        ),
        'psi_memory_avg10': (
            '/proc/pressure/memory',
            'some avg10 unverändert übernommen',
        ),
        'psi_io_avg10': (
            '/proc/pressure/io',
            'some avg10 unverändert übernommen',
        ),
    }

    def test_five_specs_with_unique_ids_in_order(self):
        specs = monitor_model.VALUE_SPECS
        self.assertEqual(len(specs), 5)
        ids = [spec.id for spec in specs]
        self.assertEqual(ids, list(self.EXPECTED))
        self.assertEqual(len(set(ids)), 5)

    def test_labels_units_decimals_and_tolerances(self):
        for spec in monitor_model.VALUE_SPECS:
            label, decimals, tolerance = self.EXPECTED[spec.id]
            with self.subTest(spec=spec.id):
                self.assertEqual(spec.unit, '%')
                self.assertEqual(spec.label, label)
                self.assertEqual(spec.decimals, decimals)
                self.assertGreater(spec.tolerance, 0.0)
                self.assertAlmostEqual(spec.tolerance, tolerance, places=6)

    def test_sources_and_formulas_are_pinned(self):
        by_id = {spec.id: spec for spec in monitor_model.VALUE_SPECS}
        self.assertEqual(set(by_id), set(self.SOURCES_AND_FORMULAS))
        for value_id, (source, formula) in self.SOURCES_AND_FORMULAS.items():
            with self.subTest(spec=value_id):
                self.assertEqual(by_id[value_id].source, source)
                self.assertEqual(by_id[value_id].formula, formula)

    def test_fixture_files_exist(self):
        for spec in monitor_model.VALUE_SPECS:
            with self.subTest(spec=spec.id):
                self.assertTrue((FIXTURE_DIR / spec.fixture).is_file(),
                                'fehlende Fixture: %s' % spec.fixture)


class RingBufferTests(unittest.TestCase):
    """Ringpuffer (D3, Task 2): Monotonie, Überlauf, Tupel-Momentaufnahme."""

    def test_sample_is_a_timestamped_payload_pair(self):
        sample = monitor_model.Sample(ts=3.0, payload='wert')
        self.assertEqual(sample.ts, 3.0)
        self.assertEqual(sample.payload, 'wert')
        self.assertEqual(tuple(sample), (3.0, 'wert'))

    def test_first_append_is_always_accepted(self):
        ring = monitor_model.RingBuffer(3)
        self.assertEqual(len(ring), 0)
        self.assertEqual(ring.rejected, 0)
        self.assertTrue(ring.append(1, 'erst'))
        self.assertEqual(len(ring), 1)

    def test_first_append_with_zero_timestamp_is_accepted(self):
        # Truthiness-Falle: ts=0 ist ein gültiger erster Zeitstempel.
        ring = monitor_model.RingBuffer(3)
        self.assertTrue(ring.append(0, 'null'))
        self.assertEqual(len(ring), 1)

    def test_overflow_keeps_the_newest_entries_in_order(self):
        ring = monitor_model.RingBuffer(3)
        for ts in (1, 2, 3, 4, 5):
            self.assertTrue(ring.append(ts, 'p%d' % ts))
        self.assertEqual(ring.rejected, 0)  # Überlauf ist Annahme, keine Ablehnung
        self.assertEqual(len(ring), 3)
        self.assertEqual([sample.ts for sample in ring.entries], [3, 4, 5])
        self.assertEqual([sample.payload for sample in ring.entries],
                         ['p3', 'p4', 'p5'])

    def test_capacity_one_keeps_only_the_newest_entry(self):
        ring = monitor_model.RingBuffer(1)
        self.assertTrue(ring.append(1, 'alt'))
        self.assertTrue(ring.append(2, 'neu'))
        self.assertEqual(len(ring), 1)
        self.assertEqual(ring.entries, (monitor_model.Sample(2, 'neu'),))

    def test_same_or_smaller_timestamp_is_rejected_without_mutation(self):
        ring = monitor_model.RingBuffer(3)
        self.assertTrue(ring.append(5, 'a'))
        before_len = len(ring)
        before_entries = ring.entries
        self.assertFalse(ring.append(5, 'b'))  # gleicher ts wie der letzte
        self.assertEqual(ring.rejected, 1)
        self.assertFalse(ring.append(4, 'c'))  # kleinerer ts
        self.assertEqual(ring.rejected, 2)
        self.assertEqual(len(ring), before_len)
        self.assertEqual(ring.entries, before_entries)

    def test_rejected_counter_does_not_block_a_larger_timestamp(self):
        ring = monitor_model.RingBuffer(3)
        ring.append(5, 'a')
        self.assertFalse(ring.append(5, 'b'))
        self.assertFalse(ring.append(4, 'c'))
        self.assertTrue(ring.append(6, 'd'))
        self.assertEqual(ring.rejected, 2)
        self.assertEqual([sample.ts for sample in ring.entries], [5, 6])

    def test_nan_timestamp_is_rejected_and_guard_stays_active(self):
        ring = monitor_model.RingBuffer(3)
        self.assertTrue(ring.append(1.0, 'a'))
        before_len = len(ring)
        before_entries = ring.entries
        self.assertFalse(ring.append(float('nan'), 'n'))
        self.assertEqual(ring.rejected, 1)
        self.assertEqual(len(ring), before_len)
        self.assertEqual(ring.entries, before_entries)
        self.assertTrue(ring.append(2.0, 'b'))

    def test_positive_inf_follows_the_documented_monotonic_contract(self):
        # Doku (RingBuffer.append-Docstring + MONITOR.md §3): +inf wird
        # angenommen, solange der letzte Eintrag kleiner ist — inf > 1 gilt;
        # ein zweiter inf-Append scheitert, weil inf > inf falsch ist.
        ring = monitor_model.RingBuffer(3)
        self.assertTrue(ring.append(1.0, 'a'))
        self.assertTrue(ring.append(float('inf'), 'inf'))
        self.assertEqual(len(ring), 2)
        self.assertFalse(ring.append(float('inf'), 'nochmals'))
        self.assertEqual(ring.rejected, 1)
        self.assertEqual([sample.ts for sample in ring.entries],
                         [1.0, float('inf')])

    def test_negative_inf_is_rejected_once_the_buffer_has_entries(self):
        # Doku: -inf wird bei bestehendem Puffer abgelehnt (nicht monoton
        # gegenüber dem letzten Eintrag); nur als erster Append akzeptiert,
        # weil der Guard bei leerem Puffer kurzschließt.
        ring = monitor_model.RingBuffer(3)
        self.assertTrue(ring.append(1.0, 'a'))
        before_entries = ring.entries
        self.assertFalse(ring.append(float('-inf'), 'minus'))
        self.assertEqual(ring.rejected, 1)
        self.assertEqual(ring.entries, before_entries)

        empty = monitor_model.RingBuffer(3)
        self.assertTrue(empty.append(float('-inf'), 'erster'))
        self.assertEqual(len(empty), 1)

    def test_entries_is_a_tuple_snapshot(self):
        ring = monitor_model.RingBuffer(3)
        ring.append(1, 'a')
        entries = ring.entries
        self.assertIsInstance(entries, tuple)
        self.assertEqual(entries, (monitor_model.Sample(1, 'a'),))
        self.assertIsInstance(ring.entries, tuple)

    def test_payload_is_not_restricted_to_one_type(self):
        ring = monitor_model.RingBuffer(2)
        ring.append(1, ('value-sample', 37.8))
        ring.append(2, None)
        self.assertEqual(ring.entries[0].payload, ('value-sample', 37.8))
        self.assertIsNone(ring.entries[1].payload)

    def test_capacity_below_one_raises_value_error(self):
        for capacity in (0, -1, 0.5):
            with self.subTest(capacity=capacity):
                with self.assertRaises(ValueError):
                    monitor_model.RingBuffer(capacity)


def inline_ram_percent(text):
    """Unabhängige RAM-Nachrechnung in Prozent aus einem meminfo-Text."""
    total, available = inline_meminfo(text)
    return 100.0 * (total - available) / total


def series_entry(ts, value):
    """Sample-Eintrag mit ValueSample-Payload für build_series-Tests."""
    return monitor_model.Sample(
        ts=ts, payload=monitor_model.ValueSample(wall=ts, value=value))


class FakeReader(dict):
    """Injizierter Reader: Dict {relpath: text}; fehlender Key wirft OSError."""

    def __init__(self, files):
        super().__init__(files)
        self.read_paths = []

    def __call__(self, relpath):
        self.read_paths.append(relpath)
        if relpath not in self:
            raise OSError('Fake-Reader ohne %s' % relpath)
        return self[relpath]


class FakeClock:
    """Deterministische Uhr: liefert die (mono, wall)-Paare der Reihe nach."""

    def __init__(self, stamps):
        self._stamps = list(stamps)

    def __call__(self):
        return self._stamps.pop(0)


def fixture_reader():
    """Voll bestückter Fake-/proc-Reader: alle fünf VALUE_SPECS-Pfade."""
    return FakeReader({
        'stat': fixture_text('proc_stat_a.txt'),
        'meminfo': fixture_text('proc_meminfo.txt'),
        'pressure/cpu': fixture_text('proc_pressure_cpu.txt'),
        'pressure/memory': fixture_text('proc_pressure_memory.txt'),
        'pressure/io': fixture_text('proc_pressure_io.txt'),
    })


class BuildSeriesTests(unittest.TestCase):
    """Serienraster (D4, Task 3): Slots, stale-Lücken, jüngster Eintrag."""

    def test_gap_sequence_keeps_stale_slots_as_none_not_zero(self):
        entries = [series_entry(0, 10.0), series_entry(15, 20.0)]
        series = monitor_model.build_series(
            entries, interval=3, capacity=5, now=15)
        self.assertEqual(len(series), 5)
        self.assertEqual(series, (None, None, None, None, 20.0))
        for slot in series[:-1]:
            self.assertIsNone(slot)
            self.assertNotEqual(slot, 0.0)

    def test_full_grid_keeps_all_five_values_in_order(self):
        entries = [series_entry(ts, float(ts))
                   for ts in (3, 6, 9, 12, 15)]
        series = monitor_model.build_series(
            entries, interval=3, capacity=5, now=15)
        self.assertEqual(series, (3.0, 6.0, 9.0, 12.0, 15.0))
        self.assertEqual(monitor_model.stale_count(series), 0)

    def test_window_overflow_keeps_only_the_newest_values(self):
        entries = [series_entry(ts, float(ts)) for ts in range(3, 31, 3)]
        series = monitor_model.build_series(
            entries, interval=3, capacity=5, now=30)
        self.assertEqual(series, (18.0, 21.0, 24.0, 27.0, 30.0))

    def test_newest_entry_wins_within_one_slot(self):
        entries = [series_entry(3, 10.0), series_entry(4, 20.0)]
        series = monitor_model.build_series(
            entries, interval=3, capacity=2, now=4)
        self.assertEqual(series, (None, 20.0))

    def test_newest_entry_wins_regardless_of_input_order(self):
        entries = [series_entry(4, 20.0), series_entry(3, 10.0)]
        series = monitor_model.build_series(
            entries, interval=3, capacity=2, now=4)
        self.assertEqual(series, (None, 20.0))

    def test_now_exactly_on_slot_boundary_keeps_the_boundary_slot(self):
        entries = [series_entry(15, 20.0)]
        boundary = monitor_model.build_series(
            entries, interval=3, capacity=5, now=15)
        self.assertEqual(boundary[-1], 20.0)
        # Knapp davor liegt ts=15 (Slot 5) in der Zukunft → fällt weg.
        before = monitor_model.build_series(
            entries, interval=3, capacity=5, now=14.999)
        self.assertEqual(before, (None, None, None, None, None))

    def test_stale_count_counts_none_slots(self):
        self.assertEqual(
            monitor_model.stale_count((None, None, None, None, 20.0)), 4)
        self.assertEqual(monitor_model.stale_count([None, 1.0, None]), 2)
        self.assertEqual(monitor_model.stale_count(()), 0)

    def test_empty_entries_yield_full_none_grid_of_capacity_length(self):
        series = monitor_model.build_series(
            (), interval=3, capacity=5, now=0)
        self.assertEqual(series, (None,) * 5)
        self.assertEqual(monitor_model.stale_count(series), 5)


class ProcReaderTests(unittest.TestCase):
    """ProcReader (D5): Datei-I/O mit injizierbarem root, kein /proc-Zugriff."""

    def test_read_returns_file_content_below_root(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            nested = Path(tmpdir) / 'x'
            nested.mkdir()
            (nested / 'y').write_text('inhalt\n', encoding='utf-8')
            reader = monitor_model.ProcReader(root=tmpdir)
            self.assertEqual(reader.read('x/y'), 'inhalt\n')

    def test_missing_file_raises_os_error(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            reader = monitor_model.ProcReader(root=tmpdir)
            with self.assertRaises(OSError):
                reader.read('fehlt/nicht')


class SamplerTests(unittest.TestCase):
    """Sampler (D5, Task 3): Injektion, Lücken, CPU-Delta, Serien."""

    def test_value_sample_pairs_wall_clock_and_value(self):
        sample = monitor_model.ValueSample(wall=1000.5, value=43.98)
        self.assertEqual((sample.wall, sample.value), (1000.5, 43.98))
        self.assertEqual(tuple(sample), (1000.5, 43.98))

    def test_defaults_and_configured_interval_capacity_are_readable(self):
        default = monitor_model.Sampler(fixture_reader(), FakeClock([]))
        self.assertEqual(default.interval, 3.0)
        self.assertEqual(default.capacity, 60)
        custom = monitor_model.Sampler(
            fixture_reader(), FakeClock([]), interval=1.5, capacity=8)
        self.assertEqual(custom.interval, 1.5)
        self.assertEqual(custom.capacity, 8)

    def test_tick_reads_exactly_the_spec_sources_once(self):
        reader = fixture_reader()
        sampler = monitor_model.Sampler(
            reader, FakeClock([(0.0, 1000.0)]))
        sampler.tick()
        self.assertEqual(
            reader.read_paths,
            ['stat', 'meminfo', 'pressure/cpu',
             'pressure/memory', 'pressure/io'])

    def test_first_tick_reports_cpu_gap_and_reads_the_other_values(self):
        reader = fixture_reader()
        sampler = monitor_model.Sampler(
            reader, FakeClock([(0.0, 1000.0)]))
        sampler.tick()

        self.assertEqual(
            sampler.gaps,
            {'cpu_percent': 'Delta-Basis fehlt (erster Tick)'})
        self.assertEqual(sampler.samples('cpu_percent'), ())
        self.assertIsNone(sampler.latest('cpu_percent'))

        expected_ram = inline_ram_percent(fixture_text('proc_meminfo.txt'))
        # Anker gegen Erratum E1: 100 × 7066996/16066996 = 43,98455… %.
        self.assertAlmostEqual(
            expected_ram, 100.0 * 7066996 / 16066996, places=6)
        ram = sampler.latest('ram_percent')
        self.assertAlmostEqual(ram.value, expected_ram, delta=0.2)
        self.assertEqual(ram.wall, 1000.0)

        for value_id, expected in (('psi_cpu_avg10', 0.52),
                                   ('psi_memory_avg10', 1.25),
                                   ('psi_io_avg10', 2.50)):
            with self.subTest(value_id=value_id):
                got = sampler.latest(value_id)
                self.assertAlmostEqual(got.value, expected, delta=0.01)
                self.assertEqual(got.wall, 1000.0)

        series = sampler.series('ram_percent', now=0.0)
        self.assertEqual(len(series), 60)  # Default: 60 Slots (D2)
        self.assertAlmostEqual(series[-1], expected_ram, delta=0.2)

    def test_second_tick_reports_cpu_delta_and_clears_gaps(self):
        stat_a = fixture_text('proc_stat_a.txt')
        stat_b = fixture_text('proc_stat_b.txt')
        total_a, idle_a, iowait_a = inline_cpu_times(stat_a)
        total_b, idle_b, iowait_b = inline_cpu_times(stat_b)
        expected = 100.0 * (
            (total_b - idle_b - iowait_b) - (total_a - idle_a - iowait_a)
        ) / (total_b - total_a)
        # Anker gegen den Plan: Δbusy 376 / Δtotal 996.
        self.assertAlmostEqual(expected, 100.0 * 376 / 996, places=6)

        reader = fixture_reader()
        sampler = monitor_model.Sampler(
            reader, FakeClock([(0.0, 1000.0), (3.0, 1003.0)]))
        sampler.tick()
        reader['stat'] = stat_b  # Probe a → b zwischen den Ticks
        sampler.tick()

        self.assertEqual(sampler.gaps, {})
        cpu = sampler.latest('cpu_percent')
        self.assertAlmostEqual(cpu.value, expected, delta=0.5)
        self.assertEqual(cpu.wall, 1003.0)
        self.assertEqual(len(sampler.samples('cpu_percent')), 1)
        # Ring-ts ist mono, nicht wall: ts=3.0 ist bei now=3.0 der letzte Slot.
        series = sampler.series('cpu_percent', now=3.0)
        self.assertAlmostEqual(series[-1], expected, delta=0.5)

    def test_missing_file_is_a_gap_and_the_others_stay_fresh(self):
        reader = fixture_reader()
        sampler = monitor_model.Sampler(
            reader, FakeClock([(0.0, 1000.0), (3.0, 1003.0)]))
        sampler.tick()
        reader['stat'] = fixture_text('proc_stat_b.txt')  # CPU-Delta Tick 2
        del reader['pressure/io']
        sampler.tick()

        self.assertTrue(sampler.gaps['psi_io_avg10'].startswith('OSError'))
        self.assertEqual(
            sampler.gaps, {'psi_io_avg10': 'OSError: pressure/io'})
        for value_id in ('cpu_percent', 'ram_percent', 'psi_cpu_avg10',
                         'psi_memory_avg10'):
            with self.subTest(value_id=value_id):
                self.assertNotIn(value_id, sampler.gaps)
                self.assertEqual(sampler.latest(value_id).wall, 1003.0)
        # IO behält die Tick-1-Probe, kein neuer Eintrag.
        self.assertEqual(len(sampler.samples('psi_io_avg10')), 1)

    def test_broken_meminfo_is_a_value_error_gap(self):
        reader = fixture_reader()
        reader['meminfo'] = 'MemFree: 2111222 kB\n'  # ohne Pflichtfelder
        sampler = monitor_model.Sampler(
            reader, FakeClock([(0.0, 1000.0)]))
        sampler.tick()

        self.assertTrue(sampler.gaps['ram_percent'].startswith('ValueError'))
        self.assertEqual(
            sampler.gaps,
            {'cpu_percent': 'Delta-Basis fehlt (erster Tick)',
             'ram_percent': 'ValueError: meminfo'})
        self.assertIsNone(sampler.latest('ram_percent'))
        for value_id, expected in (('psi_cpu_avg10', 0.52),
                                   ('psi_memory_avg10', 1.25),
                                   ('psi_io_avg10', 2.50)):
            with self.subTest(value_id=value_id):
                self.assertAlmostEqual(sampler.latest(value_id).value,
                                       expected, delta=0.01)

    def test_meminfo_without_usable_total_is_a_named_value_gap(self):
        reader = fixture_reader()
        # Parsebar (beide Pflichtfelder da), aber total 0 → meminfo_percent None.
        reader['meminfo'] = 'MemTotal: 0 kB\nMemAvailable: 0 kB\n'
        sampler = monitor_model.Sampler(
            reader, FakeClock([(0.0, 1000.0)]))
        sampler.tick()

        self.assertEqual(
            sampler.gaps['ram_percent'], 'Wert ungueltig: meminfo')
        self.assertEqual(
            sampler.gaps,
            {'cpu_percent': 'Delta-Basis fehlt (erster Tick)',
             'ram_percent': 'Wert ungueltig: meminfo'})
        self.assertIsNone(sampler.latest('ram_percent'))
        self.assertEqual(sampler.samples('ram_percent'), ())
        for value_id, expected in (('psi_cpu_avg10', 0.52),
                                   ('psi_memory_avg10', 1.25),
                                   ('psi_io_avg10', 2.50)):
            with self.subTest(value_id=value_id):
                self.assertAlmostEqual(sampler.latest(value_id).value,
                                       expected, delta=0.01)

    def test_series_after_three_ticks_has_stale_gaps_and_fresh_tails(self):
        reader = fixture_reader()
        sampler = monitor_model.Sampler(
            reader, FakeClock([(0.0, 1000.0), (3.0, 1003.0),
                               (6.0, 1006.0)]))
        sampler.tick()
        reader['stat'] = fixture_text('proc_stat_b.txt')
        sampler.tick()
        # Dritte Probe mit denselben Deltas wie a→b (CPU bleibt 37,7510).
        reader['stat'] = 'cpu  1600 70 320 6200 140 14 28 0 0 0\n'
        sampler.tick()

        ram_series = sampler.series('ram_percent')
        self.assertEqual(len(ram_series), 60)
        ram_values = [sample.value
                      for sample in sampler.samples('ram_percent')]
        self.assertEqual(len(ram_values), 3)
        self.assertEqual(ram_series[-3:], tuple(ram_values))
        self.assertTrue(all(slot is None for slot in ram_series[:-3]))
        self.assertEqual(sampler.stale_count('ram_percent'), 57)

        cpu_series = sampler.series('cpu_percent')
        self.assertEqual(len(cpu_series), 60)
        # Tick 1 war die Delta-Basis-Lücke → stale (None), nie 0.
        self.assertEqual(sampler.stale_count('cpu_percent'), 58)
        self.assertIsNone(cpu_series[-3])
        self.assertIsNotNone(cpu_series[-2])
        self.assertIsNotNone(cpu_series[-1])
        self.assertEqual(len(sampler.samples('cpu_percent')), 2)

    def test_series_before_first_tick_is_a_full_none_grid(self):
        sampler = monitor_model.Sampler(fixture_reader(), FakeClock([]))
        series = sampler.series('ram_percent')
        self.assertEqual(series, (None,) * 60)
        self.assertEqual(sampler.stale_count('ram_percent'), 60)
        self.assertIsNone(sampler.latest('ram_percent'))
        self.assertEqual(sampler.samples('ram_percent'), ())

    def test_repeated_clock_is_rejected_as_non_monotonic_gap(self):
        reader = fixture_reader()
        sampler = monitor_model.Sampler(
            reader, FakeClock([(0.0, 1000.0), (0.0, 1003.0)]))
        sampler.tick()
        sampler.tick()

        self.assertEqual(sampler.gaps['ram_percent'], 'Zeit nicht monoton')
        self.assertEqual(len(sampler.samples('ram_percent')), 1)
        # CPU: zweite Probe unverändert → Δtotal 0 → 'Delta ungueltig'.
        self.assertEqual(sampler.gaps['cpu_percent'], 'Delta ungueltig')

    def test_stat_read_failure_keeps_cpu_a_gap_without_storing_a_basis(self):
        # Der CPU-Zweig ist der einzige mit zustandstragendem Delta: Liest
        # self._read (monitor_model.py:371) für stat schon bei Tick 1 nicht,
        # wirft er VOR der Zuweisung self._previous_cpu = current (:375) —
        # es wird nie eine Delta-Basis gespeichert. Tick 2 mit wieder
        # lesbarem stat muss deshalb erneut 'Delta-Basis fehlt' melden
        # statt aus einer nie vorhandenen Basis zu rechnen.
        reader = fixture_reader()
        sampler = monitor_model.Sampler(
            reader, FakeClock([(0.0, 1000.0), (3.0, 1003.0)]))
        del reader['stat']
        sampler.tick()
        self.assertEqual(sampler.gaps['cpu_percent'], 'OSError: stat')
        self.assertIsNone(sampler.latest('cpu_percent'))

        reader['stat'] = fixture_text('proc_stat_a.txt')
        sampler.tick()
        self.assertEqual(sampler.gaps['cpu_percent'],
                         'Delta-Basis fehlt (erster Tick)')
        self.assertIsNone(sampler.latest('cpu_percent'))

    def test_truncated_stat_is_a_value_error_gap(self):
        # ValueError-Zweig derselben Naht: proc_stat_truncated.txt wirft
        # beim Parsen, die Meldung folgt dem gaps-Format '%s: %s' (:354).
        reader = fixture_reader()
        reader['stat'] = fixture_text('proc_stat_truncated.txt')
        sampler = monitor_model.Sampler(
            reader, FakeClock([(0.0, 1000.0)]))
        sampler.tick()
        self.assertEqual(sampler.gaps['cpu_percent'], 'ValueError: stat')

    def test_custom_interval_and_capacity_flow_into_the_series_grid(self):
        # Serie über den Sampler: Werden interval/capacity im Konstruktor
        # gesetzt, müssen build_series-Aufrufe in Sampler.series (:408-410)
        # diese Werte weiterreichen — ein hardcodiertes 3.0/60 dort würde
        # die Slots hier falsch rasterieren.
        reader = fixture_reader()
        stamps = [(0.0, 1000.0), (1.5, 1001.5), (3.0, 1003.0), (4.5, 1004.5)]
        sampler = monitor_model.Sampler(
            reader, FakeClock(stamps), interval=1.5, capacity=4)
        for _ in stamps:
            sampler.tick()

        series = sampler.series('ram_percent', now=4.5)
        self.assertEqual(len(series), 4)
        self.assertEqual(sampler.stale_count('ram_percent', now=4.5), 0)
        ram_values = [sample.value
                      for sample in sampler.samples('ram_percent')]
        self.assertEqual(series, tuple(ram_values))


def value_spec(value_id):
    """ValueSpec per id aus VALUE_SPECS (Reihenfolge prüft die Spec-Klasse)."""
    return next(spec for spec in monitor_model.VALUE_SPECS if spec.id == value_id)


class FormatterTests(unittest.TestCase):
    """Formatierer (Task 4): Anzeige, Caption, Drill-down — exakte Strings.

    Die Zeitfälle laufen mit `TZ=UTC` (setUp/tearDown, `time.tzset()`);
    Wall 1000.0 → `00:16:40`, 1003.0 → `00:16:43`.
    """

    def setUp(self):
        self._old_tz = os.environ.get('TZ')
        os.environ['TZ'] = 'UTC'
        time.tzset()

    def tearDown(self):
        if self._old_tz is None:
            os.environ.pop('TZ', None)
        else:
            os.environ['TZ'] = self._old_tz
        time.tzset()

    def test_format_value_uses_spec_decimals_and_unit(self):
        # Punkt als Dezimaltrenner; Anzeige-Rundung der Plan-Anker.
        self.assertEqual(
            monitor_model.format_value(
                value_spec('cpu_percent'), 100.0 * 376 / 996), '37.8 %')
        self.assertEqual(
            monitor_model.format_value(
                value_spec('ram_percent'), 100.0 * 7066996 / 16066996),
            '44.0 %')
        self.assertEqual(
            monitor_model.format_value(value_spec('psi_cpu_avg10'), 0.52),
            '0.52 %')

    def test_format_value_none_is_stale_never_zero(self):
        cpu = value_spec('cpu_percent')
        self.assertEqual(monitor_model.format_value(cpu, None), 'stale')
        self.assertNotEqual(monitor_model.format_value(cpu, None), '0.0 %')
        self.assertNotEqual(monitor_model.format_value(cpu, None), '0 %')

    def test_format_caption_pins_source_unit_and_wall_clock(self):
        self.assertEqual(
            monitor_model.format_caption(value_spec('cpu_percent'), 1000.0, 0),
            'Quelle: /proc/stat · Einheit: % · Messzeit: 00:16:40')

    def test_format_caption_appends_stale_suffix_only_when_stale(self):
        cpu = value_spec('cpu_percent')
        self.assertEqual(
            monitor_model.format_caption(cpu, 1000.0, 57),
            'Quelle: /proc/stat · Einheit: % · Messzeit: 00:16:40 · stale: 57')
        self.assertEqual(
            monitor_model.format_caption(cpu, 1000.0, 0),
            'Quelle: /proc/stat · Einheit: % · Messzeit: 00:16:40')

    def test_format_caption_without_sample_shows_dash_and_stale(self):
        self.assertEqual(
            monitor_model.format_caption(value_spec('cpu_percent'), None, 60),
            'Quelle: /proc/stat · Einheit: % · Messzeit: – · stale: 60')

    def test_format_drilldown_pins_full_multiline_text(self):
        samples = [monitor_model.ValueSample(wall=1000.0, value=10.0),
                   monitor_model.ValueSample(wall=1003.0, value=20.0)]
        self.assertEqual(
            monitor_model.format_drilldown(
                value_spec('cpu_percent'), samples, 58),
            'CPU: 20.0 %\n'
            'Quelle: /proc/stat\n'
            'Formel: 100 × Δbusy/Δtotal, busy = total − idle − iowait, '
            'Delta zweier aufeinanderfolgender Proben\n'
            'Toleranz: ±0.5 pp\n'
            'stale: 58\n'
            '00:16:40  10.0 %\n'
            '00:16:43  20.0 %')

    def test_format_drilldown_without_samples_has_no_sample_lines(self):
        lines = monitor_model.format_drilldown(
            value_spec('cpu_percent'), [], 60).splitlines()
        self.assertEqual(lines, [
            'CPU: stale',
            'Quelle: /proc/stat',
            'Formel: 100 × Δbusy/Δtotal, busy = total − idle − iowait, '
            'Delta zweier aufeinanderfolgender Proben',
            'Toleranz: ±0.5 pp',
            'stale: 60',
        ])

    def test_format_drilldown_keeps_only_the_last_ten_samples(self):
        samples = [monitor_model.ValueSample(wall=1000.0 + 3 * index,
                                             value=10.0 + index)
                   for index in range(12)]
        lines = monitor_model.format_drilldown(
            value_spec('cpu_percent'), samples, 48).splitlines()
        self.assertEqual(len(lines), 5 + 10)
        self.assertEqual(lines[5], '00:16:46  12.0 %')   # ältestes der letzten 10
        self.assertEqual(lines[-1], '00:17:13  21.0 %')  # jüngstes


if __name__ == '__main__':
    unittest.main()
