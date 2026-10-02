"""Tests für die /proc-Parser, die Wertespec und den Ringpuffer (Issue #96).

Die erwarteten Werte rechnet jeder Test unabhängig aus den Fixture-Texten
nach (kleine Inline-Zerlegung, bewusst NICHT die Produktionsfunktionen) —
so kann ein Formelfehler in monitor_model.py nicht durch dieselbe Rechnung
im Test verdeckt werden.

Läuft mit: python3 -m unittest discover -s prototype/gtk/tests (Repo-Root).
Kein gi-Import: die CI läuft headless.
"""
import sys
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

    def test_overflow_keeps_the_newest_entries_in_order(self):
        ring = monitor_model.RingBuffer(3)
        for ts in (1, 2, 3, 4, 5):
            self.assertTrue(ring.append(ts, 'p%d' % ts))
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
        for capacity in (0, -1):
            with self.subTest(capacity=capacity):
                with self.assertRaises(ValueError):
                    monitor_model.RingBuffer(capacity)


if __name__ == '__main__':
    unittest.main()
