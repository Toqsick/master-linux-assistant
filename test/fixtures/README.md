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
| `zorin_free.txt` | `LC_ALL=C /usr/bin/free -m` | `lib/linux/linux_system.dart:11` |
| `zorin_loadavg.txt` | `cat /proc/loadavg` | `lib/linux/linux_system.dart:53` |

Dokumentierte Abweichung: `zorin_ps.txt` wurde auf die ersten 60 Zeilen
gekürzt (das Capture hatte 682; die Top-Liste braucht der Parser nur in
Ausschnitten, und weniger Zeilen bedeuten weniger Schwärzungsfläche). Alle
anderen `zorin_*`-Dateien sind vollständig.

Bug-Notiz (`zorin_free.txt`, neu aufgezeichnet am 2026-09-30): Der erste
Capture lief ohne `-m` und enthielt KiB-Werte, während `MemoryInfo.*Mb`
(Doku: „free -m, in mebibytes") und die Formatter (`/1024`, MiB→GiB)
Mebibytes erwarten — auf diesem Capture-Pfad wären alle RAM-/Swap-Werte
1024× zu hoch angezeigt worden. Der Produktionsaufruf in
`lib/linux/linux_system.dart:11` wurde auf `/usr/bin/free -m` korrigiert und
die Fixture damit neu aufgezeichnet (Follow-up aus dem #94-Review-Minor zu
MemoryInfo MiB/KiB + Ad-hoc-Befund 2026-09-30). Der Dashboard-Poller
(`lib/services/system_stats_service.dart`) führte `free -m` bereits korrekt;
der Fix beseitigt den letzten KiB-Capture und stellt die
Produktions-Parität dieser Fixture wieder her.

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
- Die Brave-Crash-Reporter-Client-ID (`--enable-crash-reporter=<UUID>`,
  4 Vorkommnisse) → `<redacted>`: diese ID ist persistent pro Installation
  und damit identifierend. Sie wurde in der ersten Fassung dieses Abschnitts
  fälschlich als Session-Zufallswert geführt und im Final-Review-#94-Fix
  korrigiert.
- Ports in eindeutiger Form → `<redacted>`: `telnet:localhost:7100`
  (host:port-Form), `tcp:<redacted>:7149` (Port hinter bereits geschwärztem
  Host) und `--port=41641` (tailscaled, `port=`-Form). Verbleibende Ports:
  `5700` (`websocket=5700`, QEMU-VNC-Websocket-Default) und `7000`
  (`--port 7000`, Leerzeichen-Form) — Begründung im Abschnitt Leak-Check.
- Der Brave-Installationspfad `/opt/brave.com/…` → `/opt/brave/…`: der
  Domain-Anteil im Pfad ist ein Struktur-Fehlalarm des Leak-Checks (er kann
  Installationspfad nicht von Host unterscheiden) und wird nach der
  Host-Regel neutralisiert; der geparste Basename bleibt `brave`.

Bewertet und absichtlich behalten (nicht identifizierend): UID `1000`
(Default-Erstbenutzer, u. a. in `/run/user/1000`), generische
Software-Inventar-Namen (Steam, Ollama, …), Chromium-Sitzungs-Zufallswerte
(`--metrics-shmem-handle`, `--pseudonymization-salt-handle` — pro Session
zufällige Handle-/Salt-Werte; die Brave-Crash-Reporter-Client-ID zählt
nicht dazu, sie ist persistent pro Installation und wurde nachträglich
geschwärzt, siehe Liste oben) sowie generische Pfade unter
`/storage` (VM-Disk-Images ohne Personenbezug).

## Leak-Check (heuristische Absicherung)

`additional/python/tests/test_fixture_leak_check.py` läuft mit der
Python-Testsuite in CI und prüft jede `*.txt`-Datei hier gegen Musterkategorien
(IPv4, IPv6-Heuristik, `/home`/`/media` mit erlaubtem Namen `user`, Domains mit
TLD-Allowlist, `user@host`, Ports in `port=`-/`port:`-Form, `host:port`).
`README.md` wird nicht gescannt — sie dokumentiert
die Regeln selbst und enthielte damit die zu findenden Muster per Design.

Port-Formen im Einzelnen: geprüft werden `port=<zahl>`/`port: <zahl>`
(z. B. `--port=41641`) und `host:port` mit hostname-artigem Host
(Buchstaben/Ziffern/Bindestriche/Punkte, keine Unterstriche) unmittelbar vor
dem Doppelpunkt (z. B. `localhost:7100`); der Doppelpunkt darf nicht
unmittelbar nach einer Ziffer oder einem Doppelpunkt stehen, damit Uhrzeiten
(`14:23:01`, `up 3:45`) und Kernel-Thread-Namen (`259:0`) nicht matchen.
Bloße Port-Zahlen in Argumenten ohne Host-Kontext bleiben bewusst drin — sie
sind ohne Fehlalarme nicht erkennbar und nicht identifizierend
(Standard-Dienstports): in `zorin_ps.txt` verbleiben `websocket=5700`
(QEMU-Default) und `--port 7000` (Leerzeichen-Form, von `port=`/`port:`
unterschieden).

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

## GTK-/Python-Track

Der Python-/GTK-Track liest dieselben Fixtures über den Repo-Root, der zur
Laufzeit aus dem Skriptpfad aufgelöst wird — exakt wie im Leak-Check
(`additional/python/tests/test_fixture_leak_check.py:19`, `REPO_ROOT` aus
`__file__`, vier dirname-Ebenen nach oben (tests → python → additional →
Repo-Root), dann `os.path.join(REPO_ROOT, "test", "fixtures")`). Adapter
unter `prototype/gtk/` sollen im Repo-Checkout denselben
`test/fixtures/`-Pfad lesen. Wie ein später installierter (nicht
ausgecheckter) Client die Fixtures findet, ist über den A2/#92-Adapter
zu definieren — dafür gibt es noch keine Konvention.

Beleg, dass der Python-Lesezugriff auf diese Fixtures funktioniert und
bei jedem CI-Lauf ausgeführt wird (Trigger sind ausschließlich Push/PR):
`additional/python/tests/test_fixture_leak_check.py`
iteriert über jede `*.txt`-Datei in `test/fixtures/` und failt, wenn das
Verzeichnis fehlt oder leer ist — der Pfad ist damit Teil der laufenden
Python-Testsuite, nicht nur dokumentiert.

Echte GTK-Datenadapter (Anbindung der Fixtures an die GTK-Oberfläche) sind
Gegenstand von A2/#92 und Folgetasks. Dieser Abschnitt dokumentiert nur die
Lese-Konvention; in `prototype/gtk/` existiert dazu bewusst noch kein Code.

## Dateien

| Datei | Art | Inhalt |
|---|---|---|
| `zorin_df.txt` | echt | `df -h`, deutsches Locale, inkl. `/run/user/1000` |
| `zorin_ps.txt` | echt | `ps -eo pcpu,args --sort=-pcpu`, erste 60 Zeilen, geschwärzt |
| `zorin_uptime.txt` | echt | `LC_ALL=C /usr/bin/uptime` |
| `zorin_free.txt` | echt | `LC_ALL=C /usr/bin/free -m` (Maschine mit Swap, MiB) |
| `zorin_loadavg.txt` | echt | `cat /proc/loadavg` |
| `df_duplicate_device.txt` | synthetisch | doppeltes Gerät (`/dev/sda2` zweimal) wird auf einen Eintrag reduziert |
| `df_mountpoint_spaces.txt` | synthetisch | Mountpoint mit Leerzeichen (`/media/user/USB Stick`) |
| `ps_kernel_thread_line.txt` | synthetisch | bare `0.0`-Zeile (Kernel-Thread) wird übersprungen |
| `uptime_minutes.txt` | synthetisch | `up 0:27` → Minuten-Ausgabe |
| `uptime_min_wording.txt` | synthetisch | `up 42 min` → Wortlaut „min" |
| `uptime_days.txt` | synthetisch | `up 12 days, 3:21` → Tages-Ausgabe |
| `free_no_swap.txt` | synthetisch | `Swap:`-Zeile mit Nullen → `hasSwap == false` |
