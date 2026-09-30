# Gemeinsame Fixture-Bibliothek (`test/fixtures/`)

Diese Verzeichnis ist die eine Ablage für Parser-Fixtures über beide Test-Tracks
(Flutter-Root und `packages/la_core`) sowie den Python-/GTK-Track. Sie entstand
mit #94 und ersetzt die bisher inline in `test/system_parsers_test.dart`
duplizierten Samples. Ein-Literale wie `""` oder `"some error\n"` bleiben
bewusst inline — sie sind Robustheits-Assertionen, keine Daten.

Es gibt zwei Arten von Fixtures:

- **`zorin_*.txt`** — echte, geschwärzte Ausgaben der Produktions-Kommandos,
  aufgezeichnet auf einem Zorin-Desktop (unprivilegiert).
- **`<parser>_<case>.txt`** — synthetische Edge-Vektoren für Sonderfälle, die
  ein echter Capture nicht zuverlässig liefert (duplizierte Geräte, Mountpoints
  mit Leerzeichen, Kernel-Thread-Zeilen, Uptime-Wortlautvarianten, fehlender
  Swap).

## Capture-Kommandos (Produktions-Parität)

Die echten Fixtures sind exakt mit den Aufrufen entstanden, die die App auch
im Betrieb verwendet (Quellen in Klammern). Nicht abwandeln — insbesondere die
`LC_ALL=C`-Setzungen bei `uptime`/`free` gehören zum Produktionsaufruf, während
`df` bewusst **ohne** `LC_ALL` läuft und daher deutsche Dezimalkommas
(`7,8G`) und deutsche Spaltenköpfe zeigt. Locale-Realismus ist gewollt.

| Datei | Capture-Kommando | Quelle der Parität |
|---|---|---|
| `zorin_df.txt` | `df -h` (ohne LC_ALL — Produktionsdefault) | `lib/linux/linux_filesystem.dart:9` |
| `zorin_ps.txt` | `ps -eo pcpu,args --sort=-pcpu` | `lib/linux/linux_process.dart:10` (metric=pcpu) |
| `zorin_uptime.txt` | `LC_ALL=C /usr/bin/uptime` | `lib/linux/linux_system.dart:22` |
| `zorin_free.txt` | `LC_ALL=C /usr/bin/free` | `lib/linux/linux_system.dart:11` |
| `zorin_loadavg.txt` | `cat /proc/loadavg` | `lib/linux/linux_system.dart:53` |

Dokumentierte Abweichung: `zorin_ps.txt` wurde auf die ersten 60 Zeilen
gekürzt (das Capture hatte 682; die Top-Liste braucht der Parser nur in
Ausschnitten, und weniger Zeilen bedeuten weniger Schwärzungsfläche). Alle
anderen `zorin_*`-Dateien sind vollständig.

## Schwärzungsregeln

Beim Aufzeichnen einer echten Ausgabe werden verbindlich ersetzt:

- `/home/<name>` → `/home/user` (und analog `/media/<name>/…` → `/media/user/…`).
  `/home/user` bzw. `/media/user` sind die einzigen erlaubten `/home`- bzw.
  `/media`-Segmente in Fixtures.
- Usernamen in `ps`-Argumenten → `user`.
- URLs/Hosts → `https://example.invalid/x` bzw. entfernen. `example.invalid`
  ist der einzige erlaubte URL-Platzhalter.
- IPs → entfernen (in den fünf Ausgaben kommen außer `0.0.0.0` als
  Listen-Adresse keine vor).
- Deutsche Dezimalkommas (`7,8G`) bleiben erhalten (Locale-Realismus).

Darüber hinaus im Task #94 zusätzlich geschwärzt (sensible Inhalte, die die
Regeln oben nicht abdecken):

- Hardware-Kennungen in `ps`-Argumenten: QEMU-SMBIOS-Serial und MAC-Adresse →
  `<redacted>`.
- QMP-/uvicorn-Bind-Adressen (`tcp:0.0.0.0:7149`, `--host 0.0.0.0`) →
  `<redacted>`.
- Zufalls-Suffix einer Xwayland-Session-Auth-Datei → `XXXXXX`.
- Eine im Brave-Args-Aufruf sichtbare Konto-URL → `https://example.invalid/x`.
- Der Brave-Installationspfad `/opt/brave.com/…` → `/opt/brave/…`: der
  Domain-Anteil im Pfad ist ein Struktur-Fehlalarm des Leak-Checks (er kann
  Installationspfad nicht von Host unterscheiden) und wird nach der
  Host-Regel neutralisiert; der geparste Basename bleibt `brave`.

Bewertet und absichtlich behalten (nicht identifizierend): UID `1000`
(Default-Erstbenutzer, u. a. in `/run/user/1000`), generische
Software-Inventar-Namen (Steam, Ollama, …), Chromium-Sitzungs-Zufallswerte
(`--metrics-shmem-handle`, `--pseudonymization-salt-handle`, Crash-UUIDs —
pro Session zufällig bzw. öffentliche Konstanten) sowie generische Pfade unter
`/storage` (VM-Disk-Images ohne Personenbezug).

## Leak-Check (heuristische Absicherung)

`additional/python/tests/test_fixture_leak_check.py` läuft mit der
Python-Testsuite in CI und prüft jede `*.txt`-Datei hier gegen Musterkategorien
(IPv4, IPv6-Heuristik, `/home`/`/media` mit erlaubtem Namen `user`, Domains mit
TLD-Allowlist, `user@host`). `README.md` wird nicht gescannt — sie dokumentiert
die Regeln selbst und enthielte damit die zu findenden Muster per Design.

**Der Check ist heuristisch und ersetzt keine manuelle Durchsicht:** Die
TLD-Allowlist ist bewusst kurz (`.ai` fällt z. B. durch das Raster), hex- und
ziffernähnliche Kennungen wie Serials oder MACs erkennt kein der Muster. Jede
neue echte Ausgabe vor dem Einchecken selbst nach Usernamen, Rechnernamen,
UIDs, Pfaden in `ps`-Argumenten und Browser-URLs durchsehen.

## Lesepfade

- Flutter-Root-Tests (CWD = Repo-Root): `test/fixtures/…`
- `la_core`-Tests (CWD = `packages/la_core`): `../../test/fixtures/…`
- Python-/GTK-Track: über den Repo-Root, z. B. `os.path.join(REPO_ROOT,
  "test", "fixtures")` mit `REPO_ROOT` aus `__file__` aufgelöst (siehe
  Leak-Check-Test).

## Dateien

| Datei | Art | Inhalt |
|---|---|---|
| `zorin_df.txt` | echt | `df -h`, deutsches Locale, inkl. `/run/user/1000` |
| `zorin_ps.txt` | echt | `ps -eo pcpu,args --sort=-pcpu`, erste 60 Zeilen, geschwärzt |
| `zorin_uptime.txt` | echt | `LC_ALL=C /usr/bin/uptime` |
| `zorin_free.txt` | echt | `LC_ALL=C /usr/bin/free` (Maschine mit Swap) |
| `zorin_loadavg.txt` | echt | `cat /proc/loadavg` |
| `df_duplicate_device.txt` | synthetisch | doppeltes Gerät (`/dev/sda2` zweimal) wird auf einen Eintrag reduziert |
| `df_mountpoint_spaces.txt` | synthetisch | Mountpoint mit Leerzeichen (`/media/user/USB Stick`) |
| `ps_kernel_thread_line.txt` | synthetisch | bare `0.0`-Zeile (Kernel-Thread) wird übersprungen |
| `uptime_minutes.txt` | synthetisch | `up 0:27` → Minuten-Ausgabe |
| `uptime_min_wording.txt` | synthetisch | `up 42 min` → Wortlaut „min" |
| `uptime_days.txt` | synthetisch | `up 12 days, 3:21` → Tages-Ausgabe |
| `free_no_swap.txt` | synthetisch | `Swap:`-Zeile mit Nullen → `hasSwap == false` |
