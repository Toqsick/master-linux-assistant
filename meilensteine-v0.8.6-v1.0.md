# Meilensteine V0.8.6 – V1.0 — Linux Master Assistant

> Repo: `Toqsick/linux-assistant`
> Quelle: Ausbauplan V0.8.6–V1.0 (Master-Plan 2026-09-23, `ausbauplan-v0.8.6-v1.0.md`)
> Anlegen: fortlaufend ab Nummer 6 (1–5 = V0.8.1–V0.8.5, teils offen), via Web-UI (Issues → Milestones → New milestone) oder per Skript (siehe Ausbauplan, „Überführung" Schritt 3). Issue-Bodies stehen in `issues-v0.8.6-v1.0.md`.

---

## Meilenstein 6 — V0.8.6 „Sofort-Nutzen“

**Beschreibung:**

Welle 1 als ein gemeinsamer Plan mit sieben kleinen Tasks (Q1–Q7, je S): Security-Scan auf Knopfdruck statt pkexec beim Betreten der Sektion, Neustart-Badge aus `reboot-required`, Kachel fehlgeschlagene Dienste (`list-units --failed -o json`, beide Scopes), Hotkey über gsettings in Wayland und X11 (`hotkey_manager` + `libkeybinder-3.0-0` raus), Browser-Status read-only (braucht V0.8.2), ehrliche Speicher-Kachel (PSI statt RAM-Quote, zram getrennt), Feedback an Upstream abklemmen (Basti entscheidet vorab: entfernen oder Fork-Issue-Link).

**Erfolgskriterium:** Alle sieben Abnahmen auf dem Referenzsystem erfüllt (u. a. kein pkexec-Dialog beim Öffnen der Security-Sektion, Reboot-Badge sichtbar, X11- und Wayland-Hotkey-Gate grün); fünf CI-Gates grün; Voraussetzung V0.8.5 abgeschlossen.

---

## Meilenstein 7 — V0.9 „Fundament & Lagebild“

**Beschreibung:**

Fundament und erstes Lagebild: FU2 reiner Dart-Kern `packages/la_core` (Spike zuerst: `dart compile exe`, dann Probe-Vertrag und Parser-Umzug), FU1 Modul-Registry (#27, `HubModule`-Deskriptor ersetzt die switch-Blöcke), FU3 Fehlerrahmen (Fehlerbildschirm statt leerem Fenster), LB1 Lagebild-Leiste (fünf Ampeln als Registry-Probes), LB2 Backup-Cockpit (Units, Timer, Journal; heute rot, ohne dass es jemand merkt). Parallel: QA1 Gate-Automatisierungs-Spike (go/no-go) und DS1 Token-Einheit (erst nach FU1).

**Erfolgskriterium:** `la_probe --version` läuft auf Zorin ohne Session-Variablen; `dart test` + `flutter test` in `la_core` grün; ein neues Modul ist ein Listeneintrag plus Screen; die fünf Ampeln zeigen heute Backups ROT und Updates GELB (Neustart) und erklären sich je in einem Satz.

---

## Meilenstein 8 — V0.10 „Wächter & Dienste“

**Beschreibung:**

Hintergrund-Meldungen und Dienstebene: LB3 Wächter als User-Units (`linux-assistant-watch.service/.timer`, `la_probe` schreibt `status.json`, `notify-send` nur beim Übergang nach Rot, Takt 30 min + 5 min nach Login), DI1 Dienste & Timer (Watchlist, fehlgeschlagene Units, Timer; Start/Stop/Restart nur `--user`), DI2 Docker & Compose (Gruppierung nach Compose-Projekt, Expositions-Flags „umgeht UFW"), DI3 Agenten-Tile (TokenTelemetry-Budget, Hermes-Kanban-Blocker, Gateway-Status; nur CLI/systemctl-Zugriff), TE1 Such-Index-Cache (behebt „Bereite Suche vor…"). Parallel: QA2 Release-Workflow (Tag → CI → GitHub-Release mit Asset-Digest) und DS2 l10n (`_tr(` → ARB, Budgets senken).

**Erfolgskriterium:** Wächter: Ampel wird rot → genau eine Benachrichtigung, zweiter Lauf ohne Änderung → keine, App zeigt denselben Stand wie `status.json`; Docker-Screen listet Compose-Projekte mit korrekten Expositions-Flags; zweiter App-Start zeigt Suchtreffer aus dem Cache, bevor der Refresh fertig ist.

---

## Meilenstein 9 — V0.11 „Tempo & Diagnose“

**Beschreibung:**

Tempo und Diagnose: TE2 Befehlspalette (Strg+K / `>`) plus eigene Aktionen aus `config.json` (`custom_actions`, argv ohne Shell, Modus `terminal` als Nie-Listen-konforme Mini-Variante), TE3 Suchanbieter & Kleinigkeiten (Dienste/Container, GNOME-Einstellungsseiten, Notizen, Rechner offline; Privatsphäre-Modus M6; Executable-Badge), WZ2 Quick Notes (Obsidian-Inbox, `note:`-Capture, `obsidian://`-Übergabe), ST1 Boot- & Stabilitätsbericht (je Boot Dauer/Fehler/GPU/OOM, 19,9-s-Loader-Hinweis mit Sprung in den GRUB-Screen, SMART nur Spike), ST2 Änderungs-Zeitleiste (apt/flatpak/snap, Kernel und NVIDIA hervorgehoben), ST3 App-Doctor + Support-Bericht (`la_probe --doctor` ohne GUI). Parallel: DS3 Goldens + Tastatur (nach DS1). V0.11 und V0.12 sind tauschbar.

**Erfolgskriterium:** Die unsauberen Boots vom 13.–16.09. werden als solche erkannt (Fixture aus dem echten Journal); der Treiberwechsel 595.84 → 595.91 und Kernel-Updates erscheinen mit Datum in der Zeitleiste; ein Bundle ohne `additional/` startet in den Fehlerbildschirm und der Doctor nennt genau das.

---

## Meilenstein 10 — V0.12 „Sicherheit & Speicher“

**Beschreibung:**

Sicherheit und Speicher: SI1 Expositions-Check + UFW (Root-Report liefert `ss -tulpnH`, `ufw status verbose`, Docker-Bindings; Dart gleicht gegen `exposure_baseline` ab; Tailnet = Info, LAN/alle Interfaces = Warnung, Docker-Freigabe/Host-Netz = kritisch; Python-TDD, polkit unverändert), SI2 Aktions-Journal (#151; JSONL je Queue-Ausführung, nach WP-S2), SI3 Update-Radar (apt-Cache ohne `apt update`, Kernel/NVIDIA-Gruppierung, `reboot-required.pkgs`), SP1 Trend & Prognose (`disk-history.jsonl`, 180 Tage, „<Mount> voll in ~N Tagen"; braucht LB3), SP2 Kategorien & Aufräumen (Docker/journal/apt/Kernel/Papierkorb/Nutzer-Cache mit Vorschau), WZ1 Systemmonitor ausbauen (Schwellen-Badges, 1-h-History downgesampelt, kein Autostart). Parallel: DS4 Navigation (Einstellungen als Sektion, Breadcrumb, Sidebar einklappbar).

**Erfolgskriterium:** Die heutigen sechs Listener erscheinen im Expositions-Check, bis Basti sie als bekannt markiert; ein frisch gestarteter Test-Listener auf allen Interfaces wird gemeldet; mit einer Fixture des echten Verlaufs (69 → 100 %) hätte die Platten-Prognose mindestens 7 Tage vorher gewarnt; jede Queue-Ausführung landet im Aktions-Journal.

---

## Meilenstein 11 — V1.0 „Cockpit komplett“

**Beschreibung:**

Abschluss: QA3 Fixture-Bibliothek (echte, geschwärzte Zorin-Ausgaben für alle Parser, Doku in `docs/wiki/Testing.md`; Regel gilt schon ab FU2), Parkliste-Entscheide (Wiedervorlage nur mit Beleg — jedes Thema hat Urteil, Nie-Listen-konforme Mini-Variante und Beleg-Trigger in der Parkliste-Tabelle), Ende-zu-Ende-Verifikation nach der Gate-Tabelle aus `docs/wiki/Release-Process.md` in Wayland und X11, Doku-Abschluss (MANIFEST, features.csv mit allen neuen Zeilen, Architecture-Wiki).

**Erfolgskriterium:** Alle Parser laufen gegen die Fixture-Bibliothek; Parkliste-Entscheide sind dokumentiert (aktiviert mit Go oder bleibt geparkt); Gate-Tabelle in beiden Sessions abgehakt; `bash install.sh` führt Basti aus; Push und Tag erst nach seinem OK.
