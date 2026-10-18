# Issues V1.1 – V1.3 — Master Linux Assistant (MLA)

> 32 Issues, je mit Titel, Meilenstein, Labels und fertigem Body (1:1 kopierbar).
> Labels: vorhanden `epic:{fu,lb,di,sp,st,te,wz,ds}`, `tier:{core,qol,n2h}`, `size:{S,M,L}`, `gate:manual`, `roadmap`; neu: `epic:ux`, `epic:gn`, `epic:ga`, `shell:gtk`.
> Issue-Bodies unterliegen dem Leak-Grep (keine Hosts, IPs, Ports, `/home`-Pfade, keine Unit-, Container- oder Koordinatenwerte des Referenzsystems).
> Abhängigkeiten nennen neue Issues per Kurz-ID (z. B. `FU4`); das Anlege-Skript ersetzt sie durch GitHub-Nummern und setzt die Rückrichtung „Blockiert". Die GitHub-Nummern stehen in der Zuordnungstabelle am Ende.
> Meilensteine: V1.1 = „V1.1 – Cockpit-QoL & UX" · V1.2 = „V1.2 – Zorin/GNOME-Integration & Werkzeuge" · V1.3 = „V1.3 – Nice-to-haves & Parkliste".

---

## Issue 1 — [V1.1] FU4 Generischer Probe-Vertrag über IPC

**Meilenstein:** V1.1 · **Labels:** `epic:fu`, `tier:core`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
„Ist alles in Ordnung?" braucht einen Weg, auf dem jede Probe aus dem Dart-Kern ohne eigene UI-Verdrahtung in der GTK-Shell ankommt. Befund: `ModuleRegistry`, `ProbeRegistry` und `EventBus` (`CoreTopics.probeResult`) laufen heute nur in den la_core-Tests; `la_probe` kennt nur `--version`/`SelfProbe`; der IPC-Entwurf nennt nur `backup.*`-Methoden.

## Scope
- GTK-Delta zu #100 (A4 IPC) und #102 (Lagebild): Transport und Peer-Prüfung bleiben #100, die Ampeln bleiben #102 — FU4 macht den Vertrag **probe-generisch**, damit neue Probes keine neuen Wire-Methoden brauchen.
- (a) `la_probe --json <probe-id>` als CLI-Backend (kein Socket): gibt `ProbeResult{severity, key, params, at}` + `ProbeState` als eine JSON-Zeile aus; `--json all` listet alle registrierten Probes. Das ist die Zwischenstufe für alle ⚡-Probes (ST4, GA1, SP3, DI8 …).
- (b) IPC-Methoden `probe.list`, `probe.get`, `probe.watch` und Notification `probe.changed` mit demselben Payload, registry-getrieben aus `ProbeRegistry`. `backup.*` aus `docs/mla-next/IPC_CONTRACT.md` wird Capability/Spezialfall von `probe.*` (Vertrag dort anpassen; Kommentar auf #100/#102: Namensraum von Anfang an so nutzen).
- (c) `prototype/gtk/probe_store.py`: ein `ProbeStore` mit Backends `fixture` → `cli` (la_probe) → `ipc` (stdlib `socket` AF_UNIX + `GLib.io_add_watch`, 64-KiB-Framelimit **vor** dem Parsen, Seq-Lücke/Disconnect → `stale` + Snapshot-Neuabruf). Module lesen nur aus dem Store.
- Prozess-Modell: IPC-Host = Kindprozess der GTK-App (`Gio.Subprocess`), endet mit ihr. Kein Dauerprozess, kein Autostart.
- Grenzen: GTK-UI und Dart-Host nie als Root; keine Shell-Strings; keine Root-/Exec-Methoden im Wire; polkit-Grenze unberührt; keine Secrets im Payload.

## Andockpunkte
- `packages/la_core/bin/la_probe.dart` (heute nur `--version`), `packages/la_core/lib/src/probe.dart` (`ProbeResult`, `ProbeSeverity`), `probe_status.dart` (`ProbeState`), `probe_registry.dart`, `event_bus.dart`
- `docs/mla-next/IPC_CONTRACT.md` (Methodenliste), `prototype/gtk/mla_app.py` (`MODULES`, `select_module`)
- Fixtures: `packages/la_core/test/` (Contract-Fixtures je Methode), `prototype/gtk/tests/test_probe_store.py`

## Abnahme
- [ ] Eine neue Probe im Kern erscheint ohne GTK-Codeänderung im Store und damit in der Ampel-Liste
- [ ] Contract-Fixtures positiv/negativ für `probe.list/get/watch` (falscher Frame, über 64 KiB, unbekannte ID)
- [ ] `la_probe --json <id>` liefert dasselbe Schema wie die IPC-Antwort (Schema-Test vergleicht beide)
- [ ] Nach Disconnect zeigt der Store `stale` (gestrichelt), nach Reconnect einen vollständigen Snapshot

## Abhängigkeiten
Blockiert durch: #100, #102 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: #100/#102 bauen eigene Methoden, bevor FU4 greift → FU4 schrumpft auf Store + Contract-Fixtures; bis dahin laufen ⚡-Issues über das `cli`-Backend._

_Tier: Core · Größe: M · shell:gtk · Gates: `cd packages/la_core && dart test` · `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic FU (Teilplan FU4)._
```

---

## Issue 2 — [V1.1] DS7 l10n-Grundgerüst GTK

**Meilenstein:** V1.1 · **Labels:** `epic:ds`, `tier:qol`, `size:S`, `shell:gtk`

### Body

```markdown
## Job
Jede Satz-Abnahme („erklärt sich in einem Satz", „Was tun?") braucht übersetzbare Strings; die GTK-Shell hat heute weder gettext noch `.po`-Dateien.

## Scope
- gettext-Domain `linux-assistant`, Quelldateien `prototype/gtk/po/{de,en}.po`, Build-Schritt `msgfmt` (Make-Ziel oder `tool/`-Skript), Laufzeit-Lookup über `gettext.translation`; Hilfsfunktion `_()` in `prototype/gtk/i18n.py`.
- Key-Konvention = ARB-Key der Flutter-App (`lib/l10n/app_en.arb`), damit Probe-`messageKey`s in beiden Shells dieselben Keys treffen.
- Sprache folgt `LANG`/`LANGUAGE`; ein Override kommt mit UX4.
- Ratchet-Test: jeder in `prototype/gtk/*.py` benutzte Key existiert in beiden `.po` (Regex über `_('…')`).
- Grenzen: keine neuen pip-Pakete (gettext ist Standardbibliothek).

## Andockpunkte
- `prototype/gtk/mla_app.py` (`MODULES`-Titel, Detailtexte), `lib/l10n/app_en.arb` (Key-Vorbild), `.github/workflows/build.yml` (msgfmt-Schritt neben dem Token-Gate)
- Test: `prototype/gtk/tests/test_i18n.py`

## Abnahme
- [ ] Alle sichtbaren Strings in `mla_app.py` laufen über `_()`
- [ ] Ratchet-Test grün; ein fehlender Key in `de.po` macht den Test rot (Negativ-Fixture)
- [ ] `LANG=de_DE.UTF-8` zeigt deutsche Modultitel, `LANG=C` englische (Test über das Übersetzungsobjekt)

## Abhängigkeiten
Blockiert durch: — (⚡ sofort startbar) · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: `msgfmt` fehlt auf dem Runner → `.mo` im Test aus `.po` mit dem Python-Äquivalent erzeugen._

_Tier: QoL · Größe: S · shell:gtk · Gates: `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic DS (Teilplan DS7)._
```

---

## Issue 3 — [V1.1] UX1 Navigation, Fensterzustand & Tastatur-Grundgerüst

**Meilenstein:** V1.1 · **Labels:** `epic:ux`, `tier:qol`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
„Schnell erledigen": Die Shell soll sich wie ein Werkzeug anfühlen, das sich merkt, wo man war, und per Tastatur bedienbar ist. Flutter-Pendants: DS4 (#86, Sidebar/Navigation) und DS3 (#79, Kürzel) — gelten für GTK sinngemäß, der Flutter-UI-Teil entfällt.

## Scope
- `Adw.OverlaySplitView` statt `Adw.NavigationSplitView`: Sidebar ein-/ausklappbar (Strg+B); unter 1000 px Breite (`Adw.Breakpoint`) eine Rail aus symbolischen Icons — je Modul in `MODULES` ein Icon-Name (z. B. `view-grid-symbolic`, `utilities-system-monitor-symbolic`, `drive-harddisk-symbolic`, `security-high-symbolic`).
- Fensterzustand (Größe, Position soweit der Compositor sie liefert, Paned-Position, letztes Modul, Sidebar-Zustand) atomar (tmp + rename) in `$XDG_CONFIG_HOME/linux-assistant/gtk-state.json` mit `schema`-Feld.
- Kürzel aus einer zentralen Tabelle (`prototype/gtk/shortcuts.py`): Strg+1…9 = Modul, Esc = Dashboard, F5 = Modul neu laden, Strg+B = Sidebar, Strg+? = `Gtk.ShortcutsWindow` (aus derselben Tabelle generiert).
- Header zeigt Modul-Icon + Titel.
- Grenzen: nur UI-Zustand, keine Systemaktionen.

## Andockpunkte
- `prototype/gtk/mla_app.py`: `Window.__init__` (SplitView, `Gtk.Paned`, `PANE_POSITION`), `MODULES`, `select_module`; Layout-Tokens `docs/mla-next/TOKENS.md` §2 (`layoutPanePos`, `layoutWindow`)
- Hinweis: PR #119 (#96) ändert `mla_app.py` — Andockpunkte nach dessen Merge neu beziehen
- Tests: `prototype/gtk/tests/test_window_state.py` (headless, State-Datei), Widget-Test unter `xvfb-run`

## Abnahme
- [ ] Neustart stellt Größe, Paned-Position, Sidebar-Zustand und letztes Modul wieder her (State-Datei-Test, headless)
- [ ] Strg+3 wechselt ins dritte Modul; Esc führt zum Dashboard (Widget-Test unter xvfb)
- [ ] Unter 1000 px erscheint die Rail, darüber die volle Sidebar
- [ ] Kürzel-Overlay listet exakt die Einträge der Kürzel-Tabelle (Test vergleicht beide)

## Abhängigkeiten
Blockiert durch: — (⚡ sofort startbar; nach Merge von PR #119 rebasen) · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Fensterposition ist unter Wayland nicht abfragbar → nur Größe/Paned/Modul merken, Position auslassen und dokumentieren._

_Tier: QoL · Größe: M · shell:gtk · Gates: `python3 -m unittest discover -s prototype/gtk/tests` (Widget-Tests unter `xvfb-run`)._
_Quelle: Ausbauplan V1.1–V1.3, Epic UX (Teilplan UX1)._
```

---

## Issue 4 — [V1.1] UX2 Kontext-Inspektor (rechte Leiste)

**Meilenstein:** V1.1 · **Labels:** `epic:ux`, `tier:qol`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
Jede Ampel und jede Kachel muss sich erklären: Quelle, Messzeit, Einheit, ein Satz, mögliche Aktionen. Heute ist die rechte Leiste ein `Gtk.Label` mit Platzhaltertext.

## Scope
- Panel statt Label: Status-Chip (Tone-Klassen aus TOKENS §4), Ein-Satz-Erklärung (messageKey → DS7), Meta-Zeilen Quelle · Messzeit · Einheit, Aktionsliste (nur Hand-offs und bestätigte Aktionen), Verlauf (letzte Übergänge, aus LB4), ein-/ausklappbar (Strg+I), per Tastatur fokussierbar.
- `DetailsProvider`-Protokoll (Python `typing.Protocol`): `details(module_id) -> Details(status, sentence_key, source, measured_at, unit, actions, history)`; je Modul ein Provider, dazu ein Fixture-Provider für alle vier Module.
- Panel-Zustand (offen/zu, Breite) in `gtk-state.json` (UX1).
- Grenzen: keine Systemaktionen aus dem Panel ohne Bestätigung; keine Rohausgaben (Journal, Tokens) im Panel.

## Andockpunkte
- `prototype/gtk/mla_app.py`: `self.details`, `self.status_chip`, `detail_panel`, `select_module`; `prototype/gtk/tokens.css` (`.mla-details`, `.mla-chip`, `.mla-tone-*`)
- Store aus FU4 (`probe_store.py`) als Datenquelle; bis dahin Fixture-Backend
- Tests: `prototype/gtk/tests/test_details.py`

## Abnahme
- [ ] Jedes Modul liefert über seinen Provider Details (Fixture-Test je Modul)
- [ ] Eine `stale`-Probe zeigt den gestrichelten Chip und „seit <Zeit>"
- [ ] Panel ist per Strg+I und per Tab erreichbar; Zustand wird gemerkt (xvfb-Test + State-Datei)
- [ ] Verlauf erscheint, sobald LB4 Daten liefert; ohne Daten bleibt die Zeile weg (kein Fehler)

## Abhängigkeiten
Blockiert durch: UX1 (Zustand), LB4 (Verlauf) · ⚡ Teil A (Panel + Provider) sofort startbar · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Provider-Protokoll wird zu breit → nur die fünf Pflichtfelder festschreiben, Rest optional._

_Tier: QoL · Größe: M · shell:gtk · Gates: `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic UX (Teilplan UX2)._
```

---

## Issue 5 — [V1.1] UX3 Leer-, Lade-, Stale- und Fehlerzustände

**Meilenstein:** V1.1 · **Labels:** `epic:ux`, `tier:qol`, `size:S`, `shell:gtk`

### Body

```markdown
## Job
Kein leerer Screen, keine lügenden Flächen: Fehlt Docker oder `nvidia-smi`, sagt die Fläche, was fehlt — nie ein Fehler; veraltete Daten sehen nie wie aktuelle aus (TOKENS §4: stale ≠ ok).

## Scope
- `prototype/gtk/states.py`: Fabriken für `Adw.StatusPage` „nicht verfügbar" (nennt das fehlende Werkzeug und was damit möglich wäre), „lädt" (erst nach 300 ms sichtbar), „stale" (gestrichelte Border + Messzeit), `Adw.Banner` für nicht blockierende Fehler, `Adw.Toast` für Aktionsergebnisse.
- Regel: jedes `Gtk.Stack`-Kind rendert genau einen der Zustände `ok|loading|stale|unavailable|error`.
- HardcodeTests in `prototype/gtk/tests/test_tokens.py` von `mla_app.py` auf alle `prototype/gtk/*.py` erweitern (keine Hex-Farben außerhalb der Token-Dateien).
- Grenzen: nur Darstellung.

## Andockpunkte
- `prototype/gtk/mla_app.py` (Modul-Boxen in `Window.__init__`), `prototype/gtk/tokens.css` (`.mla-tone-stale`), `prototype/gtk/tests/test_tokens.py` (`HardcodeTests`, Konstante `APP_PY`)
- Tests: `prototype/gtk/tests/test_states.py`

## Abnahme
- [ ] Alle vier Module lassen sich per Fixture in jeden der fünf Zustände versetzen (Test)
- [ ] Hardcode-Gate deckt alle `.py` unter `prototype/gtk/` ab (Negativ-Fixture mit Hex-Wert macht es rot)
- [ ] Kein Stack-Kind ohne Zustand (Test iteriert über alle Kinder)
- [ ] Galerie-Lauf (DS5) zeigt alle Zustände hell/dunkel — nach DS5

## Abhängigkeiten
Blockiert durch: DS5 (nur der Galerie-Lauf) · ⚡ Teil A (`states.py` + Gate) sofort startbar · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: `Adw.StatusPage` wirkt in kleinen Kacheln zu groß → kompakte Variante (`compact`-Stilklasse) im selben Modul._

_Tier: QoL · Größe: S · shell:gtk · Gates: `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic UX (Teilplan UX3)._
```

---

## Issue 6 — [V1.1] UX4 Einstellungen als Seite

**Meilenstein:** V1.1 · **Labels:** `epic:ux`, `tier:qol`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
Einstellungen gehören in die Navigation, nicht in einen Dialog (UI-Befund N3; Flutter-Pendant DS4/#86 — gilt für GTK sinngemäß). Watchlists, Ruhezeiten und eigene Aktionen brauchen einen Ort.

## Scope
- `Adw.PreferencesPage`s im `Gtk.Stack` (Modul „Einstellungen" in `MODULES`), kein Dialog. Seiten: **Allgemein** (Sprache — mit DS7, Start-Modul) · **Wächter** (Takt, Ruhezeiten, Erinnerung; der Schalter `systemctl --user enable --now` wirkt erst mit #66) · **Watchlists** (Unit-Muster, Mounts, Compose-Projekte) · **Exposition** (Baseline „bekannt", Schema aus SI1/#80) · **Eigene Aktionen** (Schema `custom_actions` aus TE2/#73: name, argv-Liste, cwd, mode, confirm, keywords; argv-Editor als Liste, kein Shell-Feld).
- Persistenz in `config.json` (`$XDG_CONFIG_HOME/linux-assistant/`): unbekannte Keys bleiben beim Round-trip erhalten (die Flutter-`ConfigHandler`-Datei ist eine flache Key/Value-Map); Schreiben atomar.
- Import/Export über `Gtk.FileDialog` (JSON).
- Grenzen: nur Konfiguration; keine Ausführung aus den Einstellungen heraus; keine Secrets in `config.json` (Tokens kommen in den Secret Service, LB6/DI6).

## Andockpunkte
- `prototype/gtk/mla_app.py` (`MODULES`, Stack), neu `prototype/gtk/settings_page.py`, `prototype/gtk/config_store.py`
- Schema-Vorbilder: `lib/services/config_handler.dart` (Dateiformat), Issue #73 (`custom_actions`), Issue #80 (`exposure_baseline`)
- Tests: `prototype/gtk/tests/test_config_store.py` mit Fixture, die Flutter-Keys enthält; Dart-Seite: `test/config_handler_test.dart` liest eine GTK-geschriebene Datei

## Abnahme
- [ ] Jede Einstellung round-trippt (schreiben → neu laden → gleicher Wert)
- [ ] Unbekannte Keys der Fixture bleiben unverändert erhalten
- [ ] Ungültiges argv (leer, kein String-Array) wird abgewiesen; ein Shell-Feld existiert nicht
- [ ] Flutter-`ConfigHandler` liest die GTK-geschriebene Datei ohne Fehler (Dart-Test)

## Abhängigkeiten
Blockiert durch: DS7 (nur „Sprache") · ⚡ Teil A sofort startbar · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Key-Kollision mit künftigen Flutter-Keys → Namensraum `gtk.*` für rein GTK-seitige Einstellungen._

_Tier: QoL · Größe: M · shell:gtk · Gates: `python3 -m unittest discover -s prototype/gtk/tests` · Flutter-Gates (`flutter test`) wegen `config.json`._
_Quelle: Ausbauplan V1.1–V1.3, Epic UX (Teilplan UX4)._
```

---

## Issue 7 — [V1.1] DS5 Komponenten-Katalog, Galerie & GTK-CI-Gate

**Meilenstein:** V1.1 · **Labels:** `epic:ds`, `tier:qol`, `size:M`, `shell:gtk`, `gate:manual`

### Body

```markdown
## Job
Neue Module sollen aus denselben Bausteinen entstehen wie der Monitor, nicht aus Kopien; und GTK-Widget-Tests müssen in CI laufen, sonst bleibt jede Abnahme manuell.

## Scope
- `prototype/gtk/widgets.py`, **extrahiert** aus `monitor_ui.py` (#96 / PR #119): `StatCard` (Wert, Einheit, Sparkline), `AmpelChip` (Tone-Klassen), `MetaRow`, `Sparkline` (`Gtk.Snapshot`-Zeichnung, kein pycairo), `Badge`, `SectionHeader`, `ActionRow`. Gegenstück zum Flutter-Katalog `docs/handoff/components/component-catalog.md`.
- Galerie-Screen (`MLA_SHOW_GALLERY=1`): jede Komponente in allen Tönen (ok/warn/crit/running/unknown/stale), hell/dunkel (`MLA_FORCE_COLOR_SCHEME`), 100/125/150 %.
- Doku `docs/mla-next/COMPONENTS.md` (Komponente → Zweck → Tokens → Beispiel).
- **CI:** Schritt `xvfb-run -a python3 -m unittest discover -s prototype/gtk/tests` mit apt `xvfb gir1.2-gtk-4.0 gir1.2-adw-1` in `.github/workflows/build.yml`.
- Grep-Gate in `test_tokens.py`: `.mla-chip`/`.mla-tone-*`-Klassen und `Gtk.Snapshot`-Zeichnen nur in `widgets.py`.
- Grenzen: nur Darstellung.

## Andockpunkte
- `prototype/gtk/monitor_ui.py` (Quelle der Extraktion), `prototype/gtk/tokens.css`, `docs/mla-next/TOKENS.md` §4/§8, `.github/workflows/build.yml` (Token-Gate-Schritt)
- Tests: `prototype/gtk/tests/test_widgets.py` (xvfb), Gate in `test_tokens.py`

## Abnahme
- [ ] Monitor und Dashboard nutzen nur Katalog-Komponenten (Grep-Gate grün, Negativ-Fixture rot)
- [ ] Widget-Tests laufen in CI unter xvfb (Workflow-Lauf grün)
- [ ] Galerie zeigt alle Komponenten in allen Tönen hell/dunkel; Kontrast-Tests bleiben grün
- [ ] Galerie bei 125 % und 150 % ohne Abschneiden gesichtet (manuell, einmalig)

## Abhängigkeiten
Blockiert durch: #96 (PR #119 liefert `monitor_ui.py`) · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: xvfb-Lauf flackert → Widget-Tests nur Konstruktion/Property-Checks, keine Pixel-Vergleiche._

_Tier: QoL · Größe: M · shell:gtk · Gates: `xvfb-run -a python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic DS (Teilplan DS5)._
```

---

## Issue 8 — [V1.1] LB4 Ampel-Feinschliff: Bekannt, Snooze, Ruhezeiten, Verlauf

**Meilenstein:** V1.1 · **Labels:** `epic:lb`, `tier:qol`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
Eine Ampel, die rot bleibt, weil man den Zustand kennt, erzieht zum Wegschauen. Bekannt-Markierung, Erinnerung später, Ruhezeiten und ein Verlauf halten das Lagebild glaubwürdig. Baut auf #102 (Lagebild GTK) und #66 (Wächter) auf — beide gelten für GTK sinngemäß (Kern = la_core/la_probe).

## Scope
- `state.json` (`$XDG_STATE_HOME/linux-assistant/`, Schema in la_core, Schreiber GTK, Leser la_probe): je Probe `known` (bis zum nächsten Zustandswechsel; gemeinsames Schema mit SI1/#80 `exposure_baseline`), `snoozed_until` (1 h / bis morgen), global `quiet_hours` (z. B. 22–08 Uhr).
- Der Wächter (`la_probe`) respektiert `state.json`: bekannte/gesnoozte Probes zählen nicht zur Gesamtfarbe; in Ruhezeiten keine Benachrichtigung, die Anzeige bleibt.
- `status-history.jsonl` (la_probe schreibt bei jedem Übergang, Ring 30 Tage) → „seit wann" und die letzten Übergänge je Probe im Kontext-Inspektor (UX2).
- „Was tun?"-Satz je Probe (messageKey, DS7) mit Sprung ins Detail.
- Kommentar auf #66: Historie-Datei und `state.json`-Lesen dort einplanen.
- Grenzen: nie Root; Dateien atomar; keine Secrets.

## Andockpunkte
- `packages/la_core/lib/src/probe_status.dart`, `probe.dart`; neu `lib/src/state_file.dart` (Schema `known/snoozed_until/quiet_hours`) und `history_file.dart`
- `prototype/gtk/probe_store.py` (FU4), Kontext-Inspektor (UX2), `prototype/gtk/settings_page.py` (UX4: Ruhezeiten)
- Fixtures: `packages/la_core/test/fixtures/state_*.json`, Fixture-Uhr für den Snooze-Ablauf

## Abnahme
- [ ] Bekannt-markierte Ampel zählt nicht zur Gesamtfarbe und meldet nicht (la_core-Test)
- [ ] Snooze läuft mit der Fixture-Uhr ab und die Ampel meldet wieder
- [ ] In Ruhezeiten unterdrückt der Wächter die Benachrichtigung; der Übergang steht trotzdem in der History
- [ ] Inspektor zeigt „seit <Zeit>" und die letzten drei Übergänge aus einer Fixture-History

## Abhängigkeiten
Blockiert durch: #102, #66, FU4 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Zwei Schreiber auf `state.json` (GTK + Wächter) → der Wächter liest nur; einzige Schreibstelle ist die GTK-App._

_Tier: QoL · Größe: M · shell:gtk · Gates: `cd packages/la_core && dart test` · `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic LB (Teilplan LB4)._
```

---

## Issue 9 — [V1.1] LB5 Tages-Check „Heute"

**Meilenstein:** V1.1 · **Labels:** `epic:lb`, `tier:qol`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
„Ist alles in Ordnung?" einmal am Tag als Liste statt als Suche über alle Kacheln: Neustart, kaputte Units, letztes Backup, Platte, Updates, Grafik-Ereignisse, Agenten-Blocker, Restore-Probe.

## Scope
- Dashboard-Karte „Heute", beim ersten Öffnen des Tages ausgeklappt (Marker in `gtk-state.json`). Zeilen entstehen nur aus vorhandenen Probes; fehlt eine Quelle, fehlt die Zeile (kein Fehler, kein Platzhalter): Neustart nötig (#58-Q2) · fehlgeschlagene Units (#58-Q3/#102) · letztes Backup (#63/#101) · Platten-Prognose (#83) · ausstehende Updates, Kernel/NVIDIA markiert (#82) · Grafik-Ereignisse letzter Boot (ST4) · Agenten-Blocker (#69) · **„Restore zuletzt geprobt vor N Tagen"** aus config `last_restore_test` (ein erfolgreicher Unit-Lauf ist kein Restore-Nachweis; Schwelle `restore_test_warn_days`, Default 90).
- Zeilen abhakbar („erledigt" bis zum nächsten Zustandswechsel, `state.json` aus LB4); leer → „Alles in Ordnung".
- Grenzen: nur Lesen; Aktionen sind Sprünge in die Module.

## Andockpunkte
- `prototype/gtk/probe_store.py` (FU4), Dashboard-Modul in `mla_app.py`, `widgets.py` (DS5: `ActionRow`), `state_file.dart` (LB4)
- Fixtures: Probe-Sätze mit 0, 2 und 8 roten Probes; einer ohne Backup-/Update-Quelle

## Abnahme
- [ ] Fixture mit zwei roten Probes → genau zwei Zeilen; Fixture ohne rote → „Alles in Ordnung"
- [ ] Abgehakte Zeile bleibt weg, bis die Probe den Zustand wechselt
- [ ] Fehlende Quellen (kein Backup-, kein Update-Probe) erzeugen keine Zeile und keinen Fehler
- [ ] Restore-Zeile wird gelb, wenn `last_restore_test` älter als die Schwelle ist (Fixture-Uhr)

## Abhängigkeiten
Blockiert durch: #102, #66, FU4 (Pflicht) · nutzt, wenn vorhanden: #58, #63, #101, #82, #83, #69, ST4 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Zu viele Zeilen → nur rot/gelb anzeigen, grün zusammenfassen._

_Tier: QoL · Größe: M · shell:gtk · Gates: `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic LB (Teilplan LB5)._
```

---

## Issue 10 — [V1.1] ST4 Grafik-Stabilitäts-Wache (NVIDIA/Wayland)

**Meilenstein:** V1.1 · **Labels:** `epic:st`, `tier:qol`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
„Was ist passiert?" nach einem eingefrorenen Desktop: Auf dem Referenzsystem traten wiederholt Treiber-Livelocks unter Wayland auf, einmal hing sogar der Neustart; das Runbook dafür liegt außerhalb der App. GTK-Delta zu ST1/#76 (Boots, Journal-Grep, SysRq, Runbook-Link sind dort spezifiziert — gilt für GTK sinngemäß, Kern = la_core/la_probe, die Fixture wird geteilt).

## Scope
- Probe `gpu_stability` in la_core, Quellen als Nutzer (Gruppe `adm`): `journalctl --list-boots -o json`, `journalctl -k -b <id> -o json` mit Markern `nvidia-modeset`, `nvkms`, `Xid`, `blocked for more than`, `NVRM`; unsaubere Boots (fehlender Shutdown-Marker); Treiberversion (`nvidia-smi --query-gpu=driver_version --format=csv,noheader`) gegen config `known_bad_drivers` (Liste exakter Versionsstrings); Sitzungstyp (`XDG_SESSION_TYPE`).
- **Neu gegenüber #76 — Rettungs-Bereitschaft:** `/proc/sys/kernel/sysrq` (Wert), persistentes Journal (`/var/log/journal` vorhanden), `/dev/watchdog` (vorhanden/nicht vorhanden — beides gültige Zustände), Zustand des OC-Dienstes (config `oc_service`, `systemctl is-enabled/is-active`).
- Karte „Grafik" + Inspektor-Detail: Ereignisse je Boot, „Runbook öffnen" (config `runbook_url`, Datei oder URL, WZ3-Hand-off), SysRq-Leiter als kopierbarer Text. Ohne NVIDIA → „nicht zutreffend" (UX3).
- Fixture `test/fixtures/zorin_journal_freeze.txt` (JSONL) mit Streichliste: `_HOSTNAME`, `_MACHINE_ID`, `_BOOT_ID`, `_CMDLINE`, Seriennummern, MAC-Adressen; der Leak-Check (`additional/python/tests/test_fixture_leak_check.py`) muss die Datei erfassen.
- Grenzen: nur Lesen; kein Root; keine Rohzeilen mit Hostnamen im UI.

## Andockpunkte
- `packages/la_core/lib/src/probe.dart`, neu `lib/src/probes/gpu_stability.dart`, Parser `lib/src/parsers/journal.dart`; CLI über `la_probe --json gpu_stability` (FU4-Zwischenstufe)
- `prototype/gtk/` Karte über `widgets.py`/`probe_store.py`
- Verweise: ST5 (Setup-Check), DI8 (Tailscale-SSH als Rettungsweg)

## Abnahme
- [ ] Fixture-Boots mit Freeze-Signatur → Ampel rot, Ereignisliste je Boot (Dart-Test)
- [ ] Bereitschaft zeigt sysrq, Journal, Watchdog, OC-Dienst als eigene Zeilen, „nicht vorhanden" inklusive
- [ ] Treiberversion aus `known_bad_drivers` → rot mit Satz
- [ ] Ohne `nvidia-smi` / ohne Journal-Zugriff: „nicht zutreffend" / „keine Berechtigung", kein Fehler

## Abhängigkeiten
Blockiert durch: — (⚡ sofort startbar; ST1/#76 als Referenz) · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Journal-Fixture zu groß → auf die Boots mit Signatur plus einen sauberen Boot kürzen._

_Tier: QoL · Größe: M · shell:gtk · Gates: `cd packages/la_core && dart test` · `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic ST (Teilplan ST4)._
```

---

## Issue 11 — [V1.1] GA1 Gaming-Vorflug

**Meilenstein:** V1.1 · **Labels:** `epic:ga`, `tier:qol`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
„Vor dem Spielen prüfen": Power-Profil, GameMode, Thermik, OC-Dienst, Speicherdruck, freier Platz und Standby-Blocker auf einen Blick, bevor das Spiel startet — statt vier Terminals.

## Scope
- Probe `gaming_readiness` in la_core: `gamemoded -s`, `powerprofilesctl get`, EPP (`/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference`), GPU Temp/Takt/VRAM/Power-Limit (`nvidia-smi --query-gpu=temperature.gpu,clocks.gr,memory.used,memory.total,power.limit --format=csv,noheader`), OC-Dienst (config `oc_service`), PSI/zram (bestehende Parser), freier Platz je Steam-Bibliothek (GA2; Fallback Mount-Prüfung), Steam läuft (`pgrep -x steam`), Standby-Inhibitoren (`systemd-inhibit --list --no-pager`).
- Schwellen als config-Defaults: `gaming.temp_warn_c` = 80, `gaming.free_gb_warn` = 10, `gaming.psi_warn` = 10.
- Karte „Gaming" als Checkliste mit Ein-Satz-Hinweisen (DS7-Keys).
- **Eine bestätigte Aktion:** Power-Profil umschalten über `powerprofilesctl set <profil>` (User-D-Bus, kein Root). Alles andere sind Hand-offs (Steam öffnen) oder eigene Aktionen (TE4).
- Grenzen: nie Root; argv-Liste; ohne GameMode/NVIDIA degradiert zu „nicht installiert".

## Andockpunkte
- `packages/la_core/lib/src/probes/gaming_readiness.dart`, Parser für `nvidia-smi`-CSV und `systemd-inhibit`; `la_probe --json gaming_readiness`
- `prototype/gtk/` Karte über `widgets.py`; Bestätigung über `Adw.AlertDialog`
- Fixtures: `test/fixtures/gaming_*.txt` (balanced/performance, 60/85 °C, Inhibitoren vorhanden/leer)

## Abnahme
- [ ] Fixture „balanced + 85 °C + 3 GB frei" → drei gelbe Hinweise mit Satz
- [ ] Profil-Umschaltung nur nach Bestätigung; argv-Assert `powerprofilesctl set performance`
- [ ] Inhibitoren-Fixture → Zeile „Standby blockiert durch …" ohne Prozess-Argumente
- [ ] Ohne `gamemoded`/`nvidia-smi` → „nicht installiert", kein Fehler

## Abhängigkeiten
Blockiert durch: — (⚡ sofort startbar; GA2 optional für den Bibliotheks-Platz) · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: `powerprofilesctl set` scheitert ohne power-profiles-daemon → Aktion ausblenden, Hinweis._

_Tier: QoL · Größe: M · shell:gtk · Gates: `cd packages/la_core && dart test` · `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic GA (Teilplan GA1)._
```

---

## Issue 12 — [V1.1] SP3 Speicher-Feinschliff: Mounts, Timeshift, SMART

**Meilenstein:** V1.1 · **Labels:** `epic:sp`, `tier:qol`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
„Platz schaffen, bevor es knallt": Auf dem Referenzsystem lief das Datenlaufwerk voll und der Timeshift-Zeitplan regredierte unbemerkt auf monatlich. Mount-Ampeln, Soll-Abgleich und ein SMART-Warnflag ohne Root schließen die Lücke. Referenz SP1/#83 (Prognose) und LB2/#63 (Backup-Units; Auslagerungs-Jobs laufen dort als Watchlist-Muster `*rclone*`, kein eigener Code) — gelten für GTK sinngemäß.

## Scope
- Probe `storage_health` in la_core: Mounts mit Ampel 85/90/95 % (`DeviceInfo`-Parser), Prognose-Zeile nur wenn `disk-history.jsonl` (#83) existiert.
- Timeshift-Soll-Abgleich: `/etc/timeshift/timeshift.json` (lesbar als Nutzer) `schedule_*`/`count_*` gegen config `timeshift_expected` (z. B. `{"daily": 2, "monthly": 1}`) → gelb bei Abweichung mit Satz „Zeitplan weicht ab: täglich 1 statt 2". Kein Snapshot-Listing über den privilegierten Sicherheits-Report (keine neue Root-Naht).
- SMART-Warnflag ohne Root: UDisks2 `org.freedesktop.DBus.ObjectManager.GetManagedObjects` auf dem System-Bus → `org.freedesktop.UDisks2.NVMe.Controller` `SmartCriticalWarning`/`SmartTemperature` bzw. `Drive.Ata` `SmartFailing` → rot/gelb.
- Karte „Speicher" mit Hand-off „Aufräumen" (SP2/#84).
- Grenzen: nur Lesen; kein Root; keine Remotes/Tokens.

## Andockpunkte
- `packages/la_core/lib/src/parsers/df.dart` (`DeviceInfo`), neu `lib/src/probes/storage_health.dart`, Parser `timeshift_config.dart`, D-Bus-Abfrage über `busctl --json=short call` (argv) statt eigener D-Bus-Bibliothek
- Fixtures: `test/fixtures/timeshift_*.txt`, `udisks2_managed_objects_*.txt`; `df`-Fixtures vorhanden

## Abnahme
- [ ] Fixture `count_daily: 1` bei Soll 2 → gelb mit Satz; passende Werte → grün
- [ ] Mount bei 92 % → rot, bei 86 % → gelb (Schwellen-Test)
- [ ] `SmartCriticalWarning` ≠ 0 in der Fixture → rot; ohne UDisks2-Antwort → „unbekannt"
- [ ] Ohne Timeshift → „nicht installiert", kein Fehler

## Abhängigkeiten
Blockiert durch: #83 (nur Prognose-Zeile) · ⚡ Teil A sofort startbar · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: `busctl`-JSON-Format variiert → Parser-Fixtures je Variante, sonst SMART-Zeile „unbekannt"._

_Tier: QoL · Größe: M · shell:gtk · Gates: `cd packages/la_core && dart test` · `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic SP (Teilplan SP3)._
```

---

## Issue 13 — [V1.2] GN4 App-ID, Desktop-Einbindung & Autostart

**Meilenstein:** V1.2 · **Labels:** `epic:gn`, `tier:qol`, `size:S`, `shell:gtk`, `gate:manual`

### Body

```markdown
## Job
Schritt 0 für jede GNOME-Naht: Suchanbieter, Benachrichtigungs-Aktionen und Hotkey brauchen eine D-Bus-aktivierbare App mit fester ID, Desktop-Actions und einem symbolischen Icon.

## Scope
- App-ID: vorläufig `dev.toqsick.MlaPrototype` (Tests), final nach #106 — der Entscheid fällt dort, hier gibt es nur eine Konstante.
- `packaging/<app-id>.desktop`: `DBusActivatable=true`, `StartupWMClass`, Actions Dashboard / Suche / Systemmonitor / „Backup jetzt" → `gapplication action <app-id> open "'<module>'"`.
- `packaging/<app-id>.service` für `/usr/share/dbus-1/services/` (Muster: vorhandene Search-Provider-Services auf GNOME).
- `Gio.Application`: `Gio.SimpleAction("open", GLib.VariantType("s"))` → Modul öffnen und Fenster `present()`.
- Symbolisches Icon `<app-id>-symbolic.svg` (einfarbig) neben dem Farb-Icon; AppStream `packaging/<app-id>.metainfo.xml` (ohne Screenshots).
- Autostart „beim Login minimiert starten": `~/.config/autostart/<app-id>.desktop` (XDG-Autostart, `X-GNOME-Autostart-Delay`), Schalter in UX4, Standard aus. Das Background-Portal ist nur optional (die Host-App-ID stammt aus dem systemd-Scope und fehlt bei Start aus dem Terminal). Der Wächter bleibt systemd-Timer.
- Grenzen: keine Systemdateien schreiben — `/usr/share/…` kommt über das .deb (#105).

## Andockpunkte
- `prototype/gtk/mla_app.py` (`App.__init__`, `application_id`, `do_activate`), neu `packaging/` (Desktop, Service, Metainfo, Icon), `build-deb.sh` (#105 übernimmt die Pfade)
- Tests: `prototype/gtk/tests/test_desktop_files.py` (`desktop-file-validate`, `appstreamcli validate` wenn vorhanden, Action-Namen gegen `MODULES`)

## Abnahme
- [ ] `desktop-file-validate` und `appstreamcli validate` grün (CI, sofern die Tools auf dem Runner sind; sonst Test übersprungen und benannt)
- [ ] `gapplication action <app-id> open "'backup'"` öffnet das Backup-Modul bei laufender App; bei gestoppter App nach Installation des .deb (#105)
- [ ] Dock-Kontextmenü zeigt die vier Actions (manuell)
- [ ] Autostart-Schalter erzeugt genau eine Datei und entfernt sie beim Ausschalten

## Abhängigkeiten
Blockiert durch: #105, #106 (nur Teil B: Systempfade, finale ID) · ⚡ Teil A sofort startbar · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: ID-Wechsel nach #106 → alle Dateien tragen die ID nur über eine Konstante/Template._

_Tier: QoL · Größe: S · shell:gtk · Gates: `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic GN (Teilplan GN4)._
```

---

## Issue 14 — [V1.2] GN1 GNOME-Shell-Suchanbieter

**Meilenstein:** V1.2 · **Labels:** `epic:gn`, `tier:qol`, `size:M`, `shell:gtk`, `gate:manual`

### Body

```markdown
## Job
Super-Taste drücken, „backup" tippen, Enter — und im MLA steht das Backup-Modul. Der GNOME-Weg für „Schnell erledigen", ohne eigenen Hotkey.

## Scope
- `prototype/gtk/search_provider.py`: `org.gnome.Shell.SearchProvider2` über `Gio.Application.do_dbus_register(connection, object_path)` + `connection.register_object(path, Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0], handler)`; Methoden `GetInitialResultSet`, `GetSubsearchResultSet`, `GetResultMetas`, `ActivateResult`, `LaunchSearch`.
- `.ini` (`packaging/<app-id>.search-provider.ini`: `DesktopId`, `BusName`, `ObjectPath`) nach `/usr/share/gnome-shell/search-providers/` über das .deb (#105) — die Shell liest nur System-Datadirs.
- Dienst-Modus: `Gio.ApplicationFlags.IS_SERVICE`, `--gapplication-service` im `.service`, `hold()`/`release()` mit Inaktivitäts-Timeout (z. B. 60 s); Fenster nur bei `ActivateResult`/`LaunchSearch`.
- Treffer: Module, Probe-Aktionen, eigene Aktionen (TE4). Notiztitel nur bei config `search_provider.notes = true` (Standard aus — Privatsphäre, UI-Befund M6). Die Vorschau zeigt nie private Daten.
- Grenzen: kein Dauerprozess ohne Timeout; keine Ausführung aus der Suche ohne die üblichen Bestätigungen.

## Andockpunkte
- `prototype/gtk/mla_app.py` (`App`), GN4 (App-ID, `.service`, `app.open`), DS7 (Treffertitel), TE4 (Aktionsliste)
- Tests: `prototype/gtk/tests/test_search_provider.py` — headless auf dem Session-Bus mit Test-Busnamen (`dbus-run-session`)

## Abnahme
- [ ] `GetInitialResultSet("backup")` liefert die Modul-ID, `GetResultMetas` Titel + Icon (Test unter `dbus-run-session`)
- [ ] Super + „backup" zeigt den Eintrag; Enter öffnet das Modul (manuell, nach Paketinstallation)
- [ ] Der Service beendet sich nach dem Timeout ohne Fenster (Test über den `hold`-Zähler)
- [ ] Notiztitel erscheinen nur bei aktiviertem Schalter (Fixture)

## Abhängigkeiten
Blockiert durch: GN4, #105 · Notizen: #98 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Die Shell cached die Provider-Liste → Abnahme nach Relogin dokumentieren._

_Tier: QoL · Größe: M · shell:gtk · Gates: `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic GN (Teilplan GN1)._
```

---

## Issue 15 — [V1.2] GN2 Hotkey-Robustheit & Portal-Pfad

**Meilenstein:** V1.2 · **Labels:** `epic:gn`, `tier:qol`, `size:S`, `shell:gtk`, `gate:manual`

### Body

```markdown
## Job
Der Hotkey muss in Wayland und X11 zuverlässig das Fenster holen, ohne verwaiste Einträge zu hinterlassen. Beleg: GNOME 46 / xdg-desktop-portal-gnome 46.x bieten **kein** GlobalShortcuts-Portal — gsettings bleibt der Weg. GTK-Delta zu #58-Q4 (Hotkey über gsettings in beiden Sessions; gilt für GTK sinngemäß).

## Scope
- `prototype/gtk/hotkey.py` = GNOME-Port von `additional/python/setup_keybinding.py`: Custom-Keybinding idempotent anlegen (`org.gnome.settings-daemon.plugins.media-keys` `custom-keybindings`), verwaiste `custom*`-Einträge mit MLA-Kommando erkennen und entfernen; Kommando = `gapplication launch <app-id>` (D-Bus-Activation, kein Binärpfad); Modifier-Regel wie `Linux.getHotkeyModifier()` (Alt+Q auf Zorin/Ubuntu/KDE/Pop, sonst Super+Q).
- Diagnosezeile in UX4: aktuelles Binding, Session-Typ, verwaiste Einträge, Knopf „Reparieren".
- Portal-Erkennung: Introspektion von `org.freedesktop.portal.Desktop` auf `org.freedesktop.portal.GlobalShortcuts`; vorhanden (GNOME ≥ 48) → Hinweis „Portal verfügbar" + Folge-Issue. Keine universellen Wayland-Hotkeys versprechen (Nie-Liste).
- Grenzen: nur gsettings des Nutzers; kein Root.

## Andockpunkte
- `additional/python/setup_keybinding.py` (Vorlage), `lib/services/linux.dart` (`getHotkeyModifier`, Regel), GN4 (App-ID), UX4 (Diagnosezeile)
- Tests: `prototype/gtk/tests/test_hotkey.py` mit gsettings-Fake (Dict) und Introspektions-Fixture

## Abnahme
- [ ] Hotkey holt das Fenster in Wayland und in X11 (manuell, beide Sessions)
- [ ] Verwaister Eintrag im Fake wird erkannt und entfernt; ein zweiter Lauf ändert nichts (Idempotenz-Test)
- [ ] Portal-Hinweis erscheint nur mit einer Introspektions-Fixture, die das Interface enthält

## Abhängigkeiten
Blockiert durch: UX4 (nur Diagnosezeile), GN4 (App-ID) · ⚡ Teil A (`hotkey.py`) sofort startbar · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Desktop-Layouts belegen Alt+Q → Konflikt erkennen und ein alternatives Binding vorschlagen._

_Tier: QoL · Größe: S · shell:gtk · Gates: `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic GN (Teilplan GN2)._
```

---

## Issue 16 — [V1.2] GN3 Benachrichtigungen mit Aktionen & Deep-Links

**Meilenstein:** V1.2 · **Labels:** `epic:gn`, `tier:qol`, `size:M`, `shell:gtk`, `gate:manual`

### Body

```markdown
## Job
Der Wächter meldet „Backup rot" — ein Klick auf „Öffnen" muss im Backup-Modul landen, auch wenn die App gerade nicht läuft. GTK-Delta zu LB3/#66 („Öffnen → Ziel-Sektion", dort offen gelassen; `raise:<section>` wird auf GTK zu `app.open`).

## Scope
- Entscheid für die Lücke aus #66: Der Wächter startet die Benachrichtigung als transiente Einheit `systemd-run --user --collect -- notify-send --wait -A open=Öffnen …` und ruft bei Auswahl `gapplication action <app-id> open "'<module>'"`; die D-Bus-Activation über die `.service`-Datei (GN4) startet die App bei Bedarf. Der Timer-Lauf blockiert nicht.
- In-App-Ereignisse über `Gio.Notification` mit Aktion `app.open`.
- Ruhezeiten und Entprellung aus LB4 (nur Übergänge nach Rot).
- Kommentar auf #66 mit dem Entscheid.
- Grenzen: keine privaten Daten im Benachrichtigungstext (nur Probe-Titel + Satz).

## Andockpunkte
- `packages/la_core/bin/la_probe.dart` (Wächter-Lauf, #66), neu `lib/src/notify.dart` (argv-Erzeugung), GN4 (`app.open`), LB4 (`state.json`)
- Tests: Dart-Fixture prüft die erzeugte argv-Kette; `prototype/gtk/tests/test_notifications.py` für `Gio.Notification`

## Abnahme
- [ ] „Backup rot" → „Öffnen" landet im Backup-Modul, bei laufender und bei gestoppter App (manuell)
- [ ] Ein zweiter Lauf ohne Zustandsänderung erzeugt keine Benachrichtigung (la_core-Test)
- [ ] Die argv-Kette (`systemd-run …`, `gapplication action …`) ist exakt gepinnt (Fixture)
- [ ] Ruhezeit unterdrückt die Benachrichtigung (LB4-Fixture)

## Abhängigkeiten
Blockiert durch: GN4, #66, FU4 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: `notify-send --wait` liefert die Aktion auf GNOME nicht zuverlässig → `gdbus call org.freedesktop.Notifications.Notify` + `ActionInvoked`-Signal im Wächter-Kindprozess._

_Tier: QoL · Größe: M · shell:gtk · Gates: `cd packages/la_core && dart test` · `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic GN (Teilplan GN3)._
```

---

## Issue 17 — [V1.2] DS6 Tastatur, Accessibility & Darstellung folgt GNOME

**Meilenstein:** V1.2 · **Labels:** `epic:ds`, `tier:qol`, `size:M`, `shell:gtk`, `gate:manual`

### Body

```markdown
## Job
Die Shell muss vollständig per Tastatur bedienbar sein, Ampeln müssen vom Screenreader verstanden werden, und Systemeinstellungen (Skalierung, Animationen, Kontrast) gelten auch in der App. Rest zu #97 (Fokus/Kontrast/Langlauf im Monitor).

## Scope
- `update_property(Gtk.AccessibleProperty.DESCRIPTION, …)` für Ampel-Chips („Backup: kritisch seit <Zeit>"), Rollen/Labels für Karten und Aktionen; Mnemonics in Dialogen; Tab-Reihenfolge je Modul festgelegt.
- Systemeinstellungen: `gtk-enable-animations` → keine Sparkline-Animation; `text-scaling-factor` und 100/125/150 % ohne Abschneiden; High-Contrast (`Adw.StyleManager` `high-contrast`) ohne eigene Farben (die Tokens genügen).
- Automatisierter Fokus-Walk unter `xvfb-run`: Der Tab-Durchlauf erreicht jede interaktive Fläche.
- Orca-Durchgang einmalig manuell (Dashboard, Backup, Einstellungen).
- Grenzen: nur Darstellung.

## Andockpunkte
- `prototype/gtk/widgets.py` (DS5: `AmpelChip`), `mla_app.py`, `docs/mla-next/TOKENS.md` §6 (Fokusregeln)
- Tests: `prototype/gtk/tests/test_a11y.py` (xvfb)

## Abnahme
- [ ] Fokus-Walk erreicht jede interaktive Fläche (Test zählt Widgets vs. Fokusstopps)
- [ ] Jeder Ampel-Chip trägt eine `accessible-description` mit Zustand und Zeit (Test)
- [ ] Reduce-Motion deaktiviert die Sparkline-Animation (Test mit gesetzter Einstellung)
- [ ] 150 % ohne Abschneiden; Orca liest Ampeln korrekt vor (manuell)

## Abhängigkeiten
Blockiert durch: #97, DS5 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Orca-Befund erfordert Widget-Umbau → nur die Chips umbauen, Rest als Folge-Issue._

_Tier: QoL · Größe: M · shell:gtk · Gates: `xvfb-run -a python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic DS (Teilplan DS6)._
```

---

## Issue 18 — [V1.2] WZ3 Werkstatt-Übergaben & Dashboard-Links

**Meilenstein:** V1.2 · **Labels:** `epic:wz`, `tier:qol`, `size:S`, `shell:gtk`

### Body

```markdown
## Job
Integrieren statt nachbauen: Terminal, Dateien, Obsidian und externe Dashboards sind einen Klick entfernt, ohne dass die App sie einbettet (Nie-Liste). Referenz #99 (Browser-/Terminal-Aktionen im Dokument-Reviewer), WZ1/#85 (der n2h-Grafana-Link läuft hier), #110 Position C (PATH-Entscheid).

## Scope
- `prototype/gtk/handoffs.py` + `ActionRow` (DS5): „Im Terminal öffnen" (Kandidaten in dieser Reihenfolge: `x-terminal-emulator`, `gnome-terminal`, `kgx`, `ptyxis`; Arbeitsverzeichnis per `--working-directory`; **nie `bash -c`**), „In Dateien zeigen" (`Gtk.FileLauncher.open_containing_folder`), „In Obsidian öffnen" (`Gtk.UriLauncher`, `obsidian://open?path=<pfad>`), „Dashboard im Browser" (config `dashboard_links`: `{"monitor": "<url>", …}`, `Gtk.UriLauncher`; kein Einbetten).
- Start detached mit eigenem Scope über `Gio.AppInfo.create_from_commandline(argv, …).launch()`; Programmsuche über `GLib.find_program_in_path` mit der festen Kandidatenliste (Entscheid #110-C: keine freie PATH-Auflösung von Nutzereingaben).
- Die Ausführung *eigener Befehle* im Terminal lebt in TE4, nicht hier.
- Grenzen: argv-Listen; keine Shell; kein Root.

## Andockpunkte
- `prototype/gtk/mla_app.py` (Module Dateien/Notizen/Monitor aus #98/#96), `widgets.py`, UX4 (`dashboard_links`)
- Tests: `prototype/gtk/tests/test_handoffs.py` (argv-Assert, Kandidatenwahl mit gefaktem `find_program_in_path`)

## Abnahme
- [ ] Jede Übergabe erzeugt eine argv-Liste ohne Shell-String (Assert je Aktion)
- [ ] Fehlt das Ziel (kein Terminal, kein Obsidian), erscheint ein Hinweis-Toast statt eines Fehlers
- [ ] Link-Knopf nur sichtbar, wenn `dashboard_links` den Schlüssel enthält; keine URL im Code (Grep-Gate)
- [ ] Dateimanager, Notizen und Monitor nutzen dieselbe Aktionsliste (Test über die Registrierung)

## Abhängigkeiten
Blockiert durch: — (⚡ sofort startbar; #99/#98 liefern die Module, in denen die Aktionen erscheinen) · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: `Gtk.FileLauncher` fehlt in älterem GTK → `gio open <ordner>` als argv._

_Tier: QoL · Größe: S · shell:gtk · Gates: `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic WZ (Teilplan WZ3)._
```

---

## Issue 19 — [V1.2] TE4 Palette-Aktionen & Schnellaktionen-Kacheln (GTK)

**Meilenstein:** V1.2 · **Labels:** `epic:te`, `tier:qol`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
Strg+K, drei Buchstaben, Enter: Module, Probe-Aktionen, Einstellungen und eigene Skripte aus einer Palette; die wichtigsten eigenen Aktionen als Kacheln auf dem Dashboard (Pendant zu den Flutter-Schnellaktionen). GTK-Delta zu TE2/#73 (Schema `custom_actions`, Bestätigungsmuster) und #99 (Suchpalette); Rechner/Einheiten bleiben in TE3/#74.

## Scope
- Palette (Strg+K, aus #99) um Provider erweitern: Module, Probe-Aktionen (FU4), Einstellungen (UX4), eigene Aktionen aus `config.json` `custom_actions` (#73: `name`, `argv`, `cwd`, `mode` `output|terminal|detached`, `confirm`, `keywords`, neu `pinned`).
- Dashboard-Abschnitt „Schnellaktionen": alle `pinned`-Aktionen als Kacheln.
- Bestätigung nach WP-S1-Muster (`Adw.AlertDialog` mit vollem argv). Modus `terminal`: Terminal-Kandidaten aus WZ3, Übergabe als `-- <argv…>`, **nie `bash -c`**; sudo fragt im Terminal selbst. Modus `output`: stdout/stderr im `Adw.Dialog` mit Kopieren. Modus `detached`: `Gio.AppInfo`-Start.
- Grenzen: argv-Listen; nie pkexec; keine Shell; Sonderzeichen-Test wie in #99.

## Andockpunkte
- Palette aus #99 (Datei wie dort benannt, z. B. `prototype/gtk/palette.py`), `handoffs.py` (WZ3), `config_store.py` (UX4), Dashboard-Modul
- Tests: `prototype/gtk/tests/test_palette.py` (Keyword-Fixture, Sonderzeichen), `test_custom_actions.py` (argv-Assert je Modus)

## Abnahme
- [ ] Modus `terminal` startet mit Bestätigung; der argv-Assert zeigt `<terminal> -- <argv>` ohne Shell
- [ ] `pinned` round-trippt in `config.json`; die Kachel erscheint/verschwindet entsprechend
- [ ] Die Palette findet eine Aktion über `keywords` (Fixture) und zeigt Treffer aus allen Providern
- [ ] Sonderzeichen in `argv` (Leerzeichen, Anführungszeichen, `$`) kommen unverändert an (Test)

## Abhängigkeiten
Blockiert durch: #99, DS7 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: #99 liefert keine erweiterbare Palette → Provider-Schnittstelle hier nachrüsten (kleiner Umbau, im Issue vermerken)._

_Tier: QoL · Größe: M · shell:gtk · Gates: `python3 -m unittest discover -s prototype/gtk/tests` · Flutter-Gates wegen `config.json`._
_Quelle: Ausbauplan V1.1–V1.3, Epic TE (Teilplan TE4)._
```

---

## Issue 20 — [V1.2] DI4 Stack-Operationen & Container-Hygiene

**Meilenstein:** V1.2 · **Labels:** `epic:di`, `tier:qol`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
„Meine Dienste im Griff": Compose-Projekte als Einheit starten/stoppen, alte Images und Build-Cache sehen, bevor die Platte voll ist. Baut auf DI2/#68 (Compose-Gruppierung, Expositions-Flags, Logs — gilt für GTK sinngemäß) auf; die Docker-Kategorie von SP2/#84 verlinkt hierher.

## Scope
- Je Compose-Projekt: `down`, `stop`, `start`, `restart` über `docker compose -p <projekt> …` nach Bestätigung; `up` nur mit `--project-directory` und `-f` aus den Container-Labels `com.docker.compose.project.working_dir` / `com.docker.compose.project.config_files`.
- Lose Container (ohne Projekt-Label) als eigene Gruppe.
- Image-Alter und „neueres Image lokal vorhanden?" (`docker image inspect`, `RepoDigests`).
- `docker system df -v` → Karte „Aufräumbar" (dangling Images, ungenutzte Volumes, Build-Cache) mit Vorschau → `docker image prune`, `docker builder prune` nach Bestätigung (Nutzer-Aktionen, kein Root).
- Expositions-Zusammenfassung je Stack (Flags aus DI2); „Compose-Datei öffnen" (WZ3).
- UI-Hinweis: Mitgliedschaft in `docker` ≈ Root.
- Grenzen: argv-Listen; keine Shell; kein `docker rm -f` ohne Bestätigung; ohne Docker → „nicht installiert".

## Andockpunkte
- Parser in la_core: `lib/src/parsers/docker_ps.dart` (#68), neu `docker_df.dart`, Probe `docker_stacks`; GTK-Modul „Container" (GTK-Fassung von #68), `widgets.py`
- Fixtures: `test/fixtures/docker_ps_*.txt` (3 Projekte + 2 lose, mit Labels), `docker_system_df_*.txt`

## Abnahme
- [ ] Fixture mit 3 Projekten und 2 losen Containern wird korrekt gruppiert
- [ ] `up` nutzt Projektverzeichnis und Compose-Datei aus den Labels (argv-Assert)
- [ ] Vorschau nennt Größen vor der Aufräum-Aktion; Aktion nur nach Bestätigung (argv-Assert)
- [ ] Ohne Docker → StatusPage „nicht installiert", kein Fehler

## Abhängigkeiten
Blockiert durch: #68 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: `docker compose` fehlt (nur v1 `docker-compose`) → Operationen ausblenden, Hinweis._

_Tier: QoL · Größe: M · shell:gtk · Gates: `cd packages/la_core && dart test` · `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic DI (Teilplan DI4)._
```

---

## Issue 21 — [V1.2] DI5 Agenten-Betrieb: Tunnel-Status & Gateway-Audit

**Meilenstein:** V1.2 · **Labels:** `epic:di`, `tier:n2h`, `size:S`, `shell:gtk`

### Body

```markdown
## Job
Wenn ein lokaler Port-Forward zu einem entfernten Dienst stirbt, scheitern Skills still. Ein Blick ins Agenten-Tile soll zeigen, ob die Tunnel leben und was das Agenten-Gateway zuletzt genehmigt hat. Baut auf DI3/#69 (Agenten-Tile: Units, Start-Knöpfe, Budget — gilt für GTK sinngemäß) und A8/#103 (Gateway-Audit) auf.

## Scope
- Probe `tunnel_status` in la_core: config `tunnels: [{"name": "<name>", "local_port": <port>}]` → `ss -ltnH` (Nutzer) → je Tunnel aktiv/tot; Hand-off „neu starten" = eigene Aktion aus TE4 (argv aus config, keine eingebauten Befehle).
- Audit-Ansicht im Agenten-Tile: letzte genehmigte Aktionen aus dem Gateway-Audit (#103), read-only.
- Grenzen: fremde Backends nie Core; nur `ss`/`systemctl --user`; keine Hosts/Ports im Code (nur config).

## Andockpunkte
- `packages/la_core/lib/src/probes/tunnel_status.dart`, Parser `ss_listen.dart`; Agenten-Tile aus #69 (GTK-Fassung), Audit-Datei aus #103
- Fixtures: `test/fixtures/ss_ltn_*.txt`, Audit-Fixture

## Abnahme
- [ ] Fixture „Port nicht gebunden" → Tunnel rot mit Hand-off; gebunden → grün
- [ ] Audit-Fixture wird gelistet (Zeit, Aktion, Ergebnis), ohne Argumente mit Secrets
- [ ] Grep-Gate: keine Portnummern/Hosts in `la_core`/`prototype/gtk` außerhalb von Fixtures

## Abhängigkeiten
Blockiert durch: #69, #103 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: `ss` fehlt → `/proc/net/tcp` parsen (Fixture vorhanden machen)._

_Tier: n2h · Größe: S · shell:gtk · Gates: `cd packages/la_core && dart test` · `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic DI (Teilplan DI5)._
```

---

## Issue 22 — [V1.2] ST5 Grafik-Setup-Check, Radar & GNOME-Erweiterungen

**Meilenstein:** V1.2 · **Labels:** `epic:st`, `tier:qol`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
Treiber- und Kernel-Updates sind die häufigste Ursache für Grafik-Regressionen; GNOME-Updates brechen Erweiterungen. Ein Setup-Check vor und ein Radar nach dem Update halten das sichtbar. Der Radar-Teil baut auf SI3/#82 (Update-Radar) und ST2/#77 (Zeitleiste) auf — gelten für GTK sinngemäß.

## Scope
- **Teil A, Probe `graphics_setup` (la_core, read-only):** `/sys/module/nvidia_drm/parameters/modeset`, `/proc/driver/nvidia/params` (`PreserveVideoMemoryAllocations`), `/proc/driver/nvidia/version` (Open- vs. proprietäres Modul), `dkms status`, `mokutil --sb-state` (falls vorhanden), Sitzungstyp; **Kernel-Rollback-Bereitschaft:** installierte Kernel (`dpkg-query -W 'linux-image-*'`) vs. `uname -r` → „vorheriger Kernel vorhanden", Sprung in den vorhandenen GRUB-Screen; **GNOME-Erweiterungen:** `gnome-extensions list --enabled` + `gnome-extensions info` → `ERROR`/`OUT_OF_DATE` gelb.
- **Teil B, Radar:** ausstehende Kernel-/NVIDIA-Pakete aus #82 mit Hinweis „nach dem Update ST4 beobachten"; `known_bad_drivers`-Abgleich vor der Installation; Flatpak-Updates (`flatpak remote-ls --updates`); Firmware (`fwupdmgr get-updates --json`, die Installation bleibt extern); Treiber-/Kernel-Wechsel aus #77 im Detail.
- Grenzen: nur Lesen; kein Root; ohne NVIDIA „nicht zutreffend".

## Andockpunkte
- `packages/la_core/lib/src/probes/graphics_setup.dart`, Parser `dkms_status.dart`, `gnome_extensions.dart`, `flatpak_updates.dart`, `fwupd_updates.dart`; `lib/layouts/grub_config/grub_config.dart` (Flutter-GRUB-Screen als Referenz für die GTK-Fassung)
- Fixtures: `test/fixtures/graphics_setup_*.txt`, `gnome_extensions_*.txt`, `flatpak_updates_*.txt`, `fwupd_*.txt`

## Abnahme
- [ ] Fixture `modeset=0` → gelb mit Satz; `modeset=1` + Preserve gesetzt → grün
- [ ] Erweiterung `OUT_OF_DATE` in der Fixture → gelb mit Name
- [ ] Fixture „Update auf known-bad-Version" → rot vor der Installation
- [ ] Ohne NVIDIA → „nicht zutreffend"; ohne `fwupdmgr`/`flatpak` → Zeile entfällt

## Abhängigkeiten
Blockiert durch: #82, #77 (nur Teil B) · ⚡ Teil A sofort startbar · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: `fwupdmgr --json` fehlt in der Version → Zeile weglassen, nicht raten._

_Tier: QoL · Größe: M · shell:gtk · Gates: `cd packages/la_core && dart test` · `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic ST (Teilplan ST5)._
```

---

## Issue 23 — [V1.2] GA2 Steam-Bibliotheken & Platzfresser

**Meilenstein:** V1.2 · **Labels:** `epic:ga`, `tier:n2h`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
Steam-Bibliotheken auf mehreren Laufwerken, verwaiste Proton-Präfixe und Shader-Caches fressen still Platz. Eine Übersicht mit Vorschau und Papierkorb statt `du -sh` von Hand. Referenz SP2/#84 (Vorschau-Muster).

## Scope
- Parser in la_core (`lib/src/parsers/vdf.dart`, Mini-VDF/KeyValues): Steam-Wurzeln `~/.steam/steam`, `~/.local/share/Steam`, Flatpak-Pfad `~/.var/app/com.valvesoftware.Steam/data/Steam`; `steamapps/libraryfolders.vdf` → Bibliotheken; je Bibliothek `appmanifest_*.acf` (Name, `SizeOnDisk`, `LastUpdated`), Größen von `compatdata/<appid>` und `shadercache/<appid>`; verwaiste Verzeichnisse = ohne passendes Manifest.
- Karte „Steam": Bibliotheken mit Mount-Ampel (SP3), Top-N nach Größe, verwaiste Präfixe mit Vorschau → `gio trash <pfad>` nach Bestätigung (scheitert auf Fremd-Dateisystemen → Hinweis, **nie `rm`**); Hand-off „Steam öffnen" (WZ3).
- Grenzen: nur Nutzerdateien; kein Root; keine Löschung ohne Bestätigung.

## Andockpunkte
- `packages/la_core/lib/src/parsers/vdf.dart`, Probe `steam_libraries.dart`; `prototype/gtk/` Karte (DS5)
- Fixtures: `test/fixtures/steam_libraryfolders.txt`, `steam_appmanifest_*.txt`, Verzeichnis-Fixture mit einem verwaisten Präfix

## Abnahme
- [ ] Fixture-VDF mit zwei Bibliotheken → zwei Karten mit korrekten Pfaden und Spielen
- [ ] Verwaistes `compatdata`-Verzeichnis erkannt; Papierkorb erst nach Bestätigung (argv-Assert `gio trash`)
- [ ] `gio trash`-Fehler (Fremd-Dateisystem) → Hinweis, keine Alternative mit `rm`
- [ ] Ohne Steam → StatusPage „nicht installiert"

## Abhängigkeiten
Blockiert durch: — (⚡ sofort startbar) · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: VDF-Varianten (Escapes, verschachtelte Blöcke) → Parser auf die zwei benötigten Dateien beschränken._

_Tier: n2h · Größe: M · shell:gtk · Gates: `cd packages/la_core && dart test` · `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic GA (Teilplan GA2)._
```

---

## Issue 24 — [V1.3] UX5 Dashboard anpassbar & Fokus-Modus

**Meilenstein:** V1.3 · **Labels:** `epic:ux`, `tier:n2h`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
Nicht jede Karte ist jeden Tag wichtig: Karten ein-/ausblenden, umsortieren, und ein Fokus-Modus mit nur Ampel-Leiste und Tages-Check.

## Scope
- Kartenliste in UX4 (Schalter + Reihenfolge, keine Drag-Pflicht), Layout in `gtk-state.json`.
- Fokus-Modus (Strg+Shift+F): nur Ampel-Leiste (#102) + Tages-Check (LB5).
- 1/2/3 Spalten über `Adw.Breakpoint` (ab 1400 px drei Spalten); Karten aus dem Katalog (DS5).
- Grenzen: nur UI-Zustand.

## Andockpunkte
- Dashboard-Modul in `mla_app.py`, `widgets.py` (DS5), `settings_page.py` (UX4), `gtk-state.json` (UX1)
- Tests: `prototype/gtk/tests/test_dashboard_layout.py` (xvfb für Breakpoints)

## Abnahme
- [ ] Ausgeblendete Karte bleibt nach Neustart weg; die Reihenfolge wird gemerkt (State-Datei)
- [ ] Fokus-Modus per Kürzel ein/aus; zeigt nur Ampeln + Tages-Check
- [ ] Drei Spalten ab 1400 px, eine Spalte unter 800 px (xvfb)

## Abhängigkeiten
Blockiert durch: DS5, UX4 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Breakpoint-Umschaltung flackert → Spaltenzahl nur bei Fenster-Ruhe anpassen._

_Tier: n2h · Größe: M · shell:gtk · Gates: `xvfb-run -a python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic UX (Teilplan UX5)._
```

---

## Issue 25 — [V1.3] UX6 Wetter-Kachel (Open-Meteo)

**Meilenstein:** V1.3 · **Labels:** `epic:ux`, `tier:n2h`, `size:S`, `shell:gtk`

### Body

```markdown
## Job
Parkliste 4.4 (#88), Mini-Variante mit Bastis Go: eine kleine Wetter-Kachel ohne Geolokalisierung, ohne API-Key, standardmäßig aus.

## Scope
- Ort manuell: config `weather.lat`/`weather.lon` (Fixtures und Doku nur mit den Beispielkoordinaten aus der Open-Meteo-Dokumentation, nie Werte vom Referenzsystem).
- Abfrage `https://api.open-meteo.com/v1/forecast?latitude=…&longitude=…&current=temperature_2m,weather_code` über `urllib.request` in einem GLib-Thread; Cache `$XDG_CACHE_HOME/linux-assistant/weather.json`, 1 h; offline → `stale`.
- Standard aus (`weather.enabled = false`); Nutzungsbedingungen (nicht-kommerziell, Attribution „Weather data by Open-Meteo.com") im Issue belegt, Attribution in der Kachel.
- Ausnahme von der Logik-Heimat-Regel: reine Kachel, bleibt in Python.
- Grenzen: kein Netzverkehr bei deaktivierter Kachel; keine Geolokalisierung; keine Dritt-Pakete.

## Andockpunkte
- `prototype/gtk/weather.py`, Dashboard-Modul, `settings_page.py` (UX4), `states.py` (UX3)
- Tests: `prototype/gtk/tests/test_weather.py` mit gefaktem `urlopen`

## Abnahme
- [ ] Kachel deaktiviert → kein `urlopen`-Aufruf (Test mit Fake)
- [ ] Fixture-Antwort rendert Temperatur und Symbol zum `weather_code`
- [ ] Attribution sichtbar; der Cache verhindert einen zweiten Aufruf innerhalb einer Stunde (Test mit Fixture-Uhr)

## Abhängigkeiten
Blockiert durch: — (⚡ sofort startbar) · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Nutzungsbedingungen ändern sich → die Kachel zu entfernen ist legitim (n2h-Regel im MANIFEST)._

_Tier: n2h · Größe: S · shell:gtk · Gates: `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic UX (Teilplan UX6, Parkliste 4.4)._
```

---

## Issue 26 — [V1.3] LB6 ntfy-Ziel im Wächter

**Meilenstein:** V1.3 · **Labels:** `epic:lb`, `tier:n2h`, `size:S`, `shell:gtk`

### Body

```markdown
## Job
Parkliste „Handy-Push" (#88), Mini-Variante mit Bastis Go: Der Wächter darf optional ein ntfy-Ziel benachrichtigen — nur bei Übergängen nach Rot, standardmäßig aus, Token nie im Klartext. Baut auf LB3/#66 und LB4 auf.

## Scope
- config `ntfy.enabled` (Default false), `ntfy.url`, `ntfy.topic`; Token ausschließlich über den Secret Service (`secret-tool lookup service linux-assistant key ntfy-token`). Keyring gesperrt oder kein Session-Bus → Versand entfällt still (Log-Zeile ohne Token), nie ein Prompt, nie eine Datei (Nie-Liste: kein Klartext-Fallback).
- Nur Übergänge nach Rot (LB4-Entprellung, Ruhezeiten), Ratenbegrenzung 1 Nachricht je Probe und Stunde.
- Versand aus `la_probe` über `packages/la_core/lib/src/io/http_sender.dart` (injizierbar, `dart:io` `HttpClient`); Sendefehler blockieren den Wächter-Lauf nicht.
- „Test senden" in UX4.
- Grenzen: keine Secrets in config/Logs; kein Root.

## Andockpunkte
- `packages/la_core/bin/la_probe.dart` (Wächter, #66), neu `lib/src/io/http_sender.dart`, `lib/src/notify_ntfy.dart`; UX4 (`settings_page.py`)
- Tests: Fixture-HTTP-Server in `packages/la_core/test/`, Grep-Gate über Logs/config-Fixtures

## Abnahme
- [ ] Übergang nach Rot → genau ein POST an den Fixture-Server mit Topic und Satz
- [ ] Gesperrter Keyring (Fake liefert Fehler) → kein Versand, Log ohne Token, der Lauf endet grün
- [ ] Der Token taucht weder in Logs noch in `config.json` auf (Grep-Gate)
- [ ] `ntfy.enabled = false` → kein Netzzugriff (der Fake-Sender bleibt ungerufen)

## Abhängigkeiten
Blockiert durch: #66, LB4 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: `secret-tool` fehlt → Funktion deaktiviert mit Hinweis, nie Klartext._

_Tier: n2h · Größe: S · shell:gtk · Gates: `cd packages/la_core && dart test`._
_Quelle: Ausbauplan V1.1–V1.3, Epic LB (Teilplan LB6, Parkliste Handy-Push)._
```

---

## Issue 27 — [V1.3] DI6 Odysseus „Ungelesen: N"

**Meilenstein:** V1.3 · **Labels:** `epic:di`, `tier:n2h`, `size:S`, `shell:gtk`

### Body

```markdown
## Job
Parkliste 4.11 (#88), Mini-Variante mit Bastis Go: nur die Zahl ungelesener Nachrichten über die eigene Scoped-API, kein Mail-Client. Nach dem DI3-Muster (#69), Tunnel-Status aus DI5.

## Scope
- Generisches Schema, kein Wissen über das private Backend im Code: `GET <base_url><path>` mit `Authorization: Bearer <token>` → JSON `{"unread": <int>}`; `agents.unread.base_url` und `agents.unread.path` aus config; Token aus dem Secret Service (`secret-tool lookup service linux-assistant key odysseus-token`), gesperrt → `stale`.
- Anzeige: Zähler im Agenten-Tile + Hand-off „Im Browser öffnen" (config-URL, WZ3). Tunnel tot (DI5) → `stale` mit Satz.
- Grenzen: nie Inhalte, nie Absender; kein Klartext-Token; fremde Backends nie Core.

## Andockpunkte
- `packages/la_core/lib/src/probes/unread_count.dart` über `http_sender.dart` (LB6) oder `la_probe --json unread_count`; Agenten-Tile (GTK-Fassung von #69)
- Fixtures: HTTP-Antworten 200/401/Timeout

## Abnahme
- [ ] Fixture 200 → Zahl im Tile; 401 → `stale` mit Satz; Timeout → `stale`
- [ ] Der Token taucht nirgends außer im Secret Service auf (Grep-Gate)
- [ ] Deaktiviert (keine `base_url`) → kein Netzzugriff

## Abhängigkeiten
Blockiert durch: #69, DI5 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Die API liefert kein `unread`-Feld → Probe `unknown`, kein Rätselraten über andere Felder._

_Tier: n2h · Größe: S · shell:gtk · Gates: `cd packages/la_core && dart test`._
_Quelle: Ausbauplan V1.1–V1.3, Epic DI (Teilplan DI6, Parkliste 4.11)._
```

---

## Issue 28 — [V1.3] ST6 Wochenbericht

**Meilenstein:** V1.3 · **Labels:** `epic:st`, `tier:n2h`, `size:M`, `shell:gtk`

### Body

```markdown
## Job
Einmal pro Woche eine Seite: Boots und Freezes, Updates, Platten-Trend, Backup-Erfolge, Wächter-Übergänge — als Markdown in die Notizen oder den Obsidian-Eingang. Schwärzung wie im Support-Bericht ST3/#78 (gilt für GTK sinngemäß).

## Scope
- `la_probe --weekly` + User-Units `linux-assistant-weekly.service/.timer` im .deb (Muster #66), Aktivierung per Schalter in UX4.
- Abschnitte: Boots (Dauer, sauber/unsauber, Grafik-Ereignisse — ST4), Updates Kernel/NVIDIA (#82), Platten-Trend (#83), Backup-Erfolge (#63/#101), Wächter-Übergänge (LB4-History).
- Ausgabe `$XDG_STATE_HOME/linux-assistant/reports/<yyyy-ww>.md`; optional Kopie in den Notizordner (WZ2-Muster, Inbox-first); Benachrichtigung „Wochenbericht liegt bereit" (GN3).
- Schwärzung aus ST3 (Hostnamen, IPs, Pfade unter dem Home-Verzeichnis).
- Grenzen: nur Lesen; kein Root; keine Secrets.

## Andockpunkte
- `packages/la_core/bin/la_probe.dart`, neu `lib/src/report/weekly.dart`, Schwärzung aus #78, Units neben #66 in `build-deb.sh`
- Fixtures: eine Fixture-Woche aus den vorhandenen Probe-Fixtures

## Abnahme
- [ ] Fixture-Woche → Bericht mit allen fünf Abschnitten
- [ ] Der Bericht enthält keine Hostnamen/IPs/Home-Pfade (Grep-Test)
- [ ] Die Timer-Unit landet im .deb; `systemctl --user list-timers` zeigt sie nach Aktivierung (manuell)

## Abhängigkeiten
Blockiert durch: #66, ST4, #82, #83, #63, #101 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Einzelne Quellen fehlen → der Abschnitt entfällt mit Hinweis, der Bericht erscheint trotzdem._

_Tier: n2h · Größe: M · shell:gtk · Gates: `cd packages/la_core && dart test`._
_Quelle: Ausbauplan V1.1–V1.3, Epic ST (Teilplan ST6)._
```

---

## Issue 29 — [V1.3] DI7 Lab-Status: Container-Labs & VMs

**Meilenstein:** V1.3 · **Labels:** `epic:di`, `tier:n2h`, `size:S`, `shell:gtk`

### Body

```markdown
## Job
Container-basierte Labs (z. B. eine Windows-Umgebung im Container) und VMs laufen über eigene User-Timer; eine Karte zeigt, was läuft und wann der nächste Lauf ist.

## Scope
- Karte „Lab": Container nach Name-Muster (`lab.container_patterns`, z. B. `["<projekt>-*"]`) + zugehörige User-Timer (`lab.timer_patterns`) mit nächstem Lauf (`systemctl --user list-timers -o json`); VirtualBox optional (`VBoxManage list runningvms`, wenn vorhanden, sonst entfällt die Zeile).
- Start/Stop nur über User-Units bzw. Docker-CLI nach Bestätigung; keine VM-Innenansicht.
- Grenzen: keine Unit-/Container-Namen im Code (nur config); kein Root.

## Andockpunkte
- `packages/la_core/lib/src/probes/lab_status.dart` (nutzt Parser aus #67/#68), `prototype/gtk/` Karte (DS5), UX4 (Muster)
- Fixtures: `docker_ps`-Fixture mit Lab-Container, `list-timers`-Fixture, VBox-Fixture

## Abnahme
- [ ] Fixture mit laufendem Container + Timern → Karte mit nächstem Lauf
- [ ] Ohne Docker/VBox → StatusPage bzw. die Zeile entfällt, kein Fehler
- [ ] Grep-Gate: keine Container-/Unit-Namen außerhalb von config und Fixtures

## Abhängigkeiten
Blockiert durch: — (⚡ sofort startbar; Parser aus #67/#68 wiederverwenden, sobald vorhanden) · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: `VBoxManage` hängt ohne Display → Timeout 3 s, dann „unbekannt"._

_Tier: n2h · Größe: S · shell:gtk · Gates: `cd packages/la_core && dart test` · `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic DI (Teilplan DI7)._
```

---

## Issue 30 — [V1.3] DI8 Tailscale-Status

**Meilenstein:** V1.3 · **Labels:** `epic:di`, `tier:n2h`, `size:S`, `shell:gtk`

### Body

```markdown
## Job
Ist das Tailnet verbunden und Tailscale-SSH aktiv? Das ist der Rettungsweg vom Handy beim nächsten Desktop-Freeze (ST4). Referenz DI1/#67 (n2h-Interface-Probe; Proton-VPN bleibt generisch dort, Parkliste 4.10 geparkt).

## Scope
- Probe `tailscale_status` in la_core aus `tailscale status --json` (läuft als Nutzer): `BackendState`, Self online, Peers online/gesamt, Tailscale-SSH aktiv (Feld aus der Fixture bestimmen), Exit-Node aktiv.
- Anzeige **ohne IPs und DNS-Namen** (nur Zähler und Flags — öffentliches Repo, Screenshots); Hand-off „Konsole im Browser" (config-URL, WZ3).
- Grenzen: nur Lesen; kein Root; ohne Binary „nicht installiert".

## Andockpunkte
- `packages/la_core/lib/src/probes/tailscale_status.dart`, Parser `tailscale_json.dart`; Karte (DS5)
- Fixtures: `test/fixtures/tailscale_status_*.txt` (geschwärzt: keine IPs, keine Hostnamen, keine Keys)

## Abnahme
- [ ] Fixture-JSON → Peer-Zähler, Backend-Zustand, SSH-Flag
- [ ] Die Ausgabe der Probe enthält keine IP-Adressen und keine DNS-Namen (Regex-Test)
- [ ] Ohne `tailscale` → „nicht installiert"; `BackendState` ≠ Running → gelb mit Satz

## Abhängigkeiten
Blockiert durch: — (⚡ sofort startbar) · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: JSON-Felder ändern sich zwischen Versionen → nur die genannten Felder lesen, Rest ignorieren._

_Tier: n2h · Größe: S · shell:gtk · Gates: `cd packages/la_core && dart test`._
_Quelle: Ausbauplan V1.1–V1.3, Epic DI (Teilplan DI8)._
```

---

## Issue 31 — [V1.3] UX7 Erster Start & Onboarding

**Meilenstein:** V1.3 · **Labels:** `epic:ux`, `tier:qol`, `size:S`, `shell:gtk`, `gate:manual`

### Body

```markdown
## Job
Beim ersten Start wählen, was das Cockpit beobachten soll, den Wächter aktivieren, den Hotkey verstehen — und wissen, dass nichts nach außen telefoniert.

## Scope
- `Adw.Dialog` beim ersten Start (Marker in `gtk-state.json`): Module/Watchlists wählen (UX4), Wächter aktivieren (optional, #66), Hotkey-Hinweis je Session-Typ (GN2), Datenschutz („keine Telemetrie; Netz nur für aktivierte Kacheln"), „Später"; Wiederaufruf aus UX4.
- Grenzen: nur Konfiguration; Abbruch hinterlässt Standardwerte.

## Andockpunkte
- `prototype/gtk/onboarding.py`, `mla_app.py` (`do_activate`), `settings_page.py`, DS7 (Texte)
- Tests: `prototype/gtk/tests/test_onboarding.py` (State-Marker, Abbruch-Pfad)

## Abnahme
- [ ] Der Dialog erscheint genau einmal (State-Test, zweiter Start ohne Dialog)
- [ ] Abbruch hinterlässt die Standardkonfiguration unverändert
- [ ] Dialog hell/dunkel gesichtet (manuell)

## Abhängigkeiten
Blockiert durch: UX4, GN2, DS7 · Blockiert: _(vom Skript gesetzt)_
_Risiko & Fallback: Zu viele Schritte → auf zwei Seiten kürzen (Beobachten, Benachrichtigen)._

_Tier: QoL · Größe: S · shell:gtk · Gates: `python3 -m unittest discover -s prototype/gtk/tests`._
_Quelle: Ausbauplan V1.1–V1.3, Epic UX (Teilplan UX7)._
```

---

## Issue 32 — [V1.3] Abschluss V1.x — Parkliste, Doku, features.csv

**Meilenstein:** V1.3 · **Labels:** `roadmap`, `size:S`, `shell:gtk`

### Body

```markdown
## Scope
Sammel-Issue zum Abschluss der Wellen V1.1–V1.3.
- Parkliste (#88) aktualisieren: Mini-Varianten aktiv (UX6 Wetter, LB6 ntfy, DI6 Ungelesen); Terminal-Übergabe in WZ3/TE4, Sidebar einklappbar in UX1, Proton-Status generisch in #67/DI8; Dock bleibt geparkt.
- `features.csv`: eine Zeile je V1.x-Funktion (21 Felder, `yes` nur für Zorin OS und GNOME, sonst `?`), geprüft mit dem CSV-Check.
- `docs/mla-next/MILESTONES.md`, Wiki (Roadmap, Admin-Hub, Architecture) und `MANIFEST.md`-Tier-Check nachziehen; `tool/sync-wiki.sh`.
- Doku-Altlasten abräumen oder begründen: `docs/design/admin-hub-followups.md` und `docs/wiki/Roadmap.md` („Issues deaktiviert"), `docs/handoff/README.md`-Statusspalte, `docs/wiki/Release-Process.md` Bump-Beispiel 0.7.2, `docs/handoff/roadmap.md` auf `main` mit veralteten V0.9-Modulen.

## Abnahme
- [ ] CSV-Check grün; jede V1.x-Funktion hat eine Zeile mit Tier
- [ ] `tool/sync-wiki.sh` (Vorschau) zeigt nur die erwarteten Seiten
- [ ] Parkliste-Tabelle in #88 auf Stand
- [ ] Die vier Doku-Altlasten korrigiert oder je mit Verweis begründet

## Abhängigkeiten
Blockiert durch: alle V1.x-Teilpläne (zuletzt) · Blockiert: —

_Größe: S · shell:gtk · Gates: CSV-Check, Leak-Grep._
_Quelle: Ausbauplan V1.1–V1.3, Abschluss._
```

---

## Zusammenfassung (Zuordnungstabelle, angelegt 2026-10-18)

| # | GitHub | ID | Titel | Meilenstein | Labels |
|---|---|---|---|---|---|
| 1 | #120 | FU4 | Generischer Probe-Vertrag über IPC | V1.1 | epic:fu, tier:core, size:M, shell:gtk |
| 2 | #121 | DS7 | l10n-Grundgerüst GTK | V1.1 | epic:ds, tier:qol, size:S, shell:gtk |
| 3 | #122 | UX1 | Navigation, Fensterzustand & Tastatur-Grundgerüst | V1.1 | epic:ux, tier:qol, size:M, shell:gtk |
| 4 | #123 | UX2 | Kontext-Inspektor (rechte Leiste) | V1.1 | epic:ux, tier:qol, size:M, shell:gtk |
| 5 | #124 | UX3 | Leer-, Lade-, Stale- und Fehlerzustände | V1.1 | epic:ux, tier:qol, size:S, shell:gtk |
| 6 | #125 | UX4 | Einstellungen als Seite | V1.1 | epic:ux, tier:qol, size:M, shell:gtk |
| 7 | #126 | DS5 | Komponenten-Katalog, Galerie & GTK-CI-Gate | V1.1 | epic:ds, tier:qol, size:M, shell:gtk, gate:manual |
| 8 | #127 | LB4 | Ampel-Feinschliff: Bekannt, Snooze, Ruhezeiten, Verlauf | V1.1 | epic:lb, tier:qol, size:M, shell:gtk |
| 9 | #128 | LB5 | Tages-Check „Heute" | V1.1 | epic:lb, tier:qol, size:M, shell:gtk |
| 10 | #129 | ST4 | Grafik-Stabilitäts-Wache (NVIDIA/Wayland) | V1.1 | epic:st, tier:qol, size:M, shell:gtk |
| 11 | #130 | GA1 | Gaming-Vorflug | V1.1 | epic:ga, tier:qol, size:M, shell:gtk |
| 12 | #131 | SP3 | Speicher-Feinschliff: Mounts, Timeshift, SMART | V1.1 | epic:sp, tier:qol, size:M, shell:gtk |
| 13 | #132 | GN4 | App-ID, Desktop-Einbindung & Autostart | V1.2 | epic:gn, tier:qol, size:S, shell:gtk, gate:manual |
| 14 | #133 | GN1 | GNOME-Shell-Suchanbieter | V1.2 | epic:gn, tier:qol, size:M, shell:gtk, gate:manual |
| 15 | #134 | GN2 | Hotkey-Robustheit & Portal-Pfad | V1.2 | epic:gn, tier:qol, size:S, shell:gtk, gate:manual |
| 16 | #135 | GN3 | Benachrichtigungen mit Aktionen & Deep-Links | V1.2 | epic:gn, tier:qol, size:M, shell:gtk, gate:manual |
| 17 | #136 | DS6 | Tastatur, Accessibility & Darstellung folgt GNOME | V1.2 | epic:ds, tier:qol, size:M, shell:gtk, gate:manual |
| 18 | #137 | WZ3 | Werkstatt-Übergaben & Dashboard-Links | V1.2 | epic:wz, tier:qol, size:S, shell:gtk |
| 19 | #138 | TE4 | Palette-Aktionen & Schnellaktionen-Kacheln (GTK) | V1.2 | epic:te, tier:qol, size:M, shell:gtk |
| 20 | #139 | DI4 | Stack-Operationen & Container-Hygiene | V1.2 | epic:di, tier:qol, size:M, shell:gtk |
| 21 | #140 | DI5 | Agenten-Betrieb: Tunnel-Status & Gateway-Audit | V1.2 | epic:di, tier:n2h, size:S, shell:gtk |
| 22 | #141 | ST5 | Grafik-Setup-Check, Radar & GNOME-Erweiterungen | V1.2 | epic:st, tier:qol, size:M, shell:gtk |
| 23 | #142 | GA2 | Steam-Bibliotheken & Platzfresser | V1.2 | epic:ga, tier:n2h, size:M, shell:gtk |
| 24 | #143 | UX5 | Dashboard anpassbar & Fokus-Modus | V1.3 | epic:ux, tier:n2h, size:M, shell:gtk |
| 25 | #144 | UX6 | Wetter-Kachel (Open-Meteo) | V1.3 | epic:ux, tier:n2h, size:S, shell:gtk |
| 26 | #145 | LB6 | ntfy-Ziel im Wächter | V1.3 | epic:lb, tier:n2h, size:S, shell:gtk |
| 27 | #146 | DI6 | Odysseus „Ungelesen: N" | V1.3 | epic:di, tier:n2h, size:S, shell:gtk |
| 28 | #147 | ST6 | Wochenbericht | V1.3 | epic:st, tier:n2h, size:M, shell:gtk |
| 29 | #148 | DI7 | Lab-Status: Container-Labs & VMs | V1.3 | epic:di, tier:n2h, size:S, shell:gtk |
| 30 | #149 | DI8 | Tailscale-Status | V1.3 | epic:di, tier:n2h, size:S, shell:gtk |
| 31 | #150 | UX7 | Erster Start & Onboarding | V1.3 | epic:ux, tier:qol, size:S, shell:gtk, gate:manual |
| 32 | #151 | — | Abschluss V1.x — Parkliste, Doku, features.csv | V1.3 | roadmap, size:S, shell:gtk |
