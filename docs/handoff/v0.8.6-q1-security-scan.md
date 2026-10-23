# deliverable.md — V0.8.6 Welle 1: Q1 Security-Scan auf Knopfdruck (#58)

> **Stand:** 2026-10-23 · **Basis:** `main` @ `08dad94` · **Branch:** `feature/58-q1-security-scan`
> **Umfang:** Q1 aus Issue #58 — der Security-Check startet nicht mehr beim Betreten der
> Sektion, sondern auf Knopfdruck, und sein Ergebnis überlebt einen App-Neustart.

## Was geändert wurde

| Datei | Änderung |
|---|---|
| `lib/services/security_scan_cache.dart` (neu) | Cache des letzten Scan-Ergebnisses unter `$XDG_CACHE_HOME/linux-assistant/security-last.json` |
| `lib/layouts/security_check/overview.dart` | Scan startet nur auf Klick; Cache wird gelesen und geschrieben; Alter des gecachten Ergebnisses wird angezeigt |
| `lib/l10n/*.arb` + generierte Dateien | 7 neue Strings in **allen vier** Sprachen (en/de/it/fi) |
| `test/q1_security_scan_test.dart` (neu) | 29 Tests: Cache-Ort, Snapshot-Format, Altersberechnung, Cache-Verhalten, Seiten-Verhalten |

## Die Abnahmekriterien aus #58

| Kriterium | Umsetzung | Nachweis |
|---|---|---|
| Der Scan startet **nicht** beim ersten Build | `_checkerOutput` ist nullable und bleibt null, bis der Knopf gedrückt wird | `the page starts no scan when the page is opened` — `runner.calls` ist leer |
| Kein pkexec-Dialog beim Betreten | dieselbe Ursache: es wird kein Befehl gestartet | derselbe Test |
| Ergebnis in `$XDG_CACHE_HOME/linux-assistant/security-last.json` | `SecurityScanCache` — `XDG_CACHE_HOME` mit Fallback `~/.cache` | `cache location`-Gruppe (3 Tests) + `the result file is security-last.json in that directory` |
| Befund-Tokens + Zeitstempel | `SecurityScanSnapshot` mit `tokens` (die Zeilen des Checkers) und `timestamp` (UTC, ISO 8601) | `the JSON shape is stable` + `cache the written file is the documented JSON` |
| Nach Neustart mit „vor X" | Die Seite liest den Cache beim Öffnen und zeigt das Alter | `shows the cached result with its age after a restart` |
| l10n in allen vier Sprachen | 7 Keys × (en, de, it, fi) | `flutter gen-l10n` erzeugt, l10n-Ratchet grün |

### Das Cache-Format

```json
{
  "version": 1,
  "timestamp": "2026-10-23T12:30:00.000Z",
  "tokens": ["firewallinactive", "upgradeablepackage: linux-assistant-1.0"]
}
```

Der Cache ist ein **Cache**, keine Konfiguration: er darf jederzeit gelöscht werden, und die App
muss sein Fehlen überstehen. Deshalb:

- **Format-Version.** Eine Datei mit anderer Version wird ignoriert, nicht missverstanden.
- **Defekte Datei.** Eine kaputte Datei liefert `null` statt einer Exception — die Seite
  zeigt „noch kein Check gelaufen", nicht einen Fehlerdialog.
- **Atomares Schreiben.** Die Datei wird als Nachbar geschrieben und danach umbenannt. Eine
  App, die mitten im Schreiben stirbt, hinterlässt keine halbe Datei, die niemand mehr lesen kann.
- **Tokens statt Sätzen.** Gespeichert werden die Zeilen des Checkers, nicht die Sätze der UI.
  Die Sätze werden bei jedem Start neu abgeleitet — ein auf Deutsch gecachter Befund liest sich
  nach einem Wechsel auf Finnisch trotzdem richtig.
- **Erfolgsschild.** Die Erfolgsmarke des Checkers ist kein Befund und wird nicht gespeichert.

## TDD-Beleg

`test/q1_security_scan_test.dart` — 29 Tests in fünf Gruppen:

| Gruppe | Testfälle |
|---|---|
| `cache location` | `XDG_CACHE_HOME` wird beachtet · Fallback `~/.cache` · leeres `XDG_CACHE_HOME` · Datei heißt `security-last.json` |
| `snapshot` | Befundzeilen bleiben, Erfolgsschild fällt weg · der Inhalt bleibt erhalten · JSON-Roundtrip · stabiles Format · fremde Version abgelehnt · unbrauchbarer Zeitstempel abgelehnt · Nicht-Text-Tokens abgelehnt |
| `age` | unter einer Minute = „gerade eben" · Minuten · Stunden · Tage · Zeitstempel in der Zukunft = „gerade eben" · exakt eine Minute ist eine Minute |
| `cache` | vor dem ersten Scan kein Ergebnis · schreiben und lesen · Verzeichnis wird angelegt · kaputte Datei überlebt · leere Datei überlebt · keine temporäre Datei bleibt liegen · geschriebene Datei ist das dokumentierte JSON |
| `the page` | **kein Scan beim Öffnen** · der Knopf ist da · genau ein Scan pro Druck · das Ergebnis landet im Cache · nach „Neustart" zeigt die Seite das gecachte Ergebnis mit Alter — und startet nichts |

## Gate-Protokoll

`bash /workspace/tools/run-mla-gates.sh` — echte Exitcodes.

| Gate | Ergebnis |
|---|---|
| `flutter pub get` | OK |
| `bash tool/check-versions.sh` | OK |
| `dart format --output=none --set-exit-if-changed lib test` | OK — 126 Dateien, 0 geändert |
| `flutter analyze` | OK — *No issues found!* |
| `flutter test` | OK — **259 Tests** (230 Baseline + 29 neue) |
| Python-Unit-Tests | OK — 62 Tests |
| GTK-Token-Gate | OK — 96 Tests (2 skipped) |
| `packages/la_core` | OK — 0 Findings, 25 Dateien, 68 Tests |

**Summenzeile: `ALLE GATES GRUEN`.**

## Konventionen geprüft

- Conventional Commit, deutschsprachiger Body, `Refs #58` ✓
- `dart format` vor dem Commit ✓
- Logging über `lib/services/logger.dart`, kein `print` ✓
- l10n: 7 Keys in allen vier ARB-Dateien, generiert mit `flutter gen-l10n` ✓
- Keine Secrets, kein Versions-Bump, kein Release ✓
- **Die Security-Check-Logik selbst wurde nicht angefasst** — der privilegierte Runner und die
  polkit-Aktionen bleiben unangetastet. Der Cache speichert nur, was der Checker ohnehin
  ausgibt.

## Zwei Korrekturen an der Vorarbeit

1. **`setState` mit Future.** `setState(() => _checkerOutput = _runAndStore())` übergibt dem
   Callback ein Future — Flutter lehnt das ab („setState() callback argument returned a
   Future"). Der Callback braucht einen Block-Body.
2. **Echte Datei-IO im Widget-Test.** `await cache.read()` in der Fake-Async-Zone eines
   `testWidgets` bekommt sein IO-Ereignis nie und der Test hängt bis zum Zeitüberlauf. Echte
   IO muss über `tester.runAsync(...)` laufen. Betroffen waren zwei Stellen im Test.

Beides war in der Vorarbeit so nicht vorhanden und ist hier behoben.

## Offene Punkte

- **Der manuelle Abnahmeschritt** bleibt offen: ein echter Scan braucht root und damit ein
  Passwort-Dialog. In der Sandbox läuft der Check über einen Fake-Runner, der das
  Checker-Format liefert. Der Button und der Cache-Pfad sind damit geprüft, das echte
  `pkexec` nicht.
- **Was passiert, wenn der Check fehlschlägt?** `_rootRequired` und `_scriptFailed` bleiben
  unverändert — sie zeigen den Fehler und bieten den erneuten Versuch. In den Cache landet
  nur ein erfolgreicher Lauf; ein fehlgeschlagener verwischt das letzte gecachte Ergebnis
  nicht.
- **Q4 und Q7** (Hotkey bzw. Feedback-Entfernung) sind nicht Teil dieses Pakets.
