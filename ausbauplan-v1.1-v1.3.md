# Ausbauplan „Master Linux Assistant (MLA)" — V1.1 bis V1.3 (GTK-Shell)

> Repo: `Toqsick/master-linux-assistant` · Quelle: Planungssession 2026-10-18 (Brainstorming, read-only geprüfter Evidenz-Schnappschuss, Builder-Check)
> Zerlegung in Meilensteine und Issues: `meilensteine-v1.1-v1.3.md` · `issues-v1.1-v1.3.md`
> Vorgänger: `ausbauplan-v0.8.6-v1.0.md` (dessen Leitplanken, Nie-Liste und Security-Invarianten gelten unverändert weiter).

> **Für ausführende Agenten:** Dies ist ein Master-Plan. Umgesetzt wird nie direkt aus ihm, sondern aus
> dem GitHub-Issue des Teilplans (Body in `issues-v1.1-v1.3.md`) und dem Kurzdesign/Teilplan, der beim
> Start entsteht. Jede ID (UX1, ST4, …) = ein Issue. Abschnitt „Für ausführende Agenten" unten beschreibt
> den Ablauf.

## Kontext

**Warum:** Nach V1.0 „Cockpit komplett" soll die Admin-Steuerzentrale Alltagskomfort bekommen: QoL und
Nice-to-haves, zugeschnitten auf das Referenzsystem (Zorin OS 18.1, GNOME 46, Wayland, NVIDIA-Laptop,
Docker-Stacks, Agenten, Gaming, mehrere Laufwerke), mit reifer UI/UX — und so festgehalten, dass autonome
Agenten die Pakete ohne Rückfragen ziehen können.

**Stand 2026-10-18 (verifiziert):**
- Drei Stränge auf GitHub: V0.8.1–V0.8.5-Härtung (Milestones 1–5, PR #118 offen) · Ausbauplan
  V0.8.6–V1.0 (Milestones 6–11, Issues #58–#88; FU1/#60 fertig) · MLA-Next-GTK-Track (Milestones 12–18,
  Issues #90–#106; #93/#94/#95 fertig, PR #119 = A5 Monitor offen). 0.4.x = Flutter-vs-GTK-Entscheid (#106).
- Code: `prototype/gtk/mla_app.py` (GTK4/libadwaita-Scaffold mit vier Fixture-Modulen und rechter
  Kontextleiste), Tokens `tokens.css`/`tokens-dark.css` mit Gate `tests/test_tokens.py`;
  `packages/la_core` mit `ModuleRegistry`, `ProbeRegistry`, `Probe`/`ProbeResult`/`ProbeSeverity`,
  `ProbeStatus`/`ProbeState`, `EventBus`, Parsern und der CLI `la_probe` (heute nur `--version`).
  Registry und Probes werden von keinem Produktionsprozess konstruiert. IPC nur als Entwurf
  (`docs/mla-next/IPC_CONTRACT.md`). Keine Notifications, keine User-Units, kein Autostart, keine
  D-Bus-Dienste, keine GTK-l10n.

**Entscheidungen (2026-10-18):**
- **Ziel-Shell = GTK (MLA-Next)**, nicht der Flutter-Hub.
- **Drei Wellen V1.1–V1.3**, je 9–12 Issues.
- **Parkliste (#88):** die drei günstigsten Mini-Varianten werden geöffnet — Wetter (Open-Meteo),
  ntfy-Ziel im Wächter, Odysseus „Ungelesen: N".
- **Use-Case-Schwerpunkte:** NVIDIA/Wayland-Stabilität · Docker & Agenten-Betrieb · Gaming & Leistung ·
  Platten & Backups.
- **Verifikation bewusst schlank:** 3–5 Abnahme-Boxen je Issue, eine Gates-Zeile, kein
  Reviewer-Handoff; die QA-Infrastruktur entsteht in V0.9.x–V1.0.

## Prämisse und Rückfallregel

V1.x setzt „V1.0 Cockpit komplett" **auf der GTK-Shell** voraus: Der Entscheid in MLA-Next 0.4.x (#106)
fällt für GTK, und die Teilpläne V0.9–V0.12 werden danach auf GTK umgeschrieben (nicht Teil dieses
Plans). Jedes V1.x-Issue ist auf sein **GTK-Delta** zum bestehenden Issue geschnitten und verweist mit
dem Einzeiler „#NN gilt für GTK sinngemäß: Kern = la_core/la_probe, Flutter-UI-Teil entfällt".

**Rückfall:** Fällt der Entscheid gegen GTK, bleibt der la_core-Anteil jedes Issues gültig (Probes, Parser,
CLI, Zustandsdateien); nur die UI-Hälfte wird auf den Flutter-Hub umgeschrieben. Das steht hier einmal
und wird nicht in jedem Issue wiederholt.

## Leitplanken V1.x (Ergänzung zu den Leitplanken des Ausbauplans V0.8.6–V1.0)

1. **Logik-Heimat:** Parser und Probes → `packages/la_core` (Dart, Fixtures in `test/fixtures/*.txt`),
   erreichbar über `la_probe --json <probe-id>` (CLI-Zwischenstufe ohne Socket) und später über IPC
   (FU4). Python (`prototype/gtk/`) übernimmt nur Darstellung, UI-Zustand und GNOME-Nähte (D-Bus,
   Portale, Desktop-Dateien). Ausnahme: UX6 Wetter (reine Kachel, standardmäßig aus) bleibt Python.
2. **Zustandsdateien** (Schreiber → Leser, je mit `schema`-Feld, Schreiben atomar):

   | Datei | Schreiber | Leser | Inhalt |
   |---|---|---|---|
   | `$XDG_CONFIG_HOME/linux-assistant/config.json` | GTK (UX4) | la_probe, Flutter | Einstellungen; unbekannte Keys bleiben erhalten |
   | `$XDG_STATE_HOME/linux-assistant/status.json` | la_probe (#66) | GTK | letzter Probe-Stand |
   | `$XDG_STATE_HOME/linux-assistant/status-history.jsonl` | la_probe (LB4) | GTK | Übergänge, Ring 30 Tage |
   | `$XDG_STATE_HOME/linux-assistant/state.json` | GTK (LB4) | la_probe | Bekannt/Snooze/Ruhezeiten/erledigt (Schema in la_core) |
   | `$XDG_CONFIG_HOME/linux-assistant/gtk-state.json` | GTK (UX1) | GTK | Fenster, Layout, Onboarding-Marker |

3. **Prozess-Modell:** kein Dauerprozess. Der IPC-Host (#100) ist ein Kindprozess der GTK-App
   (`Gio.Subprocess`) und endet mit ihr; der Wächter bleibt systemd-User-Timer (#66); der
   Shell-Suchanbieter (GN1) läuft als `IS_SERVICE` mit `hold()/release()` und Inaktivitäts-Timeout.
4. **App-ID ist Schritt 0** (GN4): Desktop-Datei, D-Bus-`.service` und die Aktion `app.open::<module>`
   gehören zu GN4; GN1/GN3 konsumieren sie. Vorläufig `dev.toqsick.MlaPrototype` für Tests, final nach #106.
5. **Fremdprogramme starten:** nie `bash -c`; detached über `Gio.AppInfo.create_from_commandline(...).launch()`,
   `Gtk.FileLauncher`, `Gtk.UriLauncher`; Programmsuche über `GLib.find_program_in_path` mit fester
   Kandidatenliste (Sicherheitsentscheid #110-C beachten).
6. **API-Floor:** GTK 4.14 / libadwaita 1.5 (Zorin 18): `Adw.PreferencesDialog/PreferencesPage/Breakpoint/
   Dialog/Banner/Toast/StatusPage/OverlaySplitView/AlertDialog`, `Gtk.ShortcutsWindow/FileLauncher/
   UriLauncher/Snapshot` ✓; `Adw.Spinner/ButtonRow/ShortcutsDialog` ✗. Python 3.12 + PyGObject, keine
   pip-Pakete; Sparklines über `Gtk.Snapshot` (kein pycairo). Dart: kein neues pub-Paket; HTTP über
   `dart:io` `HttpClient`.
7. **GTK-Teststrategie:** Modelle headless (`unittest`, Muster aus #119); Widget-Tests unter `xvfb-run`
   mit apt `xvfb gir1.2-gtk-4.0 gir1.2-adw-1` (CI-Schritt kommt mit DS5); sonst `gate:manual`.
   Gates-Zeile je Issue: `python3 -m unittest discover -s prototype/gtk/tests` · `cd packages/la_core &&
   dart test`; Flutter-Gates zusätzlich, wenn `config.json`-Kompatibilität berührt ist (UX4, TE4, LB4).
8. **l10n GTK (DS7):** gettext-Domain `linux-assistant`, `.po` de/en, Key-Konvention = ARB-Key; Probe-
   `messageKey`s zeigen auf dieselben Keys. Satz-Abnahmen setzen DS7 voraus.
9. **Epic-Grenze:** DS = Tokens/Komponenten/A11y/l10n · UX = Navigation/Zustände/Einstellungen/Dashboard ·
   GN = GNOME-Nähte · ST = Stabilität/Diagnose · GA = Gaming/Leistung · LB/DI/SP/TE/WZ/FU wie bisher.
10. **`gate:manual`** = „Abnahme nur am lebenden GNOME möglich": GN1–GN4, DS5, DS6, UX7. Manuelle
    Abnahme-Boxen sind als solche markiert.
11. **Öffentliches Repo:** keine privaten Unit-Namen, Ports, Hostnamen, Koordinaten oder Pfade in Code,
    Doku und Issues — nur Muster (`<projekt>-*`), Platzhalter (`<port>`), Demo-Werte und `config`-Keys.
    Der Leak-Grep aus V0.8.5 gilt für alle neuen Dateien und Fixtures.
12. **Labels:** `shell:gtk` markiert das Ziel; `track:mla-next` wird nicht gesetzt (es beschreibt das
    Experiment, V1.x ist Produktplanung). Neue Epics: `epic:ux`, `epic:gn`, `epic:ga`.

## Evidenz-Schnappschuss (2026-10-18, read-only, generalisiert)

| Befund | Quelle | führt zu |
|---|---|---|
| GNOME Shell 46, GTK 4.14, libadwaita 1.5, xdg-desktop-portal-gnome 46.x: Portale Background/Notification/Settings vorhanden, **kein GlobalShortcuts-Portal** | `busctl --user introspect`, Portal-Dateien | GN2 (gsettings bleibt), GN3, GN4, API-Floor |
| Shell-Suchanbieter werden nur aus System-Datadirs geladen; ein Custom-Keybinding für die App existiert | `/usr/share/gnome-shell/search-providers/`, gsettings | GN1 (Abnahme über .deb), GN2 |
| `journalctl -k -o json`, `--list-boots`, `tailscale status --json`, `docker ps`, `gamemoded -s`, `powerprofilesctl get`, `dkms status`, UDisks2-`SmartCriticalWarning` laufen als Nutzer | CLI/D-Bus | ST4, ST5, DI8, DI4, GA1, SP3 — alles ohne Root |
| Wiederholte Treiber-Livelocks unter Wayland, ein hängender Neustart; Runbook außerhalb der App; `/dev/watchdog` fehlt | Journal, Runbook | ST4 (Bereitschaft inkl. „nicht vorhanden"), ST5, DI8 (SSH-Rettungsweg) |
| Zwei Steam-Bibliotheken über `libraryfolders.vdf`; Flatpak-Steam nicht vorhanden | Dateisystem | GA2 (VDF-Parser statt Pfadraten) |
| `/etc/timeshift/timeshift.json` als Nutzer lesbar; der Zeitplan war unbemerkt regrediert | Dateisystem | SP3 (Soll-Abgleich) |
| Mehrere User-Timer für Backup, Heartbeat und Labs; keine fehlgeschlagene Unit zum Zeitpunkt der Aufnahme | `systemctl --user list-timers` | LB4/LB5, DI7 (Muster aus config) |
| `secret-tool`, `gapplication`, `gnome-terminal` vorhanden; `kgx`/`ptyxis` nicht | `which` | LB6/DI6 (Secret Service), GN2/GN3, WZ3 (Kandidatenreihenfolge) |
| PR #119 ändert `mla_app.py` und bringt `monitor_ui.py`/`monitor_model.py` | GitHub | DS5 (Extraktion), UX1 (Andockpunkte nach Merge) |
| Flutter-`ConfigHandler` ist eine flache Key/Value-Map; `custom_actions`/`exposure_baseline` existieren noch nicht | `lib/services/config_handler.dart`, #73, #80 | UX4 (unbekannte Keys erhalten, Schemata übernehmen) |

## Ideenpool — Jobs auf dem Referenzsystem

| Job | V1.x-Teilpläne |
|---|---|
| „Ist alles in Ordnung?" | FU4, LB4, LB5, SP3, ST4 |
| „Was ist passiert, was hat sich geändert?" | ST4, ST5, ST6 |
| „Meine Dienste im Griff" | DI4, DI5, DI6, DI7, DI8 |
| „Vor dem Spielen prüfen" | GA1, GA2 |
| „Schnell erledigen" | UX1, GN1, GN2, TE4, WZ3 |
| „Die Oberfläche trägt" | DS5, DS6, DS7, UX2, UX3, UX4, UX5, UX7, GN3, GN4, UX6 |

- **Weglassen statt bauen:** kein GlobalShortcuts-Portal versprechen, kein Snapshot-Listing über den
  Sicherheits-Report, kein eigener D-Bus-Stack (`busctl`/GI genügen), kein pycairo.
- **Integrieren statt nachbauen:** Terminal, Dateien, Obsidian, Grafana per Übergabe (WZ3); Steam,
  Timeshift, Tailscale, Docker nur lesen und starten.
- **Bewusst draußen:** Tray, eingebettetes Terminal, Inline-Webview, Dauerprozess, Clipboard-Historie,
  Proton-Vollclient, Gmail-Vollclient (Nie-Liste).

## Release-Wellen

| Release | Titel | Teilpläne | ⚡ sofort startbar |
|---|---|---|---|
| **V1.1** | Cockpit-QoL & UX | FU4, DS7, UX1, UX2, UX3, UX4, DS5, LB4, LB5, ST4, GA1, SP3 | DS7, UX1, UX2 (A), UX3 (A), UX4 (A), ST4, GA1, SP3 (A) |
| **V1.2** | Zorin/GNOME-Integration & Werkzeuge | GN4, GN1, GN2, GN3, DS6, WZ3, TE4, DI4, DI5, ST5, GA2 | GN4 (A), GN2 (A), WZ3, ST5 (A), GA2 |
| **V1.3** | Nice-to-haves & Parkliste | UX5, UX6, LB6, DI6, ST6, DI7, DI8, UX7, Abschluss | UX6, DI7, DI8 |

Die Wellen sind thematisch geschnitten, nicht streng sequenziell: Ein ⚡-Teilplan aus V1.2 darf vor
einem blockierten V1.1-Teilplan starten.

## Abhängigkeiten

```text
#100 A4 IPC ─► FU4 ─► LB4, LB5, GN3, UX2(Verlauf)     #102 Lagebild ─► LB4, LB5
#66 Wächter ─► LB4, LB5, GN3, LB6, ST6                 #96/#119 Monitor ─► DS5 ─► UX3(Galerie), DS6, UX5
#97 A11y ─► DS6            #98/#99 ─► GN1(Notizen), TE4                   DS7 ─► UX4(Sprache), TE4, UX7
GN4 (App-ID, Schritt 0) ─► GN1, GN3;  #105 Packaging ─► GN1, GN4(Teil B);  #106 ─► finale App-ID
UX4 ─► GN2(Diagnose), UX5, UX7;  UX1 ─► UX2(Zustand)
DI2/#68 ─► DI4;  DI3/#69 + A8/#103 ─► DI5 ─► DI6;  SP1/#83 ─► SP3(Prognose), LB5, ST6
SI3/#82 + ST2/#77 ─► ST5(Teil B);  ST4 ─► LB5, ST5, ST6, DI8(Verweis);  #63/#101 ─► LB5, ST6
```

Das Anlege-Skript setzt aus diesem Graphen die Zeilen „Blockiert durch / Blockiert" in den Issues.

## Epics & Teilpläne

Größen: S = höchstens eine Session · M = 2–3 Sessions · L = 4+ Sessions. Vollständige Bodies in
`issues-v1.1-v1.3.md`; hier die Kurzfassung.

### Welle V1.1 — Cockpit-QoL & UX

- **FU4 Generischer Probe-Vertrag über IPC** — Core · M · `la_probe --json <probe-id>` als
  CLI-Backend, `probe.list/get/watch` + `probe.changed` über IPC (registry-getrieben; `backup.*` wird
  Spezialfall), GTK-`ProbeStore` mit Backends fixture → cli → ipc. Blockiert durch #100, #102.
- **DS7 l10n-Grundgerüst GTK** ⚡ — QoL · S · gettext-Domain, `.po` de/en, Key = ARB-Key, Ratchet-Test.
- **UX1 Navigation, Fensterzustand & Tastatur** ⚡ — QoL · M · `Adw.OverlaySplitView`, Rail unter 1000 px,
  `gtk-state.json`, Strg+1…9/Esc/F5/Strg+B, `Gtk.ShortcutsWindow` aus zentraler Tabelle.
- **UX2 Kontext-Inspektor** ⚡ (A) — QoL · M · Panel mit Chip, Satz, Quelle/Messzeit/Einheit, Aktionen,
  Verlauf (nach LB4); `DetailsProvider`-Protokoll je Modul.
- **UX3 Leer-, Lade-, Stale-, Fehlerzustände** ⚡ (A) — QoL · S · `states.py`, Hardcode-Gate auf alle `.py`.
- **UX4 Einstellungen als Seite** ⚡ (A) — QoL · M · `Adw.PreferencesPage` im Stack; Seiten Allgemein/
  Wächter/Watchlists/Exposition/Eigene Aktionen; `config.json` mit erhaltenen Fremd-Keys.
- **DS5 Komponenten-Katalog, Galerie & GTK-CI-Gate** — QoL · M · `widgets.py` aus `monitor_ui.py`
  extrahiert, Galerie, xvfb-Schritt in CI. Blockiert durch #96.
- **LB4 Ampel-Feinschliff** — QoL · M · `state.json` (bekannt/snooze/Ruhezeiten), `status-history.jsonl`,
  „Was tun?"-Satz. Blockiert durch #102, #66, FU4.
- **LB5 Tages-Check „Heute"** — QoL · M · Karte aus vorhandenen Probes inkl. Restore-Drill-Erinnerung;
  Zeilen abhakbar. Blockiert durch #102, #66, FU4.
- **ST4 Grafik-Stabilitäts-Wache** ⚡ — QoL · M · Probe `gpu_stability` (Journal-Marker, unsaubere Boots,
  known-bad-Treiber, Rettungs-Bereitschaft); GTK-Delta zu #76; geschwärzte Journal-Fixture.
- **GA1 Gaming-Vorflug** ⚡ — QoL · M · Probe `gaming_readiness` (GameMode, Profil, EPP, GPU, OC-Dienst,
  PSI, Platz, Inhibitoren); eine bestätigte Aktion: `powerprofilesctl set`.
- **SP3 Speicher-Feinschliff** ⚡ (A) — QoL · M · Mount-Ampeln, Timeshift-Soll-Abgleich, SMART-Flag über
  UDisks2 ohne Root; Prognose-Zeile nach #83.

### Welle V1.2 — Zorin/GNOME-Integration & Werkzeuge

- **GN4 App-ID, Desktop-Einbindung & Autostart** ⚡ (A) — QoL · S · gate:manual · Desktop-Datei mit
  Actions, D-Bus-`.service`, `app.open`, symbolisches Icon, AppStream, XDG-Autostart-Schalter.
- **GN1 GNOME-Shell-Suchanbieter** — QoL · M · gate:manual · `SearchProvider2` über `do_dbus_register`,
  Dienst-Modus mit Timeout, Notizen nur per Schalter. Blockiert durch GN4, #105.
- **GN2 Hotkey-Robustheit & Portal-Pfad** ⚡ (A) — QoL · S · gate:manual · `hotkey.py` (gsettings,
  idempotent, verwaiste Einträge), Kommando `gapplication launch`, Portal-Erkennung; GTK-Delta zu #58-Q4.
- **GN3 Benachrichtigungen mit Aktionen & Deep-Links** — QoL · M · gate:manual · `systemd-run --user
  notify-send --wait -A` → `gapplication action … open`, `Gio.Notification` in-app. Blockiert durch GN4, #66, FU4.
- **DS6 Tastatur, Accessibility & GNOME-Darstellung** — QoL · M · gate:manual · `accessible-description`
  für Ampeln, Fokus-Walk unter xvfb, Reduce-Motion, Orca-Durchgang. Blockiert durch #97, DS5.
- **WZ3 Werkstatt-Übergaben & Dashboard-Links** ⚡ — QoL · S · Terminal/Dateien/Obsidian/Links über
  `Gio.AppInfo`/`Gtk.*Launcher`, argv-Asserts; übernimmt den n2h-Link aus #85.
- **TE4 Palette-Aktionen & Schnellaktionen-Kacheln** — QoL · M · Provider für Module/Probe-Aktionen/
  Einstellungen/`custom_actions` (#73), `pinned`-Kacheln, Terminal-Modus mit argv. Blockiert durch #99, DS7.
- **DI4 Stack-Operationen & Container-Hygiene** — QoL · M · Compose-Operationen aus Labels,
  Image-Alter, `docker system df` mit Vorschau. Blockiert durch #68.
- **DI5 Tunnel-Status & Gateway-Audit** — n2h · S · Probe `tunnel_status` aus config + `ss -ltnH`,
  Audit read-only. Blockiert durch #69, #103.
- **ST5 Grafik-Setup-Check, Radar & GNOME-Erweiterungen** ⚡ (A) — QoL · M · modeset/Preserve/DKMS/
  Secure Boot, Kernel-Rollback-Bereitschaft, Erweiterungen; Radar (apt/Flatpak/Firmware) nach #82/#77.
- **GA2 Steam-Bibliotheken & Platzfresser** ⚡ — n2h · M · VDF-Parser in la_core, verwaiste Präfixe mit
  Vorschau → `gio trash`.

### Welle V1.3 — Nice-to-haves & Parkliste

- **UX5 Dashboard anpassbar & Fokus-Modus** — n2h · M · Karten ein-/ausblenden, Fokus-Modus, Breakpoints.
- **UX6 Wetter-Kachel (Open-Meteo)** ⚡ — n2h · S · Parkliste 4.4; Ort manuell, Cache, Standard aus.
- **LB6 ntfy-Ziel im Wächter** — n2h · S · Parkliste Handy-Push; Token nur im Secret Service, nur
  Übergänge nach Rot. Blockiert durch #66, LB4.
- **DI6 Odysseus „Ungelesen: N"** — n2h · S · Parkliste 4.11; generisches `GET … → {"unread": N}`.
  Blockiert durch #69, DI5.
- **ST6 Wochenbericht** — n2h · M · `la_probe --weekly` + Timer, Schwärzung aus #78. Blockiert durch
  #66, ST4, #82, #83, #63/#101.
- **DI7 Lab-Status: Container-Labs & VMs** ⚡ — n2h · S · Muster aus config, User-Timer, VBox optional.
- **DI8 Tailscale-Status** ⚡ — n2h · S · Zähler/Flags ohne IPs, SSH-Flag als Rettungsweg.
- **UX7 Erster Start & Onboarding** — QoL · S · gate:manual · `Adw.Dialog` einmalig. Blockiert durch UX4, GN2, DS7.
- **Abschluss V1.x** — roadmap · S · Parkliste, `features.csv`, Wiki, Doku-Altlasten.

## Parkliste — Stand nach V1.x-Planung

| Thema | Urteil 2026-09-23 | V1.x |
|---|---|---|
| 4.1 Hermes Web-UI/Client | geparkt | bleibt geparkt (Start-Knöpfe in #69) |
| 4.4 Wetter | Mini-Variante möglich | **UX6** (Go erteilt) |
| 4.6 Notizen-Ausbau | geparkt | bleibt geparkt (#98/#99 decken Suche/Capture) |
| 4.8 Dock / stufenlose Sidebar | Sidebar einklappbar = Mini | **UX1** (Sidebar einklappbar), Dock bleibt geparkt |
| 4.9 Terminal+ | Terminal-Übergabe = Mini | **WZ3/TE4** (Übergabe und argv-Ausführung) |
| 4.10 Proton-Hub | generischer VPN-Status = Mini | #67 (Interface-Probe), **DI8** nur Tailscale; Proton bleibt geparkt |
| 4.11 Gmail/Odysseus | „Ungelesen: N" = Mini | **DI6** (Go erteilt) |
| Handy-Push | ntfy-Ziel = Mini | **LB6** (Go erteilt) |

## Für ausführende Agenten

1. **Issue wählen:** `gh issue list --repo Toqsick/master-linux-assistant --milestone "<Milestone>" --label shell:gtk`;
   ⚡-Issues zuerst (Zeile „Abhängigkeiten" im Body); bei Teil-⚡ nur den genannten Teil A.
2. **Vor dem Start:** Issue-Body lesen (nicht diesen Plan), Andockpunkte gegen den aktuellen `main`
   prüfen (Dateien können sich seit dem Anlegen verschoben haben), bei Konflikt im Issue kommentieren.
3. **Einordnung:** bounded → Kurzdesign im Chat; architectural (FU4, GN1, GN3, LB4) → Spec, dann Teilplan.
   Plan-Datei außerhalb des Repos.
4. **Branch** `feature/mla-<issue-nr>-<slug>` von `main`; Commits mit Conventional-Commit-Scope `mla`
   und Co-Authored-By-Zeile des ausführenden Modells.
5. **Gates:** die Gates-Zeile des Issues plus die fünf bestehenden CI-Gates; Fixtures aus echten,
   geschwärzten Ausgaben; Leak-Grep über Diff und Fixtures.
6. **Abnahme:** jede Box im Issue abhaken, manuelle Boxen als „für Basti offen" markieren; PR gegen `main`
   mit Verweis auf das Issue. **Kein Push, Merge, Versions-Bump, Tag oder Policy-Update ohne Bastis OK.**
7. **Sicherheitsgrenzen (jedes Issue):** GTK-UI und Dart-Host nie als Root; keine Shell-Strings;
   polkit-Grenze unberührt (keine dritte Action); Secrets nur im Secret Service, kein Klartext-Fallback;
   keine privaten Hosts/Ports/Pfade im Code.

## Risiken

1. **#106 fällt gegen GTK** → Rückfallregel oben; la_core-Anteile bleiben, UI-Hälften werden umgeschrieben.
2. **FU4 kommt spät** → ⚡-Probes laufen über das `cli`-Backend (`la_probe --json`), kein Wartestau.
3. **App-ID wechselt nach #106** → alle Dateien beziehen die ID aus einer Konstante/Template (GN4).
4. **GNOME-Nähte sind nur manuell abnehmbar** → `gate:manual` ehrlich gesetzt; automatisierte Teile
   (D-Bus-Tests unter `dbus-run-session`, Desktop-Datei-Validierung) bleiben in CI.
5. **Leaks im öffentlichen Repo** → Fixtures mit Streichliste (ST4), keine Unit-Namen/Koordinaten in
   Issues, Grep-Gates in DI5/DI7/DI8/LB6/DI6.
6. **Scope-Drift** → jedes Issue nennt seinen Job und seinen Beleg; was keinen Beleg hat, bleibt auf der Parkliste.

## Überführung in Repo & GitHub

1. Repo-Fassung: dieser Plan, `meilensteine-v1.1-v1.3.md`, `issues-v1.1-v1.3.md`; Zeiger in
   `docs/mla-next/MILESTONES.md`, `docs/mla-next/ISSUES.md`, `docs/wiki/Roadmap.md`.
2. Leak-Grep über alle neuen Dateien — muss leer sein.
3. GitHub: Labels `epic:ux`, `epic:gn`, `epic:ga`, `shell:gtk` → Milestones 19–21 → 32 Issues → zweiter
   Lauf setzt „Blockiert durch/Blockiert" mit echten Nummern → Kommentare auf #88, #106, #100, #102,
   #66, #63, #73, #82, #83, #85 (GTK-Lesart, Namensraum, Watchlist-Muster). Zuordnungstabelle in
   `issues-v1.1-v1.3.md`.
4. Commit `docs(planning): …` auf dem Arbeits-Branch; Push und PR nur nach Bastis OK.
